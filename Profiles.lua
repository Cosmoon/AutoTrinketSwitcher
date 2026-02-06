local ATS = AutoTrinketSwitcherFrame

local function NormalizeQueueSet(queue)
    if not queue then queue = {} end
    queue[13] = queue[13] or {}
    queue[14] = queue[14] or {}
    return queue
end

local function EnsureProfileQueueSets(profile, seedActive)
    if not profile.queueSets then
        if profile.queues then
            profile.queueSets = {
                [1] = NormalizeQueueSet(profile.queues),
                [2] = { [13] = {}, [14] = {} },
            }
        else
            profile.queueSets = {
                [1] = { [13] = {}, [14] = {} },
                [2] = { [13] = {}, [14] = {} },
            }
        end
    end

    profile.queueSets[1] = NormalizeQueueSet(profile.queueSets[1])
    profile.queueSets[2] = NormalizeQueueSet(profile.queueSets[2])

    if profile.activeQueueSet ~= 1 and profile.activeQueueSet ~= 2 then
        profile.activeQueueSet = (seedActive == 2) and 2 or 1
    end

    profile.queues = profile.queueSets[profile.activeQueueSet]
end

local function CopyList(values)
    local out = {}
    if not values then return out end
    for i, v in ipairs(values) do
        out[i] = v
    end
    return out
end

local function CloneQueueSet(queueSet)
    return {
        [13] = CopyList(queueSet and queueSet[13]),
        [14] = CopyList(queueSet and queueSet[14]),
    }
end

local function CloneQueueSets(queueSets)
    return {
        [1] = CloneQueueSet(queueSets and queueSets[1]),
        [2] = CloneQueueSet(queueSets and queueSets[2]),
    }
end

local function CloneProfile(source, seedActive)
    local profile = {}
    if source and source.queueSets then
        profile.queueSets = CloneQueueSets(source.queueSets)
        profile.activeQueueSet = source.activeQueueSet
    elseif source and source.queues then
        profile.queueSets = {
            [1] = CloneQueueSet(source.queues),
            [2] = { [13] = {}, [14] = {} },
        }
        profile.activeQueueSet = source.activeQueueSet
    end
    EnsureProfileQueueSets(profile, seedActive)
    return profile
end

local function ParseSignature(signature)
    if type(signature) ~= "string" then return nil, nil, nil end
    local classTag, group, talents = signature:match("^([^:]+):G(%d+):(.+)$")
    return classTag, tonumber(group), talents
end

local function IsNoTalentsSignature(signature)
    return type(signature) == "string" and signature:match(":NO_TALENTS$") ~= nil
end

local function FindSiblingSpecSignature(db, signature)
    local classTag, group, talents = ParseSignature(signature)
    if not classTag or not group or not talents then return nil end
    local siblingGroup = (group == 1) and 2 or ((group == 2) and 1 or nil)
    if not siblingGroup then return nil end

    local sibling = string.format("%s:G%d:%s", classTag, siblingGroup, talents)
    if db and db.talentProfiles and db.talentProfiles[sibling] then
        return sibling
    end
    return nil
end

local function ProfileHasItems(profile)
    if not profile then return false end

    local function QueueHasItems(queue)
        if not queue then return false end
        return (queue[13] and #queue[13] > 0) or (queue[14] and #queue[14] > 0)
    end

    if profile.queueSets then
        if QueueHasItems(profile.queueSets[1]) then return true end
        if QueueHasItems(profile.queueSets[2]) then return true end
    end

    if profile.queues and QueueHasItems(profile.queues) then
        return true
    end

    return false
end

local function FindAnyNonEmptyProfile(db, preferredGroup)
    if not db or not db.talentProfiles then return nil end

    local fallbackProfile
    for key, profile in pairs(db.talentProfiles) do
        if ProfileHasItems(profile) then
            local _, group = ParseSignature(key)
            if preferredGroup and group == preferredGroup then
                return profile
            end
            if not fallbackProfile then
                fallbackProfile = profile
            end
        end
    end

    return fallbackProfile
end

local function FirstValidGroup(...)
    for i = 1, select("#", ...) do
        local value = tonumber(select(i, ...))
        if value and value >= 1 then
            return math.floor(value)
        end
    end
    return nil
end

local function SafeCallForGroup(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c = pcall(func, ...)
    if not ok then return nil end
    return FirstValidGroup(a, b, c)
end

local function GetActiveTalentGroupSafe()
    local group
    group = SafeCallForGroup(GetActiveTalentGroup, false, false)
    if not group then
        group = SafeCallForGroup(GetActiveTalentGroup)
    end
    if not group then
        group = SafeCallForGroup(GetActiveSpecGroup)
    end
    if not group and type(C_SpecializationInfo) == "table" and type(C_SpecializationInfo.GetActiveSpecGroup) == "function" then
        group = SafeCallForGroup(C_SpecializationInfo.GetActiveSpecGroup)
    end
    if not group and ATS and ATS.lastKnownTalentGroup then
        group = FirstValidGroup(ATS.lastKnownTalentGroup)
    end
    return group or 1
end

-- Build a stable signature of the player's current talents (Classic-style trees)
function ATS:ComputeTalentSignature()
    local _, classTag = UnitClass and UnitClass("player")
    classTag = classTag or "UNKNOWN"

    local tabs = {}
    local group = GetActiveTalentGroupSafe()
    if GetNumTalentTabs and GetTalentInfo and GetNumTalents then
        local numTabs = GetNumTalentTabs()
        for t = 1, numTabs do
            local points = 0
            local num = GetNumTalents(t)
            for i = 1, num do
                local _, _, _, _, rank = GetTalentInfo(t, i)
                points = points + (tonumber(rank) or 0)
            end
            table.insert(tabs, tostring(points))
        end
    end

    if #tabs == 0 then
        return string.format("%s:G%s:NO_TALENTS", classTag, tostring(group))
    else
        return string.format("%s:G%s:%s", classTag, tostring(group), table.concat(tabs, "-"))
    end
end

-- Ensure per-talent profiles exist and activate the one matching current talents
function ATS:SyncActiveTalentProfile(opts)
    local db = AutoTrinketSwitcherCharDB
    if not db then return false end

    db.talentProfiles = db.talentProfiles or nil -- lazily create on first sync

    local signature = self:ComputeTalentSignature()
    local firstSetup = (db.talentProfiles == nil)

    if not firstSetup and IsNoTalentsSignature(signature) and db.activeTalentSignature and db.talentProfiles and db.talentProfiles[db.activeTalentSignature] then
        signature = db.activeTalentSignature
    end

    if firstSetup then
        db.talentProfiles = {}
        local seedProfile = {}
        if db.queueSets then
            seedProfile.queueSets = db.queueSets
            seedProfile.activeQueueSet = db.activeQueueSet
        else
            seedProfile.queues = db.queues or { [13] = {}, [14] = {} }
        end
        local profile = CloneProfile(seedProfile, db.activeQueueSet)
        db.talentProfiles[signature] = profile
        db.activeTalentSignature = signature
        db.queueSets = profile.queueSets
        db.activeQueueSet = profile.activeQueueSet
        db.queues = db.queueSets[db.activeQueueSet]
        return false
    end

    if not db.talentProfiles[signature] then
        local sourceProfile
        local siblingSignature = FindSiblingSpecSignature(db, signature)
        if siblingSignature then
            sourceProfile = db.talentProfiles[siblingSignature]
        end
        if not sourceProfile and db.activeTalentSignature and db.talentProfiles[db.activeTalentSignature] then
            sourceProfile = db.talentProfiles[db.activeTalentSignature]
        end
        if not sourceProfile then
            sourceProfile = {
                queueSets = db.queueSets,
                activeQueueSet = db.activeQueueSet,
                queues = db.queues,
            }
        end
        db.talentProfiles[signature] = CloneProfile(sourceProfile, db.activeQueueSet)
    end

    local activeProfile = db.talentProfiles[signature]
    if activeProfile and not ProfileHasItems(activeProfile) then
        local rescueProfile
        local _, signatureGroup = ParseSignature(signature)
        local siblingSignature = FindSiblingSpecSignature(db, signature)
        if siblingSignature and db.talentProfiles[siblingSignature] and ProfileHasItems(db.talentProfiles[siblingSignature]) then
            rescueProfile = db.talentProfiles[siblingSignature]
        elseif db.activeTalentSignature and db.activeTalentSignature ~= signature and db.talentProfiles[db.activeTalentSignature] and ProfileHasItems(db.talentProfiles[db.activeTalentSignature]) then
            rescueProfile = db.talentProfiles[db.activeTalentSignature]
        elseif db.activeTalentSignature and db.talentProfiles[db.activeTalentSignature] and ProfileHasItems(db.talentProfiles[db.activeTalentSignature]) then
            rescueProfile = db.talentProfiles[db.activeTalentSignature]
        else
            rescueProfile = FindAnyNonEmptyProfile(db, signatureGroup)
        end

        if rescueProfile then
            activeProfile = CloneProfile(rescueProfile, db.activeQueueSet)
            db.talentProfiles[signature] = activeProfile
        end
    end

    EnsureProfileQueueSets(activeProfile, db.activeQueueSet)

    local switched = (db.activeTalentSignature ~= signature)
    db.activeTalentSignature = signature
    db.queueSets = db.talentProfiles[signature].queueSets
    db.activeQueueSet = db.talentProfiles[signature].activeQueueSet
    db.queues = db.queueSets[db.activeQueueSet]

    if opts and opts.silent then return false end
    return switched
end

-- Apply profile switching and notify the player
function ATS:OnTalentConfigurationChanged()
    local switched = self:SyncActiveTalentProfile()
    if switched then
        local msg = "Switched trinket queues to current talents"
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100AutoTrinketSwitcher:|r " .. msg)
        end
        if self.PruneMissingFromQueues then self:PruneMissingFromQueues() end
        self:UpdateButtons()
        if self.UpdateQueueSetButtons then self:UpdateQueueSetButtons() end
        if self.menu and self.menu:IsShown() then
            self:RefreshMenuNumbers()
            self:UpdateMenuCooldowns()
        end
    end
end

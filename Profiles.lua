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

-- Build a stable signature of the player's current talents (Classic-style trees)
function ATS:ComputeTalentSignature()
    local _, classTag = UnitClass and UnitClass("player")
    classTag = classTag or "UNKNOWN"

    local tabs = {}
    local group = (type(GetActiveTalentGroup) == "function" and GetActiveTalentGroup()) or 1
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

    if firstSetup then
        db.talentProfiles = {}
        local profile = {}
        if db.queueSets then
            profile.queueSets = db.queueSets
            profile.activeQueueSet = db.activeQueueSet
        else
            profile.queues = db.queues or { [13] = {}, [14] = {} }
        end
        EnsureProfileQueueSets(profile, db.activeQueueSet)
        db.talentProfiles[signature] = profile
        db.activeTalentSignature = signature
        db.queueSets = profile.queueSets
        db.activeQueueSet = profile.activeQueueSet
        db.queues = db.queueSets[db.activeQueueSet]
        return false
    end

    if not db.talentProfiles[signature] then
        db.talentProfiles[signature] = {}
    end
    EnsureProfileQueueSets(db.talentProfiles[signature], db.activeQueueSet)

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

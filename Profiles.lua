local ATS = AutoTrinketSwitcherFrame

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
        db.talentProfiles[signature] = {
            queues = db.queues or { [13] = {}, [14] = {} },
        }
        db.activeTalentSignature = signature
        db.queues = db.talentProfiles[signature].queues
        return false
    end

    db.talentProfiles[signature] = db.talentProfiles[signature] or { queues = { [13] = {}, [14] = {} } }

    local switched = (db.activeTalentSignature ~= signature)
    db.activeTalentSignature = signature
    db.queues = db.talentProfiles[signature].queues

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
        if self.menu and self.menu:IsShown() then
            self:RefreshMenuNumbers()
            self:UpdateMenuCooldowns()
        end
    end
end

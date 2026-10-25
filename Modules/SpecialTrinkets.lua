local ATS = AutoTrinketSwitcherFrame

ATS.SpecialTrinkets = ATS.SpecialTrinkets or {}

local SERPENT_COIL_BRAID_ID = 30720
local MANA_SURGE_SPELL_ID = 37445
local MANA_SURGE_FALLBACK_NAME = "Mana Surge"
local TRINKET_SLOTS = {13, 14}
local SOLARIAN_SAPPHIRE_ID = 30446
local BATTLE_SHOUT_SPELL_ID = 6673
local MANA_GEM_IDS = {
    22044, -- Mana Emerald
}

local SERPENT_COIL_MODES = {
    OFF = "OFF",
    DISPLAY_ONLY = "DISPLAY_ONLY",
    ROTATION = "ROTATION",
}

local SOLARIAN_MODES = {
    OFF = "OFF",
    DISPLAY_ONLY = "DISPLAY_ONLY",
    ROTATION = "ROTATION",
}

local function IsValidSpecialTrinketMode(itemID, mode)
    local special = itemID and ATS.SpecialTrinkets and ATS.SpecialTrinkets[itemID]
    if not special or not special.modeOrder then return false end
    for _, value in ipairs(special.modeOrder) do
        if mode == value then return true end
    end
    return false
end

local function FindPlayerAura(spellID, fallbackName)
    if UnitBuff and spellID then
        for i = 1, 40 do
            local name, _, _, _, duration, expirationTime, _, _, _, auraSpellID = UnitBuff("player", i)
            if not name then break end
            if auraSpellID == spellID then
                return true, duration, expirationTime
            end
        end
    end

    local spellName = (GetSpellInfo and GetSpellInfo(spellID)) or fallbackName
    if not spellName then return false end

    if AuraUtil and AuraUtil.FindAuraByName then
        local name, _, _, _, duration, expirationTime = AuraUtil.FindAuraByName(spellName, "player", "HELPFUL")
        if not name then return false end
        return true, duration, expirationTime
    end

    if UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, duration, expirationTime = UnitBuff("player", i)
            if not name then break end
            if name == spellName then
                return true, duration, expirationTime
            end
        end
    end

    return false
end

local function GetPlayerAuraCooldownBySpell(spellID, fallbackName, fallbackDuration)
    local found, duration, expirationTime = FindPlayerAura(spellID, fallbackName)
    if not found then return nil, nil, nil, false end

    duration = duration or fallbackDuration or 0
    expirationTime = expirationTime or 0
    if duration <= 0 or expirationTime <= 0 then
        return 0, 0, 0, true
    end

    local remaining = expirationTime - GetTime()
    if remaining <= 0 then return 0, 0, 0, true end
    return expirationTime - duration, duration, 1, true
end

-- Mana Surge state -----------------------------------------------------------------

-- Returns active, remaining. A found-but-permanent aura is reported inactive on
-- purpose: Mana Surge is a 15s timed buff, so anything without an expiry is a passive
-- and must never be allowed to hold the braid in place indefinitely.
function ATS:GetManaSurgeInfo()
    local found, duration, expirationTime = FindPlayerAura(MANA_SURGE_SPELL_ID, MANA_SURGE_FALLBACK_NAME)
    if not found then return false, 0 end

    duration = duration or 0
    expirationTime = expirationTime or 0
    if duration <= 0 or expirationTime <= 0 then return false, 0 end

    local remaining = expirationTime - GetTime()
    if remaining <= 0 then return false, 0 end
    return true, remaining
end

function ATS:IsManaSurgeActive()
    local active = self:GetManaSurgeInfo()
    return active
end

function ATS:GetManaSurgeRemaining()
    local _, remaining = self:GetManaSurgeInfo()
    return remaining or 0
end

function ATS:GetManaGemCooldown()
    local hasGem = false
    for _, itemID in ipairs(MANA_GEM_IDS) do
        local count = GetItemCount and GetItemCount(itemID, false) or 0
        if count > 0 then
            hasGem = true
            local start, duration, enable = self:GetItemCooldownSafe(itemID)
            if self:IsActiveCooldown(start, duration) then
                return start, duration, enable, itemID, true
            end
        end
    end

    if hasGem then
        return 0, 0, 0, nil, true
    end

    -- If the final gem charge was consumed, the item may be gone but the cooldown can still be queryable.
    for _, itemID in ipairs(MANA_GEM_IDS) do
        local start, duration, enable = self:GetItemCooldownSafe(itemID)
        if self:IsActiveCooldown(start, duration) then
            return start, duration, enable, itemID, true
        end
    end

    return nil, nil, nil, nil, false
end

function ATS:GetManaGemRemaining()
    local start, duration, _, _, hasSource = self:GetManaGemCooldown()
    if not hasSource then return nil end
    return self:GetCooldownRemaining(start or 0, duration or 0)
end

function ATS:GetManaSurgeCooldown(itemID)
    local start, duration, enable, hasAura = GetPlayerAuraCooldownBySpell(MANA_SURGE_SPELL_ID, "Mana Surge", 15)
    if hasAura then
        return start or 0, duration or 0, enable, itemID or SERPENT_COIL_BRAID_ID, true
    end
    return 0, 0, 0, itemID or SERPENT_COIL_BRAID_ID, true
end

function ATS:GetBattleShoutDurationCooldown()
    local start, duration, enable, hasAura = GetPlayerAuraCooldownBySpell(BATTLE_SHOUT_SPELL_ID, "Battle Shout", 120)
    if hasAura then
        return start or 0, duration or 0, enable
    end
    return 0, 0, 0
end

local function MigrateSerpentCoilMode(mode)
    if IsValidSpecialTrinketMode(SERPENT_COIL_BRAID_ID, mode) then return mode end
    return SERPENT_COIL_MODES.ROTATION
end

local MANA_EMERALD_COOLDOWN = 120

-- ChooseCandidate treats a queued item with 30 seconds or less remaining as selectable,
-- which normally buys an on-use trinket time to clear its 30s equip lockout. The braid
-- has no such lockout - the gem is usable the instant it lands - so it needs no head
-- start. Padding the reported cooldown by that threshold makes the braid come back
-- exactly as the emerald comes up instead of 30 seconds early, which hands those 30
-- seconds back to whatever trinket is covering the gap.
local QUEUE_READY_THRESHOLD = 30
-- Seconds before the emerald is ready that the braid should be back. Raise this if you
-- want a buffer for being stuck in combat at the moment the gem comes off cooldown.
local BRAID_RETURN_LEAD = 0

local function GetBraidEquippedSlot()
    for _, slot in ipairs(TRINKET_SLOTS) do
        if GetInventoryItemID and GetInventoryItemID("player", slot) == SERPENT_COIL_BRAID_ID then
            return slot
        end
    end
    return nil
end

function ATS:UpdateSerpentCoilState()
    local state = self.serpentCoilState
    if not state then
        state = { surgeActive = false, yielded = false, yieldStarted = 0 }
        self.serpentCoilState = state
    end

    local active = self:IsManaSurgeActive()

    if active then
        -- Buff is up: hold the braid and clear any pending yield.
        if not state.surgeActive then
            -- Mana Surge going up IS the gem use, so this is the exact moment the
            -- emerald's own cooldown started.
            state.gemUsedAt = GetTime()
        end
        state.surgeActive = true
        state.yielded = false
        state.yieldStarted = 0
        return state
    end

    if state.surgeActive then
        state.surgeActive = false
        -- Only yield the slot if the braid is the thing actually sitting in it.
        if GetBraidEquippedSlot() then
            state.yielded = true
            state.yieldStarted = GetTime()
        end
    end

    return state
end

-- Seconds until the braid should be considered available again. 0 means available now.
function ATS:GetSerpentCoilYieldRemaining()
    local state = self:UpdateSerpentCoilState()
    if not state.yielded then return 0 end

    local remaining = 0

    -- Prefer the real Mana Emerald cooldown when the client reports one.
    local gemRemaining = self:GetManaGemRemaining()
    if gemRemaining and gemRemaining > 0 then
        remaining = gemRemaining
    end

    -- Wall-clock backstop for when the item cooldown is unreadable or reads as ready.
    -- Measured from the gem use (when Mana Surge went up), not from the surge expiring,
    -- so the backstop lines up with the real cooldown instead of overshooting by the
    -- 15 seconds the buff was running.
    local since = GetTime() - (state.gemUsedAt or state.yieldStarted or 0)
    local fallback = MANA_EMERALD_COOLDOWN - since
    if fallback > remaining then remaining = fallback end

    remaining = remaining - BRAID_RETURN_LEAD
    if remaining <= 0 then
        state.yielded = false
        state.yieldStarted = 0
        return 0
    end

    return remaining
end

function ATS:IsSerpentCoilYielded()
    return self:GetSerpentCoilYieldRemaining() > 0
end


ATS.SpecialTrinkets[SERPENT_COIL_BRAID_ID] = {
    name = "Serpent-Coil Braid",
    class = "MAGE",
    clients = { TBC = true },
    -- Rotation is the default so the Mana Surge hold is live out of the box.
    defaultMode = SERPENT_COIL_MODES.ROTATION,
    modeOrder = {
        SERPENT_COIL_MODES.OFF,
        SERPENT_COIL_MODES.DISPLAY_ONLY,
        SERPENT_COIL_MODES.ROTATION,
    },
    modeLabels = {
        [SERPENT_COIL_MODES.OFF] = "Off (no Mana Surge hold, no rotation)",
        [SERPENT_COIL_MODES.DISPLAY_ONLY] = "Show Mana Emerald cooldown only",
        [SERPENT_COIL_MODES.ROTATION] = "Hold for Mana Surge, rotate on Mana Emerald",
    },

    getDisplayCooldown = function(self, itemID)
        local mode = self:GetSpecialTrinketMode(itemID)
        if mode == SERPENT_COIL_MODES.OFF then return nil end

        local start, duration, enable, sourceItemID, hasSource = self:GetManaGemCooldown()
        if hasSource then
            return start or 0, duration or 0, enable, sourceItemID
        end
    end,

    -- Readiness for rotation purposes. Once Mana Surge has expired the braid reports a
    -- live cooldown so the queue skips it and moves to the next trinket in order; that
    -- cooldown winds down to zero as the Mana Emerald comes back, which is what pulls
    -- the braid back into the same slot.
    getEffectiveCooldown = function(self, itemID)
        if self:GetSpecialTrinketMode(itemID) ~= SERPENT_COIL_MODES.ROTATION then return nil end

        local yieldRemaining = self:GetSerpentCoilYieldRemaining()
        if yieldRemaining > 0 then
            -- Pad past the selection threshold so the braid is not picked early.
            return GetTime(), yieldRemaining + QUEUE_READY_THRESHOLD, 1, itemID
        end

        local start, duration, enable, sourceItemID, hasSource = self:GetManaGemCooldown()
        if hasSource then
            return start or 0, duration or 0, enable, sourceItemID
        end

        return 0, 0, 0, itemID
    end,

    -- Treat the braid as a "use" trinket so the effect-active hold below is honoured.
    -- Mana Surge being up qualifies on its own, which keeps the hold working even on
    -- the last gem charge, when the emerald has already left the bags.
    hasEffectiveUse = function(self, itemID)
        if self:GetSpecialTrinketMode(itemID) ~= SERPENT_COIL_MODES.ROTATION then return false end
        if self:IsManaSurgeActive() then return true end
        if self:IsSerpentCoilYielded() then return true end
        local _, _, _, _, hasSource = self:GetManaGemCooldown()
        return hasSource
    end,

    -- While Mana Surge (37445) is on the player, the braid stays in its slot. When it
    -- falls off, the slot is free and the next queued trinket takes over.
    isEffectActive = function(self, itemID)
        if self:GetSpecialTrinketMode(itemID) ~= SERPENT_COIL_MODES.ROTATION then return false end
        return self:IsManaSurgeActive()
    end,

}

ATS.SpecialTrinkets[SOLARIAN_SAPPHIRE_ID] = {
    name = "Solarian's Sapphire",
    class = "WARRIOR",
    clients = { TBC = true },
    defaultMode = SOLARIAN_MODES.ROTATION,
    modeOrder = {
        SOLARIAN_MODES.OFF,
        SOLARIAN_MODES.DISPLAY_ONLY,
        SOLARIAN_MODES.ROTATION,
    },
    modeLabels = {
        [SOLARIAN_MODES.OFF] = "Off",
        [SOLARIAN_MODES.DISPLAY_ONLY] = "Show Battle Shout duration",
        [SOLARIAN_MODES.ROTATION] = "Use Battle Shout duration for switching",
    },

    getDisplayCooldown = function(self, itemID)
        local mode = self:GetSpecialTrinketMode(itemID)
        if mode == SOLARIAN_MODES.OFF then return nil end

        return self:GetBattleShoutDurationCooldown()
    end,

    getEffectiveCooldown = function(self, itemID)
        if self:GetSpecialTrinketMode(itemID) ~= SOLARIAN_MODES.ROTATION then return nil end

        return self:GetBattleShoutDurationCooldown()
    end,

    hasEffectiveUse = function(self, itemID)
        return self:GetSpecialTrinketMode(itemID) == SOLARIAN_MODES.ROTATION
    end,
}

function ATS:NormalizeSpecialTrinketSettings(db)
    db = db or AutoTrinketSwitcherCharDB
    if not db then return end

    db.specialTrinketModes = db.specialTrinketModes or {}

    if db.serpentCoilMode ~= nil or db.showSerpentCoilManaGemCooldown ~= nil then
        local mode = MigrateSerpentCoilMode(db.serpentCoilMode)
        if not mode then
            mode = SERPENT_COIL_MODES.ROTATION
        end
        db.specialTrinketModes[SERPENT_COIL_BRAID_ID] = mode
    elseif db.specialTrinketModes[SERPENT_COIL_BRAID_ID] ~= nil
        and not IsValidSpecialTrinketMode(SERPENT_COIL_BRAID_ID, db.specialTrinketModes[SERPENT_COIL_BRAID_ID]) then
        db.specialTrinketModes[SERPENT_COIL_BRAID_ID] = MigrateSerpentCoilMode(db.specialTrinketModes[SERPENT_COIL_BRAID_ID])
    end

    db.serpentCoilMode = nil
    db.showSerpentCoilManaGemCooldown = nil

    local fixes = {}
    for key, mode in pairs(db.specialTrinketModes) do
        table.insert(fixes, { key = key, itemID = tonumber(key), mode = mode })
    end
    for _, fix in ipairs(fixes) do
        if not fix.itemID then
            db.specialTrinketModes[fix.key] = nil
        else
            if fix.key ~= fix.itemID then
                db.specialTrinketModes[fix.itemID] = fix.mode
                db.specialTrinketModes[fix.key] = nil
            end
            if not IsValidSpecialTrinketMode(fix.itemID, db.specialTrinketModes[fix.itemID]) then
                db.specialTrinketModes[fix.itemID] = nil
            end
        end
    end
end

function ATS:GetSpecialTrinketMode(itemID)
    local special = self:GetSpecialTrinket(itemID)
    if not special then return nil end

    local db = AutoTrinketSwitcherCharDB
    if db then
        local modes = db.specialTrinketModes
        local mode = modes and modes[itemID]
        if IsValidSpecialTrinketMode(itemID, mode) then
            return mode
        end
    end

    return special.defaultMode
end

function ATS:SetSpecialTrinketMode(itemID, mode)
    local special = self:GetSpecialTrinket(itemID)
    if not special or not IsValidSpecialTrinketMode(itemID, mode) then return end

    local db = AutoTrinketSwitcherCharDB
    if not db then return end
    db.specialTrinketModes = db.specialTrinketModes or {}
    db.specialTrinketModes[itemID] = mode

    if self.UpdateButtons then self:UpdateButtons() end
    if self.UpdateMenuCooldowns then self:UpdateMenuCooldowns() end
    if self.PerformCheck then self:PerformCheck() end
    if self.RefreshSpecialTrinketOptions then self:RefreshSpecialTrinketOptions() end
end

function ATS:GetSerpentCoilMode()
    return self:GetSpecialTrinketMode(SERPENT_COIL_BRAID_ID) or SERPENT_COIL_MODES.ROTATION
end

function ATS:SetSerpentCoilMode(mode)
    return self:SetSpecialTrinketMode(SERPENT_COIL_BRAID_ID, mode)
end

local function AddSpecialTrinketID(out, seen, itemID)
    itemID = tonumber(itemID)
    if not itemID or seen[itemID] or not ATS:GetSpecialTrinket(itemID) then return end
    seen[itemID] = true
    table.insert(out, itemID)
end

function ATS:GetDetectedSpecialTrinketIDs()
    local out, seen = {}, {}

    for _, invSlot in ipairs({13, 14}) do
        AddSpecialTrinketID(out, seen, GetInventoryItemID and GetInventoryItemID("player", invSlot))
    end

    local getSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    if getSlots and getItemID then
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            for slot = 1, (getSlots(bag) or 0) do
                AddSpecialTrinketID(out, seen, getItemID(bag, slot))
            end
        end
    end

    local db = AutoTrinketSwitcherCharDB
    if db and db.queues then
        for _, queueSlot in ipairs({13, 14}) do
            for _, itemID in ipairs(db.queues[queueSlot] or {}) do
                AddSpecialTrinketID(out, seen, itemID)
            end
        end
    end

    table.sort(out, function(a, b)
        local nameA = GetItemInfo and GetItemInfo(a) or nil
        local nameB = GetItemInfo and GetItemInfo(b) or nil
        nameA = nameA or tostring(a)
        nameB = nameB or tostring(b)
        if nameA == nameB then return a < b end
        return nameA < nameB
    end)

    return out
end

function ATS:GetSpecialTrinketDisplayName(itemID)
    local special = self:GetSpecialTrinket(itemID)
    local itemName = GetItemInfo and GetItemInfo(itemID) or nil
    return itemName or (special and special.name) or ("item:" .. tostring(itemID))
end

function ATS:GetSpecialTrinketModeLabel(itemID, mode)
    local special = self:GetSpecialTrinket(itemID)
    if not special then return tostring(mode or "") end
    return (special.modeLabels and special.modeLabels[mode]) or tostring(mode or "")
end

function ATS:GetSpecialTrinketModeOrder(itemID)
    local special = self:GetSpecialTrinket(itemID)
    return special and special.modeOrder or nil
end

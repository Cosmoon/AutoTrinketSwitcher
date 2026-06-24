local ATS = AutoTrinketSwitcherFrame

ATS.SpecialTrinkets = ATS.SpecialTrinkets or {}

local SERPENT_COIL_BRAID_ID = 30720
local IMPROVED_MANA_GEMS_SPELL_ID = 37447
local MANA_GEM_IDS = {
    22044, -- Mana Emerald
    8008,  -- Mana Ruby
    8007,  -- Mana Citrine
    5513,  -- Mana Jade
    5514,  -- Mana Agate
}

local SERPENT_COIL_MODES = {
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

local function PlayerHasAuraBySpell(spellID, fallbackName)
    local spellName = (GetSpellInfo and GetSpellInfo(spellID)) or fallbackName
    if not spellName then return false end

    if AuraUtil and AuraUtil.FindAuraByName then
        return AuraUtil.FindAuraByName(spellName, "player", "HELPFUL") ~= nil
    end

    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if name == spellName then return true end
    end

    return false
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

ATS.SpecialTrinkets[SERPENT_COIL_BRAID_ID] = {
    name = "Serpent-Coil Braid",
    class = "MAGE",
    defaultMode = SERPENT_COIL_MODES.DISPLAY_ONLY,
    modeOrder = {
        SERPENT_COIL_MODES.OFF,
        SERPENT_COIL_MODES.DISPLAY_ONLY,
        SERPENT_COIL_MODES.ROTATION,
    },
    modeLabels = {
        [SERPENT_COIL_MODES.OFF] = "Off",
        [SERPENT_COIL_MODES.DISPLAY_ONLY] = "Show mana gem cooldown",
        [SERPENT_COIL_MODES.ROTATION] = "Use mana gem cooldown for switching",
    },

    getDisplayCooldown = function(self, itemID)
        local mode = self:GetSpecialTrinketMode(itemID)
        if mode == SERPENT_COIL_MODES.OFF then return nil end

        local start, duration, enable, sourceItemID, hasSource = self:GetManaGemCooldown()
        if hasSource then
            return start or 0, duration or 0, enable, sourceItemID
        end
    end,

    getEffectiveCooldown = function(self, itemID)
        if self:GetSpecialTrinketMode(itemID) ~= SERPENT_COIL_MODES.ROTATION then return nil end

        local start, duration, enable, sourceItemID, hasSource = self:GetManaGemCooldown()
        if hasSource then
            return start or 0, duration or 0, enable, sourceItemID
        end
    end,

    hasEffectiveUse = function(self, itemID)
        if self:GetSpecialTrinketMode(itemID) ~= SERPENT_COIL_MODES.ROTATION then return false end
        local _, _, _, _, hasSource = self:GetManaGemCooldown()
        return hasSource
    end,

    isEffectActive = function(self, itemID)
        if self:GetSpecialTrinketMode(itemID) ~= SERPENT_COIL_MODES.ROTATION then return false end
        return PlayerHasAuraBySpell(IMPROVED_MANA_GEMS_SPELL_ID, "Improved Mana Gems")
    end,
}

function ATS:NormalizeSpecialTrinketSettings(db)
    db = db or AutoTrinketSwitcherCharDB
    if not db then return end

    db.specialTrinketModes = db.specialTrinketModes or {}

    if db.serpentCoilMode ~= nil or db.showSerpentCoilManaGemCooldown ~= nil then
        local mode = db.serpentCoilMode
        if not IsValidSpecialTrinketMode(SERPENT_COIL_BRAID_ID, mode) then
            if db.showSerpentCoilManaGemCooldown == false then
                mode = SERPENT_COIL_MODES.OFF
            else
                mode = SERPENT_COIL_MODES.DISPLAY_ONLY
            end
        end
        db.specialTrinketModes[SERPENT_COIL_BRAID_ID] = mode
    elseif db.specialTrinketModes[SERPENT_COIL_BRAID_ID] ~= nil
        and not IsValidSpecialTrinketMode(SERPENT_COIL_BRAID_ID, db.specialTrinketModes[SERPENT_COIL_BRAID_ID]) then
        db.specialTrinketModes[SERPENT_COIL_BRAID_ID] = nil
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
    return self:GetSpecialTrinketMode(SERPENT_COIL_BRAID_ID) or SERPENT_COIL_MODES.DISPLAY_ONLY
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

    if db and db.specialTrinketModes then
        for itemID in pairs(db.specialTrinketModes) do
            AddSpecialTrinketID(out, seen, itemID)
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

local ATS = AutoTrinketSwitcherFrame

local MOUNT_SPEED_TRINKETS = {
    { itemID = 11122 }, -- Carrot on a Stick
    { itemID = 25653 }, -- Riding Crop
    { itemID = 32863 }, -- Skybreaker Whip
}
local MOUNT_SPEED_TRINKET_IDS = {
    [11122] = true,
    [25653] = true,
    [32863] = true,
}
local MOUNT_SPEED_TRINKET_SLOTS = { 13, 14 }
local MOUNT_SPEED_HAND_SLOT = 10
local MOUNT_SPEED_FEET_SLOT = 8
local MOUNT_SPEED_RESTORE_SLOTS = { 13, 14, 10, 8 }
local MOUNT_SPEED_ARMOR = {
    [MOUNT_SPEED_HAND_SLOT] = {
        equipLoc = "INVTYPE_HAND",
        enchantIDs = { [930] = true },
        patterns = { "riding skill", "mounted speed", "mount speed" },
    },
    [MOUNT_SPEED_FEET_SLOT] = {
        equipLoc = "INVTYPE_FEET",
        enchantIDs = { [464] = true },
        patterns = { "mithril spurs", "mounted speed", "mount speed" },
    },
}

local function CanSwap()
    return ATS and ATS.PlayerCanSwap and ATS:PlayerCanSwap()
end

local function Ensure()
    if ATS and ATS.EnsureDB then
        ATS:EnsureDB()
    end
end

local function EquipItem(item, slot)
    if ATS and ATS.EquipItemSafe then
        ATS:EquipItemSafe(item, slot)
    end
end

local function GetItemIDFromLinkOrID(item)
    if type(item) == "number" then return item end
    if type(item) ~= "string" then return nil end
    return tonumber(item:match("item:(%d+)"))
end

local function GetEnchantIDFromLink(itemLink)
    if type(itemLink) ~= "string" then return nil end
    return tonumber(itemLink:match("item:%d+:(%d+)"))
end

local function GetBagSlotCount(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    if GetContainerNumSlots then
        return GetContainerNumSlots(bag) or 0
    end
    return 0
end

local function GetBagItemID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bag, slot)
    end
    if GetContainerItemID then
        return GetContainerItemID(bag, slot)
    end
end

local function GetBagItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    if GetContainerItemLink then
        return GetContainerItemLink(bag, slot)
    end
end

local function GetItemEquipLocSafe(item)
    local equipLoc
    if GetItemInfo then
        equipLoc = select(9, GetItemInfo(item))
    end
    if not equipLoc and GetItemInfoInstant then
        equipLoc = select(4, GetItemInfoInstant(item))
    end
    return equipLoc
end

local function GetMountSpeedScanTooltip()
    if not ATS.mountSpeedScanTooltip then
        ATS.mountSpeedScanTooltip = CreateFrame("GameTooltip", "ATS_MountSpeedScanTooltip", UIParent, "GameTooltipTemplate")
        ATS.mountSpeedScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return ATS.mountSpeedScanTooltip
end

local function TooltipContainsPatterns(patterns)
    local tip = GetMountSpeedScanTooltip()
    local lineCount = tip.NumLines and tip:NumLines() or 0
    local function textMatches(text)
        text = text and text:lower()
        if not text then return false end
        for _, pattern in ipairs(patterns) do
            if text:find(pattern, 1, true) then
                return true
            end
        end
        return false
    end

    for i = 1, lineCount do
        local left = _G["ATS_MountSpeedScanTooltipTextLeft" .. i]
        local right = _G["ATS_MountSpeedScanTooltipTextRight" .. i]
        if textMatches(left and left:GetText()) or textMatches(right and right:GetText()) then
            return true
        end
    end
    return false
end

local function LinkHasEnchant(itemLink, enchantIDs)
    local enchantID = GetEnchantIDFromLink(itemLink)
    return enchantID and enchantIDs and enchantIDs[enchantID]
end

local function BagItemHasMountSpeedEnchant(bag, slot, itemLink, config)
    if LinkHasEnchant(itemLink, config.enchantIDs) then return true end

    local tip = GetMountSpeedScanTooltip()
    tip:ClearLines()
    if tip.SetBagItem then
        tip:SetBagItem(bag, slot)
    end
    return TooltipContainsPatterns(config.patterns)
end

local function InventoryItemHasMountSpeedEnchant(invSlot, config)
    local itemLink = GetInventoryItemLink and GetInventoryItemLink("player", invSlot)
    if LinkHasEnchant(itemLink, config.enchantIDs) then return true end

    local tip = GetMountSpeedScanTooltip()
    tip:ClearLines()
    if tip.SetInventoryItem then
        tip:SetInventoryItem("player", invSlot)
    end
    return TooltipContainsPatterns(config.patterns)
end

local function FindBagItemByID(itemID)
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, GetBagSlotCount(bag) do
            if GetBagItemID(bag, slot) == itemID then
                return {
                    itemID = itemID,
                    link = GetBagItemLink(bag, slot),
                }
            end
        end
    end
end

local function FindMountSpeedArmor(config)
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, GetBagSlotCount(bag) do
            local itemID = GetBagItemID(bag, slot)
            local itemLink = itemID and GetBagItemLink(bag, slot)
            if itemID and GetItemEquipLocSafe(itemLink or itemID) == config.equipLoc then
                if BagItemHasMountSpeedEnchant(bag, slot, itemLink, config) then
                    return {
                        itemID = itemID,
                        link = itemLink,
                    }
                end
            end
        end
    end
end

local function SaveMountSpeedPrevious(db, slot)
    db.mountSpeedPrevious = db.mountSpeedPrevious or {}
    if db.mountSpeedPrevious[slot] ~= nil then return end

    local previous = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if not previous and GetInventoryItemID then
        previous = GetInventoryItemID("player", slot)
    end
    db.mountSpeedPrevious[slot] = previous or false
end

local function MarkMountSpeedEquip(slot)
    ATS.lastEquip = ATS.lastEquip or {}
    ATS.lastEquip[slot] = GetTime()
end

local function UnequipInventorySlot(slot)
    if not GetInventoryItemID or not GetInventoryItemID("player", slot) then return true end
    if not PickupInventoryItem or not PutItemInBackpack then return false end
    if CursorHasItem and CursorHasItem() then return false end

    PickupInventoryItem(slot)
    if CursorHasItem and CursorHasItem() then
        PutItemInBackpack()
    end
    if CursorHasItem and CursorHasItem() then
        -- No free bag space: put the item back instead of leaving it on the cursor.
        PickupInventoryItem(slot)
        return false
    end

    MarkMountSpeedEquip(slot)
    return true
end

local function MountSpeedHasPrevious(previous)
    if not previous then return false end
    for _, slot in ipairs(MOUNT_SPEED_RESTORE_SLOTS) do
        if previous[slot] ~= nil then
            return true
        end
    end
    return false
end

local function RestoreMountSpeedSlots(db, slots)
    local previous = db.mountSpeedPrevious or {}
    for _, slot in ipairs(slots) do
        local target = previous[slot]
        local restored = true
        if target and target ~= false then
            local targetID = GetItemIDFromLinkOrID(target)
            local currentID = GetInventoryItemID("player", slot)
            if not targetID or currentID ~= targetID then
                EquipItem(target, slot)
                MarkMountSpeedEquip(slot)
            end
        elseif target == false then
            restored = UnequipInventorySlot(slot)
        else
            restored = false
        end

        if restored then
            previous[slot] = nil
        end
    end

    if MountSpeedHasPrevious(previous) then
        db.mountSpeedPrevious = previous
        db.mountSpeedActive = true
    else
        db.mountSpeedPrevious = nil
        db.mountSpeedActive = false
    end
end

function ATS:EquipMountSpeedGear()
    Ensure()
    if not CanSwap() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local db = AutoTrinketSwitcherCharDB
    local changed = false

    if db.mountSpeedTrinketsEnabled ~= false then
        local equippedSpeedTrinkets = {}
        local targetTrinketSlots = {}

        for _, slot in ipairs(MOUNT_SPEED_TRINKET_SLOTS) do
            local itemID = GetInventoryItemID("player", slot)
            if MOUNT_SPEED_TRINKET_IDS[itemID] then
                equippedSpeedTrinkets[itemID] = true
            else
                table.insert(targetTrinketSlots, slot)
            end
        end

        for _, trinket in ipairs(MOUNT_SPEED_TRINKETS) do
            if not equippedSpeedTrinkets[trinket.itemID] and #targetTrinketSlots > 0 then
                local item = FindBagItemByID(trinket.itemID)
                if item then
                    local slot = table.remove(targetTrinketSlots, 1)
                    SaveMountSpeedPrevious(db, slot)
                    db.mountSpeedActive = true
                    EquipItem(item.link or item.itemID, slot)
                    MarkMountSpeedEquip(slot)
                    equippedSpeedTrinkets[trinket.itemID] = true
                    changed = true
                end
            end
        end
    end

    for _, slot in ipairs({ MOUNT_SPEED_HAND_SLOT, MOUNT_SPEED_FEET_SLOT }) do
        local config = MOUNT_SPEED_ARMOR[slot]
        if config and not InventoryItemHasMountSpeedEnchant(slot, config) then
            local item = FindMountSpeedArmor(config)
            if item then
                SaveMountSpeedPrevious(db, slot)
                db.mountSpeedActive = true
                EquipItem(item.link or item.itemID, slot)
                MarkMountSpeedEquip(slot)
                changed = true
            end
        end
    end

    return changed
end

function ATS:RestoreMountSpeedGear()
    Ensure()
    local db = AutoTrinketSwitcherCharDB
    if not db.mountSpeedActive and not db.mountSpeedPrevious then return true end
    if not CanSwap() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    RestoreMountSpeedSlots(db, MOUNT_SPEED_RESTORE_SLOTS)
    return true
end

function ATS:RestoreMountSpeedTrinkets()
    Ensure()
    local db = AutoTrinketSwitcherCharDB
    if not db.mountSpeedPrevious then return true end
    if not CanSwap() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    RestoreMountSpeedSlots(db, MOUNT_SPEED_TRINKET_SLOTS)
    return true
end

function ATS:SetMountSpeedTrinketSwitching(enabled)
    Ensure()
    local db = AutoTrinketSwitcherCharDB
    db.mountSpeedTrinketsEnabled = not not enabled

    if db.mountSpeedTrinketsEnabled then
        if self.isMounted and db.useMountSpeedManager and self.EquipMountSpeedGear then
            self:EquipMountSpeedGear()
        end
    elseif self.RestoreMountSpeedTrinkets then
        self:RestoreMountSpeedTrinkets()
    end

    if self.UpdateButtons then self:UpdateButtons() end
end

function ATS:ToggleMountSpeedTrinketSwitching()
    Ensure()
    self:SetMountSpeedTrinketSwitching(not AutoTrinketSwitcherCharDB.mountSpeedTrinketsEnabled)
end

function ATS:OnMountSpeedManagerOptionChanged(enabled)
    Ensure()
    local db = AutoTrinketSwitcherCharDB
    db.useMountSpeedManager = not not enabled

    if db.useMountSpeedManager then
        self.resumeGuardUntil = nil
        if self.isMounted and self.EquipMountSpeedGear then
            self:EquipMountSpeedGear()
        end
    elseif self.RestoreMountSpeedGear then
        self:RestoreMountSpeedGear()
    end

    if self.UpdateButtons then self:UpdateButtons() end
end

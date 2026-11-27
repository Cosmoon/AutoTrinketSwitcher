local ATS = AutoTrinketSwitcherFrame

local client = AutoTrinketSwitcherCompatibility.client
local catalogs = {
    CLASSIC = { { itemID = 11122 } },
    TBC = { { itemID = 32863 }, { itemID = 25653 }, { itemID = 11122 } },
    RETAIL = { { itemID = 193475, minLevel = 61 } }, -- Masterwork Riding Crop
    FOREVER = { { itemID = 11122 }, { itemID = 274648 } },
}
local MOUNT_SPEED_TRINKETS = catalogs[client] or {}
local MOUNT_SPEED_TRINKET_IDS = {}
for _, item in ipairs(MOUNT_SPEED_TRINKETS) do MOUNT_SPEED_TRINKET_IDS[item.itemID] = true end
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

if client == "FOREVER" then
    MOUNT_SPEED_RESTORE_SLOTS = { 13, 14, 10, 8, 2, 11, 12, 15, 16, 17 }
elseif client ~= "CLASSIC" and client ~= "TBC" then
    MOUNT_SPEED_ARMOR = {}
end

local foreverZones = {
    desert = { [1446] = true, [1451] = true, [1443] = true, [1441] = true, [1413] = true,
        [1411] = true, [1454] = true, [1418] = true, [1419] = true, [1436] = true },
    winterspring = { [1452] = true },
    clutch = { [1413] = true, [1441] = true },
    kalimdor = { [1413] = true, [1442] = true },
    plaguelands = { [1422] = true, [1423] = true },
    westfall = { [1429] = true, [1436] = true, [1433] = true },
    forsaken = { [1421] = true, [1424] = true },
}
local foreverInstances = { [36] = "westfall", [47] = "clutch", [129] = "clutch", [209] = "desert" }
local foreverGear = {
    -- Each group selects this many distinct pieces. Slot order breaks ties.
    { count = 1, zone = "winterspring", { 284266, { 10 }, 54 } },
    { count = 1, zone = "clutch", { 6693, { 12, 11 }, 30 } },
    { count = 2, zone = "kalimdor", { 285329, { 15 }, 16 }, { 285331, { 2 }, 20 }, { 285330, { 11, 12 }, 18 } },
    { count = 2, zone = "plaguelands", { 284100, { 15 }, 57 }, { 284102, { 11, 12 }, 57 }, { 284101, { 16 }, 57 } },
    { count = 1, zone = "westfall", weapon = true, { 2042, { 16 } } },
    { count = 1, zone = "forsaken", weapon = true, { 251533, { 16 } }, { 251534, { 16 } } },
}
local GALLOPING_ITEM_ID = 271871
local GALLOPING_SPELL_ID = 1289654

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
    if ATS.GetItemInfoSafe then
        equipLoc = select(9, ATS:GetItemInfoSafe(item))
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
    if client == "FOREVER" then return false end

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
    if client == "FOREVER" then return false end

    if client == "FOREVER" then return false end

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
        if slot == 17 and previous[16] ~= nil then
            restored = false
        elseif target and target ~= false then
            local targetID = GetItemIDFromLinkOrID(target)
            local currentID = GetInventoryItemID("player", slot)
            if not targetID or currentID ~= targetID or (type(target) == "string" and GetInventoryItemLink("player", slot) ~= target) then
                EquipItem(target, slot)
                MarkMountSpeedEquip(slot)
                restored = GetInventoryItemLink("player", slot) == target or (type(target) == "number" and GetInventoryItemID("player", slot) == target)
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

local function GetForeverZoneContext()
    local instanceType, instanceID
    if GetInstanceInfo then
        local _, kind, _, _, _, _, _, id = GetInstanceInfo()
        instanceType, instanceID = kind, id
    end
    if instanceType and instanceType ~= "none" then
        return nil, foreverInstances[instanceID]
    end
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

local function InForeverZone(zone, mapID, instanceZone)
    while mapID do
        if foreverZones[zone][mapID] then return true end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
        if mapID == 0 then break end
    end
    return instanceZone == zone
end

local function FindForeverCandidate(piece, reserved)
    local itemID, slots, minLevel = piece[1], piece[2], piece[3]
    if minLevel and UnitLevel("player") < minLevel then return end
    for _, slot in ipairs(slots) do
        if not reserved[slot] and GetInventoryItemID("player", slot) == itemID then
            return { itemID = itemID, slot = slot, equipped = true }
        end
    end
    if ATS:GetItemCountSafe(itemID) == 0 then return end
    local item = FindBagItemByID(itemID)
    if item then
        for _, slot in ipairs(slots) do
            if not reserved[slot] then
                item.slot = slot
                return item
            end
        end
    end
end

local function PlanForeverGroup(plan, group)
    local reserved, selectedIDs, selected = {}, {}, {}
    for slot in pairs(plan) do reserved[slot] = true end
    -- Keep pieces that are already worn before choosing a slot for a bag item.
    for _, equippedOnly in ipairs({ true, false }) do
        for _, piece in ipairs(group) do
            if #selected == group.count then break end
            local item = not selectedIDs[piece[1]] and FindForeverCandidate(piece, reserved)
            if item and not plan[item.slot] and (not equippedOnly or item.equipped) then
                selectedIDs[piece[1]] = true
                selected[#selected + 1] = item
                reserved[item.slot] = true
            end
        end
    end
    if not group.allowPartial and #selected < group.count then return end
    for _, item in ipairs(selected) do plan[item.slot] = item end
end

local function EquipForeverMountGear(db)
    local mapID, instanceZone = GetForeverZoneContext()
    local plan = {}
    if db.mountSpeedTrinketsEnabled ~= false then
        local trinkets = { count = 2, allowPartial = true, { 11122, MOUNT_SPEED_TRINKET_SLOTS } }
        if InForeverZone("desert", mapID, instanceZone) then
            trinkets[#trinkets + 1] = { 274648, MOUNT_SPEED_TRINKET_SLOTS, 42 }
        end
        PlanForeverGroup(plan, trinkets)
    end
    local twoHanded
    for _, group in ipairs(foreverGear) do
        if (not group.weapon or db.mountSpeedWeaponsEnabled) and InForeverZone(group.zone, mapID, instanceZone) then
            PlanForeverGroup(plan, group)
            if group.weapon and plan[16] then twoHanded = true end
        end
    end

    for slot, config in pairs(MOUNT_SPEED_ARMOR) do
        if not plan[slot] then
            local currentLink = GetInventoryItemLink("player", slot)
            if LinkHasEnchant(currentLink, config.enchantIDs) then
                plan[slot] = { equipped = true }
            else
                local item = FindMountSpeedArmor(config)
                if item then plan[slot] = item end
            end
        end
    end

    local changed = false
    for _, slot in ipairs(MOUNT_SPEED_RESTORE_SLOTS) do
        local item = plan[slot]
        local previous = db.mountSpeedPrevious
        if item and not item.equipped then
            SaveMountSpeedPrevious(db, slot)
            if slot == 16 and twoHanded then SaveMountSpeedPrevious(db, 17) end
            db.mountSpeedActive = true
            EquipItem(item.link or item.itemID, slot)
            MarkMountSpeedEquip(slot)
            changed = true
        elseif not item and previous and previous[slot] ~= nil and not (slot == 17 and (twoHanded or previous[16] ~= nil)) then
            RestoreMountSpeedSlots(db, { slot })
            if previous[slot] == nil then changed = true end
        end
    end
    return changed
end

function ATS:GetGiftOfGallopingStatus()
    if client ~= "FOREVER" then return end
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(GALLOPING_SPELL_ID) then
        return "Active (+10% mounted speed)"
    end
    if self:GetItemCountSafe(GALLOPING_ITEM_ID) > 0 then
        return "In bags (use manually)"
    end
end

function ATS:EquipMountSpeedGear()
    Ensure()
    if not CanSwap() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local db = AutoTrinketSwitcherCharDB
    if client == "FOREVER" then return EquipForeverMountGear(db) end
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

        local hasSpeedTrinket = next(equippedSpeedTrinkets) ~= nil
        for _, trinket in ipairs(MOUNT_SPEED_TRINKETS) do
            if not hasSpeedTrinket and #targetTrinketSlots > 0 and (not trinket.minLevel or UnitLevel("player") >= trinket.minLevel) then
                local item = FindBagItemByID(trinket.itemID)
                if item then
                    local slot = table.remove(targetTrinketSlots, 1)
                    SaveMountSpeedPrevious(db, slot)
                    db.mountSpeedActive = true
                    EquipItem(item.link or item.itemID, slot)
                    MarkMountSpeedEquip(slot)
                    equippedSpeedTrinkets[trinket.itemID] = true
                    changed = true
                    hasSpeedTrinket = true
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
    return not db.mountSpeedActive
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

-- Called when opening options, not on every frame.
function ATS:HasRelevantMountGear()
    if AutoTrinketSwitcherCharDB and AutoTrinketSwitcherCharDB.mountSpeedPrevious then return true end
    for _, item in ipairs(MOUNT_SPEED_TRINKETS) do
        if self:GetItemCountSafe(item.itemID) > 0 then return true end
        for _, slot in ipairs(MOUNT_SPEED_TRINKET_SLOTS) do
            if GetInventoryItemID("player", slot) == item.itemID then return true end
        end
    end
    if client == "FOREVER" then
        for _, group in ipairs(foreverGear) do
            for _, piece in ipairs(group) do
                if self:GetItemCountSafe(piece[1]) > 0 then return true end
                for _, slot in ipairs(piece[2]) do
                    if GetInventoryItemID("player", slot) == piece[1] then return true end
                end
            end
        end
    end
    for slot, config in pairs(MOUNT_SPEED_ARMOR) do
        if InventoryItemHasMountSpeedEnchant(slot, config) or FindMountSpeedArmor(config) then return true end
    end
    return false
end

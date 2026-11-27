local ATS = AutoTrinketSwitcherFrame

local client = AutoTrinketSwitcherCompatibility.client
local catalogs = {
    CLASSIC = { { itemID = 11122 } },
    TBC = { { itemID = 32863 }, { itemID = 25653 }, { itemID = 11122 } },
    RETAIL = { { itemID = 193475, minLevel = 61 } }, -- Masterwork Riding Crop
    FOREVER = { { itemID = 274648 }, { itemID = 11122 } }, -- The Desert Rose, Carrot on a Stick
}
local MOUNT_SPEED_TRINKETS = catalogs[client] or {}
local MOUNT_SPEED_TRINKET_IDS = {}
for _, item in ipairs(MOUNT_SPEED_TRINKETS) do MOUNT_SPEED_TRINKET_IDS[item.itemID] = true end
local MOUNT_SPEED_TRINKET_SLOTS = { 13, 14 }
local MOUNT_SPEED_HAND_SLOT = 10
local MOUNT_SPEED_FEET_SLOT = 8
-- Every slot mount-speed gear may use; main hand (16) before off hand (17) so restores work.
local MOUNT_SPEED_RESTORE_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
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

if client ~= "CLASSIC" and client ~= "TBC" then MOUNT_SPEED_ARMOR = {} end

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

-- ---------------------------------------------------------------------------
-- WoW Forever speed gear.
-- Known Forever items are matched by item ID and their zones by map/instance ID
-- (works in every client language). Anything else that says "mount speed" or
-- "movement speed ... in <zone>" in its tooltip is picked up as a fallback.
-- Zone items are worn only while their zone (or set) condition holds.
-- ---------------------------------------------------------------------------
local IS_FOREVER = client == "FOREVER"

-- uiMapIDs (parent maps are walked, so sub-zones count) and instance IDs per zone key.
local FOREVER_ZONES = {
    desert = { 1411, 1413, 1418, 1419, 1441, 1443, 1446, 1451, 1454 }, -- Durotar, Barrens, Badlands, Blasted Lands, Thousand Needles, Desolace, Tanaris, Silithus, Orgrimmar
    winterspring = { 1452 },
    clutch = { 1413, 1441 },        -- The Barrens, Thousand Needles
    kalimdor = { 1413, 1442 },      -- The Barrens, Stonetalon Mountains
    plaguelands = { 1422, 1423 },   -- Western and Eastern Plaguelands
    westfall = { 1429, 1436, 1433 },-- Elwynn Forest, Westfall, Redridge Mountains
    forsaken = { 1421, 1424 },      -- Silverpine Forest, Hillsbrad Foothills
}
local FOREVER_INSTANCES = {
    [36] = { westfall = true },                     -- The Deadmines
    [47] = { clutch = true }, [129] = { clutch = true }, -- Razorfen Kraul, Razorfen Downs
    [209] = { desert = true }, [70] = { desert = true }, -- Zul'Farrak, Uldaman
    [509] = { desert = true }, [531] = { desert = true }, -- Ruins / Temple of Ahn'Qiraj
}
for key, list in pairs(FOREVER_ZONES) do
    local set = {}
    for _, mapID in ipairs(list) do set[mapID] = true end
    FOREVER_ZONES[key] = set
end

local FOREVER_KNOWN = {
    [11122] = { group = 13, score = 3 },                                    -- Carrot on a Stick
    [274648] = { group = 13, score = 7, zone = "desert", minLevel = 42 },   -- The Desert Rose
    [284266] = { group = 10, score = 5, zone = "winterspring", minLevel = 54 }, -- Wintersaber Hide Lined Gloves
    [6693] = { group = 11, score = 3, zone = "clutch", minLevel = 30 },     -- Agamaggan's Clutch
    [2042] = { group = 16, score = 4, zone = "westfall" },                  -- Staff of Westfall
    [251533] = { group = 16, score = 4, zone = "forsaken" },                -- Forsaken Greataxe
    [251534] = { group = 16, score = 4, zone = "forsaken" },                -- Gnarled Necromancer's Staff
    -- Blessing of Kalimdor (2-piece: movement speed in The Barrens and Stonetalon Mountains)
    [285329] = { group = 15, set = "blessing of kalimdor", need = 2, score = 5, zone = "kalimdor", minLevel = 16 },
    [285330] = { group = 11, set = "blessing of kalimdor", need = 2, score = 5, zone = "kalimdor", minLevel = 18 },
    [285331] = { group = 2, set = "blessing of kalimdor", need = 2, score = 5, zone = "kalimdor", minLevel = 20 },
    -- Rider of the Plaguelands (2-piece: Eastern and Western Plaguelands)
    [284100] = { group = 15, set = "rider of the plaguelands", need = 2, score = 5, zone = "plaguelands", minLevel = 57 },
    [284101] = { group = 16, set = "rider of the plaguelands", need = 2, score = 5, zone = "plaguelands", minLevel = 57 },
    [284102] = { group = 11, set = "rider of the plaguelands", need = 2, score = 5, zone = "plaguelands", minLevel = 57 },
}
local FOREVER_ENCHANTS = {
    [930] = 2, -- Enchant Gloves - Riding Skill
    [464] = 4, -- Mithril Spurs
}
local GALLOPING_ITEM_ID = 271871
local GALLOPING_SPELL_ID = 1289654

local EQUIPLOC_GROUP = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CLOAK = 15,
    INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_FINGER = 11,
    INVTYPE_TRINKET = 13, INVTYPE_2HWEAPON = 16, INVTYPE_WEAPON = 16, INVTYPE_WEAPONMAINHAND = 16,
}
local SLOTS_BY_GROUP = { [11] = { 11, 12 }, [13] = { 13, 14 } }
local function GroupSlots(group) return SLOTS_BY_GROUP[group] or { group } end

local function NormalizeText(text)
    local s = text:lower():gsub("[,%.:;!%(%)]", " ")
    s = s:gsub("%s+", " ")
    return " " .. s .. " "
end

-- Fallback "... in <Area> areas" groups for tooltip-detected items (English zone names).
local AREA_GROUPS = {
    desert = { "Badlands", "Blasted Lands", "Desolace", "Durotar", "Silithus", "Tanaris", "The Barrens",
        "Thousand Needles", "Ahn'Qiraj", "Gates of Ahn'Qiraj", "Orgrimmar", "Ruins of Ahn'Qiraj",
        "Temple of Ahn'Qiraj", "Uldaman", "Zul'Farrak" },
    snowy = { "Dun Morogh", "Alterac Mountains", "Winterspring", "Alterac Valley" },
    swamp = { "Dustwallow Marsh", "Swamp of Sorrows", "Wetlands", "Darkshore", "Feralas", "Un'Goro Crater",
        "Riverglades", "Wailing Caverns", "Maraudon", "The Temple of Atal'Hakkar", "The Drowned City",
        "Excavation Site: Wetlands", "The Shaper's Terrace" },
    haunted = { "Eastern Plaguelands", "Western Plaguelands", "Tirisfal Glades", "Silverpine Forest",
        "Stratholme", "Undercity" },
}
for group, zones in pairs(AREA_GROUPS) do
    local set = {}
    for _, zone in ipairs(zones) do set[NormalizeText(zone)] = true end
    AREA_GROUPS[group] = set
end

local function GetWhere()
    local where = { names = {} }
    local function add(name)
        if type(name) == "string" and name ~= "" then where.names[#where.names + 1] = NormalizeText(name) end
    end
    if GetRealZoneText then add(GetRealZoneText()) end
    if GetZoneText then add(GetZoneText()) end
    if GetSubZoneText then add(GetSubZoneText()) end
    if GetInstanceInfo then
        local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
        add(name)
        if instanceType and instanceType ~= "none" then where.instanceID = instanceID end
    end
    if not where.instanceID and C_Map and C_Map.GetBestMapForUnit then
        where.mapID = C_Map.GetBestMapForUnit("player")
    end
    return where
end

local function InKnownZone(key, where)
    local instanceZones = where.instanceID and FOREVER_INSTANCES[where.instanceID]
    if instanceZones then return instanceZones[key] == true end
    local zones = FOREVER_ZONES[key]
    local mapID, guard = where.mapID, 0
    while zones and mapID and mapID ~= 0 and guard < 10 do
        if zones[mapID] then return true end
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
        guard = guard + 1
    end
    return false
end

-- "Eastern Plaguelands" also matches "Eastern and Western Plaguelands".
local function ZoneNameMatches(cond, zone)
    if cond:find(zone, 1, true) then return true end
    local words = {}
    for word in zone:gmatch("%S+") do
        if word ~= "the" then words[#words + 1] = word end
    end
    if #words < 2 then return false end
    return cond:find(" " .. words[1] .. " ", 1, true) ~= nil and cond:find(" " .. words[#words] .. " ", 1, true) ~= nil
end

local function TooltipConditionActive(cond, where)
    local c = NormalizeText(cond)
    for group, members in pairs(AREA_GROUPS) do
        if c:find(" " .. group .. " area", 1, true) then
            if FOREVER_ZONES[group] and (where.mapID or where.instanceID) then return InKnownZone(group, where) end
            for _, zone in ipairs(where.names) do
                if members[zone] then return true end
            end
            return false
        end
    end
    for _, zone in ipairs(where.names) do
        if ZoneNameMatches(c, zone) then return true end
    end
    return false
end

-- bonus = { score, zone = known zone key, cond = tooltip condition text }
local function BonusActive(bonus, where)
    if bonus.zone then return InKnownZone(bonus.zone, where) end
    if bonus.cond then return TooltipConditionActive(bonus.cond, where) end
    return true
end

-- Returns score, zoneCondition for a lower-cased tooltip line that grants mount/movement speed.
local function ParseSpeedLine(t)
    if t:find("swim", 1, true) then return nil end
    if t:find("^use:") or t:find("^chance on hit") then return nil end
    local isSpeed = (t:find("%f[%a]mount") and t:find("speed", 1, true))
        or t:find("movement speed", 1, true)
        or t:find("riding skill", 1, true)
        or t:find("mithril spurs", 1, true)
    if not isSpeed then return nil end
    local score = tonumber(t:match("(%d+)%%")) or 1
    local cond = t:match("speed.-%f[%a]in (.-)%.?$")
    return score, cond
end

local foreverInfoCache = {}

local function GetForeverItemInfo(link)
    local cached = foreverInfoCache[link]
    if cached ~= nil then return cached or nil end

    local equipLoc = GetItemEquipLocSafe(link)
    local group = equipLoc and EQUIPLOC_GROUP[equipLoc]
    local knownByID = FOREVER_KNOWN[GetItemIDFromLinkOrID(link) or 0]
    if not group and knownByID then group = knownByID.group end -- item info not cached yet
    if not group then
        if equipLoc then foreverInfoCache[link] = false end
        return nil
    end

    local itemID = GetItemIDFromLinkOrID(link)
    local info = { itemID = itemID, group = group, directs = {} }
    local known = itemID and FOREVER_KNOWN[itemID]
    if known then
        info.minLevel = known.minLevel
        if known.set then
            info.setName = known.set
            info.set = { need = known.need, score = known.score, zone = known.zone }
        else
            info.directs[1] = { score = known.score, zone = known.zone }
        end
    else
        local tip = GetMountSpeedScanTooltip()
        tip:ClearLines()
        if tip.SetHyperlink then tip:SetHyperlink(link) end
        local lineCount = tip.NumLines and tip:NumLines() or 0
        if lineCount < 2 then info.notLoaded = true end -- item data not loaded yet; rescan later
        for i = 2, lineCount do
            local fs = _G["ATS_MountSpeedScanTooltipTextLeft" .. i]
            local text = fs and fs:GetText()
            if text then
                local setName = text:match("^(.-) %(%d+/%d+%)$")
                if setName then
                    info.setName = setName:lower()
                else
                    local t = text:lower()
                    local score, cond = ParseSpeedLine(t)
                    if score then
                        local need = tonumber(t:match("^%((%d+)%) set:"))
                        if need then
                            if not info.set or score > info.set.score then
                                info.set = { need = need, score = score, cond = cond }
                            end
                        else
                            info.directs[#info.directs + 1] = { score = score, cond = cond }
                        end
                    end
                end
            end
        end
        if info.set and not info.setName then info.set = nil end
    end

    local enchantScore = FOREVER_ENCHANTS[GetEnchantIDFromLink(link) or 0]
    if enchantScore then info.directs[#info.directs + 1] = { score = enchantScore } end

    if #info.directs == 0 and not info.set then
        if not info.notLoaded then foreverInfoCache[link] = false end
        return nil
    end
    if not info.notLoaded then foreverInfoCache[link] = info end
    return info
end

local function ActiveScore(info, where)
    local best = 0
    for _, bonus in ipairs(info.directs) do
        if bonus.score > best and BonusActive(bonus, where) then best = bonus.score end
    end
    return best
end

-- Bag items must be soulbound (no bind prompt) and wearable (no red tooltip lines).
local function BagItemUsable(bag, slot)
    local tip = GetMountSpeedScanTooltip()
    tip:ClearLines()
    if not tip.SetBagItem then return true end -- cannot inspect; let the equip attempt decide
    tip:SetBagItem(bag, slot)
    local bindText = ITEM_BIND_ON_EQUIP or "Binds when equipped"
    for i = 1, (tip:NumLines() or 0) do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = _G["ATS_MountSpeedScanTooltipText" .. side .. i]
            local text = fs and fs:IsShown() and fs:GetText()
            if text then
                if text == bindText then return false end
                local r, g, b = fs:GetTextColor()
                if r and r > 0.95 and g < 0.2 and b < 0.2 then return false end
            end
        end
    end
    return true
end

local function CollectForeverCandidates(db)
    local list = {}
    local weapons = db.mountSpeedWeaponsEnabled == true
    local trinkets = db.mountSpeedTrinketsEnabled ~= false
    local function add(link, bag, slot, invSlot)
        local info = GetForeverItemInfo(link)
        if not info then return end
        if info.group == 16 and not weapons then return end
        if info.group == 13 and not trinkets then return end
        list[#list + 1] = { link = link, info = info, bag = bag, slot = slot, invSlot = invSlot }
    end
    for _, invSlot in ipairs(MOUNT_SPEED_RESTORE_SLOTS) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", invSlot)
        if link then add(link, nil, nil, invSlot) end
    end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, GetBagSlotCount(bag) do
            local link = GetBagItemLink(bag, slot)
            if link then add(link, bag, slot, nil) end
        end
    end
    return list
end

local function IsUsable(c)
    if c.usable == nil then
        if c.info.minLevel and (UnitLevel("player") or 0) < c.info.minLevel then
            c.usable = false
        else
            c.usable = c.invSlot ~= nil or BagItemUsable(c.bag, c.slot)
        end
    end
    return c.usable
end

local function PickSlot(c, assigned)
    local slots = GroupSlots(c.info.group)
    if c.invSlot and not assigned[c.invSlot] then
        for _, s in ipairs(slots) do
            if s == c.invSlot then return s end
        end
    end
    for _, s in ipairs(slots) do
        if not assigned[s] then return s end
    end
end

local function SelectForeverGear(cands, where)
    local assigned, used, usedIDs = {}, {}, {}

    -- 2-piece (or more) zone sets first: only worth wearing when enough pieces fit.
    local sets, setOrder = {}, {}
    for _, c in ipairs(cands) do
        local s = c.info.set
        if s and BonusActive(s, where) and IsUsable(c) then
            local entry = sets[c.info.setName]
            if not entry then
                entry = { need = s.need, score = s.score, pieces = {} }
                sets[c.info.setName] = entry
                setOrder[#setOrder + 1] = entry
            end
            table.insert(entry.pieces, c)
        end
    end
    table.sort(setOrder, function(a, b) return a.score > b.score end)
    for _, entry in ipairs(setOrder) do
        table.sort(entry.pieces, function(a, b) return (a.invSlot and 1 or 0) > (b.invSlot and 1 or 0) end)
        local taken, ids = {}, {}
        for _, c in ipairs(entry.pieces) do
            if #taken >= entry.need then break end
            if not used[c] and not ids[c.info.itemID] and not usedIDs[c.info.itemID] then
                local slot = PickSlot(c, assigned)
                if slot then
                    assigned[slot] = c
                    taken[#taken + 1] = slot
                    ids[c.info.itemID] = true
                end
            end
        end
        if #taken >= entry.need then
            for _, slot in ipairs(taken) do
                used[assigned[slot]] = true
                usedIDs[assigned[slot].info.itemID] = true
            end
        else
            for _, slot in ipairs(taken) do assigned[slot] = nil end
        end
    end

    -- Individual items, best active bonus first; already-equipped items win ties.
    local singles = {}
    for _, c in ipairs(cands) do
        if not used[c] then
            c.score = ActiveScore(c.info, where)
            if c.score > 0 then singles[#singles + 1] = c end
        end
    end
    table.sort(singles, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return (a.invSlot and 1 or 0) > (b.invSlot and 1 or 0)
    end)
    local free, chosen = {}, {}
    for _, c in ipairs(singles) do
        local group = c.info.group
        if free[group] == nil then
            free[group] = 0
            for _, s in ipairs(GroupSlots(group)) do
                if not assigned[s] then free[group] = free[group] + 1 end
            end
        end
        if free[group] > 0 and not usedIDs[c.info.itemID] and IsUsable(c) then
            free[group] = free[group] - 1
            usedIDs[c.info.itemID] = true
            c.zoneBound = ActiveScore({ directs = (function()
                local list = {}
                for _, b in ipairs(c.info.directs) do if not b.zone and not b.cond then list[#list + 1] = b end end
                return list
            end)() }, where) == 0
            chosen[#chosen + 1] = c
        end
    end
    table.sort(chosen, function(a, b)
        local ar = a.invSlot and 0 or (a.zoneBound and 2 or 1)
        local br = b.invSlot and 0 or (b.zoneBound and 2 or 1)
        return ar < br
    end)
    for _, c in ipairs(chosen) do
        local slot = PickSlot(c, assigned)
        if slot then assigned[slot] = c end
    end
    return assigned
end

local foreverAttempts = {}
local function CanAttemptEquip(itemID, slot)
    local key = slot .. ":" .. tostring(itemID)
    local entry = foreverAttempts[key]
    local now = GetTime()
    if entry and (now - entry.time < 3 or entry.count >= 3) then return false end
    foreverAttempts[key] = { time = now, count = (entry and entry.count or 0) + 1 }
    return true
end

local function GallopingActive()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        if C_UnitAuras.GetPlayerAuraBySpellID(GALLOPING_SPELL_ID) then return true end
    end
    local name = ATS.GetItemSpellSafe and ATS:GetItemSpellSafe(GALLOPING_ITEM_ID)
    if not name then return false end
    for i = 1, 40 do
        local buffName
        if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
            local data = C_UnitAuras.GetBuffDataByIndex("player", i)
            buffName = data and data.name
        elseif UnitBuff then
            buffName = UnitBuff("player", i)
        end
        if not buffName then return false end
        if buffName == name then return true end
    end
    return false
end

function ATS:GetGiftOfGallopingStatus()
    if not IS_FOREVER then return end
    if GallopingActive() then return "Active (+10% mounted speed)" end
    if self:GetItemCountSafe(GALLOPING_ITEM_ID) > 0 then return "In bags (use manually)" end
end

local gallopingReminded = false
local function RemindGiftOfGalloping()
    if gallopingReminded then return end
    if (UnitLevel("player") or 0) < 60 then return end
    if ATS:GetItemCountSafe(GALLOPING_ITEM_ID) == 0 or GallopingActive() then return end
    gallopingReminded = true
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100AutoTrinketSwitcher:|r Gift of Galloping is in your bags but not active (+10% mounted speed).")
    end
end

local function EquipForeverSpeedGear(db)
    RemindGiftOfGalloping()

    local wanted = SelectForeverGear(CollectForeverCandidates(db), GetWhere())
    local changed = false
    local restoreSlots = {}
    for _, slot in ipairs(MOUNT_SPEED_RESTORE_SLOTS) do
        local c = wanted[slot]
        local current = GetInventoryItemLink("player", slot)
        local currentID = current and GetItemIDFromLinkOrID(current)
        if currentID then foreverAttempts[slot .. ":" .. currentID] = nil end -- that equip worked
        if c then
            if current == c.link or (c.invSlot == slot and currentID == c.info.itemID) then
                -- already worn
            elseif CanAttemptEquip(c.info.itemID, slot) then
                SaveMountSpeedPrevious(db, slot)
                if slot == 16 then SaveMountSpeedPrevious(db, 17) end -- any main-hand swap may move the off hand
                db.mountSpeedActive = true
                EquipItem(c.link, slot)
                MarkMountSpeedEquip(slot)
                changed = true
            end
        elseif db.mountSpeedPrevious and db.mountSpeedPrevious[slot] ~= nil and not (slot == 17 and wanted[16]) then
            -- Left the zone (or option turned off): put the normal item back.
            restoreSlots[#restoreSlots + 1] = slot
        end
    end
    if #restoreSlots > 0 then
        RestoreMountSpeedSlots(db, restoreSlots)
        changed = true
    end
    return changed
end

local function ScanForeverGear(includeWeapons)
    local db = AutoTrinketSwitcherCharDB or {}
    local savedTrinkets, savedWeapons = db.mountSpeedTrinketsEnabled, db.mountSpeedWeaponsEnabled
    db.mountSpeedTrinketsEnabled = true
    db.mountSpeedWeaponsEnabled = true
    local list = CollectForeverCandidates(db)
    db.mountSpeedTrinketsEnabled, db.mountSpeedWeaponsEnabled = savedTrinkets, savedWeapons
    return list
end

local function ForeverHasSpeedGear()
    return #ScanForeverGear() > 0
end

function ATS:HasForeverSpeedWeapons()
    if not IS_FOREVER then return false end
    for _, c in ipairs(ScanForeverGear()) do
        if c.info.group == 16 then return true end
    end
    return false
end

function ATS:OnMountSpeedWeaponsOptionChanged(enabled)
    Ensure()
    local db = AutoTrinketSwitcherCharDB
    db.mountSpeedWeaponsEnabled = not not enabled
    if not CanSwap() or (InCombatLockdown and InCombatLockdown()) then return end
    if enabled then
        if self.isMounted and db.useMountSpeedManager then self:EquipMountSpeedGear() end
    elseif db.mountSpeedPrevious then
        RestoreMountSpeedSlots(db, { 16, 17 })
    end
    if self.UpdateButtons then self:UpdateButtons() end
end

function ATS:EquipMountSpeedGear()
    Ensure()
    if not CanSwap() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local db = AutoTrinketSwitcherCharDB
    if IS_FOREVER then return EquipForeverSpeedGear(db) end
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
    if IS_FOREVER then return ForeverHasSpeedGear() end
    for _, item in ipairs(MOUNT_SPEED_TRINKETS) do
        if self:GetItemCountSafe(item.itemID) > 0 then return true end
        for _, slot in ipairs(MOUNT_SPEED_TRINKET_SLOTS) do
            if GetInventoryItemID("player", slot) == item.itemID then return true end
        end
    end
    for slot, config in pairs(MOUNT_SPEED_ARMOR) do
        if InventoryItemHasMountSpeedEnchant(slot, config) or FindMountSpeedArmor(config) then return true end
    end
    return false
end

local ATS = CreateFrame("Frame", "AutoTrinketSwitcherFrame")
-- Addon logo used for the minimap button
local ATS_MINIMAP_LOGO = "Interface\\AddOns\\AutoTrinketSwitcher\\Media\\AutoTrinketSwitche_Logo.blp"

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

-- Ensure saved variables exist after they are loaded
local function EnsureDB()
    AutoTrinketSwitcherCharDB = AutoTrinketSwitcherCharDB or {}
    local db = AutoTrinketSwitcherCharDB

    db.queues = db.queues or { [13] = {}, [14] = {} }
    db.menuOnlyOutOfCombat = db.menuOnlyOutOfCombat ~= false
    db.autoSwitch = db.autoSwitch ~= false
    db.readyGlowEnabled = db.readyGlowEnabled ~= false

    if db.showCooldowns ~= nil and db.showCooldownNumbers == nil then
        db.showCooldownNumbers = db.showCooldowns
        db.showCooldowns = nil
    end
    db.showCooldownNumbers = db.showCooldownNumbers ~= false
    db.largeNumbers = db.largeNumbers or false
    db.lockWindows = db.lockWindows or false
    db.tooltipMode = db.tooltipMode or "HOVER"
    db.useDefaultTooltipAnchor = (db.useDefaultTooltipAnchor ~= false)
    db.tinyTooltips = db.tinyTooltips or false
    db.cleanTooltips = db.cleanTooltips or false
    db.menuPosition = db.menuPosition or "BOTTOM"
    db.wrapAt = db.wrapAt or 10

    db.colors = db.colors or {}
    db.colors.slot13 = db.colors.slot13 or { r = 0, g = 1, b = 0 }
    db.colors.slot14 = db.colors.slot14 or { r = 1, g = 0.82, b = 0 }
    db.colors.glow   = db.colors.glow   or { r = 1, g = 1, b = 0 }
    db.colors.manualBadge = db.colors.manualBadge or { r = 1, g = 1, b = 1 }
    db.colors.readyGlow = db.colors.readyGlow or { r = 1, g = 1, b = 1 }

    db.buttonPos = db.buttonPos or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    db.minimap = db.minimap or { hide = false }
    db.manual = db.manual or { [13] = false, [14] = false }
    db.manualPreferred = db.manualPreferred or { [13] = nil, [14] = nil }
    db.buttonFrameHidden = db.buttonFrameHidden == true
    db.queueNumberSize = db.queueNumberSize or 12
    db.wrapDirection = db.wrapDirection or "HORIZONTAL" -- or VERTICAL
    db.altFullTooltips = db.altFullTooltips or false
    db.menuSortMode = db.menuSortMode or "QUEUED_FIRST" -- QUEUED_FIRST | ALPHA | ILEVEL
    db.mountOverrideActive = db.mountOverrideActive or false
    if not db.mountOverrideActive then
        db.mountOverridePrevAutoSwitch = nil
    end
end

-- Sync the options panel 'Enable auto switching' checkbox (if present)
function ATS:UpdateOptionsAutoCheckbox()
    if self.optionCheckboxes and self.optionCheckboxes.autoSwitch then
        local cb = self.optionCheckboxes.autoSwitch
        if cb.SetChecked then
            local db = AutoTrinketSwitcherCharDB or {}
            local m13 = db.manual and db.manual[13]
            local m14 = db.manual and db.manual[14]
            local derivedOn = not (m13 and m14) -- ON if at least one slot is auto
            cb:SetChecked(derivedOn)
        end
    end
end

-- Centralized setter for global auto-switch state, with manual-slot reconciliation.
function ATS:SetGlobalAutoSwitch(enabled)
    EnsureDB()
    local db = AutoTrinketSwitcherCharDB
    enabled = not not enabled

    if not db.manual then db.manual = { [13]=false, [14]=false } end
    if not db.manualPreferred then db.manualPreferred = { [13] = nil, [14] = nil } end
    local previousManual = { [13] = db.manual[13], [14] = db.manual[14] }

    if enabled then
        -- Turning ON: both slots go auto
        db.manual[13] = false
        db.manual[14] = false
        if previousManual[13] then self:RestoreManualTrinket(13) end
        if previousManual[14] then self:RestoreManualTrinket(14) end
    else
        -- Turning OFF: both slots go manual
        db.manual[13] = true
        db.manual[14] = true
        db.manualPreferred[13] = GetInventoryItemID("player", 13)
        db.manualPreferred[14] = GetInventoryItemID("player", 14)
    end

    db.autoSwitch = enabled
    self:UpdateButtons()
    self:UpdateOptionsAutoCheckbox()
end

function ATS:RestoreManualTrinket(slot)
    EnsureDB()
    local db = AutoTrinketSwitcherCharDB
    if not db.manualPreferred then return end

    local itemID = db.manualPreferred[slot]
    if not itemID then return end

    local current = GetInventoryItemID("player", slot)
    if current == itemID then return end

    local count = GetItemCount and GetItemCount(itemID, false) or 1
    if count == 0 then return end

    if C_Item and C_Item.EquipItemByName then
        C_Item.EquipItemByName(itemID, slot)
    else
        EquipItemByName(itemID, slot)
    end

    self.lastEquip = self.lastEquip or {}
    self.lastEquip[slot] = GetTime()
end

-- Called after a per-slot manual toggle to keep global in sync
function ATS:OnManualToggle()
    EnsureDB()
    -- Only refresh UI/checkbox to reflect derived ON/OFF from per-slot manual flags
    self:UpdateButtons()
    self:UpdateOptionsAutoCheckbox()
end

-- Talent profile functions moved to Profiles.lua

-- Helper to position the tooltip at the game's default location (or legacy side-anchored)
-- Tooltip helpers moved to Tooltips.lua

-- Utility: get remaining cooldown for an itemID
local function GetItemRemaining(itemID)
    if not itemID then return 0 end
    local start, duration = GetItemCooldown(itemID)
    if start == 0 or duration == 0 then
        return 0
    end
    local remaining = duration - (GetTime() - start)
    if remaining < 0 then remaining = 0 end
    return remaining
end

-- Find index of an item within a queue (or large number if not present)
local function QueueIndex(slot, itemID)
    if not itemID then return math.huge end
    local q = AutoTrinketSwitcherCharDB.queues[slot]
    for i, id in ipairs(q) do
        if id == itemID then return i end
    end
    return math.huge
end

-- Helper: does an item have a usable effect?
local function ItemHasUse(itemID)
    if not itemID then return false end
    local useName = GetItemSpell(itemID)
    return useName ~= nil
end

local function IsItemEffectActive(itemID)
    if not itemID then return false end
    local spellName = GetItemSpell(itemID)
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

local function SlotTrinketReady(slot)
    local itemID = GetInventoryItemID("player", slot)
    if not itemID or not ItemHasUse(itemID) then return false end
    local start, duration = GetItemCooldown(itemID)
    if not start or not duration then return false end
    if start == 0 or duration == 0 then return true end
    local remaining = start + duration - GetTime()
    return remaining <= 0
end

-- If the top-priority item for a slot isn't ready, reserve the currently equipped
-- slot item (if it is in that slot's queue) so the other slot won't steal it.
local function GetReservationForSlot(slot)
    if AutoTrinketSwitcherCharDB.manual and AutoTrinketSwitcherCharDB.manual[slot] then return nil end
    local q = AutoTrinketSwitcherCharDB.queues[slot]
    if not q or #q == 0 then return nil end
    local topWanted = q[1]
    if GetItemRemaining(topWanted) > 30 then
        local equippedID = GetInventoryItemID("player", slot)
        -- Only reserve if currently equipped is part of this slot's queue
        for _, id in ipairs(q) do
            if id == equippedID then return equippedID end
        end
    end
    return nil
end

-- Choose the first ready trinket for a slot, respecting manual mode and current item cooldown rule,
-- but allowing an upgrade to a higher-priority ready trinket even if the equipped usable trinket is near ready.
local function ChooseCandidate(slot, avoidID)
    if AutoTrinketSwitcherCharDB.manual and AutoTrinketSwitcherCharDB.manual[slot] then return nil end
    local equippedID = GetInventoryItemID("player", slot)
    local equippedCD = GetItemRemaining(equippedID)
    local equippedHasUse = ItemHasUse(equippedID)

    if equippedHasUse and IsItemEffectActive(equippedID) then
        return nil
    end

    local queue = AutoTrinketSwitcherCharDB.queues[slot]
    local equippedIdx = QueueIndex(slot, equippedID)

    local targetID, targetIdx
    local otherSlot = (slot == 13) and 14 or 13
    local reservedOther = GetReservationForSlot(otherSlot)
    for i, itemID in ipairs(queue) do
        if itemID ~= equippedID and itemID ~= avoidID and itemID ~= reservedOther then
            local allowed = true
            -- Skip items not in bags/equipped
            local count = GetItemCount and GetItemCount(itemID, false) or 1
            if count == 0 then allowed = false end
            if allowed then
                local cd = GetItemRemaining(itemID)
                if cd <= 30 then
                    targetID, targetIdx = itemID, i
                    break
                end
            end
        end
    end
    if not targetID then return nil end

    -- Apply "don't swap off a near-ready usable trinket" unless the target has strictly higher priority
    if equippedHasUse and equippedCD <= 30 then
        if targetIdx and equippedIdx and targetIdx >= equippedIdx then
            return nil
        end
    end

    return targetID
end
-- Return queue position of an item for a slot or nil
function ATS:GetQueuePosition(slot, itemID)
    for i, id in ipairs(AutoTrinketSwitcherCharDB.queues[slot]) do
        if id == itemID then
            return i
        end
    end
end

-- Add or remove a trinket from a slot queue
function ATS:ToggleTrinket(slot, itemID)
    local queue = AutoTrinketSwitcherCharDB.queues[slot]
    for i, id in ipairs(queue) do
        if id == itemID then
            table.remove(queue, i)
            return
        end
    end
    table.insert(queue, itemID)
end

-- Apply configured colors to active UI elements
function ATS:ApplyColorSettings()
    if self.menu and self.menu.icons then
        local c13 = AutoTrinketSwitcherCharDB.colors.slot13
        local c14 = AutoTrinketSwitcherCharDB.colors.slot14
        for _, btn in ipairs(self.menu.icons) do
            btn.pos13:SetTextColor(c13.r, c13.g, c13.b)
            btn.pos14:SetTextColor(c14.r, c14.g, c14.b)
        end
    end

    local glowColor = AutoTrinketSwitcherCharDB.colors.glow
    for _, button in pairs(self.buttons or {}) do
        if button.glow then
            button.glow:SetVertexColor(glowColor.r, glowColor.g, glowColor.b, 1)
        end
        if button.manualBadge then
            local mb = AutoTrinketSwitcherCharDB.colors.manualBadge
            button.manualBadge:SetTextColor(mb.r, mb.g, mb.b, 1)
        end
    end
end

function ATS:UpdateCooldownFont()
    local font, size = NumberFontNormal:GetFont()
    if AutoTrinketSwitcherCharDB.largeNumbers then
        size = size + 3
    end
    for _, button in pairs(self.buttons or {}) do
        button.cdText:SetFont(font, size, "THICKOUTLINE")
    end
    if self.menu and self.menu.icons then
        for _, btn in ipairs(self.menu.icons) do
            if btn.cdText then
                btn.cdText:SetFont(font, size, "THICKOUTLINE")
            end
        end
    end
end

function ATS:UpdateLockState()
    if self.buttonFrame then
        local locked = AutoTrinketSwitcherCharDB.lockWindows
        self.buttonFrame:EnableMouse(not locked)
        self.buttonFrame:SetMovable(not locked)
    end
end

-- Tooltip display functions moved to Tooltips.lua

-- Attempt to equip a trinket for a given slot based on the rules
local function CheckSlot(slot)
    local equippedID = GetInventoryItemID("player", slot)
    local equippedCD = GetItemRemaining(equippedID)
    local equippedHasUse = false
    if equippedID then
        local useName = GetItemSpell(equippedID)
        equippedHasUse = useName ~= nil
    end
    if equippedHasUse and IsItemEffectActive(equippedID) then return end
    -- Only block swapping if the equipped trinket is a usable item AND its cooldown <= 30s
    if equippedHasUse and equippedCD <= 30 then return end

    -- Respect per-slot manual mode
    if AutoTrinketSwitcherCharDB.manual and AutoTrinketSwitcherCharDB.manual[slot] then return end

    for _, itemID in ipairs(AutoTrinketSwitcherCharDB.queues[slot]) do
        if itemID ~= equippedID then
            local cd = GetItemRemaining(itemID)
            -- Trinket is ready to be swapped in if it has 30s or less cooldown remaining
            if cd <= 30 then
                if C_Item and C_Item.EquipItemByName then
                    C_Item.EquipItemByName(itemID, slot)
                else
                    EquipItemByName(itemID, slot)
                end
                break
            end
        end
    end
end

-- Apply font size to queue numbers in the menu
function ATS:ApplyMenuQueueFont()
    if not (self.menu and self.menu.icons) then return end
    local f, defaultSize = GameFontNormal:GetFont()
    local size = AutoTrinketSwitcherCharDB.queueNumberSize or defaultSize or 12
    for _, btn in ipairs(self.menu.icons) do
        if btn.pos13 then btn.pos13:SetFont(f, size) end
        if btn.pos14 then btn.pos14:SetFont(f, size) end
    end
end

-- Determine if a swap would occur for a slot when out of combat
local function PendingSwap(slot)
    local equippedID = GetInventoryItemID("player", slot)
    -- Announce a switch when a queued trinket is within 35s of being ready (or ready)
    for _, itemID in ipairs(AutoTrinketSwitcherCharDB.queues[slot]) do
        if itemID ~= equippedID then
            local proceed = true
            local count = GetItemCount and GetItemCount(itemID, false) or 1
            if count == 0 then proceed = false end
            if proceed then
                local cd = GetItemRemaining(itemID)
                if cd <= 35 then
                    return true
                end
            end
        end
    end
    return false
end

-- Run check for both slots if out of combat
function ATS:PerformCheck()
    -- Periodically ensure mount state is respected even if an event was missed
    if self.UpdateMountState then self:UpdateMountState() end

    -- After dismount, give gear a short settling period to avoid oscillation
    if self.resumeGuardUntil and GetTime() < self.resumeGuardUntil then
        self:UpdateButtons()
        return
    end

    if AutoTrinketSwitcherCharDB.autoSwitch and not InCombatLockdown() then
        local cand13 = ChooseCandidate(13)
        local cand14 = ChooseCandidate(14)
        if cand13 and cand14 and cand13 == cand14 then
            local alt14 = ChooseCandidate(14, cand13)
            cand14 = alt14
        end
        if cand13 then
            local allow = true
            if self.lastEquip and self.lastEquip[13] and (GetTime() - self.lastEquip[13] < 0.75) then
                allow = false
            end
            if allow then
            if C_Item and C_Item.EquipItemByName then
                C_Item.EquipItemByName(cand13, 13)
            else
                EquipItemByName(cand13, 13)
            end
            self.lastEquip = self.lastEquip or {}
            self.lastEquip[13] = GetTime()
            end
        end
        if cand14 then
            local allow = true
            if self.lastEquip and self.lastEquip[14] and (GetTime() - self.lastEquip[14] < 0.75) then
                allow = false
            end
            if allow then
            if C_Item and C_Item.EquipItemByName then
                C_Item.EquipItemByName(cand14, 14)
            else
                EquipItemByName(cand14, 14)
            end
            self.lastEquip = self.lastEquip or {}
            self.lastEquip[14] = GetTime()
            end
        end
    end
    self:UpdateButtons()
end

-- Update the icons on the slot buttons
function ATS:UpdateButtons()
    if not self.buttons then return end
    for slot, button in pairs(self.buttons) do
        local itemID = GetInventoryItemID("player", slot)
        local texture = GetInventoryItemTexture("player", slot)
        if texture then
            button.icon:SetTexture(texture)
        else
            button.icon:SetTexture(134400) -- default icon
        end
        if AutoTrinketSwitcherCharDB.autoSwitch and not (AutoTrinketSwitcherCharDB.manual and AutoTrinketSwitcherCharDB.manual[slot]) and InCombatLockdown() and PendingSwap(slot) then
            local c = AutoTrinketSwitcherCharDB.colors.glow
            button.glow:SetVertexColor(c.r, c.g, c.b, 1)
            button.glow:Show()
        else
            button.glow:Hide()
        end

        -- Mount/ready indication reuse the same highlight frame
        if button.mountGlow then
            local mountOverrideActive = (self.mountAutoModified == true) or (AutoTrinketSwitcherCharDB and AutoTrinketSwitcherCharDB.mountOverrideActive)
            local mountActive = self.isMounted or mountOverrideActive
            if mountActive then
                button.mountGlow:SetVertexColor(1, 0, 0, 1)
                button.mountGlow:Show()
            elseif AutoTrinketSwitcherCharDB.readyGlowEnabled ~= false and SlotTrinketReady(slot) then
                local c = AutoTrinketSwitcherCharDB.colors.readyGlow
                button.mountGlow:SetVertexColor(c.r, c.g, c.b, 1)
                button.mountGlow:Show()
            else
                button.mountGlow:Hide()
            end
        end

        -- Manual badge visibility
        if button.manualBadge then
            local isManualSlot = AutoTrinketSwitcherCharDB.manual and AutoTrinketSwitcherCharDB.manual[slot]
            -- Show badge only for per-slot manual state. Ignore global auto state.
            if isManualSlot then button.manualBadge:Show() else button.manualBadge:Hide() end
        end

        -- Handle cooldown overlay and text
        if itemID then
            local start, duration = GetItemCooldown(itemID)
            if start and duration and start > 0 and duration > 0 then
                button.cooldown:SetCooldown(start, duration)
                button.cooldown:Show()
                if AutoTrinketSwitcherCharDB.showCooldownNumbers then
                    local remaining = start + duration - GetTime()
                    if remaining > 0 then
                        if remaining >= 60 then
                            button.cdText:SetText(string.format("%d m", math.ceil(remaining / 60)))
                        else
                            button.cdText:SetText(math.ceil(remaining))
                        end
                        button.cdText:Show()
                    else
                        button.cdText:Hide()
                    end
                else
                    button.cdText:Hide()
                end
            else
                button.cooldown:Hide()
                button.cdText:Hide()
            end
        else
            button.cooldown:Hide()
            button.cdText:Hide()
        end
    end
    if self.menu and self.menu:IsShown() then
        self:UpdateMenuCooldowns()
    end
    -- Keep minimap icon in sync with slot 13
    if self.UpdateMinimapIcon then self:UpdateMinimapIcon() end
end

function ATS:OnMinimapClick(mouse)
    EnsureDB()
    if mouse == "LeftButton" then
        if self.buttonFrame then
            if self.buttonFrame:IsShown() then
                self.buttonFrame:Hide()
                AutoTrinketSwitcherCharDB.buttonFrameHidden = true
            else
                self.buttonFrame:Show()
                AutoTrinketSwitcherCharDB.buttonFrameHidden = false
            end
        end
    elseif mouse == "RightButton" then
        if IsShiftKeyDown() then
            AutoTrinketSwitcherCharDB.lockWindows = not AutoTrinketSwitcherCharDB.lockWindows
            if self.UpdateLockState then self:UpdateLockState() end
        elseif IsControlKeyDown() then
            local manual = AutoTrinketSwitcherCharDB.manual or {}
            local on = not ((manual[13]) and (manual[14]))
            self:SetGlobalAutoSwitch(not on)
        else
            if self.optionsWindow then
                if self.optionsWindow:IsShown() then
                    self.optionsWindow:Hide()
                    if self.optionsPanel then self.optionsPanel:Hide() end
                else
                    if self.optionsPanel then self.optionsPanel:Show() end
                    self.optionsWindow:Show()
                end
            end
        end
        if self.menu and self.menu:IsShown() then self.menu:Hide() end
    end
end

function ATS:OnMinimapTooltipShow(tooltip)
    if not tooltip then return end
    tooltip:SetText("AutoTrinketSwitcher")
    local WHITE = "FFFFFFFF"
    local GOLD  = "FFFFD100"
    local function line(label, text)
        return "|c"..WHITE..label.."|r |c"..GOLD..text.."|r"
    end
    tooltip:AddLine(line("Left-Click:", "Show/Hide Trinkets"))
    tooltip:AddLine(line("Right-Click:", "Open Option Menu"))
    tooltip:AddLine(line("Shift+ Right-Click:", "Lock/Unlock Buttons"))
    tooltip:AddLine(line("Ctrl + Right-Click:", "Toggle Auto Switching"))
    tooltip:Show()
end
-- Update minimap button icon to the currently equipped trinket in slot 13
function ATS:UpdateMinimapIcon()
    if self.minimapLDB then
        self.minimapLDB.icon = ATS_MINIMAP_LOGO
        self.minimapLDB.iconCoords = {0.08, 0.92, 0.08, 0.92}
    end

    if not self.minimapButton or not self.minimapButton.icon then
        return
    end

    self.minimapButton.icon:SetTexture(ATS_MINIMAP_LOGO)
    if self.minimapButton.icon.SetTexCoord then
        self.minimapButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

-- Create the two slot buttons
function ATS:CreateButtons()
    self.buttons = {}

    -- Container frame around the buttons so players can see where to drag
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "ATSButtons", UIParent, template)
    frame:SetSize(84, 44)
    local pos = AutoTrinketSwitcherCharDB.buttonPos or {}
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    frame:EnableMouse(not AutoTrinketSwitcherCharDB.lockWindows)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        AutoTrinketSwitcherCharDB.buttonPos.point = point
        AutoTrinketSwitcherCharDB.buttonPos.relativePoint = relativePoint
        AutoTrinketSwitcherCharDB.buttonPos.x = x
        AutoTrinketSwitcherCharDB.buttonPos.y = y
    end)

    -- Add a subtle backdrop so the drag area is visible
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.5)
    end

    self.buttonFrame = frame
    if AutoTrinketSwitcherCharDB.buttonFrameHidden then
        frame:Hide()
    else
        frame:Show()
    end

    for index, slot in ipairs({13, 14}) do
        -- Use a secure action button so activating the trinket does not taint
        local btn = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
        btn:SetSize(36, 36)
        btn:SetPoint("LEFT", 4 + (index - 1) * 40, 0)

        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetAttribute("type1", "macro")
        btn:SetAttribute("macrotext", "/use " .. slot)

        btn.icon = btn:CreateTexture(nil, "BACKGROUND")
        btn.icon:SetAllPoints(true)

        -- Cooldown overlay and countdown text
        btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        btn.cooldown:SetAllPoints(true)
        btn.cooldown:SetFrameLevel(btn:GetFrameLevel())
        btn.cooldown:SetDrawEdge(false)
        btn.cooldown:Hide()
        btn.cdText = btn.cooldown:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        btn.cdText:SetPoint("CENTER")
        btn.cdText:SetDrawLayer("OVERLAY", 7)
        btn.cdText:Hide()

        btn.glow = btn:CreateTexture(nil, "OVERLAY")
        btn.glow:SetTexture("Interface/Buttons/UI-ActionButton-Border")
        btn.glow:SetBlendMode("ADD")
        btn.glow:SetPoint("CENTER")
        btn.glow:SetSize(60, 60)
        btn.glow:Hide()

        -- Mount mode red glow (separate from pending swap glow)
        btn.mountGlow = btn:CreateTexture(nil, "OVERLAY")
        btn.mountGlow:SetTexture("Interface/Buttons/UI-ActionButton-Border")
        btn.mountGlow:SetBlendMode("ADD")
        btn.mountGlow:SetPoint("CENTER")
        btn.mountGlow:SetSize(64, 64)
        btn.mountGlow:Hide()

        -- Manual mode badge (bottom-left)
        btn.manualBadge = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.manualBadge:SetPoint("BOTTOMLEFT", 2, 2)
        btn.manualBadge:SetText("M")
        btn.manualBadge:SetTextColor(1, 1, 1, 1)
        btn.manualBadge:SetDrawLayer("OVERLAY", 8)
        btn.manualBadge:Hide()

        btn.slot = slot
        -- Use PostClick so the SecureActionButton's default OnClick handler still fires
        btn:SetScript("PostClick", function(self, mouse)
            if mouse == "RightButton" and AutoTrinketSwitcherCharDB.tooltipMode == "RIGHTCLICK" then
                ATS.tooltipPinned = not ATS.tooltipPinned
                if ATS.tooltipPinned then
                    ATS:ShowTooltip(self, slot)
                else
                    ATS:HideTooltip()
                    ATS.tooltipContext = nil
                end
            end
        end)

        btn:SetScript("OnEnter", function(self)
            ATS:ShowMenu(btn)
            if AutoTrinketSwitcherCharDB.tooltipMode == "HOVER" or ATS.tooltipPinned then
                ATS:ShowTooltip(self, slot)
            end
        end)
        btn:SetScript("OnLeave", function()
            ATS:TryHideMenu()
            if not ATS.tooltipPinned then
                ATS:HideTooltip()
                ATS.tooltipContext = nil
            end
        end)

        self.buttons[slot] = btn
    end

    self:UpdateButtons()
    self:ApplyColorSettings()
    self:UpdateCooldownFont()
    self:UpdateLockState()
end

-- Create a minimap button for quick toggles
function ATS:CreateMinimapButton()
    EnsureDB()
    local db = AutoTrinketSwitcherCharDB

    if LDB and LDBIcon then
        if not self.minimapLDB then
            self.minimapLDB = LDB:NewDataObject("AutoTrinketSwitcher", {
                type = "launcher",
                icon = ATS_MINIMAP_LOGO,
                iconCoords = {0.08, 0.92, 0.08, 0.92},
                OnClick = function(_, mouse) ATS:OnMinimapClick(mouse) end,
                OnTooltipShow = function(tooltip) ATS:OnMinimapTooltipShow(tooltip) end,
            })
        else
            self.minimapLDB.icon = ATS_MINIMAP_LOGO
            self.minimapLDB.iconCoords = {0.08, 0.92, 0.08, 0.92}
        end

        db.minimap = db.minimap or { hide = false }

        if not LDBIcon:IsRegistered("AutoTrinketSwitcher") then
            LDBIcon:Register("AutoTrinketSwitcher", self.minimapLDB, db.minimap)
        end

        if db.minimap.hide then
            LDBIcon:Hide("AutoTrinketSwitcher")
        else
            LDBIcon:Show("AutoTrinketSwitcher")
        end

        if LDBIcon.GetMinimapButton then
            self.minimapButton = LDBIcon:GetMinimapButton("AutoTrinketSwitcher") or self.minimapButton
        end

        self:UpdateMinimapIcon()
        return
    end

    local btn = CreateFrame("Button", "ATS_MinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("HIGH")
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("CENTER", 0, 0)
    btn.icon:SetSize(20, 20)
    btn.icon:SetTexture(ATS_MINIMAP_LOGO)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.border = btn:CreateTexture(nil, "OVERLAY")
    btn.border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")
    btn.border:SetSize(54, 54)
    btn.border:ClearAllPoints()
    btn.border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

    btn:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")

    btn:SetScript("OnClick", function(_, mouse) ATS:OnMinimapClick(mouse) end)

    btn:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        ATS:OnMinimapTooltipShow(GameTooltip)
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.minimapButton = btn
    self:UpdateMinimapIcon()
end

function ATS:PLAYER_LOGIN()
    EnsureDB()
    -- Initialize or attach to the talent-based profile for the current build
    self:SyncActiveTalentProfile({ silent = true })
    -- Prune missing items from queues on login
    if self.PruneMissingFromQueues then self:PruneMissingFromQueues() end
    self:CreateOptions()
    self:CreateButtons()
    self:CreateMinimapButton()
    self.tooltipPinned = false
    self.elapsed = 0
    self.cdElapsed = 0
    self.mountAutoModified = false
    self.prevAutoSwitch = nil
    self.isMounted = false
    self:SetScript("OnUpdate", function(_, e)
        self.elapsed = self.elapsed + e
        self.cdElapsed = self.cdElapsed + e
        if self.elapsed > 1 then
            self.elapsed = 0
            self:PerformCheck()
        end
        if self.cdElapsed > 0.1 then
            self.cdElapsed = 0
            self:UpdateButtons()
        end
    end)
    -- Clear tooltip context if tooltip is hidden by any external cause
    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnHide", function()
            if not ATS.tooltipPinned then ATS.tooltipContext = nil end
        end)
    end
    -- Initialize mount state
    if self.UpdateMountState then self:UpdateMountState() end

    -- Slash command: /ats and /ats help show quick usage help
    SLASH_AUTOTRINKETSWITCHER1 = "/ats"
    SlashCmdList["AUTOTRINKETSWITCHER"] = function(msg)
        local function out(text)
            DEFAULT_CHAT_FRAME:AddMessage(text)
        end
        local function header(text)
            out("|cffffd100" .. text .. "|r")
        end
        local function bullet(text)
            out("  - " .. text)
        end

        msg = tostring(msg or ""):lower():gsub("^%s+"," "):gsub("%s+$","")
        if msg:match("^clear") then
            local which = msg:match("^clear%s+(%S+)") or ""
            local function clear(slot)
                AutoTrinketSwitcherCharDB.queues[slot] = {}
            end
            if which == "13" then
                clear(13)
                header("Auto Trinket Switcher")
                bullet("Cleared queue for slot 13")
            elseif which == "14" then
                clear(14)
                header("Auto Trinket Switcher")
                bullet("Cleared queue for slot 14")
            elseif which == "both" or which == "all" then
                clear(13); clear(14)
                header("Auto Trinket Switcher")
                bullet("Cleared queues for slot 13 and 14")
            else
                header("Auto Trinket Switcher")
                bullet("Usage: /ats clear 13 | 14 | both")
            end
            if ATS.menu and ATS.menu:IsShown() and ATS.menu.anchor then ATS:ShowMenu(ATS.menu.anchor) end
            ATS:UpdateButtons()
            return
        end

        -- Help
        header("Auto Trinket Switcher")
        bullet("Hover: Shows menu; also shows tooltip if enabled")
        bullet("Left-click: Use Trinket")
        bullet("Shift + Left/Right-Click: Add/Remove trinket to the priority queue (Left = slot 13, Right = slot 14)")
        bullet("Ctrl + Left/Right-Click: Equip AND toggle manual mode (Left = slot 13, Right = slot 14)")
        bullet("Right-Click: Toggle pinned tooltip when tooltip mode is Right-Click")
        bullet("Slash: /ats clear 13 | 14 | both")
    end
end

ATS:RegisterEvent("PLAYER_LOGIN")
ATS:RegisterEvent("PLAYER_REGEN_ENABLED")
ATS:RegisterEvent("UNIT_AURA")
ATS:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
ATS:RegisterEvent("PLAYER_ENTERING_WORLD")
ATS:RegisterEvent("ZONE_CHANGED")
ATS:RegisterEvent("ZONE_CHANGED_INDOORS")
ATS:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ATS:RegisterEvent("MODIFIER_STATE_CHANGED")
-- Talent-change events across Classic/Wrath variants
ATS:RegisterEvent("CHARACTER_POINTS_CHANGED")
ATS:RegisterEvent("PLAYER_TALENT_UPDATE")
ATS:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ATS:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:PerformCheck()
    elseif event == "UNIT_AURA" then
        -- React to mount state changes via aura changes
        self:UpdateMountState()
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        self:UpdateMountState()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        self:UpdateMountState()
    elseif event == "CHARACTER_POINTS_CHANGED" then
        -- Debounce rapid talent point updates while respecing
        self._talentChangePing = GetTime()
        if C_Timer and C_Timer.After then
            C_Timer.After(1.0, function()
                if not ATS._talentChangePing then return end
                if GetTime() - ATS._talentChangePing >= 0.9 then
                    ATS._talentChangePing = nil
                    ATS:OnTalentConfigurationChanged()
                end
            end)
        else
            -- Fallback without timers
            ATS:OnTalentConfigurationChanged()
        end
    elseif event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        self:OnTalentConfigurationChanged()
    elseif self[event] then
        self[event](self)
    end
end)

-- Talent-change handling moved to Profiles.lua

-- Mount handling: auto-disable autoSwitch when mounting; restore previous state on dismount
function ATS:UpdateMountState()
    EnsureDB()
    local db = AutoTrinketSwitcherCharDB
    local prevMounted = self.isMounted
    local mounted = false
    if IsMounted then
        mounted = IsMounted()
    else
        -- Fallback: simple check via movement speed or auras is omitted to avoid false positives in Classic
        mounted = false
    end

    local refreshButtons = false
    local refreshOptions = false

    if mounted then
        -- Rehydrate the mount override if we relog while already mounted
        if not self.mountAutoModified and db.mountOverrideActive then
            self.prevAutoSwitch = db.mountOverridePrevAutoSwitch
            self.mountAutoModified = true
            refreshButtons = true
            refreshOptions = true
        end

        if not self.mountAutoModified and db.autoSwitch then
            local previous = db.autoSwitch and true or false
            db.autoSwitch = false
            self.prevAutoSwitch = previous
            self.mountAutoModified = true
            db.mountOverrideActive = true
            db.mountOverridePrevAutoSwitch = previous
            refreshButtons = true
            refreshOptions = true
        end
    else
        if self.mountAutoModified or db.mountOverrideActive then
            local restore = self.prevAutoSwitch
            if restore == nil then
                restore = db.mountOverridePrevAutoSwitch
            end
            db.autoSwitch = restore and true or false
            self.prevAutoSwitch = nil
            self.mountAutoModified = false
            db.mountOverrideActive = false
            db.mountOverridePrevAutoSwitch = nil
            refreshButtons = true
            refreshOptions = true
            -- Guard against immediate rapid swaps after dismount
            self.resumeGuardUntil = GetTime() + 1.5
        end
    end

    self.isMounted = mounted

    if refreshOptions then
        self:UpdateOptionsAutoCheckbox()
    end

    if refreshButtons or prevMounted ~= mounted then
        self:UpdateButtons()
    end
end

-- Respond to ALT (or any modifier) changes to live-refresh tooltip details
function ATS:MODIFIER_STATE_CHANGED()
    if not AutoTrinketSwitcherCharDB or not AutoTrinketSwitcherCharDB.altFullTooltips then return end
    self:RefreshTooltip()
end

-- Remove any queued items that are not currently in the player's bags or equipped
function ATS:PruneMissingFromQueues()
    if not AutoTrinketSwitcherCharDB or not AutoTrinketSwitcherCharDB.queues then return end
    for _, slot in ipairs({13,14}) do
        local q = AutoTrinketSwitcherCharDB.queues[slot]
        local i = 1
        while i <= #q do
            local id = q[i]
            local count = GetItemCount and GetItemCount(id, false) or 1
            local eq13 = GetInventoryItemID("player", 13)
            local eq14 = GetInventoryItemID("player", 14)
            if count == 0 and id ~= eq13 and id ~= eq14 then
                table.remove(q, i)
            else
                i = i + 1
            end
        end
    end
    if self.menu and self.menu:IsShown() then
        self:RefreshMenuNumbers()
    end
end

local ATS = CreateFrame("Frame", "AutoTrinketSwitcherFrame")

-- Ensure saved variables exist after they are loaded
local function EnsureDB()
    AutoTrinketSwitcherCharDB = AutoTrinketSwitcherCharDB or {}
    local db = AutoTrinketSwitcherCharDB

    db.queues = db.queues or { [13] = {}, [14] = {} }
    db.menuOnlyOutOfCombat = db.menuOnlyOutOfCombat ~= false
    db.autoSwitch = db.autoSwitch ~= false

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
    db.menuPosition = db.menuPosition or "BOTTOM"
    db.wrapAt = db.wrapAt or 10

    db.colors = db.colors or {}
    db.colors.slot13 = db.colors.slot13 or { r = 0, g = 1, b = 0 }
    db.colors.slot14 = db.colors.slot14 or { r = 1, g = 0.82, b = 0 }
    db.colors.glow   = db.colors.glow   or { r = 1, g = 1, b = 0 }
    db.colors.manualBadge = db.colors.manualBadge or { r = 1, g = 1, b = 1 }

    db.buttonPos = db.buttonPos or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    db.manual = db.manual or { [13] = false, [14] = false }
    db.queueNumberSize = db.queueNumberSize or 12
    db.wrapDirection = db.wrapDirection or "HORIZONTAL" -- or VERTICAL
end

-- Helper to position the tooltip at the game's default location (or legacy side-anchored)
local function SetTooltipOwner(frame)
    if AutoTrinketSwitcherCharDB.useDefaultTooltipAnchor then
        GameTooltip:SetOwner(frame, "ANCHOR_NONE")
        if GameTooltip_SetDefaultAnchor then
            GameTooltip_SetDefaultAnchor(GameTooltip, frame)
        else
            GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -13, 64)
        end
    else
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    end
end

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

    local queue = AutoTrinketSwitcherCharDB.queues[slot]
    local equippedIdx = QueueIndex(slot, equippedID)

    local targetID, targetIdx
    local otherSlot = (slot == 13) and 14 or 13
    local reservedOther = GetReservationForSlot(otherSlot)
    for i, itemID in ipairs(queue) do
        if itemID ~= equippedID and itemID ~= avoidID and itemID ~= reservedOther then
            local cd = GetItemRemaining(itemID)
            if cd <= 30 then
                targetID, targetIdx = itemID, i
                break
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

-- Display tooltip for an equipped slot
function ATS:ShowTooltip(frame, slot)
    if AutoTrinketSwitcherCharDB.tinyTooltips then
        local itemID = GetInventoryItemID("player", slot)
        if not itemID then return end
        SetTooltipOwner(frame)
        local name = GetItemInfo(itemID)
        if name then GameTooltip:SetText(name) end
        local _, desc = GetItemSpell(itemID)
        if desc then GameTooltip:AddLine(desc, 1, 1, 1) end
        GameTooltip:Show()
    else
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", slot)
    end
end

-- Display tooltip for an itemID (used in the menu)
function ATS:ShowItemTooltip(frame, itemID)
    if AutoTrinketSwitcherCharDB.tinyTooltips then
        SetTooltipOwner(frame)
        local name = GetItemInfo(itemID)
        if name then GameTooltip:SetText(name) end
        local _, desc = GetItemSpell(itemID)
        if desc then GameTooltip:AddLine(desc, 1, 1, 1) end
        GameTooltip:Show()
    else
        SetTooltipOwner(frame)
        GameTooltip:SetItemByID(itemID)
    end
end

-- Attempt to equip a trinket for a given slot based on the rules
local function CheckSlot(slot)
    local equippedID = GetInventoryItemID("player", slot)
    local equippedCD = GetItemRemaining(equippedID)
    local equippedHasUse = false
    if equippedID then
        local useName = GetItemSpell(equippedID)
        equippedHasUse = useName ~= nil
    end
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
            local cd = GetItemRemaining(itemID)
            if cd <= 35 then
                return true
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

        -- Manual badge visibility: show when slot is manual OR global auto-switch is off
        if button.manualBadge then
            local isManualSlot = AutoTrinketSwitcherCharDB.manual and AutoTrinketSwitcherCharDB.manual[slot]
            local globalManual = not AutoTrinketSwitcherCharDB.autoSwitch
            if isManualSlot or globalManual then
                button.manualBadge:Show()
            else
                button.manualBadge:Hide()
            end
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
                    GameTooltip:Hide()
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
                GameTooltip:Hide()
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
    local btn = CreateFrame("Button", "ATS_MinimapButton", Minimap)
    btn:SetSize(40, 40)
    btn:SetFrameStrata("MEDIUM")
    btn:SetPoint("TOPLEFT")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn.icon = btn:CreateTexture(nil, "BACKGROUND")
    -- Use a clear trinket-like icon that is always available
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if faction == "Alliance" then
        btn.icon:SetTexture("Interface/TargetingFrame/UI-PVP-ALLIANCE")
    elseif faction == "Horde" then
        btn.icon:SetTexture("Interface/TargetingFrame/UI-PVP-Horde")
    else
        btn.icon:SetTexture(134430)
    end
    btn.icon:ClearAllPoints()
    btn.icon:SetPoint("CENTER", 0, 0)
    btn.icon:SetSize(34, 34)
    btn.icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)

    btn:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")

    btn:SetScript("OnClick", function(_, mouse)
        if mouse == "LeftButton" then
            if ATS.buttonFrame:IsShown() then
                ATS.buttonFrame:Hide()
            else
                ATS.buttonFrame:Show()
            end
        elseif mouse == "RightButton" then
            if IsShiftKeyDown() then
                AutoTrinketSwitcherCharDB.lockWindows = not AutoTrinketSwitcherCharDB.lockWindows
                ATS:UpdateLockState()
            elseif IsControlKeyDown() then
                AutoTrinketSwitcherCharDB.autoSwitch = not AutoTrinketSwitcherCharDB.autoSwitch
                ATS:UpdateButtons()
            else
                if ATS.optionsWindow then
                    if ATS.optionsWindow:IsShown() then
                        ATS.optionsWindow:Hide()
                        if ATS.optionsPanel then ATS.optionsPanel:Hide() end
                    else
                        if ATS.optionsPanel then ATS.optionsPanel:Show() end
                        ATS.optionsWindow:Show()
                    end
                end
            end
            -- Also hide the trinket menu if it is open
            if ATS.menu and ATS.menu:IsShown() then ATS.menu:Hide() end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local icon = "|TInterface/PaperDoll/UI-PaperDoll-Slot-Trinket:16:16|t"
        GameTooltip:SetText(icon .. " AutoTrinketSwitcher")
        local WHITE = "FFFFFFFF"
        local GOLD  = "FFFFD100"
        local function line(label, text)
            return "|c"..WHITE..label.."|r |c"..GOLD..text.."|r"
        end
        GameTooltip:AddLine(line("Left-Click:", "Show/Hide Trinkets"))
        GameTooltip:AddLine(line("Right-Click:", "Open Option Menu"))
        GameTooltip:AddLine(line("Shift+ Right-Click:", "Lock/Unlock Buttons"))
        GameTooltip:AddLine(line("Ctrl + Right-Click:", "Toggle Auto Switching"))
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.minimapButton = btn
end

function ATS:PLAYER_LOGIN()
    EnsureDB()
    self:CreateOptions()
    self:CreateButtons()
    self:CreateMinimapButton()
    self.tooltipPinned = false
    self.elapsed = 0
    self.cdElapsed = 0
    self.mountAutoModified = false
    self.prevAutoSwitch = nil
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
    -- Initialize mount state
    if self.UpdateMountState then self:UpdateMountState() end
end

ATS:RegisterEvent("PLAYER_LOGIN")
ATS:RegisterEvent("PLAYER_REGEN_ENABLED")
ATS:RegisterEvent("UNIT_AURA")
ATS:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
ATS:RegisterEvent("PLAYER_ENTERING_WORLD")
ATS:RegisterEvent("ZONE_CHANGED")
ATS:RegisterEvent("ZONE_CHANGED_INDOORS")
ATS:RegisterEvent("ZONE_CHANGED_NEW_AREA")
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
    elseif self[event] then
        self[event](self)
    end
end)

-- Mount handling: auto-disable autoSwitch when mounting; restore previous state on dismount
function ATS:UpdateMountState()
    local mounted = false
    if IsMounted then
        mounted = IsMounted()
    else
        -- Fallback: simple check via movement speed or auras is omitted to avoid false positives in Classic
        mounted = false
    end

    if mounted then
        if not self.mountAutoModified then
            self.prevAutoSwitch = AutoTrinketSwitcherCharDB.autoSwitch
            if AutoTrinketSwitcherCharDB.autoSwitch then
                AutoTrinketSwitcherCharDB.autoSwitch = false
                self.mountAutoModified = true
                self:UpdateButtons()
            end
        end
    else
        if self.mountAutoModified then
            AutoTrinketSwitcherCharDB.autoSwitch = self.prevAutoSwitch and true or false
            self.prevAutoSwitch = nil
            self.mountAutoModified = false
            self:UpdateButtons()
            -- Guard against immediate rapid swaps after dismount
            self.resumeGuardUntil = GetTime() + 1.5
        end
    end
end

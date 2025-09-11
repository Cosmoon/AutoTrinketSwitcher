local ATS = CreateFrame("Frame", "AutoTrinketSwitcherFrame")

-- Ensure saved variables exist after they are loaded
local function EnsureDB()
    AutoTrinketSwitcherCharDB = AutoTrinketSwitcherCharDB or {}
    local db = AutoTrinketSwitcherCharDB

    db.queues = db.queues or { [13] = {}, [14] = {} }
    db.menuOnlyOutOfCombat = db.menuOnlyOutOfCombat ~= false

    if db.showCooldowns ~= nil and db.showCooldownNumbers == nil then
        db.showCooldownNumbers = db.showCooldowns
        db.showCooldowns = nil
    end
    db.showCooldownNumbers = db.showCooldownNumbers ~= false
    db.largeNumbers = db.largeNumbers or false
    db.lockWindows = db.lockWindows or false
    db.tooltipMode = db.tooltipMode or "HOVER"
    db.tinyTooltips = db.tinyTooltips or false
    db.menuPosition = db.menuPosition or "BOTTOM"
    db.wrapAt = db.wrapAt or 10

    db.colors = db.colors or {}
    db.colors.slot13 = db.colors.slot13 or { r = 0, g = 1, b = 0 }
    db.colors.slot14 = db.colors.slot14 or { r = 1, g = 0.82, b = 0 }
    db.colors.glow   = db.colors.glow   or { r = 1, g = 1, b = 0 }

    db.buttonPos = db.buttonPos or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
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
    end
end

function ATS:UpdateCooldownFont()
    local obj = AutoTrinketSwitcherCharDB.largeNumbers and NumberFontNormalLarge or NumberFontNormal
    local font, size = obj:GetFont()
    for _, button in pairs(self.buttons or {}) do
        button.cdText:SetFont(font, size, "THICKOUTLINE")
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
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
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
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        local name = GetItemInfo(itemID)
        if name then GameTooltip:SetText(name) end
        local _, desc = GetItemSpell(itemID)
        if desc then GameTooltip:AddLine(desc, 1, 1, 1) end
        GameTooltip:Show()
    else
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemID)
    end
end

-- Scan bags for trinkets and return list of itemIDs
local function ScanTrinkets()
    local trinkets = {}
    -- Use the modern C_Container API when available for bag scanning
    local getSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID

    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, getSlots(bag) do
            local itemID = getItemID(bag, slot)
            if itemID then
                local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemID)
                if equipLoc == "INVTYPE_TRINKET" then
                    table.insert(trinkets, itemID)
                end
            end
        end
    end
    return trinkets
end

-- Attempt to equip a trinket for a given slot based on the rules
local function CheckSlot(slot)
    local equippedID = GetInventoryItemID("player", slot)
    local equippedCD = GetItemRemaining(equippedID)
    -- Only swap if the currently equipped trinket has more than 60s cooldown
    if equippedCD <= 60 then return end

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

-- Determine if a swap would occur for a slot when out of combat
local function PendingSwap(slot)
    local equippedID = GetInventoryItemID("player", slot)
    local equippedCD = GetItemRemaining(equippedID)
    if equippedCD <= 60 then return false end

    for _, itemID in ipairs(AutoTrinketSwitcherCharDB.queues[slot]) do
        if itemID ~= equippedID then
            local cd = GetItemRemaining(itemID)
            if cd <= 30 then
                return true
            end
        end
    end
    return false
end

-- Run check for both slots if out of combat
function ATS:PerformCheck()
    if not InCombatLockdown() then
        CheckSlot(13)
        CheckSlot(14)
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
        if PendingSwap(slot) then
            local c = AutoTrinketSwitcherCharDB.colors.glow
            button.glow:SetVertexColor(c.r, c.g, c.b, 1)
            button.glow:Show()
        else
            button.glow:Hide()
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
end

-- Create menu listing all available trinkets
function ATS:ShowMenu(anchor)
    if AutoTrinketSwitcherCharDB.menuOnlyOutOfCombat and InCombatLockdown() then return end
    if not self.menu then
        -- Backdrop support was removed from default frames in recent clients, so
        -- we conditionally use the BackdropTemplate to restore SetBackdrop.
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        self.menu = CreateFrame("Frame", "ATSMenu", UIParent, template)
        self.menu:SetFrameStrata("DIALOG")
        self.menu:SetSize(200, 50)
        self.menu.icons = {}

        -- Only call SetBackdrop when the method exists
        if self.menu.SetBackdrop then
            self.menu:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 16,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            self.menu:SetBackdropColor(0, 0, 0, 0.8)
        end

        self.menu:SetScript("OnLeave", function() ATS:TryHideMenu() end)
    end

    for _, icon in ipairs(self.menu.icons) do
        icon:Hide()
    end
    wipe(self.menu.icons)

    local trinkets = ScanTrinkets()
    local wrap = math.min(30, math.max(1, AutoTrinketSwitcherCharDB.wrapAt))
    local dir = AutoTrinketSwitcherCharDB.menuPosition
    local isVertical = dir == "LEFT" or dir == "RIGHT"
    local size, spacing = 32, 4
    local cols, rows = 0, 0

    for i, itemID in ipairs(trinkets) do
        local btn = self.menu.icons[i] or CreateFrame("Button", nil, self.menu)
        btn:SetSize(size, size)
        btn:ClearAllPoints()
        local col, row
        if isVertical then
            col = math.floor((i - 1) / wrap)
            row = (i - 1) % wrap
        else
            row = math.floor((i - 1) / wrap)
            col = (i - 1) % wrap
        end
        btn:SetPoint("TOPLEFT", 4 + col * (size + spacing), -4 - row * (size + spacing))
        cols = math.max(cols, col + 1)
        rows = math.max(rows, row + 1)

        btn.icon = btn.icon or btn:CreateTexture(nil, "BACKGROUND")
        btn.icon:SetAllPoints(true)
        btn.icon:SetTexture(GetItemIcon(itemID) or 134400)
        btn.itemID = itemID

        btn.pos13 = btn.pos13 or btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.pos13:SetPoint("TOPLEFT", 2, -2)

        btn.pos14 = btn.pos14 or btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.pos14:SetPoint("TOPRIGHT", -2, -2)

        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        -- Use shift+left click for slot 13 and shift+right click for slot 14
        btn:SetScript("OnClick", function(self, mouse)
            if IsShiftKeyDown() then
                local slot = mouse == "LeftButton" and 13 or 14
                ATS:ToggleTrinket(slot, self.itemID)
                ATS:RefreshMenuNumbers()
            elseif mouse == "RightButton" and AutoTrinketSwitcherCharDB.tooltipMode == "RIGHTCLICK" then
                ATS:ShowItemTooltip(self, self.itemID)
            end
        end)

        btn:SetScript("OnEnter", function(self)
            if AutoTrinketSwitcherCharDB.tooltipMode == "HOVER" then
                ATS:ShowItemTooltip(self, self.itemID)
            end
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        self.menu.icons[i] = btn
        btn:Show()
    end

    local width = 8 + cols * (size + spacing) - spacing
    local height = 8 + rows * (size + spacing) - spacing
    self.menu:SetSize(width, height)

    self.menu.anchor = anchor
    self.menu:ClearAllPoints()
    if dir == "TOP" then
        self.menu:SetPoint("BOTTOM", anchor, "TOP", 0, 4)
    elseif dir == "LEFT" then
        self.menu:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
    elseif dir == "RIGHT" then
        self.menu:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
    else
        self.menu:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    end

    self:RefreshMenuNumbers()
    self.menu:Show()
    self:ApplyColorSettings()
end

function ATS:RefreshMenuNumbers()
    if not self.menu or not self.menu.icons then return end
    for _, btn in ipairs(self.menu.icons) do
        local p13 = self:GetQueuePosition(13, btn.itemID)
        local p14 = self:GetQueuePosition(14, btn.itemID)
        if p13 then btn.pos13:SetText(p13) else btn.pos13:SetText("") end
        if p14 then btn.pos14:SetText(p14) else btn.pos14:SetText("") end
    end
end

function ATS:TryHideMenu()
    C_Timer.After(0.1, function()
        if not self.menu then return end
        if self.menu:IsMouseOver() then return end
        for _, btn in pairs(self.buttons or {}) do
            if btn:IsMouseOver() then return end
        end
        self.menu:Hide()
    end)
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

        btn.slot = slot
        -- Use PostClick so the SecureActionButton's default OnClick handler still fires
        btn:SetScript("PostClick", function(self, mouse)
            if mouse == "RightButton" and AutoTrinketSwitcherCharDB.tooltipMode == "RIGHTCLICK" then
                ATS:ShowTooltip(self, slot)
            end
        end)

        btn:SetScript("OnEnter", function(self)
            ATS:ShowMenu(btn)
            if AutoTrinketSwitcherCharDB.tooltipMode == "HOVER" then
                ATS:ShowTooltip(self, slot)
            end
        end)
        btn:SetScript("OnLeave", function()
            ATS:TryHideMenu()
            GameTooltip:Hide()
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
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetPoint("TOPLEFT")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn.icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon:SetAllPoints(true)
    btn.icon:SetTexture(134430) -- generic trinket icon

    btn:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")

    btn:SetScript("OnClick", function(_, mouse)
        if mouse == "LeftButton" then
            if ATS.buttonFrame:IsShown() then
                ATS.buttonFrame:Hide()
            else
                ATS.buttonFrame:Show()
            end
        else
            if Settings and Settings.OpenToCategory and ATS.optionsCategory then
                Settings.OpenToCategory(ATS.optionsCategory.ID)
            elseif InterfaceOptionsFrame_OpenToCategory and ATS.optionsPanel then
                InterfaceOptionsFrame_OpenToCategory(ATS.optionsPanel)
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("AutoTrinketSwitcher")
        GameTooltip:AddLine("Left-click: Toggle trinkets", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Toggle options", 1, 1, 1)
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
    self.elapsed = 0
    self.cdElapsed = 0
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
end

ATS:RegisterEvent("PLAYER_LOGIN")
ATS:RegisterEvent("PLAYER_REGEN_ENABLED")
ATS:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:PerformCheck()
    elseif self[event] then
        self[event](self)
    end
end)

local ATS = AutoTrinketSwitcherFrame

-- Scan bags and equipped slots for trinkets and return unique itemIDs
local function ScanTrinkets()
    local trinkets, seen = {}, {}
    local getSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID

    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, getSlots(bag) do
            local itemID = getItemID(bag, slot)
            if itemID then
                local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemID)
                if equipLoc == "INVTYPE_TRINKET" and not seen[itemID] then
                    table.insert(trinkets, itemID)
                    seen[itemID] = true
                end
            end
        end
    end

    for _, invSlot in ipairs({13, 14}) do
        local itemID = GetInventoryItemID("player", invSlot)
        if itemID and not seen[itemID] then
            table.insert(trinkets, itemID)
            seen[itemID] = true
        end
    end

    return trinkets
end

-- Create menu listing all available trinkets
function ATS:ShowMenu(anchor)
    if AutoTrinketSwitcherCharDB.menuOnlyOutOfCombat and InCombatLockdown() then return end
    if not self.menu then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        self.menu = CreateFrame("Frame", "ATSMenu", UIParent, template)
        self.menu:SetFrameStrata("DIALOG")
        self.menu:SetSize(200, 50)
        self.menu.icons = {}
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
    local isVertical = (AutoTrinketSwitcherCharDB.wrapDirection == "VERTICAL")
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

        btn.cooldown = btn.cooldown or CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        btn.cooldown:SetAllPoints(true)
        btn.cooldown:SetDrawEdge(false)
        btn.cdText = btn.cdText or btn.cooldown:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        btn.cdText:SetPoint("CENTER")
        btn.cdText:SetDrawLayer("OVERLAY", 7)

        btn.pos13 = btn.pos13 or btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.pos13:SetPoint("TOPLEFT", 2, -2)

        btn.pos14 = btn.pos14 or btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.pos14:SetPoint("TOPRIGHT", -2, -2)

        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function(self, mouse)
            if IsControlKeyDown() then
                local slot = mouse == "LeftButton" and 13 or 14
                if C_Item and C_Item.EquipItemByName then
                    C_Item.EquipItemByName(self.itemID, slot)
                else
                    EquipItemByName(self.itemID, slot)
                end
                AutoTrinketSwitcherCharDB.manual = AutoTrinketSwitcherCharDB.manual or { [13]=false, [14]=false }
                AutoTrinketSwitcherCharDB.manual[slot] = not AutoTrinketSwitcherCharDB.manual[slot]
                ATS:UpdateButtons()
            elseif IsShiftKeyDown() then
                local slot = mouse == "LeftButton" and 13 or 14
                ATS:ToggleTrinket(slot, self.itemID)
                ATS:RefreshMenuNumbers()
            elseif not AutoTrinketSwitcherCharDB.autoSwitch then
                local slot = mouse == "LeftButton" and 13 or 14
                if C_Item and C_Item.EquipItemByName then
                    C_Item.EquipItemByName(self.itemID, slot)
                else
                    EquipItemByName(self.itemID, slot)
                end
                ATS:UpdateButtons()
            elseif mouse == "RightButton" and AutoTrinketSwitcherCharDB.tooltipMode == "RIGHTCLICK" then
                ATS.tooltipPinned = not ATS.tooltipPinned
                if ATS.tooltipPinned then
                    ATS:ShowItemTooltip(self, self.itemID)
                else
                    ATS:HideTooltip()
                    ATS.tooltipContext = nil
                end
            end
        end)

        btn:SetScript("OnEnter", function(self)
            if AutoTrinketSwitcherCharDB.tooltipMode == "HOVER" or ATS.tooltipPinned then
                ATS:ShowItemTooltip(self, self.itemID)
            end
        end)
        btn:SetScript("OnLeave", function()
            if not ATS.tooltipPinned then
                ATS:HideTooltip()
                ATS.tooltipContext = nil
            end
        end)

        self.menu.icons[i] = btn
        btn:Show()
    end

    local width = 8 + cols * (size + spacing) - spacing
    local height = 8 + rows * (size + spacing) - spacing
    self.menu:SetSize(width, height)

    -- Always anchor to the buttons frame so the menu stays outside on the chosen side
    self.menu.anchor = self.buttonFrame or anchor
    self.menu:ClearAllPoints()
    if dir == "TOP" then
        self.menu:SetPoint("BOTTOM", self.menu.anchor, "TOP", 0, 4)
    elseif dir == "LEFT" then
        self.menu:SetPoint("RIGHT", self.menu.anchor, "LEFT", -4, 0)
    elseif dir == "RIGHT" then
        self.menu:SetPoint("LEFT", self.menu.anchor, "RIGHT", 4, 0)
    else
        self.menu:SetPoint("TOP", self.menu.anchor, "BOTTOM", 0, -4)
    end

    self:RefreshMenuNumbers()
    self:UpdateMenuCooldowns()
    self.menu:Show()
    self:ApplyColorSettings()
    self:ApplyMenuQueueFont()
    ATS:UpdateCooldownFont()
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

function ATS:UpdateMenuCooldowns()
    if not self.menu or not self.menu.icons then return end
    for _, btn in ipairs(self.menu.icons) do
        local start, duration = GetItemCooldown(btn.itemID)
        if start and duration and start > 0 and duration > 0 then
            btn.cooldown:SetCooldown(start, duration)
            btn.cooldown:Show()
            if AutoTrinketSwitcherCharDB.showCooldownNumbers then
                local remaining = start + duration - GetTime()
                if remaining > 0 then
                    if remaining >= 60 then
                        btn.cdText:SetText(string.format("%d m", math.ceil(remaining / 60)))
                    else
                        btn.cdText:SetText(math.ceil(remaining))
                    end
                    btn.cdText:Show()
                else
                    btn.cdText:Hide()
                end
            else
                btn.cdText:Hide()
            end
        else
            btn.cooldown:Hide()
            btn.cdText:Hide()
        end
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


local ATS = AutoTrinketSwitcherFrame

-- Scan bags and equipped slots for trinkets and return unique itemIDs
local function ScanTrinkets()
    local trinkets, seen = {}, {}
    local getSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    local present = {}

    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, getSlots(bag) do
            local itemID = getItemID(bag, slot)
            if itemID then
                local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemID)
                if equipLoc == "INVTYPE_TRINKET" and not seen[itemID] then
                    table.insert(trinkets, itemID)
                    seen[itemID] = true
                    present[itemID] = true
                end
            end
        end
    end

    for _, invSlot in ipairs({13, 14}) do
        local itemID = GetInventoryItemID("player", invSlot)
        if itemID and not seen[itemID] then
            table.insert(trinkets, itemID)
            seen[itemID] = true
            present[itemID] = true
        end
    end

    -- Include queued items even if not currently in bags, so the user can see/remove them
    local db = AutoTrinketSwitcherCharDB
    if db and db.queues then
        for _, slot in ipairs({13,14}) do
            for _, id in ipairs(db.queues[slot]) do
                if not seen[id] then
                    table.insert(trinkets, id)
                    seen[id] = true
                    present[id] = false
                end
            end
        end
    end

    return trinkets, present
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

    local trinkets, present = ScanTrinkets()

    -- Sorting
    local mode = AutoTrinketSwitcherCharDB.menuSortMode or "QUEUED_FIRST"
    local function alphaKey(id)
        local name = GetItemInfo(id) or ""
        return name:upper()
    end
    local function groupAndPos(id)
        local p13 = ATS:GetQueuePosition(13, id)
        local p14 = ATS:GetQueuePosition(14, id)
        if p13 and not p14 then return 1, p13 end
        if p14 and not p13 then return 2, p14 end
        if p13 and p14 then return 3, math.min(p13, p14) end
        return 4, math.huge
    end
    table.sort(trinkets, function(a, b)
        if mode == "ALPHA" then
            local na, nb = alphaKey(a), alphaKey(b)
            if na == nb then return a < b end
            return na < nb
        elseif mode == "ILEVEL" then
            local la = select(4, GetItemInfo(a)) or 0
            local lb = select(4, GetItemInfo(b)) or 0
            if la == lb then
                local na, nb = alphaKey(a), alphaKey(b)
                if na == nb then return a < b end
                return na < nb
            end
            return la > lb
        else -- QUEUED_FIRST: 13-only, 14-only, both, others
            local ga, pa = groupAndPos(a)
            local gb, pb = groupAndPos(b)
            if ga ~= gb then return ga < gb end
            if pa ~= pb then return pa < pb end
            local na, nb = alphaKey(a), alphaKey(b)
            if na == nb then return a < b end
            return na < nb
        end
    end)
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


        -- Glows per slot membership in queues
        btn.cand13Glow = btn.cand13Glow or btn:CreateTexture(nil, "OVERLAY")
        btn.cand13Glow:SetTexture("Interface/Buttons/UI-ActionButton-Border")
        btn.cand13Glow:SetBlendMode("ADD")
        btn.cand13Glow:SetPoint("CENTER")
        btn.cand13Glow:SetSize(54, 54)
        btn.cand13Glow:Hide()

        btn.cand14Glow = btn.cand14Glow or btn:CreateTexture(nil, "OVERLAY")
        btn.cand14Glow:SetTexture("Interface/Buttons/UI-ActionButton-Border")
        btn.cand14Glow:SetBlendMode("ADD")
        btn.cand14Glow:SetPoint("CENTER")
        btn.cand14Glow:SetSize(54, 54)
        btn.cand14Glow:Hide()

        btn.cooldown = btn.cooldown or CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        btn.cooldown:SetAllPoints(true)
        btn.cooldown:SetDrawEdge(false)
        if btn.cooldown.SetHideCountdownNumbers then
            btn.cooldown:SetHideCountdownNumbers(true)
        end
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
                AutoTrinketSwitcherCharDB.manual = AutoTrinketSwitcherCharDB.manual or { [13]=false, [14]=false }
                AutoTrinketSwitcherCharDB.manualPreferred = AutoTrinketSwitcherCharDB.manualPreferred or { [13] = nil, [14] = nil }
                local wasManual = AutoTrinketSwitcherCharDB.manual[slot] and true or false
                local nowManual = not wasManual
                AutoTrinketSwitcherCharDB.manual[slot] = nowManual

                -- Equip clicked trinket only when switching from auto -> manual
                if nowManual and not wasManual then
                    AutoTrinketSwitcherCharDB.manualPreferred[slot] = self.itemID or GetInventoryItemID("player", slot)
                    if C_Item and C_Item.EquipItemByName then
                        C_Item.EquipItemByName(self.itemID, slot)
                    else
                        EquipItemByName(self.itemID, slot)
                    end
                else
                    -- Switching from manual -> auto: resume queue logic immediately if possible
                    if ATS.RestoreManualTrinket then ATS:RestoreManualTrinket(slot) end
                    if ATS.PerformCheck then ATS:PerformCheck() end
                end

                if ATS.OnManualToggle then ATS:OnManualToggle() end
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

    -- No header quick actions; render grid from the top

    local width = 8 + cols * (size + spacing) - spacing
    local height = 8 + rows * (size + spacing) - spacing
    self.menu:SetSize(width, height)

    -- Always anchor to the buttons frame so the menu stays outside on the chosen side
    self.menu.anchor = self.buttonFrame or anchor
    local anchorFrame = self.menu.anchor or UIParent
    self.menu:ClearAllPoints()
    local belowMiddle = false
    if anchorFrame and anchorFrame:GetCenter() then
        local _, anchorY = anchorFrame:GetCenter()
        local parentHeight = UIParent and UIParent:GetHeight() or 0
        if anchorY and parentHeight and parentHeight > 0 then
            belowMiddle = anchorY < (parentHeight / 2)
        end
    end

    if dir == "TOP" then
        self.menu:SetPoint("BOTTOM", anchorFrame, "TOP", 0, 4)
    elseif dir == "LEFT" then
        if belowMiddle then
            self.menu:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMLEFT", -4, 0)
        else
            self.menu:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", -4, 0)
        end
    elseif dir == "RIGHT" then
        if belowMiddle then
            self.menu:SetPoint("BOTTOMLEFT", anchorFrame, "BOTTOMRIGHT", 4, 0)
        else
            self.menu:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 4, 0)
        end
    else
        self.menu:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -4)
    end

    self:RefreshMenuNumbers()
    if self.UpdateMenuDecorations then self:UpdateMenuDecorations(present) end
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

function ATS:UpdateMenuDecorations(presentLookup)
    if not self.menu or not self.menu.icons then return end
    presentLookup = presentLookup or {}
    local c13 = AutoTrinketSwitcherCharDB.colors.slot13
    local c14 = AutoTrinketSwitcherCharDB.colors.slot14
    for _, btn in ipairs(self.menu.icons) do
        local id = btn.itemID
        -- Missing gray-out
        local isPresent = presentLookup[id]
        if btn.icon and btn.icon.SetDesaturated then
            btn.icon:SetDesaturated(not isPresent)
        end
        if btn.icon then
            if isPresent == false then
                btn.icon:SetVertexColor(0.5,0.5,0.5)
            else
                btn.icon:SetVertexColor(1,1,1)
            end
        end
        -- Queue membership glows (slot colors)
        local in13 = ATS:GetQueuePosition(13, id) ~= nil
        local in14 = ATS:GetQueuePosition(14, id) ~= nil
        if btn.cand13Glow then
            if in13 then
                btn.cand13Glow:SetVertexColor(c13.r, c13.g, c13.b, 1)
                btn.cand13Glow:Show()
            else
                btn.cand13Glow:Hide()
            end
        end
        if btn.cand14Glow then
            if in14 then
                btn.cand14Glow:SetVertexColor(c14.r, c14.g, c14.b, 1)
                btn.cand14Glow:Show()
            else
                btn.cand14Glow:Hide()
            end
        end
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


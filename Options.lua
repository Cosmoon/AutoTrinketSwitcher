local ATS = AutoTrinketSwitcherFrame

function ATS:CreateOptions()
    local panel = CreateFrame("Frame")
    panel.name = "AutoTrinketSwitcher"

    local db = AutoTrinketSwitcherCharDB

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("AutoTrinketSwitcher")

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local function CreateBox(text, anchor, offset)
        local box = CreateFrame("Frame", nil, panel, template)
        box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offset or -8)
        box:SetPoint("RIGHT", panel, -16, 0)
        if box.SetBackdrop then
            box:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            box:SetBackdropColor(0, 0, 0, 0.25)
        end
        local header = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", 16, -16)
        header:SetText(text)
        return box, header
    end

    local function CreateCheck(parent, label, key, anchor)
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb.Text:SetText(label)
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
        cb:SetChecked(db[key])
        cb:SetScript("OnClick", function(self)
            db[key] = self:GetChecked()
            if key == "showCooldownNumbers" then ATS:UpdateButtons() end
            if key == "largeNumbers" then ATS:UpdateCooldownFont() end
            if key == "lockWindows" then ATS:UpdateLockState() end
            if key == "autoSwitch" then ATS:UpdateButtons() end
            if key == "useDefaultTooltipAnchor" then -- nothing immediate besides tooltip placement
                -- no-op; placement applied next time tooltips show
            end
            if key == "tinyTooltips" or key == "altFullTooltips" or key == "cleanTooltips" or key == "useDefaultTooltipAnchor" then
                if ATS.HideTooltip then ATS:HideTooltip() end
                if ATS.RefreshTooltip then ATS:RefreshTooltip() end
            end
        end)
        return cb
    end

    -- General settings box
    local generalBox, gHeader = CreateBox("General settings", title)
    local gColLeftX, gColRightX = 16, 260
    local gRowY = -16
    local g1 = CreateCheck(generalBox, "Enable auto switching", "autoSwitch", gHeader)
    local g2 = CreateCheck(generalBox, "Show cooldown numbers", "showCooldownNumbers", gHeader)
    local g3 = CreateCheck(generalBox, "Use large cooldown numbers", "largeNumbers", gHeader)
    local g4 = CreateCheck(generalBox, "Lock windows", "lockWindows", gHeader)

    -- New: default tooltip anchoring toggle
    local g5 = CreateCheck(generalBox, "Use default tooltip position", "useDefaultTooltipAnchor", gHeader)
    local g6 = CreateCheck(generalBox, "Use tiny tooltips", "tinyTooltips", gHeader)
    local g7 = CreateCheck(generalBox, "Hold ALT for full tooltips", "altFullTooltips", gHeader)
    local g8 = CreateCheck(generalBox, "Block other addon info in tooltips", "cleanTooltips", gHeader)

    -- Reposition into two columns
    local function PlaceCheck(cb, col, row)
        cb:ClearAllPoints()
        local x = (col == 1) and gColLeftX or gColRightX
        cb:SetPoint("TOPLEFT", gHeader, "BOTTOMLEFT", x, gRowY - (row - 1) * 28)
    end
    PlaceCheck(g1, 1, 1)
    PlaceCheck(g2, 1, 2)
    PlaceCheck(g3, 1, 3)
    PlaceCheck(g4, 2, 1)
    PlaceCheck(g5, 2, 2)
    PlaceCheck(g6, 2, 3)
    PlaceCheck(g7, 2, 4)
    PlaceCheck(g8, 2, 5)

    local tooltipLabel = generalBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    tooltipLabel:SetPoint("TOPLEFT", gHeader, "BOTTOMLEFT", gColLeftX, gRowY - 3 * 28 - 16)
    tooltipLabel:SetText("Tooltips")

    local tooltipDrop = CreateFrame("Frame", "ATSTooltipDropdown", generalBox, "UIDropDownMenuTemplate")
    tooltipDrop:SetPoint("LEFT", tooltipLabel, "RIGHT", -10, -4)
    local modes = {HOVER="Show", RIGHTCLICK="Right-click", OFF="Hide"}
    UIDropDownMenu_SetWidth(tooltipDrop, 120)
    UIDropDownMenu_Initialize(tooltipDrop, function(self, level)
        for value, text in pairs(modes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = text, value
            info.func = function()
                db.tooltipMode = value
                UIDropDownMenu_SetSelectedValue(tooltipDrop, value)
            end
            info.checked = db.tooltipMode == value
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(tooltipDrop, db.tooltipMode)

    -- menu-only-out-of-combat moved to Menu settings below

    -- Menu settings box
    local menuBox, mHeader = CreateBox("Menu settings", generalBox, -16)
    -- First line: Show menu only when out of combat
    local menuOOC = CreateCheck(menuBox, "Show menu only when out of combat", "menuOnlyOutOfCombat", mHeader)
    menuOOC:ClearAllPoints()
    menuOOC:SetPoint("TOPLEFT", mHeader, "BOTTOMLEFT", 16, -8)

    -- Second line (more space): position + queue number size
    local posLabel = menuBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    posLabel:SetPoint("TOPLEFT", mHeader, "BOTTOMLEFT", 16, -50)
    posLabel:SetText("Show menu on")

    local drop = CreateFrame("Frame", "ATSMenuPosDropdown", menuBox, "UIDropDownMenuTemplate")
    drop:SetPoint("LEFT", posLabel, "RIGHT", -10, -4)
    local positions = {TOP="Top", BOTTOM="Bottom", LEFT="Left", RIGHT="Right"}
    UIDropDownMenu_SetWidth(drop, 100)
    UIDropDownMenu_Initialize(drop, function(self, level)
        for value, text in pairs(positions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = text, value
            info.func = function()
                db.menuPosition = value
                UIDropDownMenu_SetSelectedValue(drop, value)
                if ATS.menu and ATS.menu:IsShown() and ATS.menu.anchor then
                    ATS:ShowMenu(ATS.menu.anchor)
                end
            end
            info.checked = db.menuPosition == value
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(drop, db.menuPosition)

    -- (wrap direction will be a toggle button next to Wrap at)

    local wrapSlider = CreateFrame("Slider", "ATSWrapSlider", menuBox, "OptionsSliderTemplate")
    wrapSlider:SetPoint("TOPLEFT", posLabel, "BOTTOMLEFT", -16, -40)
    wrapSlider:SetMinMaxValues(1, 30)
    wrapSlider:SetValueStep(1)
    wrapSlider:SetObeyStepOnDrag(true)
    wrapSlider:SetWidth(200)
    wrapSlider:SetValue(db.wrapAt)
    ATSWrapSliderLow:SetText("1")
    ATSWrapSliderHigh:SetText("30")
    _G[wrapSlider:GetName() .. "Text"]:SetText("Wrap at: " .. db.wrapAt)
    wrapSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db.wrapAt = value
        _G[self:GetName() .. "Text"]:SetText("Wrap at: " .. value)
        if ATS.menu and ATS.menu:IsShown() and ATS.menu.anchor then
            ATS:ShowMenu(ATS.menu.anchor)
        end
    end)

    -- Queue number font size (second line, next to position)
    local qLabel = menuBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qLabel:SetPoint("LEFT", drop, "RIGHT", 24, 0)
    qLabel:SetText("Queue number size")

    local qSlider = CreateFrame("Slider", "ATSQueueNumSizeSlider", menuBox, "OptionsSliderTemplate")
    qSlider:SetPoint("LEFT", qLabel, "RIGHT", 8, 0)
    qSlider:SetMinMaxValues(8, 24)
    qSlider:SetValueStep(1)
    qSlider:SetObeyStepOnDrag(true)
    qSlider:SetWidth(200)
    qSlider:SetValue(db.queueNumberSize or 12)
    _G[qSlider:GetName() .. "Low"]:SetText("8")
    _G[qSlider:GetName() .. "High"]:SetText("24")
    _G[qSlider:GetName() .. "Text"]:SetText("Size: " .. (db.queueNumberSize or 12))
    qSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db.queueNumberSize = value
        _G[self:GetName() .. "Text"]:SetText("Size: " .. value)
        ATS:ApplyMenuQueueFont()
    end)

    -- Wrap direction toggle button (next to Wrap at)
    local wrapDirBtn = CreateFrame("Button", "ATSWrapDirButton", menuBox, "UIPanelButtonTemplate")
    local function UpdateWrapDirButtonText()
        if db.wrapDirection == "HORIZONTAL" then
            wrapDirBtn:SetText("Vertical")
        else
            wrapDirBtn:SetText("Horizontal")
        end
    end
    UpdateWrapDirButtonText()
    wrapDirBtn:SetPoint("LEFT", wrapSlider, "RIGHT", 20, 0)
    wrapDirBtn:SetWidth(100)
    wrapDirBtn:SetScript("OnClick", function()
        db.wrapDirection = (db.wrapDirection == "HORIZONTAL") and "VERTICAL" or "HORIZONTAL"
        UpdateWrapDirButtonText()
        if ATS.menu and ATS.menu:IsShown() and ATS.menu.anchor then
            ATS:ShowMenu(ATS.menu.anchor)
        end
    end)

    -- Colour settings box
    local colorBox, cHeader = CreateBox("Colour settings", menuBox, -16)

    local function CreateColorOption(parent, label, key, anchor, offsetY)
        local swatch = CreateFrame("Button", nil, parent)
        swatch:SetSize(16, 16)
        swatch:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -8)
        swatch.tex = swatch:CreateTexture(nil, "BACKGROUND")
        swatch.tex:SetAllPoints(true)
        swatch.tex:SetTexture("Interface/ChatFrame/ChatFrameColorSwatch")

        local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
        text:SetText(label)

        local function Update()
            local c = db.colors[key]
            swatch.tex:SetVertexColor(c.r, c.g, c.b)
        end

        swatch:SetScript("OnClick", function()
            local c = db.colors[key]
            local function setColor(restore)
                local r, g, b
                if restore then
                    r, g, b = unpack(restore)
                else
                    r, g, b = ColorPickerFrame:GetColorRGB()
                end
                c.r, c.g, c.b = r, g, b
                Update()
                ATS:ApplyColorSettings()
            end
            ColorPickerFrame.func, ColorPickerFrame.swatchFunc, ColorPickerFrame.cancelFunc = setColor, setColor, setColor
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.previousValues = {c.r, c.g, c.b}
            ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
            ColorPickerFrame:Show()
        end)

        Update()
        return swatch
    end

    -- Three columns on first row
    local c1 = CreateColorOption(colorBox, "Slot 13", "slot13", cHeader, -8)
    c1:ClearAllPoints(); c1:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", 16, -8)
    local c2 = CreateColorOption(colorBox, "Slot 14", "slot14", cHeader, -8)
    c2:ClearAllPoints(); c2:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", 180, -8)
    local c3 = CreateColorOption(colorBox, "Pending swap", "glow", cHeader, -8)
    c3:ClearAllPoints(); c3:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", 344, -8)
    -- Second row (starts new line), keep 3-column grid available for future
    local c4 = CreateColorOption(colorBox, "Manual badge", "manualBadge", cHeader, -36)
    c4:ClearAllPoints(); c4:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", 16, -36)

    -- Spacer below colour box to guarantee visual padding to the window edge
    local bottomSpacer = CreateFrame("Frame", nil, panel)
    bottomSpacer:SetPoint("TOPLEFT", colorBox, "BOTTOMLEFT", 0, -16)
    bottomSpacer:SetPoint("RIGHT", panel, -16, 0)
    bottomSpacer:SetHeight(16)

    -- Size boxes when shown to avoid anchoring parents to children
    panel:SetScript("OnShow", function()
        local function layout()
            -- Compute bottom of General box: lowest of tooltip dropdown or last checkbox
            local lastCheckBottom = (g8 and g8:GetBottom()) or (g7 and g7:GetBottom()) or (g6 and g6:GetBottom()) or nil
            local tdb = tooltipDrop and tooltipDrop:GetBottom() or nil
            local gBottom
            if lastCheckBottom and tdb then
                gBottom = math.min(lastCheckBottom, tdb)
            else
                gBottom = lastCheckBottom or tdb or (gHeader:GetBottom() - 60)
            end
            generalBox:SetHeight(generalBox:GetTop() - gBottom + 16)

            -- Place wrap direction button on third line (wrapSlider row),
            -- horizontally aligned with the middle of the 'Queue number size' above.
            if wrapDirBtn and wrapSlider and qSlider and menuBox and 
               wrapSlider.GetTop and qSlider.GetLeft and menuBox.GetLeft then
                local qCenterX = qSlider:GetLeft() + (qSlider:GetWidth() or 0) / 2
                local wrapCenterY = (wrapSlider:GetTop() + wrapSlider:GetBottom()) / 2
                local boxLeft = menuBox:GetLeft() or 0
                local boxBottom = menuBox:GetBottom() or 0
                if qCenterX and wrapCenterY and boxLeft and boxBottom then
                    wrapDirBtn:ClearAllPoints()
                    wrapDirBtn:SetPoint("CENTER", menuBox, "BOTTOMLEFT", qCenterX - boxLeft, wrapCenterY - boxBottom)
                end
            end

            local mBottom = wrapSlider:GetBottom() or 0
            if drop:GetBottom() and drop:GetBottom() < mBottom then mBottom = drop:GetBottom() end
            if qSlider:GetBottom() and qSlider:GetBottom() < mBottom then mBottom = qSlider:GetBottom() end
            if menuOOC:GetBottom() and menuOOC:GetBottom() < mBottom then mBottom = menuOOC:GetBottom() end
            if wrapDirBtn:GetBottom() and wrapDirBtn:GetBottom() < mBottom then mBottom = wrapDirBtn:GetBottom() end
            if mBottom == 0 then mBottom = (mHeader:GetBottom() - 60) end
            menuBox:SetHeight(menuBox:GetTop() - mBottom + 40)

            local last = c4 or c3
            colorBox:SetHeight(colorBox:GetTop() - last:GetBottom() + 24)
        end

        -- Run layout now and once next frame to handle initial sizing
        layout()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() if panel:IsShown() then layout() end end)
        end
    end)

    -- Do not register with Blizzard Settings; we use a standalone window

    -- Also create a standalone in-game window for this panel, so users don't need the game main menu
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local win = CreateFrame("Frame", "ATSOptionsFrame", UIParent, template)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetSize(820, 640)
    win:SetPoint("CENTER")
    if win.SetBackdrop then
        win:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        win:SetBackdropColor(0,0,0,0.85)
    end
    win:Hide()
    table.insert(UISpecialFrames, "ATSOptionsFrame")

    win:SetScript("OnShow", function()
        if ATS and ATS.menu and ATS.menu:IsShown() then ATS.menu:Hide() end
    end)

    -- Make the window movable
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)

    -- Close button
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    -- Parent the existing options panel into our window for standalone display
    panel:SetParent(win)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -8)
    panel:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -8, 8)
    panel:Hide()

    -- Expose a toggle for the minimap button
    self.optionsWindow = win
    self.optionsPanel = panel
end

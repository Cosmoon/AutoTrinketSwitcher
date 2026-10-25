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
            if key == "autoSwitch" and ATS and ATS.SetGlobalAutoSwitch then
                ATS:SetGlobalAutoSwitch(self:GetChecked())
                return
            end
            db[key] = self:GetChecked()
            if key == "mountSpeedTrinketsEnabled" then ATS:SetMountSpeedTrinketSwitching(db[key]) end
            if key == "showCooldownNumbers" then
                ATS:UpdateButtons()
                if ATS.UpdateMenuCooldowns then ATS:UpdateMenuCooldowns() end
            end
            if key == "largeNumbers" then ATS:UpdateCooldownFont() end
            if key == "lockWindows" then ATS:UpdateLockState() end
            if key == "macroReadyGlowEnabled" then
                ATS:RefreshMacroButtons()
                ATS:UpdateReadyAlerts()
            end
            if key == "readySoundEnabled" then
                ATS.readyAlertState = nil
                ATS:UpdateReadyAlerts()
            end
            if key == "readyGlowEnabled" then
                if ATS.UpdateButtons then ATS:UpdateButtons() end
            end
            if key == "useMountSpeedManager" and ATS.OnMountSpeedManagerOptionChanged then
                ATS:OnMountSpeedManagerOptionChanged(db[key])
            end
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

    local function CreateTooltipCheck(parent, label, anchor)
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb.Text:SetText(label)
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
        cb:SetChecked(db.tooltipMode ~= "OFF")
        cb:SetScript("OnClick", function(self)
            db.tooltipMode = self:GetChecked() and "ON" or "OFF"
            if ATS.HideTooltip then ATS:HideTooltip() end
            if ATS.RefreshTooltip then ATS:RefreshTooltip() end
        end)
        return cb
    end

    local function EnsureSliderTrack(slider)
        if slider.atsTrack then return end
        local track = slider:CreateTexture(nil, "ARTWORK")
        track:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
        track:SetHorizTile(true)
        track:SetVertTile(false)
        track:SetPoint("LEFT", slider, "LEFT", 10, 0)
        track:SetPoint("RIGHT", slider, "RIGHT", -10, 0)
        track:SetHeight(8)

        local border = slider:CreateTexture(nil, "ARTWORK")
        border:SetTexture("Interface\\Buttons\\UI-SliderBar-Border")
        border:SetPoint("LEFT", track, "LEFT", -3, 0)
        border:SetPoint("RIGHT", track, "RIGHT", 3, 0)
        border:SetHeight(12)

        slider.atsTrack = track
        slider.atsBorder = border
    end

    -- General settings box
    local generalBox, gHeader = CreateBox("General settings", title)
    local gColLeftX, gColRightX = 16, 260
    local gRowY = -16
    local g1 = CreateCheck(generalBox, "Enable auto switching", "autoSwitch", gHeader)
    local g2 = CreateCheck(generalBox, "Show cooldown numbers", "showCooldownNumbers", gHeader)
    local g3 = CreateCheck(generalBox, "Use large cooldown numbers", "largeNumbers", gHeader)
    local g4 = CreateCheck(generalBox, "Lock windows", "lockWindows", gHeader)
    local gTooltip = CreateTooltipCheck(generalBox, "Show tooltips", gHeader)

    -- New: default tooltip anchoring toggle
    local g5 = CreateCheck(generalBox, "Use default tooltip position", "useDefaultTooltipAnchor", gHeader)
    local g6 = CreateCheck(generalBox, "Use tiny tooltips", "tinyTooltips", gHeader)
    local g7 = CreateCheck(generalBox, "Hold ALT for full tooltips", "altFullTooltips", gHeader)
    local g8 = CreateCheck(generalBox, "Block other addon info in tooltips", "cleanTooltips", gHeader)
    local g9 = CreateCheck(generalBox, "Trinket ready glow", "readyGlowEnabled", gHeader)
    local g10 = CreateCheck(generalBox, "Use mount-speed manager", "useMountSpeedManager", gHeader)

    local g11 = CreateCheck(generalBox, "Swap mount-speed trinkets", "mountSpeedTrinketsEnabled", gHeader)
    -- Reposition into two columns
    local function PlaceCheck(cb, col, row)
        cb:ClearAllPoints()
        local x = (col == 1) and gColLeftX or gColRightX
        cb:SetPoint("TOPLEFT", gHeader, "BOTTOMLEFT", x, gRowY - (row - 1) * 28)
    end
    PlaceCheck(g1, 1, 1)
    PlaceCheck(g2, 1, 2)
    PlaceCheck(g3, 1, 3)
    PlaceCheck(g9, 1, 4)
    PlaceCheck(g4, 1, 5)
    PlaceCheck(g10, 1, 6)
    PlaceCheck(g11, 2, 6)
    PlaceCheck(gTooltip, 2, 1)
    PlaceCheck(g5, 2, 2)
    PlaceCheck(g6, 2, 3)
    PlaceCheck(g7, 2, 4)
    PlaceCheck(g8, 2, 5)

    -- menu-only-out-of-combat moved to Menu settings below

    -- Special trinkets settings box; hidden when no supported special trinkets are detected/configured.
    local specialBox, sHeader = CreateBox("Special trinkets", generalBox, -16)
    local specialRows = {}

    local function CreateSpecialTrinketRow(index)
        local row = {}
        row.name = specialBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.name:SetPoint("TOPLEFT", sHeader, "BOTTOMLEFT", 16, -12 - (index - 1) * 34)
        row.name:SetWidth(280)
        row.name:SetJustifyH("LEFT")

        row.drop = CreateFrame("Frame", "ATSSpecialTrinketModeDropdown" .. index, specialBox, "UIDropDownMenuTemplate")
        row.drop:SetPoint("LEFT", row.name, "RIGHT", 10, -4)
        UIDropDownMenu_SetWidth(row.drop, 260)

        local function RefreshDropdown()
            if not row.itemID then return end
            local mode = ATS.GetSpecialTrinketMode and ATS:GetSpecialTrinketMode(row.itemID)
            UIDropDownMenu_SetSelectedValue(row.drop, mode)
            if ATS.GetSpecialTrinketModeLabel then
                UIDropDownMenu_SetText(row.drop, ATS:GetSpecialTrinketModeLabel(row.itemID, mode))
            else
                UIDropDownMenu_SetText(row.drop, tostring(mode or ""))
            end
        end

        row.refresh = RefreshDropdown
        UIDropDownMenu_Initialize(row.drop, function(self, level)
            if not row.itemID or not ATS.GetSpecialTrinketModeOrder then return end
            local order = ATS:GetSpecialTrinketModeOrder(row.itemID) or {}
            local mode = ATS.GetSpecialTrinketMode and ATS:GetSpecialTrinketMode(row.itemID)
            for _, value in ipairs(order) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = ATS.GetSpecialTrinketModeLabel and ATS:GetSpecialTrinketModeLabel(row.itemID, value) or tostring(value)
                info.value = value
                info.func = function()
                    if ATS.SetSpecialTrinketMode then
                        ATS:SetSpecialTrinketMode(row.itemID, value)
                    end
                    RefreshDropdown()
                end
                info.checked = mode == value
                UIDropDownMenu_AddButton(info)
            end
        end)

        return row
    end

    local function RefreshSpecialTrinketOptions()
        local ids = {}
        if ATS.GetDetectedSpecialTrinketIDs then
            ids = ATS:GetDetectedSpecialTrinketIDs() or {}
        end

        for _, row in ipairs(specialRows) do
            row.itemID = nil
            row.name:Hide()
            row.drop:Hide()
        end

        if #ids == 0 then
            specialBox:Hide()
            specialBox:SetHeight(1)
            return 0
        end

        specialBox:Show()
        for i, itemID in ipairs(ids) do
            local row = specialRows[i]
            if not row then
                row = CreateSpecialTrinketRow(i)
                specialRows[i] = row
            end
            row.itemID = itemID
            row.name:SetText(ATS.GetSpecialTrinketDisplayName and ATS:GetSpecialTrinketDisplayName(itemID) or ("item:" .. tostring(itemID)))
            row.name:Show()
            row.drop:Show()
            row.refresh()
        end

        specialBox:SetHeight(52 + (#ids * 34))
        return #ids
    end

    local LayoutOptions

    function ATS:RefreshSpecialTrinketOptions()
        if not panel:IsShown() then return end
        if LayoutOptions then
            LayoutOptions()
        else
            RefreshSpecialTrinketOptions()
        end
    end

    -- Menu settings box
    local menuBox, mHeader = CreateBox("Menu settings", specialBox, -16)
    -- First line: Show menu only when out of combat
    local menuOOC = CreateCheck(menuBox, "Show menu only when out of combat", "menuOnlyOutOfCombat", mHeader)
    menuOOC:ClearAllPoints()
    menuOOC:SetPoint("TOPLEFT", mHeader, "BOTTOMLEFT", 16, -8)

    -- Sorting dropdown (second line, next to position)
    local sortLabel = menuBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sortLabel:SetText("Sort by")
    local sortDrop = CreateFrame("Frame", "ATSSortDropdown", menuBox, "UIDropDownMenuTemplate")
    local sortModes = { QUEUED_FIRST = "Queued first", ALPHA = "Name", ILEVEL = "Item level" }
    UIDropDownMenu_SetWidth(sortDrop, 130)
    UIDropDownMenu_Initialize(sortDrop, function(self, level)
        for value, text in pairs(sortModes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = text, value
            info.func = function()
                db.menuSortMode = value
                UIDropDownMenu_SetSelectedValue(sortDrop, value)
                if ATS.menu and ATS.menu:IsShown() and ATS.menu.anchor then
                    ATS:ShowMenu(ATS.menu.anchor)
                end
            end
            info.checked = db.menuSortMode == value
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(sortDrop, db.menuSortMode)

    -- Second line (more space): position + sort by
    local posLabel = menuBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    posLabel:SetPoint("TOPLEFT", mHeader, "BOTTOMLEFT", 16, -50)
    posLabel:SetText("Show menu on")

    local drop = CreateFrame("Frame", "ATSMenuPosDropdown", menuBox, "UIDropDownMenuTemplate")
    drop:SetPoint("LEFT", posLabel, "RIGHT", -10, -4)
    -- Place sort controls to the right of position dropdown
    sortLabel:ClearAllPoints(); sortLabel:SetPoint("LEFT", drop, "RIGHT", 24, 0)
    sortDrop:ClearAllPoints(); sortDrop:SetPoint("LEFT", sortLabel, "RIGHT", -10, -4)
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
    EnsureSliderTrack(wrapSlider)
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

    -- Wrap direction toggle button (third line, near Wrap at)
    local wrapDirBtn = CreateFrame("Button", "ATSWrapDirButton", menuBox, "UIPanelButtonTemplate")
    local function UpdateWrapDirButtonText()
        if db.wrapDirection == "HORIZONTAL" then
            wrapDirBtn:SetText("Vertical")
        else
            wrapDirBtn:SetText("Horizontal")
        end
    end
    UpdateWrapDirButtonText()
    wrapDirBtn:SetPoint("LEFT", wrapSlider, "RIGHT", 60, 0)
    wrapDirBtn:SetWidth(100)
    wrapDirBtn:SetScript("OnClick", function()
        db.wrapDirection = (db.wrapDirection == "HORIZONTAL") and "VERTICAL" or "HORIZONTAL"
        UpdateWrapDirButtonText()
        if ATS.menu and ATS.menu:IsShown() and ATS.menu.anchor then
            ATS:ShowMenu(ATS.menu.anchor)
        end
    end)

    -- Queue font size (third line, next to Wrap At)
    local qLabel = menuBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qLabel:SetPoint("LEFT", wrapDirBtn, "RIGHT", 40, 0)
    qLabel:SetText("Queue font size")

    local qSlider = CreateFrame("Slider", "ATSQueueNumSizeSlider", menuBox, "OptionsSliderTemplate")
    qSlider:SetPoint("LEFT", qLabel, "RIGHT", 12, 0)
    qSlider:SetMinMaxValues(8, 24)
    qSlider:SetValueStep(1)
    qSlider:SetObeyStepOnDrag(true)
    qSlider:SetWidth(200)
    EnsureSliderTrack(qSlider)
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
                ATS:UpdateReadyAlerts()
                if ATS.UpdateButtons then ATS:UpdateButtons() end
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

    local alertBox, aHeader = CreateBox("Trinket ready alerts", colorBox, -12)
    local macroCheck = CreateCheck(alertBox, "Glow on /use 13 or /use 14 macros", "macroReadyGlowEnabled", aHeader)
    macroCheck:ClearAllPoints()
    macroCheck:SetPoint("TOPLEFT", aHeader, "BOTTOMLEFT", 0, -8)
    local macroColor = CreateColorOption(alertBox, "Both ready", "macroReadyGlow", aHeader, -16)
    macroColor:ClearAllPoints()
    macroColor:SetPoint("TOPLEFT", aHeader, "BOTTOMLEFT", 580, -52)
    local macroColor13 = CreateColorOption(alertBox, "Slot 13 ready", "macroReadyGlow13", aHeader, -52)
    macroColor13:ClearAllPoints()
    macroColor13:SetPoint("TOPLEFT", aHeader, "BOTTOMLEFT", 280, -52)
    local macroColor14 = CreateColorOption(alertBox, "Slot 14 ready", "macroReadyGlow14", aHeader, -52)
    macroColor14:ClearAllPoints()
    macroColor14:SetPoint("TOPLEFT", aHeader, "BOTTOMLEFT", 430, -52)
    local glowWidth = CreateFrame("Slider", "ATSMacroReadyGlowWidth", alertBox, "OptionsSliderTemplate")
    glowWidth:SetPoint("TOPLEFT", macroCheck, "BOTTOMLEFT", 8, -24)
    glowWidth:SetWidth(200)
    glowWidth:SetMinMaxValues(1, 10)
    glowWidth:SetValueStep(1)
    glowWidth:SetObeyStepOnDrag(true)
    EnsureSliderTrack(glowWidth)
    glowWidth:SetValue(db.macroReadyGlowWidth)
    _G[glowWidth:GetName() .. "Low"]:SetText("1 px")
    _G[glowWidth:GetName() .. "High"]:SetText("10 px")
    _G[glowWidth:GetName() .. "Text"]:SetText("Glow border width: " .. db.macroReadyGlowWidth .. " px")
    glowWidth:SetScript("OnValueChanged", function(self, value)
        db.macroReadyGlowWidth = math.max(1, math.min(10, math.floor(value + 0.5)))
        _G[self:GetName() .. "Text"]:SetText("Glow border width: " .. db.macroReadyGlowWidth .. " px")
        ATS:UpdateReadyAlerts()
    end)
    local styleLabel = alertBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    styleLabel:SetPoint("TOPLEFT", glowWidth, "BOTTOMLEFT", 0, -24)
    styleLabel:SetText("Glow style")
    local styleDrop = CreateFrame("Frame", "ATSMacroReadyGlowStyleDropdown", alertBox, "UIDropDownMenuTemplate")
    styleDrop:SetPoint("LEFT", styleLabel, "RIGHT", 0, -4)
    UIDropDownMenu_SetWidth(styleDrop, 140)
    local styles = {{value = "MOVING", text = "Moving"}, {value = "STEADY", text = "Steady"}}
    UIDropDownMenu_Initialize(styleDrop, function()
        for _, style in ipairs(styles) do
            local value, label = style.value, style.text
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = label, value
            info.checked = db.macroReadyGlowStyle == value
            info.func = function()
                db.macroReadyGlowStyle = value
                UIDropDownMenu_SetSelectedValue(styleDrop, value)
                ATS:UpdateReadyAlerts()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(styleDrop, db.macroReadyGlowStyle)
    local soundCheck = CreateCheck(alertBox, "Play sound when a trinket becomes ready", "readySoundEnabled", glowWidth)
    soundCheck:ClearAllPoints()
    soundCheck:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", -8, -20)
    local soundDrop = CreateFrame("Frame", "ATSReadySoundDropdown", alertBox, "UIDropDownMenuTemplate")
    soundDrop:SetPoint("TOPLEFT", soundCheck, "BOTTOMLEFT", -16, -8)
    UIDropDownMenu_SetWidth(soundDrop, 110)
    UIDropDownMenu_Initialize(soundDrop, function()
        for _, name in ipairs(ATS.readySounds) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = name, name
            info.checked = db.readySound == name
            info.func = function()
                db.readySound = name
                UIDropDownMenu_SetSelectedValue(soundDrop, name)
                ATS:PlayReadySound()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(soundDrop, db.readySound)
    local preview = CreateFrame("Button", nil, alertBox, "UIPanelButtonTemplate")
    preview:SetSize(80, 22)
    preview:SetPoint("LEFT", soundDrop, "RIGHT", 8, 0)
    preview:SetText("Preview")
    preview:SetScript("OnClick", function() ATS:PlayReadySound() end)
    local volume = CreateFrame("Slider", "ATSReadySoundVolume", alertBox, "OptionsSliderTemplate")
    volume:SetPoint("LEFT", preview, "RIGHT", 60, 0)
    volume:SetWidth(180)
    volume:SetMinMaxValues(10, 100)
    volume:SetValueStep(10)
    volume:SetObeyStepOnDrag(true)
    EnsureSliderTrack(volume)
    volume:SetValue(db.readySoundVolume)
    _G[volume:GetName() .. "Low"]:SetText("10%")
    _G[volume:GetName() .. "High"]:SetText("100%")
    _G[volume:GetName() .. "Text"]:SetText("Alert volume: " .. db.readySoundVolume .. "%")
    volume:SetScript("OnValueChanged", function(self, value)
        db.readySoundVolume = math.floor(value / 10 + 0.5) * 10
        _G[self:GetName() .. "Text"]:SetText("Alert volume: " .. db.readySoundVolume .. "%")
    end)
    local soundNote = alertBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    soundNote:SetPoint("TOPLEFT", soundDrop, "BOTTOMLEFT", 16, -6)
    soundNote:SetText("Uses WoW master volume. Alerts once per cooldown; ignores the global cooldown.")
    alertBox:SetHeight(268)

    -- Three columns on first row
    local c1 = CreateColorOption(colorBox, "Slot 13", "slot13", cHeader, -8)
    c1:ClearAllPoints(); c1:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", 16, -8)
    local c2 = CreateColorOption(colorBox, "Slot 14", "slot14", cHeader, -8)
    c2:ClearAllPoints(); c2:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", 180, -8)
    local c3 = CreateColorOption(colorBox, "Pending swap", "glow", cHeader, -8)
    c3:ClearAllPoints(); c3:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", 344, -8)
    -- Place fourth swatch on the same first row (4 columns)
    local c4 = CreateColorOption(colorBox, "Manual", "manualBadge", cHeader, -8)
    c4:ClearAllPoints(); c4:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", 508, -8)
    local c5 = CreateColorOption(colorBox, "Ready glow", "readyGlow", cHeader, -48)
    c5:ClearAllPoints(); c5:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", 16, -48)
    local c6 = CreateColorOption(colorBox, "Speed off", "speedBadge", cHeader, -48)
    c6:ClearAllPoints(); c6:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", 180, -48)

    -- Spacer below colour box to guarantee visual padding to the window edge
    local bottomSpacer = CreateFrame("Frame", nil, panel)
    bottomSpacer:SetPoint("TOPLEFT", alertBox, "BOTTOMLEFT", 0, -16)
    bottomSpacer:SetPoint("RIGHT", panel, -16, 0)
    bottomSpacer:SetHeight(16)

    -- Size boxes when shown to avoid anchoring parents to children
    panel:SetScript("OnShow", function()
        LayoutOptions = function()
            -- Compute bottom of General box: lowest checkbox
            local function lowestBottom(...)
                local bottom
                for i = 1, select("#", ...) do
                    local obj = select(i, ...)
                    local b = obj and obj.GetBottom and obj:GetBottom() or nil
                    if b and (not bottom or b < bottom) then
                        bottom = b
                    end
                end
                return bottom
            end
            local showMount = ATS:HasRelevantMountGear()
            g10:SetShown(showMount); g11:SetShown(showMount)
            local gBottom = lowestBottom(g1, g2, g3, g4, g5, g6, g7, g8, g9, gTooltip, showMount and g10, showMount and g11)
            if not gBottom then gBottom = (gHeader:GetBottom() - 60) end
            generalBox:SetHeight(generalBox:GetTop() - gBottom + 16)

            local specialCount = RefreshSpecialTrinketOptions()
            menuBox:ClearAllPoints()
            if specialCount > 0 then
                menuBox:SetPoint("TOPLEFT", specialBox, "BOTTOMLEFT", 0, -16)
            else
                menuBox:SetPoint("TOPLEFT", generalBox, "BOTTOMLEFT", 0, -16)
            end
            menuBox:SetPoint("RIGHT", panel, -16, 0)

            -- Wrap dir button uses its static anchor next to wrap slider.

            local mBottom = wrapSlider:GetBottom() or 0
            if drop:GetBottom() and drop:GetBottom() < mBottom then mBottom = drop:GetBottom() end
            if qSlider:GetBottom() and qSlider:GetBottom() < mBottom then mBottom = qSlider:GetBottom() end
            if menuOOC:GetBottom() and menuOOC:GetBottom() < mBottom then mBottom = menuOOC:GetBottom() end
            if sortDrop:GetBottom() and sortDrop:GetBottom() < mBottom then mBottom = sortDrop:GetBottom() end
            if wrapDirBtn:GetBottom() and wrapDirBtn:GetBottom() < mBottom then mBottom = wrapDirBtn:GetBottom() end
            if mBottom == 0 then mBottom = (mHeader:GetBottom() - 60) end
            menuBox:SetHeight(menuBox:GetTop() - mBottom + 40)

            local last = c6 or c5 or c4 or c3
            colorBox:SetHeight(colorBox:GetTop() - last:GetBottom() + 24)
            if panel:GetTop() and bottomSpacer:GetBottom() then
                panel:SetHeight(panel:GetTop() - bottomSpacer:GetBottom() + 8)
            end
        end

        -- Run layout now and once next frame to handle initial sizing
        LayoutOptions()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() if panel:IsShown() then LayoutOptions() end end)
        end
    end)

    -- Do not register with Blizzard Settings; we use a standalone window

    -- Also create a standalone in-game window for this panel, so users don't need the game main menu
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local win = CreateFrame("Frame", "ATSOptionsFrame", UIParent, template)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetSize(820, 640)
    local pos = db.optionsPos or {}
    win:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
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
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ATS.SaveFramePosition then ATS:SaveFramePosition(self, "optionsPos") end
    end)

    -- Close button
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    -- Scroll the options so all settings remain reachable in the window.
    local scroll = CreateFrame("ScrollFrame", "ATSOptionsScrollFrame", win, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -30)
    scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -32, 8)
    panel:SetParent(scroll)
    panel:ClearAllPoints()
    panel:SetWidth(780)
    panel:SetHeight(900)
    scroll:SetScrollChild(panel)
    panel:Hide()

    -- Expose a toggle for the minimap button
    self.optionsWindow = win
    self.optionsPanel = panel
    self.optionCheckboxes = self.optionCheckboxes or {}
    self.optionCheckboxes.autoSwitch = g1
    self.optionCheckboxes.useMountSpeedManager = g10

    if ATS and ATS.UpdateOptionsAutoCheckbox then ATS:UpdateOptionsAutoCheckbox() end
end

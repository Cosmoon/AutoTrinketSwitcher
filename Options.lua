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
        end)
        return cb
    end

    -- General settings box
    local generalBox, gLast = CreateBox("General settings", title)
    gLast = CreateCheck(generalBox, "Show menu only when out of combat", "menuOnlyOutOfCombat", gLast)
    gLast = CreateCheck(generalBox, "Show cooldown numbers", "showCooldownNumbers", gLast)
    gLast = CreateCheck(generalBox, "Use large cooldown numbers", "largeNumbers", gLast)
    gLast = CreateCheck(generalBox, "Lock windows", "lockWindows", gLast)

    local tooltipLabel = generalBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    tooltipLabel:SetPoint("TOPLEFT", gLast, "BOTTOMLEFT", 0, -16)
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

    gLast = CreateCheck(generalBox, "Use tiny tooltips", "tinyTooltips", tooltipDrop)

    -- Menu settings box
    local menuBox, mHeader = CreateBox("Menu settings", generalBox, -16)
    local posLabel = menuBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    posLabel:SetPoint("TOPLEFT", mHeader, "BOTTOMLEFT", 16, -8)
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

    local cLast = cHeader
    cLast = CreateColorOption(colorBox, "Slot 13", "slot13", cLast, -8)
    cLast = CreateColorOption(colorBox, "Slot 14", "slot14", cLast)
    cLast = CreateColorOption(colorBox, "Pending swap", "glow", cLast)

    -- Size boxes when shown to avoid anchoring parents to children
    panel:SetScript("OnShow", function()
        generalBox:SetHeight(generalBox:GetTop() - gLast:GetBottom() + 16)
        menuBox:SetHeight(menuBox:GetTop() - wrapSlider:GetBottom() + 40)
        colorBox:SetHeight(colorBox:GetTop() - cLast:GetBottom() + 16)
    end)

    if Settings and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = panel.name
        Settings.RegisterAddOnCategory(category)
        self.optionsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        self.optionsPanel = panel
    end
end

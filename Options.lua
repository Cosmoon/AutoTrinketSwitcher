local ATS = AutoTrinketSwitcherFrame

-- Create options panel
function ATS:CreateOptions()
    local panel = CreateFrame("Frame")
    panel.name = "AutoTrinketSwitcher"

    local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    checkbox.Text:SetText("Show menu only when out of combat")
    checkbox:SetPoint("TOPLEFT", 16, -16)
    checkbox:SetChecked(AutoTrinketSwitcherDB.menuOnlyOutOfCombat)
    checkbox:SetScript("OnClick", function(self)
        AutoTrinketSwitcherDB.menuOnlyOutOfCombat = self:GetChecked()
    end)

    local cdCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cdCheckbox.Text:SetText("Show cooldowns on trinket buttons")
    cdCheckbox:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 0, -8)
    cdCheckbox:SetChecked(AutoTrinketSwitcherDB.showCooldowns)
    cdCheckbox:SetScript("OnClick", function(self)
        AutoTrinketSwitcherDB.showCooldowns = self:GetChecked()
        ATS:UpdateButtons()
    end)

    local function CreateColorOption(label, key, anchor, offsetY)
        local swatch = CreateFrame("Button", nil, panel)
        swatch:SetSize(16, 16)
        swatch:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -8)
        swatch.tex = swatch:CreateTexture(nil, "BACKGROUND")
        swatch.tex:SetAllPoints(true)
        swatch.tex:SetTexture("Interface/ChatFrame/ChatFrameColorSwatch")

        local text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
        text:SetText(label)

        local function Update()
            local c = AutoTrinketSwitcherDB.colors[key]
            swatch.tex:SetVertexColor(c.r, c.g, c.b)
        end

        swatch:SetScript("OnClick", function()
            local c = AutoTrinketSwitcherDB.colors[key]
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
            ColorPickerFrame.func, ColorPickerFrame.cancelFunc = setColor, setColor
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.previousValues = {c.r, c.g, c.b}
            ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
            ColorPickerFrame:Show()
        end)

        Update()
        return swatch
    end

    local last = cdCheckbox
    last = CreateColorOption("Slot 13 queue color", "slot13", last, -16)
    last = CreateColorOption("Slot 14 queue color", "slot14", last)
    CreateColorOption("Pending swap glow color", "glow", last)

    -- Register the options panel depending on the API available
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
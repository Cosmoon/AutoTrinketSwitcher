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

            -- Wrap dir button uses its static anchor next to wrap slider.

            local mBottom = wrapSlider:GetBottom() or 0
            if drop:GetBottom() and drop:GetBottom() < mBottom then mBottom = drop:GetBottom() end
            if qSlider:GetBottom() and qSlider:GetBottom() < mBottom then mBottom = qSlider:GetBottom() end
            if menuOOC:GetBottom() and menuOOC:GetBottom() < mBottom then mBottom = menuOOC:GetBottom() end
            if sortDrop:GetBottom() and sortDrop:GetBottom() < mBottom then mBottom = sortDrop:GetBottom() end
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
    self.optionCheckboxes = self.optionCheckboxes or {}
    self.optionCheckboxes.autoSwitch = g1
end


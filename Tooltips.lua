local ATS = AutoTrinketSwitcherFrame

-- Helper to position the tooltip at the game's default location (or legacy side-anchored)
local function SetTooltipOwner(frame)
    local tip = ATS:GetTooltip()
    if AutoTrinketSwitcherCharDB.useDefaultTooltipAnchor then
        tip:SetOwner(frame, "ANCHOR_NONE")
        if GameTooltip_SetDefaultAnchor then
            GameTooltip_SetDefaultAnchor(tip, frame)
        else
            tip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -13, 64)
        end
    else
        tip:SetOwner(frame, "ANCHOR_RIGHT")
    end
    return tip
end

-- Helper to get a tooltip object; optionally uses an isolated tooltip to avoid other addons
function ATS:GetTooltip()
    if AutoTrinketSwitcherCharDB and AutoTrinketSwitcherCharDB.cleanTooltips then
        if not self.cleanTooltip then
            local template = "GameTooltipTemplate"
            self.cleanTooltip = CreateFrame("GameTooltip", "ATS_CleanTooltip", UIParent, template)
            if self.cleanTooltip.HookScript then
                self.cleanTooltip:HookScript("OnHide", function()
                    ATS.tooltipContext = nil
                end)
            end
        end
        return self.cleanTooltip
    end
    return GameTooltip
end

function ATS:HideTooltip()
    if self.cleanTooltip and self.cleanTooltip.Hide then self.cleanTooltip:Hide() end
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
end

-- Display tooltip for an equipped slot
function ATS:ShowTooltip(frame, slot)
    local tiny = AutoTrinketSwitcherCharDB.tinyTooltips
    if AutoTrinketSwitcherCharDB.altFullTooltips and IsAltKeyDown() then
        tiny = false
    end
    self.tooltipContext = { kind = "slot", frame = frame, slot = slot }
    if tiny then
        local itemID = GetInventoryItemID("player", slot)
        if not itemID then return end
        local tip = SetTooltipOwner(frame)
        local name = GetItemInfo(itemID)
        if name then tip:SetText(name) end
        local _, desc = GetItemSpell(itemID)
        if desc then tip:AddLine(desc, 1, 1, 1) end
        tip:Show()
    else
        local tip = SetTooltipOwner(frame)
        tip:SetInventoryItem("player", slot)
    end
end

-- Display tooltip for an itemID (used in the trinket menu)
function ATS:ShowItemTooltip(frame, itemID)
    local tiny = AutoTrinketSwitcherCharDB.tinyTooltips
    if AutoTrinketSwitcherCharDB.altFullTooltips and IsAltKeyDown() then
        tiny = false
    end
    self.tooltipContext = { kind = "item", frame = frame, itemID = itemID }
    if tiny then
        local tip = SetTooltipOwner(frame)
        local name = GetItemInfo(itemID)
        if name then tip:SetText(name) end
        local _, desc = GetItemSpell(itemID)
        if desc then tip:AddLine(desc, 1, 1, 1) end
        tip:Show()
    else
        local tip = SetTooltipOwner(frame)
        tip:SetItemByID(itemID)
    end
end

-- Re-render tooltip when modifiers change (e.g., ALT toggled)
function ATS:RefreshTooltip()
    if not self.tooltipContext then return end
    local shown = (GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown())
    if not shown and self.cleanTooltip and self.cleanTooltip.IsShown then
        shown = self.cleanTooltip:IsShown()
    end
    if not shown then return end
    local ctx = self.tooltipContext
    if ctx.kind == "slot" and ctx.frame and ctx.slot then
        self:ShowTooltip(ctx.frame, ctx.slot)
    elseif ctx.kind == "item" and ctx.frame and ctx.itemID then
        self:ShowItemTooltip(ctx.frame, ctx.itemID)
    end
end

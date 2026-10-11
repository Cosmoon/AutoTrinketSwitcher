local ATS = AutoTrinketSwitcherFrame
local slots = {13, 14}
local glowLibrary = LibStub("LibCustomGlow-1.0")
local glowKey = "AutoTrinketSwitcherReady"

local function StopMacroGlow(button)
    glowLibrary.PixelGlow_Stop(button, glowKey)
    if button.atsMacroSteadyGlow then button.atsMacroSteadyGlow:Hide() end
end

local function StartMacroHalo(button, color, width)
    local frame = button.atsMacroSteadyGlow
    if not frame then
        frame = CreateFrame("Frame", nil, button)
        frame:SetAllPoints(button)
        frame:EnableMouse(false)
        frame.halos = {}
        for index = 1, 2 do
            local halo = frame:CreateTexture(nil, "OVERLAY")
            -- Blizzard's soft action-button border supplies a luminous rim
            -- with transparent falloff instead of an opaque rectangle.
            halo:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            halo:SetBlendMode("ADD")
            frame.halos[index] = halo
        end
        button.atsMacroSteadyGlow = frame
    end
    frame:SetFrameLevel(button:GetFrameLevel() + 8)
    local buttonWidth, buttonHeight = button:GetWidth(), button:GetHeight()
    for index, halo in ipairs(frame.halos) do
        local spread = (width - 1) * (index == 1 and 0.5 or 1)
        local padX = buttonWidth * 0.38 + spread
        local padY = buttonHeight * 0.38 + spread
        halo:ClearAllPoints()
        halo:SetPoint("TOPLEFT", frame, "TOPLEFT", -padX, padY)
        halo:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", padX, -padY)
        halo:SetVertexColor(color.r, color.g, color.b, index == 1 and 0.9 or 0.4)
    end
    frame:Show()
end

ATS.readySounds = {"Chime", "Bell", "Pulse"}

function ATS:PlayReadySound()
    local db = AutoTrinketSwitcherCharDB
    local name = db.readySound
    if name ~= "Chime" and name ~= "Bell" and name ~= "Pulse" then name = "Chime" end
    local volume = math.max(10, math.min(100, math.floor((db.readySoundVolume or 70) / 10 + 0.5) * 10))
    PlaySoundFile("Interface\\AddOns\\AutoTrinketSwitcher\\Media\\Sounds\\" .. name .. volume .. ".wav", "Master")
end

-- Only slot-use lines count, including conditional alternatives such as
-- /use [combat] 13; [nocombat] 14. Readiness is independent of macro conditions.
local function MacroSlots(body)
    local result = {}
    for line in (body or ""):gmatch("[^\r\n]+") do
        local args = line:lower():match("^%s*/use%s+(.+)")
        if args then
            args = args:gsub("%b[]", "")
            for alternative in args:gmatch("[^;]+") do
                local slot = tonumber(alternative:match("^%s*(%d+)%s*$"))
                if slot == 13 or slot == 14 then result[slot] = true end
            end
        end
    end
    return result
end

local actionButtonGroups = {
    {"ActionButton", 12},
    {"MultiBarBottomLeftButton", 12},
    {"MultiBarBottomRightButton", 12},
    {"MultiBarLeftButton", 12},
    {"MultiBarRightButton", 12},
    {"MultiBar5Button", 12},
    {"MultiBar6Button", 12},
    {"MultiBar7Button", 12},
    {"BT4Button", 180},
    {"DominosActionButton", 180},
}

local function ButtonMacroID(button, cache)
    local kind, action
    if button.GetAction then
        -- LibActionButton (Bartender) supports direct macros as well as slots.
        kind, action = button:GetAction()
    else
        kind = "action"
        action = button.action or (button.GetAttribute and button:GetAttribute("action"))
    end
    if issecretvalue and (issecretvalue(kind) or issecretvalue(action)) then return end
    if kind == "action" and type(action) == "number" and action > 0 then
        local actionSlot = action
        if cache[actionSlot] ~= nil then return cache[actionSlot] or nil end
        kind, action = GetActionInfo(actionSlot)
        if issecretvalue and issecretvalue(kind) then return end
        if kind == "macro" then
            -- Some clients return the macro's spell/item ID, not its index.
            local name = GetActionText(actionSlot)
            if issecretvalue and issecretvalue(name) then return end
            action = name and GetMacroIndexByName(name) or nil
            if action == 0 then action = nil end
        end
        if not (issecretvalue and (issecretvalue(kind) or issecretvalue(action))) then
            cache[actionSlot] = (kind == "macro" and action) or false
        end
    end
    if issecretvalue and (issecretvalue(kind) or issecretvalue(action)) then return end
    if kind == "macro" and (type(action) == "number" or type(action) == "string") then
        return action
    end
end

function ATS:QueueReadyAlerts(delay, discover)
    local db = AutoTrinketSwitcherCharDB
    if not db or not (db.macroReadyGlowEnabled or db.readySoundEnabled) then return end
    self.readyDiscoverPending = self.readyDiscoverPending or discover
    local due = GetTime() + (delay or 0.1)
    if self.readyAlertTimer and self.readyAlertDue <= due then return end
    if self.readyAlertTimer then self.readyAlertTimer:Cancel() end
    self.readyAlertDue = due
    self.readyAlertTimer = C_Timer.NewTimer(math.max(0, due - GetTime()), function()
        self.readyAlertTimer, self.readyAlertDue = nil, nil
        if self.readyDiscoverPending then
            self.readyDiscoverPending = nil
            if AutoTrinketSwitcherCharDB.macroReadyGlowEnabled then self:RefreshMacroButtons() end
        end
        self:UpdateReadyAlerts()
    end)
end

function ATS:RefreshMacroButtons()
    self.macroButtons = self.macroButtons or {}
    -- Never enumerate unrelated UI frames: aura-provider objects can reject
    -- IsObjectType even after an IsForbidden check in this client.
    for _, group in ipairs(actionButtonGroups) do
        for index = 1, group[2] do
            local button = _G[group[1] .. index]
            if button and not button:IsForbidden() then
                self.macroButtons[button] = true
            end
        end
    end
end

function ATS:UpdateReadyAlerts()
    local db = AutoTrinketSwitcherCharDB
    if not db then return end
    if self.readyAlertTimer then self.readyAlertTimer:Cancel() end
    self.readyAlertTimer, self.readyAlertDue = nil, nil
    if not (db.macroReadyGlowEnabled or db.readySoundEnabled) then
        for button in pairs(self.macroButtons or {}) do
            if not button:IsForbidden() and button.atsMacroReadyGlowColor then
                StopMacroGlow(button)
                button.atsMacroReadyGlowColor = nil
            end
        end
        self.readyAlertState = nil
        return
    end
    self.readyAlertState = self.readyAlertState or {}
    local ready, alert, nextEnd = {}, false, nil
    for _, slot in ipairs(slots) do
        local itemID = GetInventoryItemID("player", slot)
        local start, duration, enabled
        if GetInventoryItemCooldown then
            start, duration, enabled = GetInventoryItemCooldown("player", slot)
        else
            start, duration, enabled = self:GetItemCooldownSafe(itemID)
        end
        local secret = issecretvalue and (issecretvalue(start) or issecretvalue(duration) or issecretvalue(enabled))
        if not secret then
            start, duration = start or 0, duration or 0
            -- Trinket use/equip/shared cooldowns exceed the GCD. Ignore short
            -- cooldown reports entirely, so casting never toggles readiness.
            local previous = self.readyAlertState[slot]
            local cooling = duration > 2 and self:GetCooldownRemaining(start, duration) > 0
            local endsAt = cooling and (start + duration) or nil
            -- If a short GCD report masks a known item cooldown, keep that
            -- cooldown until its recorded end rather than emitting a false alert.
            if duration > 0 and duration <= 2 and previous and previous.itemID == itemID
                and previous.endsAt and previous.endsAt > GetTime() then
                cooling, endsAt = true, previous.endsAt
            end
            -- Inventory cooldown's enable flag identifies on-use trinkets,
            -- without depending on item spell data having loaded into cache.
            local usable = itemID and enabled == 1
            if not GetInventoryItemCooldown then
                usable = itemID and (GetItemSpell and GetItemSpell(itemID)) and enabled ~= 0 and enabled ~= false
            end
            ready[slot] = usable and not cooling
            if db.readySoundEnabled and ready[slot] and previous and previous.itemID == itemID and previous.cooling then
                alert = true
            end
            self.readyAlertState[slot] = {itemID = itemID, cooling = cooling, endsAt = endsAt}
            if endsAt and (not nextEnd or endsAt < nextEnd) then nextEnd = endsAt end
        else
            self.readyAlertState[slot] = nil
        end
    end
    -- Coalesce shared cooldown completion into a single alert.
    if alert then self:PlayReadySound() end

    if nextEnd then self:QueueReadyAlerts(math.max(0.05, nextEnd - GetTime() + 0.05)) end
    self.readyMacroCache = self.readyMacroCache or {}
    self.readyActionCache = self.readyActionCache or {}
    local macros = self.readyMacroCache
    local style = db.macroReadyGlowStyle == "STEADY" and "STEADY" or "MOVING"
    local width = math.max(1, math.min(10, math.floor((tonumber(db.macroReadyGlowWidth) or 2) + 0.5)))
    for button in pairs(self.macroButtons or {}) do
        -- A previously discovered button can become forbidden later.
        if button:IsForbidden() then
            self.macroButtons[button] = nil
        else
            local show = false
            local color
            if db.macroReadyGlowEnabled and button:IsVisible() then
                local id = ButtonMacroID(button, self.readyActionCache)
                if id then
                    if not macros[id] then macros[id] = MacroSlots(GetMacroBody(id)) end
                    local ready13 = macros[id][13] and ready[13]
                    local ready14 = macros[id][14] and ready[14]
                    show = ready13 or ready14
                    if ready13 and ready14 then
                        color = db.colors.macroReadyGlow
                    elseif ready13 then
                        color = db.colors.macroReadyGlow13
                    elseif ready14 then
                        color = db.colors.macroReadyGlow14
                    end
                end
            end
            local previous = button.atsMacroReadyGlowColor
            if show then
                if not previous or previous.r ~= color.r or previous.g ~= color.g or previous.b ~= color.b or previous.width ~= width or previous.style ~= style then
                    -- Use a private key so other addons' proc glows stay independent.
                    StopMacroGlow(button)
                    if style == "STEADY" then
                        StartMacroHalo(button, color, width)
                    else
                        glowLibrary.PixelGlow_Start(button, {color.r, color.g, color.b, 1},
                            8, 0.25, nil, width, 0, 0, false, glowKey)
                    end
                    button.atsMacroReadyGlowColor = {r = color.r, g = color.g, b = color.b, width = width, style = style}
                end
            elseif previous then
                StopMacroGlow(button)
                button.atsMacroReadyGlowColor = nil
            end
        end
    end
end

function ATS:StartReadyAlerts()
    if self.readyAlertFrame then return end
    local frame = CreateFrame("Frame")
    self.readyAlertFrame = frame
    frame:SetScript("OnEvent", function(_, event, arg)
        if event == "PLAYER_EQUIPMENT_CHANGED" and arg ~= 13 and arg ~= 14 then return end
        if event == "UPDATE_MACROS" or event == "PLAYER_ENTERING_WORLD" then
            self.readyMacroCache, self.readyActionCache = nil, nil
        elseif event == "ACTIONBAR_SLOT_CHANGED" then
            if arg and arg ~= 0 and self.readyActionCache then
                self.readyActionCache[arg] = nil
            else
                self.readyActionCache = nil
            end
        end
        self:QueueReadyAlerts(0.1, event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED")
    end)
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_EQUIPMENT_CHANGED",
        "ACTIONBAR_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "ACTIONBAR_SLOT_CHANGED",
        "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM",
        "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_MACROS",
        "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    self:QueueReadyAlerts(0, true)
end

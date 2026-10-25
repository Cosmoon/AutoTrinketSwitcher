if AutoTrinketSwitcherCompatibility.client ~= "FOREVER" then return end

-- Mirror.lua
-- Duplicates the SavedVariables table for WoW Forever clients that write
-- SavedVariables but do not read them back on reload/startup.
--
-- Load order:
--   1. normal SavedVariables, when available
--   2. Blizzard_AddOnList's host table, which this client does reload
--   3. chunked addon CVars, which survive /reload on this client
--
-- Format: MIR1:path.a.b=n12;path.c=b1;path.d=sText;path.e=t
-- Numeric keys are written as #3. Structural characters are percent-escaped.
local ADDON_NAME = ...

local Mirror = {}
_G.AutoTrinketSwitcherMirror = Mirror

Mirror.SLOTS = 8
Mirror.CHUNK = 4000
Mirror.PREFIX = "MIR1:"
Mirror.IGNORE = {}
Mirror.HOST = "g_addonCategoriesCollapsed"

local lastText, registeredBase
local watched, watchedDefaults

local function CharacterKey()
    local name = UnitName and UnitName("player") or nil
    local realm = GetRealmName and GetRealmName() or nil
    if name and name ~= "" then
        if realm and realm ~= "" then
            return realm .. ":" .. name
        end
        return name
    end
    return "default"
end

local function SafeKey(text)
    return tostring(text or "default"):gsub("[^%w_]", "_")
end

function Mirror:HostKey()
    return ADDON_NAME .. ":" .. CharacterKey()
end

function Mirror:CVarBase()
    return ADDON_NAME .. "Mirror" .. SafeKey(CharacterKey())
end

local function Escape(text)
    return (tostring(text):gsub('[%%;=%.#|"\\%c]', function(c) return string.format("%%%02X", c:byte()) end))
end

local function Unescape(text)
    return (text:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function EncodeKey(key)
    if type(key) == "number" then return "#" .. Escape(string.format("%.14g", key)) end
    return Escape(key)
end

local function DecodeKey(part)
    if part:sub(1, 1) == "#" then return tonumber(Unescape(part:sub(2))) end
    return Unescape(part)
end

local function KeyLess(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"
end

local function Flatten(value, path, out)
    if type(value) == "table" then
        local keys = {}
        for key in pairs(value) do
            if type(key) == "string" or type(key) == "number" then keys[#keys + 1] = key end
        end
        table.sort(keys, KeyLess)
        if next(value) == nil and path ~= "" then out[#out + 1] = path .. "=t" end
        for _, key in ipairs(keys) do
            Flatten(value[key], path == "" and EncodeKey(key) or (path .. "." .. EncodeKey(key)), out)
        end
    elseif type(value) == "boolean" then
        out[#out + 1] = path .. "=b" .. (value and "1" or "0")
    elseif type(value) == "number" then
        out[#out + 1] = path .. "=n" .. string.format("%.14g", value)
    elseif type(value) == "string" then
        out[#out + 1] = path .. "=s" .. Escape(value)
    end
end

function Mirror.Serialize(tbl)
    local out = {}
    Flatten(tbl, "", out)
    return Mirror.PREFIX .. table.concat(out, ";")
end

function Mirror.Deserialize(text)
    if type(text) ~= "string" or text:sub(1, #Mirror.PREFIX) ~= Mirror.PREFIX then return nil end
    local result = {}
    for pair in (text:sub(#Mirror.PREFIX + 1) .. ";"):gmatch("([^;]*);") do
        if pair ~= "" then
            local path, kind, raw = pair:match("^([^=]+)=([bnst])(.*)$")
            if not path then return nil end
            local value
            if kind == "t" then value = {}
            elseif kind == "b" then value = raw == "1"
            elseif kind == "n" then value = tonumber(raw)
            else value = Unescape(raw) end
            if value == nil then return nil end
            local parts = {}
            for part in path:gmatch("[^%.]+") do parts[#parts + 1] = DecodeKey(part) end
            if #parts == 0 then return nil end
            local node = result
            for i = 1, #parts - 1 do
                if parts[i] == nil then return nil end
                if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
                node = node[parts[i]]
            end
            if parts[#parts] == nil then return nil end
            node[parts[#parts]] = value
        end
    end
    return result
end

local function Prune(value, defaults, top)
    local out = {}
    for key, child in pairs(value) do
        if not (top and Mirror.IGNORE[key]) then
            local default
            if type(defaults) == "table" then default = defaults[key] end
            if type(child) == "table" then
                local pruned = Prune(child, default)
                if next(pruned) ~= nil then out[key] = pruned end
            elseif child ~= default then
                out[key] = child
            end
        end
    end
    return out
end

local function Api()
    local api = _G.C_CVar
    if api and api.RegisterCVar and api.GetCVar and api.SetCVar then return api end
    return nil
end

function Mirror:Register()
    local api = Api()
    if not api then return false end
    local base = self:CVarBase()
    if registeredBase == base then return true end
    for i = 1, self.SLOTS do
        if not pcall(api.RegisterCVar, base .. i, "") then return false end
    end
    registeredBase = base
    return true
end

function Mirror:Read()
    if not self:Register() then return nil end
    local base = self:CVarBase()
    local parts = {}
    for i = 1, self.SLOTS do
        local chunk = C_CVar.GetCVar(base .. i)
        if type(chunk) ~= "string" or chunk == "" then break end
        parts[#parts + 1] = chunk
    end
    if #parts == 0 then return nil end
    local text = table.concat(parts)
    local saved = self.Deserialize(text)
    if saved then lastText = text end
    return saved
end

function Mirror:Write(tbl, defaults)
    if type(tbl) ~= "table" or not self:Register() then return false end
    local text = self.Serialize(Prune(tbl, defaults, true))
    if text == lastText or #text > self.SLOTS * self.CHUNK then return false end
    if not self.Deserialize(text) then return false end
    local base = self:CVarBase()
    local written = true
    for i = 1, self.SLOTS do
        local chunk = text:sub((i - 1) * self.CHUNK + 1, i * self.CHUNK)
        if C_CVar.SetCVar(base .. i, chunk) == false then written = false end
    end
    if written then lastText = text end
    return written
end

local function Host()
    local host = _G[Mirror.HOST]
    if type(host) == "table" then return host end
    return nil
end

function Mirror:Host(tbl)
    local host = Host()
    if not host then return false end
    host[self:HostKey()] = tbl
    return true
end

function Mirror:Load(saved)
    if type(saved) == "table" and next(saved) ~= nil then return saved end
    local host = Host()
    local hosted = host and host[self:HostKey()]
    if type(hosted) == "table" and next(hosted) ~= nil then return hosted end
    return self:Read() or saved
end

if not _G.CreateFrame then return end

local watcher = CreateFrame("Frame")
local elapsedSince = 0
local FLUSH_INTERVAL = 30
local flushTicker

local function StartPeriodicFlush()
    if flushTicker then return end
    if C_Timer and C_Timer.NewTicker then
        flushTicker = C_Timer.NewTicker(FLUSH_INTERVAL, function() Mirror:Flush() end)
        return
    end

    watcher:SetScript("OnUpdate", function(_, elapsed)
        elapsedSince = elapsedSince + elapsed
        if elapsedSince < FLUSH_INTERVAL then return end
        elapsedSince = 0
        Mirror:Flush()
    end)
end

watcher:SetScript("OnEvent", function() Mirror:Flush() end)

function Mirror:Watch(tbl, defaults)
    watched, watchedDefaults = tbl, defaults
    watcher:RegisterEvent("PLAYER_LOGOUT")
    StartPeriodicFlush()
    self:Flush()
end

function Mirror:Flush()
    if not watched then return false end
    self:Host(watched)
    return self:Write(watched, watchedDefaults)
end

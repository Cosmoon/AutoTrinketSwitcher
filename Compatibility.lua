-- Client identification is centralized; unknown clients keep the ordinary queues.
local _, _, _, interface = GetBuildInfo()
interface = tonumber(interface) or 0
local client = "UNKNOWN"
if interface >= 16000 and interface < 20000 then client = "FOREVER"
elseif interface >= 10000 and interface < 16000 then client = "CLASSIC"
elseif interface >= 20000 and interface < 30000 then client = "TBC"
elseif interface >= 50000 and interface < 60000 then client = "MOP"
elseif interface >= 100000 then client = "RETAIL" end
AutoTrinketSwitcherCompatibility = { client = client, interface = interface }

from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]

def runtime(interface):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        function GetBuildInfo() return "test", "0", "", TEST_INTERFACE end
        function CreateFrame(_, name) local f={RegisterEvent=function() end, SetScript=function() end, SetOwner=function() end, ClearLines=function() end, NumLines=function() return 0 end}; if name then _G[name]=f end; return f end
        function UnitClass() return "Mage", "MAGE" end
        function UnitLevel() return 80 end
        function GetTime() return 100 end
        function InCombatLockdown() return combat or false end
        inventory = {[13]=100, [14]=200}
        bags = {}
        C_Container = {
            GetContainerNumSlots=function(bag) return bag == 0 and #bags or 0 end,
            GetContainerItemID=function(bag, slot) return bags[slot] end,
            GetContainerItemLink=function(bag, slot) return "item:"..bags[slot] end,
        }
        function GetInventoryItemID(_, slot) return inventory[slot] end
        function GetInventoryItemLink(_, slot) local id=inventory[slot]; return id and "item:"..id end
        function GetItemCount(id) for _, v in ipairs(bags) do if v==id then return 1 end end return 0 end
        C_Item = {GetItemInfo=function() end}
    ''')
    lua.globals().TEST_INTERFACE=interface
    for name in ['Compatibility.lua','AutoTrinketSwitcher.lua','Modules/SpecialTrinkets.lua','Modules/MountSpeed.lua']:
        lua.execute((ROOT/name).read_text(encoding='utf-8-sig'))
    lua.execute('''
        local ats=AutoTrinketSwitcherFrame
        ats.PlayerCanSwap=function() return not combat end
        ats.EquipItemSafe=function(_, item, slot)
            if not failEquip then inventory[slot]=tonumber(tostring(item):match("item:(%d+)")) or item end
        end
        ats:EnsureDB()
    ''')
    return lua

for interface, expected in [(11509,'CLASSIC'),(20506,'TBC'),(50504,'MOP'),(120105,'RETAIL'),(16001,'FOREVER'),(39999,'UNKNOWN')]:
    lua=runtime(interface)
    assert lua.globals().AutoTrinketSwitcherCompatibility.client==expected
    assert lua.eval('AutoTrinketSwitcherFrame:GetSpecialTrinket(30720) ~= nil') == (expected=='TBC')
    lua.execute('bags={193475,274648}; C_Map={GetBestMapForUnit=function() return 1446 end}; AutoTrinketSwitcherFrame:EquipMountSpeedGear()')
    equipped=lua.globals().inventory[13]
    assert equipped == ({'RETAIL':193475,'FOREVER':274648}.get(expected,100))
    if expected in ['RETAIL','FOREVER']:
        lua.execute('failEquip=true; assert(not AutoTrinketSwitcherFrame:RestoreMountSpeedGear()); assert(AutoTrinketSwitcherCharDB.mountSpeedPrevious[13]=="item:100")')
        lua.execute('failEquip=false; assert(AutoTrinketSwitcherFrame:RestoreMountSpeedGear()); assert(inventory[13]==100); assert(not AutoTrinketSwitcherCharDB.mountSpeedActive)')
    print(expected, 'client routing, special-item filtering, mount selection OK')
lua=runtime(20506)
lua.execute('''
    bags={32863,25653,11122}
    combat=true; assert(not AutoTrinketSwitcherFrame:EquipMountSpeedGear()); assert(inventory[13]==100)
    combat=false; AutoTrinketSwitcherFrame:EquipMountSpeedGear()
    assert(inventory[13]==32863 and inventory[14]==200)
    AutoTrinketSwitcherCharDB.specialTrinketModes={[30720]="DISPLAY_ONLY"}
    bags={}; assert(#AutoTrinketSwitcherFrame:GetDetectedSpecialTrinketIDs()==0)
    assert(AutoTrinketSwitcherCharDB.specialTrinketModes[30720]=="DISPLAY_ONLY")
    AutoTrinketSwitcherCharDB.queues[13]={30720}
    assert(#AutoTrinketSwitcherFrame:GetDetectedSpecialTrinketIDs()==1)
''')
print('Combat, mount priority, single riding trinket, hidden saved modes, queued modes OK')
lua=runtime(20506)
lua.execute("""
    local ats=AutoTrinketSwitcherFrame
    ats.UnregisterEvent=function() end
    local existing=AutoTrinketSwitcherCharDB
    existing.queues[13]={30720}
    existing.specialTrinketModes[30720]="DISPLAY_ONLY"
    TrinketSwitcherCharDB={queues={[13]={11122}}}
    ats:ADDON_LOADED("AutoTrinketSwitcher")
    assert(AutoTrinketSwitcherCharDB==existing)
    assert(existing.queues[13][1]==30720)
    assert(existing.specialTrinketModes[30720]=="DISPLAY_ONLY")
""")
print('Existing AutoTrinketSwitcher settings preserved; beta settings ignored OK')

lua=runtime(16001)
lua.execute('''
    local ats = AutoTrinketSwitcherFrame
    local db = AutoTrinketSwitcherCharDB
    local mapID = 1413
    C_Map = {GetBestMapForUnit = function() return mapID end}
    function GetItemInfoInstant(item)
        local itemID = tonumber(tostring(item):match("item:(%d+)")) or item
        return itemID, nil, nil, ({[901] = "INVTYPE_HAND", [902] = "INVTYPE_FEET"})[itemID]
    end
    C_Container.GetContainerItemLink = function(_, slot)
        local id = bags[slot]
        return "item:" .. id .. (({[901] = ":930", [902] = ":464"})[id] or "")
    end
    inventory[2], inventory[8], inventory[10], inventory[11], inventory[12], inventory[15] = 201, 208, 210, 211, 212, 215
    bags = {11122, 274648, 284266, 901, 902, 6693, 285329, 285330, 284100, 284101, 284102, 2042, 271871}
    assert(ats:HasRelevantMountGear())
    assert(ats:GetGiftOfGallopingStatus() == "In bags (use manually)")
    C_UnitAuras = {GetPlayerAuraBySpellID = function(id) if id == 1289654 then return {} end end}
    assert(ats:GetGiftOfGallopingStatus() == "Active (+10% mounted speed)")
    assert(ats:EquipMountSpeedGear())
    assert(inventory[13] == 11122 and inventory[14] == 274648)
    assert(inventory[11] == 285330 and inventory[12] == 6693 and inventory[15] == 285329)
    assert(inventory[10] == 901 and inventory[8] == 902)

    mapID = 1452
    assert(ats:EquipMountSpeedGear())
    assert(inventory[13] == 11122 and inventory[14] == 200)
    assert(inventory[11] == 211 and inventory[12] == 212 and inventory[15] == 215)
    assert(inventory[10] == 284266 and inventory[8] == 902)

    mapID = 1422
    assert(ats:EquipMountSpeedGear())
    assert(inventory[10] == 901)
    assert(inventory[15] == 284100 and inventory[11] == 284102 and not inventory[16])
    assert(ats:RestoreMountSpeedGear())
    assert(inventory[8] == 208 and inventory[10] == 210 and inventory[13] == 100)
    assert(inventory[11] == 211 and inventory[15] == 215)

    mapID = 1436
    bags = {2042}
    inventory[16], inventory[17] = 216, 217
    assert(not ats:EquipMountSpeedGear())
    db.mountSpeedWeaponsEnabled = true
    local equip = ats.EquipItemSafe
    ats.EquipItemSafe = function(self, item, slot)
        equip(self, item, slot)
        if slot == 16 and inventory[16] == 2042 then inventory[17] = nil end
    end
    assert(ats:EquipMountSpeedGear())
    assert(inventory[16] == 2042 and not inventory[17])
    combat = true
    assert(not ats:RestoreMountSpeedGear())
    combat = false
    assert(ats:RestoreMountSpeedGear())
    assert(inventory[16] == 216 and inventory[17] == 217)
''')
print('Forever zone transitions, stacked trinkets, enchants, sets, consumable status and weapon restoration OK')

lua=LuaRuntime(unpack_returned_tuples=True)
for p in list(ROOT.glob('*.lua'))+list((ROOT/'Modules').glob('*.lua')):
    ok,error=lua.eval('function(s,n) local f,e=loadstring(s,n); return f~=nil,e end')(p.read_text(encoding='utf-8-sig'),str(p))
    assert ok, (p,error)
print('All addon Lua files parse successfully')



manifest=(ROOT/'AutoTrinketSwitcher.toc').read_text(encoding='utf-8-sig')
assert '## SavedVariablesPerCharacter: AutoTrinketSwitcherCharDB' in manifest
for line in manifest.splitlines():
    if line and not line.startswith('#'):
        assert (ROOT/line.replace(chr(92),'/')).is_file(), line
main=(ROOT/'AutoTrinketSwitcher.lua').read_text(encoding='utf-8-sig')
assert 'SLASH_AUTOTRINKETSWITCHER1 = "/ats"' in main
assert 'SLASH_AUTOTRINKETSWITCHER2 = "/autotrinketswitcher"' in main
assert '"/ts"' not in main and '"/trinketswitcher"' not in main
assert 'importedFrom' not in main
print('Manifest paths, original SavedVariables and slash commands OK')

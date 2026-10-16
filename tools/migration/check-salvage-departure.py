"""Run actual salvage stores, garage restoration and departure UI without a GPU."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime, lua_type

PRODUCTION = ['scripts/app/SalvageLobby.lua', 'scripts/salvage/StashRules.lua',
              'scripts/ui/SalvagePage.lua', 'scripts/construction/Garage.lua',
              'scripts/storage/BlueprintStore.lua', 'scripts/construction/Blueprint.lua']
HASHES = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in PRODUCTION}
BASELINE = json.loads((ROOT / 'docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json').read_text(encoding='utf-8'))
SOURCE_HASHES = {}
for p in ['shared/salvage/session.js', 'shared/salvage/stash.js', 'shared/ui/salvageHub.js']:
    digest = hashlib.sha256((Path(BASELINE['snapshot']) / p).read_bytes()).hexdigest()
    assert digest == BASELINE['files'][p]['sha256'], p
    SOURCE_HASHES[p] = digest
RESOURCES = {}

LUA = r'''
package.path='scripts/?.lua;'..package.path
local checks={}
local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
package.loaded['core.ResourceData']={Read=ReadResource}
package.loaded['storage.CloudStorage']={Queue=function()end,Invalid=function()end}
package.loaded['storage.PreviewCache']={Ref=function()return false end,Retire=function()end}
FILE_READ=1;FILE_WRITE=2
local fs={};local fail=false
fileSystem={FileExists=function(_,p)return fs[p]~=nil end}
function File(p,mode)
 local text=mode==FILE_READ and fs[p] or (not fail and '' or nil)
 return {size=text and #text or 0,IsOpen=function()return text~=nil end,ReadString=function()return text end,
 WriteString=function(_,v)text=v end,Flush=function()fs[p]=text end,Dispose=function()end}
end
local Store=require 'storage.BlueprintStore'
local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Garage=require 'construction.Garage'
local Rules=require 'salvage.StashRules'
local Lobby=require 'app.SalvageLobby'
local cfg=ReadResource('UI/SalvageRules.json')
local starter=ReadResource('Warehouse/Manifest.json').starter
local function App()
 local bp=Prefab.BuildRaceCar(BP.New());local store=Store.New('vox-arena-test')
 local a={lobby='arena',blueprint=bp,store=store}
 function a:LoadBlueprint(data)self.blueprint:Load(data);return true end
 a.bays=Garage.New(bp,store,function(d)return a:LoadBlueprint(d)end)
 a.bays.unsaved=false
 return a
end
local function Reset()fs={} end
local function SaveStash(owned)
 Check(Store.New('vox-salvage'):Write('stash',{v=1,credits=8000,items=owned or {},op=1},Rules.Valid),'fixture valid stash saved')
end
local function SaveCar(slot,kind)
 local bp=Prefab.Create(BP.New(),kind);bp.name=kind..slot
 Check(Store.New('vox-salvage'):SaveSlot(slot,bp),'fixture real blueprint saved');return bp:ToTable()
end
if cfg.testFill==0 then
 Reset();local app=App();app.salvageLobby=Lobby.New(app)
 local needed=Rules.Need(starter.parts)
 Check(app.salvageLobby:Owned('part:cube')==needed['part:cube']+40,'without test fill new stash owns starter blocks plus 40 extras')
 Check(app.salvageLobby:Owned('part:drive1')==(needed['part:drive1']or 0)+2,'without test fill starter movement plus two spares')
 Check(app.salvageLobby:Owned('part:laser1')==(needed['part:laser1']or 0)+1,'without test fill starter weapon plus one spare')
 Check(Lobby.Switch(app,'salvage') and next(app.salvageLobby:Shortfall())==nil,'production starter deploys without debug fill')
 local previous=app.salvageLobby:Owned('part:cube');local second=Lobby.New({})
 Check(not second.fresh and second:Owned('part:cube')==previous,'reopening real stash never grants starter twice')
 Reset();SaveStash();app=App();Check(Lobby.Switch(app,'salvage'),'old no-fill stash enters')
 Check(app.blueprint:Size()==1 and app.salvageLobby:Owned('part:cube')==0,'old empty no-fill stash preserves zero inventory and empty chassis')
 return checks
end
Reset()
local app=App();app.salvageLobby=Lobby.New(app)
Check(app.salvageLobby.fresh,'new stash detected before constructor save')
Check(Lobby.Switch(app,'salvage'),'new stash enters salvage')
Check(#app.blueprint:ToTable().parts==#starter.parts and app.bays.active==1,'fresh garage receives source starter in first bay')
Check(next(app.salvageLobby:Shortfall())==nil,'fresh starter stock permits deployment')
Check(app.salvageLobby:Owned('part:cube')==999,'source test fill remains 999, not infinite')

Reset();SaveStash();local first=SaveCar(1,'raceCar');local last=SaveCar(17,'miniScout')
local store=Store.New('vox-salvage');Check(store:SaveGarageState(17),'fixture active bay persisted')
app=App();local preview=Lobby.VehicleData(app,'salvage')
Check(preview.name==last.name,'preview selects saved active bay without draft')
Check(Lobby.Switch(app,'salvage'),'existing slot-only garage enters')
Check(app.blueprint.name==last.name and app.bays.active==17,'missing draft restores active bay 17')
Check(store:LoadSlot(1).name==first.name,'missing draft never overwrites bay 1')
Check(select(2,store:LoadSlot(1))==1,'existing bay receives no hidden new generation')
local counts=Rules.Need(first.parts);for id,n in pairs(Rules.Need(last.parts))do counts[id]=(counts[id]or 0)+n end
local usage=app.salvageLobby:Usage()
for id,n in pairs(counts)do Check(usage[id]==n,'all saved cars counted once: '..id)end
Check(usage['part:core']==nil,'free core excluded from usage')
local draft=Prefab.Create(BP.New(),'miniAssault');app.blueprint:Load(draft:ToTable());app.bays.active=false
local expected=(counts['part:cube']or 0)+(Rules.Need(draft:ToTable().parts)['part:cube']or 0)
Check(app.salvageLobby:Usage()['part:cube']==expected,'unslotted live draft adds to every saved bay')

Reset();SaveStash();SaveCar(5,'miniScout');SaveCar(9,'raceCar')
store=Store.New('vox-salvage');store:SaveGarageState(20)
store:Queue(Prefab.Create(BP.New(),'megaMech'));store:Flush()
app=App();Check(Lobby.Switch(app,'salvage'),'invalid active metadata recovers')
Check(app.bays.active==5 and app.blueprint.name=='miniScout5','first valid saved bay wins over unrelated stale draft')

Reset();SaveStash();app=App();Check(Lobby.Switch(app,'salvage'),'old empty garage enters')
Check(app.blueprint:Size()==1 and app.bays.active==1,'old stash without cars receives empty chassis, not free starter')
Check(app.salvageLobby:Owned('part:cube')==999,'old garage creation does not grant starter parts')

Reset();SaveStash();SaveCar(3,'raceCar');Store.New('vox-salvage'):SaveGarageState(3)
app=App();local arena=app.store;fail=true
local ok=Lobby.Switch(app,'salvage');fail=false
Check(not ok and app.lobby=='arena' and app.store==arena,'metadata write failure cannot switch visible context')

Reset();SaveStash();SaveCar(1,'megaMech');Store.New('vox-salvage'):SaveGarageState(1)
app=App();Check(Lobby.Switch(app,'salvage'),'large saved car loads unchanged')
local lobby=app.salvageLobby;local short=lobby:Shortfall();local needed=lobby:Usage()['part:cube']
Check(needed>999 and short['part:cube']==needed-999,'large car legitimately exceeds 999 test blocks')
local info=Rules.ShortfallInfo(short)
Check(info.kinds>0 and info.details:find(tostring(needed-999),1,true),'shortage explains exact missing count')
Check(info.tip:find('先去改装或商人补齐',1,true),'shortage names source repair routes')
local before=lobby.data;local credit=lobby.data.credits
fail=true;local purchase=lobby:BuyAll(short);fail=false
Check(not purchase.ok and lobby.data==before and lobby.data.credits==credit,'failed exact-shortage purchase rolls back stock and credits')
purchase=lobby:BuyAll(short)
Check(purchase.ok and next(lobby:Shortfall())==nil,'purchasing exact shortfall clears legitimate inventory block')
Check(lobby.data.credits==credit-purchase.cost and lobby:Owned('part:cube')==needed,'shortage purchase charges credits without free refill')
lobby.data.items['part:cube']=0
Check(lobby:Shortfall()['part:cube']==needed,'lost stock stays missing in current session')

local function Widget(p)
 p=p or {};p.props={};for k,v in pairs(p)do p.props[k]=v end;p.children=p.children or {}
 function p:AddChild(v)self.children[#self.children+1]=v end
 function p:SetStyle(t)for k,v in pairs(t)do self.props[k]=v end end
 function p:ClearChildren()self.children={}end
 function p:Destroy()end
 return p
end
package.loaded['urhox-libs/UI']={Panel=Widget,ScrollView=Widget}
package.loaded['ui.SourceDraw']={Number=tostring,orange={},muted={}}
package.loaded['ui.SalvageButton']=Widget;package.loaded['ui.SalvageItem']=Widget
package.loaded['ui.SalvagePaint']={Page=Widget,Surface=Widget,Text=Widget,Value=function()return 5000 end}
package.loaded['ui.SourceParagraph']={New=function()return {}end}
package.loaded['ui.VoxTheme']={}
local Page=require 'ui.SalvagePage';local messages={};local departures=0
app.toasts={Push=function(_,message)messages[#messages+1]=message end}
function app:EnterTrial(id)Check(id=='salvage','correct departure mode');departures=departures+1;return true end
local s={app=app,width=1920,height=1080,Track=function(v)return v end,salvage={tab='loadout',gear={}}}
local function DeployButton(page)
 for _,child in ipairs(page.children)do if child.props.text=='出发'then return child end end
 error('no deploy control')
end
local button=DeployButton(Page.Create(s))
Check(button.props.disabled and button.props.subtitle=='1 种零件超出库存','real loadout UI disables departure and displays shortage category count')
Check(button.props.tooltip==Rules.ShortfallInfo(lobby:Shortfall()).tip,'real loadout tooltip restores source guidance')
Check(not Page.Deploy(s) and departures==0,'direct callback cannot deploy with shortages')
Check(messages[#messages]:find(tostring(needed),1,true),'keyboard/callback feedback contains actual missing blocks')
KEY_ESCAPE=1;KEY_TAB=2;KEY_RETURN=3
input={GetKeyPress=function(_,key)return key==KEY_RETURN end}
Page.Key(s);Check(departures==0,'Enter cannot bypass disabled departure')
lobby.data.items['part:cube']=needed
button=DeployButton(Page.Create(s))
Check(not button.props.disabled and button.props.subtitle:find('带入价值',1,true),'eligible loadout restores enabled source CTA')
Check(Page.Deploy(s) and departures==1,'eligible departure reaches game exactly once')
Check(Rules.ShortfallInfo({}).kinds==0,'empty stock warning remains absent')
return checks
'''


def execute(mutation=None, test_fill=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    null = lua.table()
    same = lua.eval('rawequal')

    def convert(v):
        if v is None:
            return null
        if isinstance(v, dict):
            return lua.table_from({k: convert(x) for k, x in v.items()})
        if isinstance(v, list):
            return lua.table_from([convert(x) for x in v])
        return v

    def plain(v):
        if lua_type(v) != 'table':
            return v
        if same(v, null):
            return None
        keys = list(v.keys())
        if keys and all(isinstance(k, int) and k > 0 for k in keys) and max(keys) == len(keys):
            return [plain(v[i]) for i in range(1, len(keys) + 1)]
        return {str(k): plain(x) for k, x in v.items()}

    def resource(p):
        file = ROOT / 'assets' / p
        RESOURCES[str(file.relative_to(ROOT)).replace('\\', '/')] = hashlib.sha256(file.read_bytes()).hexdigest()
        data = json.loads(file.read_text(encoding='utf-8'))
        if p == 'UI/SalvageRules.json' and test_fill is not None:
            data['testFill'] = test_fill
        return convert(data)

    lua.globals().ReadResource = resource
    lua.globals().cjson = lua.table_from({'null': null,
        'encode': lambda v: json.dumps(plain(v), ensure_ascii=False, separators=(',', ':')),
        'decode': lambda v: convert(json.loads(v))})
    if mutation:
        path, old, new = mutation
        source = (ROOT / path).read_text(encoding='utf-8')
        assert old in source, path
        lua.globals().overrideSource = source.replace(old, new, 1)
        module = path.removeprefix('scripts/').removesuffix('.lua').replace('/', '.')
        lua.execute(f"package.preload['{module}']=assert(load(overrideSource,'@negative-control'))")
    return list(lua.execute(LUA).values())


checks = execute()
no_fill_checks = execute(test_fill=0)
negative = []
for mutation in [
    ('scripts/app/SalvageLobby.lua', 'if saved then return saved,active end', 'if false then return saved,active end'),
    ('scripts/app/SalvageLobby.lua', 'local data,slot=StoredVehicle(store)', "local data,slot=store:Read('draft'),1"),
    ('scripts/app/SalvageLobby.lua', 'i~=self.app.bays.active', 'true'),
    ('scripts/app/SalvageLobby.lua', 'if app.salvageLobby.fresh then bp:Load', 'if true then bp:Load'),
    ('scripts/ui/SalvagePage.lua', 'if shortage.kinds>0 then', 'if false then'),
    ('scripts/ui/SalvagePage.lua', 'disabled=shortage.kinds>0', 'disabled=false'),
    ('scripts/salvage/StashRules.lua', 'n-(owned[id] or 0)', 'n'),
]:
    try:
        execute(mutation)
    except Exception as error:
        negative.append({'file': mutation[0], 'mutation': mutation[2], 'rejected': True,
                         'reason': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control passed: ' + mutation[0])
assert HASHES == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in PRODUCTION}, 'Production drift'
report = {'result': 'PASS', 'checks': checks + no_fill_checks, 'negativeControls': negative,
          'sourceCommit': 'b276064942ae09c0227ec28d4cfda1d5ff006455', 'sourceHashes': SOURCE_HASHES,
          'productionHashes': HASHES, 'resources': RESOURCES,
          'testInputs': {'tools/migration/check-salvage-departure.py': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},
          'boundary': 'Actual Lua 5.4 SalvageLobby, StashRules, Garage, BlueprintStore, Blueprint and SalvagePage.Create/Key/Deploy executed. Filesystem, JSON and UI widgets are controlled CPU adapters. No real account, user old save, GPU, pointer hit testing, visuals, live battle or mobile performance acceptance.'}
out = ROOT / 'docs/migration/evidence/salvage-departure-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(report['checks']), 'negativeControls': len(negative), 'evidence': str(out)}))

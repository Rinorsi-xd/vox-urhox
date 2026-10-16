"""Compare actual CarUnit reads/repair against git main, without a native window."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
null = lua.table()


def convert(value):
    if value is None:
        return null
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value


def plain(value):
    if hasattr(value, 'items'):
        return {str(key): plain(item) for key, item in value.items()}
    return value


relative = 'scripts/combat/CarUnit.lua'
before = subprocess.check_output(['git', 'show', '48ef15f2:' + relative]).decode('utf-8')
lua.globals().OLD_CAR_UNIT = before
lua.globals().read_resource = lambda path: convert(json.loads((ROOT / 'assets' / path).read_text(encoding='utf-8-sig')))
lua.globals().cjson = lua.table(null=null)
result = lua.execute(r'''
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
package.preload['core.ResourceData']=function() return {Read=function(path) return read_resource(path) end} end
local BP=require 'construction.Blueprint'
local Defs=require('parts.Defs').PARTS
local Unit=require 'combat.CarUnit'
local Old=assert(load(OLD_CAR_UNIT,'@48ef15f2/CarUnit.lua'))()
local AI=require 'combat.EnemyDriverMath'
local Prefab=require 'construction.Prefab'
local assertions=0
local function Check(value,label) assertions=assertions+1;assert(value,label) end
local function Equal(a,b,label)
    Check(type(a)==type(b),label..' type')
    if type(a)=='table' then
        for k,v in pairs(a) do Equal(v,b[k],label..'.'..tostring(k)) end
        for k in pairs(b) do Check(a[k]~=nil,label..' extra '..tostring(k)) end
    else Check(a==b,label..' '..tostring(a)..' ~= '..tostring(b)) end
end
local function Make(mod,bp)
    local hp,original,order,total={},{},{},0
    for _,p in ipairs(bp:List()) do
        hp[p.id]=Defs[p.type].hp*.4;original[p.id]=p;order[#order+1]=p.id;total=total+Defs[p.type].hp
    end
    local out=setmetatable({bp=bp,hp=hp,original=original,repairOrder=order,alive=true,partScale=.4,
        rawHpMax=total,shields={},combat=true,env={time=10,viewEvents={}},structMax=100,struct=10,
        bodyHpMax=100,bodyHp=80},mod)
    out.budget0=Old.Budget(out)
    return out
end
local function Read(unit)
    return {core=unit:Core(),budget=unit:Budget(),integrity=unit:Integrity(),life=unit:Life(),ai=AI.Life(unit)}
end
local oldList,oldGraph,oldCore=BP.List,BP.Graph,BP.CoreParts
local counters={}
BP.List=function(self,...) counters.list=(counters.list or 0)+1;return oldList(self,...) end
BP.Graph=function(self,...) counters.graph=(counters.graph or 0)+1;return oldGraph(self,...) end
BP.CoreParts=function(self,...) counters.coreParts=(counters.coreParts or 0)+1;return oldCore(self,...) end
local currentCounters
local cases={}
local sources=require('combat.ArenaData').prefabs
for key,source in pairs(sources) do if key:sub(1,4)=='red:' then
    local bp=BP.New():Load(source);local fresh=Make(Unit,bp);local old=Make(Old,bp)
    Equal(Read(fresh),Read(old),'actual arena '..key)
    for _,p in ipairs(bp:List()) do fresh.hp[p.id]=fresh.hp[p.id]*.31;old.hp[p.id]=old.hp[p.id]*.31 end
    Equal(Read(fresh),Read(old),'damaged arena '..key)
    local remove={};for i,p in ipairs(bp:List()) do if i%3==0 then remove[#remove+1]=p.id end end
    for _,id in ipairs(remove) do bp:Remove(id);fresh.hp[id]=nil;old.hp[id]=nil end
    Equal(Read(fresh),Read(old),'removed arena '..key)
    cases[#cases+1]={key=key,parts=#source.parts}
end end
-- Sparse IDs, several cores, deleted core, missing HP, empty/dead all retain old semantics.
local small=BP.New()
for i=1,16 do small:Add({type=i%4==0 and 'core' or 'cube',pos={i*5,0,0},rot=0}) end
local fresh,old=Make(Unit,small),Make(Old,small)
for _,id in ipairs({2,4,7,8,12,16,1,3,5,6,9,10,11,13,14,15}) do
    Equal(Read(fresh),Read(old),'sparse multiple cores '..id)
    small:Remove(id);fresh.hp[id]=nil;old.hp[id]=nil
end
Equal(Read(fresh),Read(old),'empty')
fresh.alive=false;old.alive=false;Equal(Read(fresh),Read(old),'dead')
for kind,def in pairs(Defs) do
    Check(type(def.budget)=='number' and def.budget>=0 and def.budget%1==0,'exact integer budget '..kind)
end
local function RepairState(u,restored)
    local parts={};for _,p in ipairs(u.bp:List()) do parts[#parts+1]={id=p.id,type=p.type,pos=p.pos,rot=p.rot} end
    local events={};for _,e in ipairs(u.env.viewEvents) do events[#events+1]={type=e.type,id=e.id} end
    return {parts=parts,hp=u.hp,bodyHp=u.bodyHp,struct=u.struct,dirty=u.dirty,shields=u.shields,restored=restored,events=events}
end
local repairCases=0
for _,preset in ipairs({'raceCar','miniAssault','megaMech'}) do
    for _,mode in ipairs({'complete','one','many','all','dead','zero'}) do
        local a,b=Make(Unit,Prefab.Create(BP.New(),preset)),Make(Old,Prefab.Create(BP.New(),preset))
        local ids={};for i,p in ipairs(a.bp:List()) do if mode=='all' or mode=='one' and i==3 or mode=='many' and i%3==0 then ids[#ids+1]=p.id end end
        for _,id in ipairs(ids) do a.bp:Remove(id);b.bp:Remove(id);a.hp[id]=nil;b.hp[id]=nil end
        a.alive=mode~='dead';b.alive=a.alive
        for call=1,3 do
            local amount=mode=='zero' and 0 or call
            local ra,rb=a:RestoreMissing(amount),b:RestoreMissing(amount)
            Equal(RepairState(a,ra),RepairState(b,rb),'actual repair '..preset..'/'..mode..'/'..call)
        end
        if mode=='complete' then
            -- Old Graph has warmed adjacency; new full-car early return has not.
            local target=a.bp:List()[3].id
            a.bp:Remove(target);b.bp:Remove(target);a.hp[target]=nil;b.hp[target]=nil
            Equal(RepairState(a,a:RestoreMissing(1)),RepairState(b,b:RestoreMissing(1)),
                'cold versus warm adjacency after complete repair '..preset)
        end
        repairCases=repairCases+1
    end
end
local profile={}
for _,preset in ipairs({'miniAssault','raceCar','megaMech'}) do
    local bp=Prefab.Create(BP.New(),preset)
    local function Bench(mod,operation,loops)
        local u=Make(mod,bp);collectgarbage('collect');counters={}
        local at=os.clock()
        for _=1,loops do if operation=='aiLife' then AI.Life(u) else u:RestoreMissing(1) end end
        return {ms=(os.clock()-at)*1000,calls=loops,list=counters.list or 0,
            graph=counters.graph or 0,coreParts=counters.coreParts or 0}
    end
    profile[preset]={parts=bp:Size(),aiLife={before=Bench(Old,'aiLife',1000),after=Bench(Unit,'aiLife',1000)},
        completeRepair={before=Bench(Old,'repair',30),after=Bench(Unit,'repair',30)}}
end
-- Real old code must fail the intended redundant-work budgets.
local negatives={}
for _,preset in ipairs({'miniAssault','raceCar','megaMech'}) do
    local row=profile[preset]
    Check(row.aiLife.before.list==2000 and row.aiLife.after.list==0,'old/new life work '..preset)
    Check(row.completeRepair.before.graph==30 and row.completeRepair.after.graph==0,'old/new repair work '..preset)
    negatives[#negatives+1]={preset=preset,oldLifeRejected=row.aiLife.before.list>0,
        oldFullRepairRejected=row.completeRepair.before.graph>0}
end
-- Catch deliberate incorrect core selection and stale budget in the same real reads.
local m=BP.New();m:Add({type='core',pos={0,0,0},rot=0});m:Add({type='core',pos={8,0,0},rot=0})
local u=Make(Unit,m);u.hp[1]=11;u.hp[2]=99
Check(u:Core().hp==11,'lowest live core before deletion');m:Remove(1);u.hp[1]=nil
Check(u:Core().hp==99,'lowest live core after deletion');local oldBudget=u:Budget()
m:Add({type='cube',pos={15,0,0},rot=0});Check(u:Budget()==oldBudget+Defs.cube.budget,'no stale budget on add')
return {ok=true,assertions=assertions,arenaCases=#cases,repairCases=repairCases,profile=profile,negativeControls=negatives}
''')
report = plain(result)
report['result'] = 'PASS' if report['ok'] else 'FAIL'
report['testInputs'] = {'tools/migration/check-car-unit-read-work.py': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
report['boundary'] = 'Actual production Lua methods and Blueprint/prefabs, JSON adapter, Lua 5.4 CPU only. os.clock timings are not Web/GPU/FPS evidence; nested timing is not additive.'
report['before'] = {'commit': '48ef15f2', 'sha256': hashlib.sha256(before.encode('utf-8')).hexdigest()}
report['production'] = {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()}
baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8-sig'))
source_relative = 'shared/combat/carUnit.js'
source_path = Path(baseline['snapshot']) / source_relative
source_data = source_path.read_bytes()
assert hashlib.sha256(source_data).hexdigest() == baseline['files'][source_relative]['sha256']
source_text = source_data.decode('utf-8')
assert 'for ( const p of this.bp.parts.values() ) b += PARTS[ p.type ].budget;' in source_text
report['source'] = {'commit': baseline['commit'], 'branch': baseline['branch'], 'path': source_relative,
                    'sha256': hashlib.sha256(source_data).hexdigest()}
for resource in ['Parts/Catalog.json', 'Combat/Arena.json']:
    report.setdefault('resources', {})[resource] = hashlib.sha256((ROOT / 'assets' / resource).read_bytes()).hexdigest()
output = ROOT / 'docs/migration/evidence/car-unit-read-work-offline.json'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))

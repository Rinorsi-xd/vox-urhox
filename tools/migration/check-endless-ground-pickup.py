"""Compare actual frozen H5 and production Lua loot pickup, without a Runtime."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('D:/Rino_Project/Vox')
BASELINE = 'b276064942ae09c0227ec28d4cfda1d5ff006455'
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

cases = []
for kind in ['credits', 'part']:
    for name, death, ground, player, alive, expected in [
        ('airborne-death-ground-player', [12, 30, -9], 0, [12, .1, -9], True, True),
        ('airborne-death-airborne-player', [12, 30, -9], 0, [12, 30, -9], True, False),
        ('high-plateau', [-27, 60, 31], 22, [-27, 22.1, 31], True, True),
        ('below-ground', [12, -25, -9], 0, [12, .1, -9], True, True),
        ('dead-player', [12, 30, -9], 0, [12, .1, -9], False, False),
        ('exact-radius-x', [12, 30, -9], 0, [20, .1, -9], True, True),
        ('outside-radius-x', [12, 30, -9], 0, [20.001, .1, -9], True, False),
        ('exact-radius-y', [12, 30, -9], -.1, [12, 8, -9], True, True),
        ('outside-radius-y', [12, 30, -9], -.1, [12, 8.001, -9], True, False),
        ('exact-radius-z', [12, 30, -9], 0, [12, .1, -1], True, True),
        ('diagonal-outside', [12, 30, -9], 0, [18, .1, -3], True, False),
        ('root-not-bobbing-pivot', [12, 30, -9], 0, [12, -7.8, -9], True, True),
    ]:
        cases.append(dict(name=kind + ':' + name, kind=kind, death=death, ground=ground,
                          player=player, alive=alive, expected=expected))

js = r'''
const fs=require('node:fs'),cp=require('node:child_process'),assert=require('node:assert/strict');
const input=JSON.parse(fs.readFileSync(0,'utf8'));
const read=p=>cp.execFileSync('git',['-c','safe.directory='+input.source,'show',input.baseline+':'+p],{cwd:input.source,encoding:'utf8'});
class Vec {constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}toArray(){return[this.x,this.y,this.z]}clone(){return new Vec(this.x,this.y,this.z)}lerpVectors(a,b,k){return this.set(a.x+(b.x-a.x)*k,a.y+(b.y-a.y)*k,a.z+(b.z-a.z)*k)}}
class Group {constructor(){this.position=new Vec();this.rotation={};this.scale={setScalar:v=>this.scalar=v};this.children=[]}add(...v){this.children.push(...v)}removeFromParent(){this.removed=true}}
class Resource {dispose(){this.disposed=true}}
class Mesh extends Group {constructor(geometry,material){super();this.geometry=geometry;this.material=material}}
const THREE={Group,Mesh,Vector3:Vec,CylinderGeometry:Resource,MeshStandardMaterial:Resource,MeshBasicMaterial:Resource};
const config=input.config;
const originalLootSource=read('three/src/battle/endlessLoot.js');
const lootSource=originalLootSource.replace(/^import .*;\r?\n/gm,'').replace('export class EndlessLoot','class EndlessLoot');
const Loot=Function('THREE','ENDLESS',lootSource+'\nreturn EndlessLoot')(THREE,config);
const runSource=read('shared/battle/endless.js').replace(/^import .*;\r?\n/gm,'').replace(/export /g,'');
const Run=Function('ENDLESS','PARTS','isLimited',runSource+'\nreturn EndlessRun')(config,{laser1:{cat:'weapon'}},id=>id==='laser1');
const output=[];
for(const c of input.cases){
 const drop={id:'d',pos:c.death,...(c.kind==='credits'?{credits:37}:{type:'laser1'})};
 const run=Object.assign(Object.create(Run.prototype),{pendingDrops:new Map([['d',drop]]),credits:0,inventory:{},events:[],weaponDrought:3});
 const session={run,events(){},drive:{sim:{time:1},player:{pos:c.player,alive:c.alive},track:{W:{sample:()=>({h:c.ground})}},scene3:new Group()}};
 const loot=Object.assign(Object.create(Loot.prototype),{session,items:new Map(),supplies(){}});
 loot.addCoins(drop);loot.update();
 const item=loot.items.get('d'),collected=!run.pendingDrops.has('d');
 assert.equal(collected,c.expected,c.name);
 const result={name:c.name,collected,root:item.root.position.toArray(),credits:run.credits,inventory:{...run.inventory},events:run.events.map(e=>e.type)};
 if(!collected)run.pickupDrop('d','waveClear');
 loot.onEvent({type:'dropCollected',drop,reason:collected?'near':'waveClear'});
 const duration=collected?config.pickupDuration:config.clearPickupDuration;
 session.drive.sim.time=1+duration/2;session.drive.player.pos=[c.player[0]+6,c.player[1]+2,c.player[2]-3];loot.update();
 result.midRoot=item.root.position.toArray();result.midScale=item.root.scalar;
 session.drive.sim.time=1+duration+.001;session.drive.player.pos=[c.player[0]+9,c.player[1]+3,c.player[2]-4];loot.update();
 assert.equal(loot.items.size,0,c.name+' source absorption removed');result.finalRoot=item.root.position.toArray();
 output.push(result);
}
process.stdout.write(JSON.stringify({output,sourceSha256:require('node:crypto').createHash('sha256').update(originalLootSource).digest('hex')}));
'''
config = json.loads((ROOT / 'assets/Endless/Rules.json').read_text(encoding='utf-8'))['config']
source_process = subprocess.run(['node', '-e', js], input=json.dumps(dict(
    baseline=BASELINE, source=str(SOURCE), cases=cases, config=config)),
    text=True, capture_output=True)
assert source_process.returncode == 0, source_process.stderr
source = json.loads(source_process.stdout)

lua_tests = r'''
local checks={}
local function Check(ok,label)assert(ok,label);checks[#checks+1]=label end
local Vec={};Vec.__index=Vec
function Vector3(x,y,z)return setmetatable({x=x or 0,y=y or 0,z=z or 0},Vec)end
function Vec.__add(a,b)return Vector3(a.x+b.x,a.y+b.y,a.z+b.z)end
function Vec.__sub(a,b)return Vector3(a.x-b.x,a.y-b.y,a.z-b.z)end
function Vec.__mul(a,b)if type(a)=='number'then a,b=b,a end;return Vector3(a.x*b,a.y*b,a.z*b)end
Vector3= setmetatable({}, {__call=function(_,x,y,z)return setmetatable({x=x or 0,y=y or 0,z=z or 0},Vec)end})
Vector3.UP=Vector3(0,1,0)
function Quaternion()return{}end
function Variant(v)return v end
function Color(...)return{...}end
local function Node()
 local n={position=Vector3(),worldPosition=Vector3(),children={}}
 function n:CreateChild()local c=Node();self.children[#self.children+1]=c;return c end
 function n:SetScale(v)self.scale=v end
 function n:Dispose()self.disposed=true end
 return n
end
Material={new=function()return{SetTechnique=function()end,SetShaderParameter=function()end,Dispose=function(self)self.disposed=true end}end}
cache={GetResource=function()return{}end}
local geometry={mesh={Commit=function()end},Begin=function()end,Beam=function()end,Dispose=function(self)self.disposed=true end}
local data={config=config,roles={}}
package.loaded['render.ObjectiveView']={Geometry=function()return geometry end}
package.loaded['construction.Blueprint']={}
package.loaded['render.VehicleView']={}
package.loaded['endless.Coin']={Add=function()end}
package.loaded['parts.Defs']={PARTS={laser1={cat='weapon'}}}
package.loaded['core.Coord']={Vec=function(x,y,z)return Vector3(-x,y,z)end}
package.loaded['endless.Data']=data
package.loaded['endless.Inventory']={Limited=function(id)return id=='laser1'end}
package.loaded['endless.Random']={}
local Run=assert(load(runSource,'@scripts/endless/Run.lua'))()
local View=assert(load(viewSource,'@scripts/endless/View.lua'))()
local results={}
for i,c in ipairs(cases)do
 local drop={id='d',pos=c.death};if c.kind=='credits'then drop.credits=37 else drop.type='laser1'end
 local run=setmetatable({pendingDrops={d=drop},credits=0,inventory={},events={},weaponDrought=3},Run)
 local player={alive=c.alive,pos=c.player,Position=function(self)return self.pos end}
 local session={run=run,player=player,world={time=1,GroundAt=function()return{h=c.ground}end},entries={},session={environment={}}}
 local view=View.New(Node());view:Add({id='d',pos=c.death,credits=37});view.drops.d.drop=drop
 view:Update(session,1/60)
 local item=view.drops.d;local hit=run.pendingDrops.d==nil;local want=golden[i]
 Check(hit==want.collected,c.name..' source pickup parity')
 Check(item.root.position.x==-want.root[1]and item.root.position.y==want.root[2]and item.root.position.z==want.root[3],c.name..' source displayed root')
 Check(run.credits==want.credits and (run.inventory.laser1 or 0)==(want.inventory.laser1 or 0),c.name..' actual inventory result')
 Check(#run.events==#want.events,c.name..' exact event count')
 for j,e in ipairs(run.events)do Check(e.type==want.events[j],c.name..' event '..j)end
 if not hit then Check(run:PickupDrop('d','waveClear'),c.name..' actual clear-wave economy applies')end
 local credits=run.credits;local parts=run.inventory.laser1 or 0
 view:Event({type='dropCollected',drop=drop,reason=hit and 'near' or 'waveClear'})
 local duration=hit and config.pickupDuration or config.clearPickupDuration
 Check(item.duration==duration,c.name..' source absorption duration')
 session.world.time=1+duration/2;player.pos={c.player[1]+6,c.player[2]+2,c.player[3]-3};view:Update(session,1/60)
 local mid=item.root.position
 Check(math.abs(mid.x+want.midRoot[1])<1e-9 and math.abs(mid.y-want.midRoot[2])<1e-9 and math.abs(mid.z-want.midRoot[3])<1e-9,c.name..' absorption follows moving player exactly as source')
 Check(math.abs(item.root.scale-want.midScale)<1e-9,c.name..' source absorption scale')
 Check(run.credits==credits and (run.inventory.laser1 or 0)==parts,c.name..' no duplicate during absorption')
 session.world.time=1+duration+.001;player.pos={c.player[1]+9,c.player[2]+3,c.player[3]-4};view:Update(session,1/60)
 local final=item.root.position
 Check(math.abs(final.x+want.finalRoot[1])<1e-9 and math.abs(final.y-want.finalRoot[2])<1e-9 and math.abs(final.z-want.finalRoot[3])<1e-9,c.name..' absorption final tracks new pose including dead/clear path')
 Check(view.drops.d==nil and item.root.disposed,c.name..' completed absorption releases root')
 view:Dispose();Check(view.root==nil and next(view.drops)==nil,c.name..' disposed drop map released')
 results[#results+1]={name=c.name,collected=hit}
end
-- Run the actual session boundary: a visual pickup must drain its event in this step.
for _,name in ipairs({'parts.Dependencies','endless.Audio','drive.SpawnSpecCache','endless.SpawnPresentation','drive.VehicleSpec','combat.DriverActions','drive.RotorMotion','ui.EndlessBanner','endless.Records','render.NodeVisibility','combat.PlayerViewSync','combat.CarUnit','combat.EnemyDriver','combat.DrillRaiderDriver','combat.ShieldQuery','core.Math3'})do package.loaded[name]={}end
package.loaded['endless.View']=View;package.loaded['endless.Run']=Run
local Session=assert(load(sessionSource,'@scripts/app/EndlessSession.lua'))()
local calls={};local run={}
local s=setmetatable({entries={{}},player={alive=true},run=run,Events=function()calls[#calls+1]='events'end,view={Update=function()calls[#calls+1]='view'end}},Session)
s:AfterStep(1/60)
Check(table.concat(calls,',')=='events,view,events','Actual fixed-step boundary drains pickup after view')
-- Execute the exact Web suffix against the real View/Run/AfterStep methods.
-- Physics/native objects are bounded doubles; this only rejects broken QA tools.
local function Unit(pos)
 local u={pos=pos,alive=true,previous={},current={}}
 function u:Position()return self.pos end
 u.vehicle={body={translation=function()return{x=u.pos[1],y=u.pos[2],z=u.pos[3]}end,rotation=function()return{w=1,x=0,y=0,z=0}end,setTranslation=function(p)u.pos={p.x,p.y,p.z}end}}
 function u.vehicle:Place(p)u.pos={p[1],p[2],p[3]}end
 function u:SavePose()end
 function u:Damage(id,amount)Check(id=='core'and amount==1e9,'Web probe damages actual core contract');self.pendingDeath=true end
 function u:Flush()if self.pendingDeath then self.alive=false end end
 u.bp={CoreParts=function()return{{id='core'}}end,List=function()return{}end}
 return u
end
local p=Unit({0,.1,0});local enemy=Unit({100,0,0});enemy.endless={id='test',role='assault',tier=1,elite=false}
data.roles.assault={cost=2};package.loaded['endless.Inventory'].Credits=function()return 37 end;package.loaded['endless.Inventory'].Drops=function()return{}end
local r=setmetatable({state='combat',wave=1,alive={test=enemy.endless},queue={{id='later'}},kills={assault=0},score=0,events={},dropSerial=0,dropOrder={},pendingDrops={},credits=0,inventory={}},Run)
local e=setmetatable({run=r,player=p,entries={{unit=p},{unit=enemy}},world={time=1,units={p,enemy},GroundAt=function()return{h=0}end},session={environment={}},SyncPlayer=function()end},Session)
e.view=View.New(Node())
function e:Events()for _,event in ipairs(self.run:Drain())do self.view:Event(event)end end
app={mode='trial',loadingFlow={active=false},trial={endless=e},SelectEndless=function()end}
package.loaded['urhox-libs/UI']={GetViewportSize=function()return 1600,900 end,GetRoot=function()end,GetTopOverlay=function()end}
package.loaded['ui.GarageHud']={GetState=function()return{tab='hangar'}end}
local snapshots={};cjson={encode=function(t)if t.sequence then snapshots[#snapshots+1]=t end;return'{}'end,decode=function()return{}end}
local key=nil;KEY_F7='F7';KEY_F10='F10';KEY_F11='F11';input={GetKeyPress=function(_,k)return k==key end}
HandleUpdate=function()end;HandlePostUpdate=function()end
local printBefore=print;print=function()end
assert(load(probeSource,'@tools/migration/probe-endless-ground-pickup.lua'))()
for n=1,4 do key=KEY_F11;HandleUpdate();local snap=snapshots[#snapshots];Check(snap.stage==n,'Exact Web probe reaches stage '..n)
 if n==1 or n==2 then Check(snap.selected.pending and snap.run.credits==0,'Probe preserves uncollected wallet '..n)
 elseif n==3 then Check(not snap.selected.pending and snap.selected.collecting and snap.run.credits==37,'Probe uses actual pickup result')
 else Check(not snap.frozen,'Probe releases simulation')end
end
print=printBefore;e.world.time=2;e:AfterStep(0);Check(next(e.view.drops)==nil,'Probe drop naturally completes after release in bounded harness')
return checks,results
'''


def run(view_source):
    lua = LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value, dict): return lua.table_from({key: table(item) for key, item in value.items()})
        if isinstance(value, list): return lua.table_from([table(item) for item in value])
        return value
    for key, value in dict(config=config, cases=cases, golden=source['output']).items():
        lua.globals()[key] = table(value)
    lua.globals().viewSource = view_source
    lua.globals().runSource = (ROOT / 'scripts/endless/Run.lua').read_text(encoding='utf-8')
    lua.globals().sessionSource = (ROOT / 'scripts/app/EndlessSession.lua').read_text(encoding='utf-8')
    lua.globals().probeSource = (ROOT / 'tools/migration/probe-endless-ground-pickup.lua').read_text(encoding='utf-8')
    checks, results = lua.execute(lua_tests)
    return [checks[i] for i in range(1, len(checks) + 1)]


view_source = (ROOT / 'scripts/endless/View.lua').read_text(encoding='utf-8')
checks = run(view_source)
negatives = []
for old, new, label in [
    ('local at=item.root.position', 'local at=Coord.Vec(table.unpack(drop.pos))', 'airborne death pose instead of ground root'),
    ('p[1]+at.x', 'p[1]-at.x', 'incorrect engine X mirror'),
    ('p[2]-at.y', 'p[2]-at.y-item.pivot.position.y', 'bobbing pivot instead of root'),
    ('if session.player.alive then', 'if true then', 'dead player can pick up'),
]:
    assert view_source.count(old) == 1, old
    try: run(view_source.replace(old, new, 1))
    except Exception as error: negatives.append(dict(label=label, rejected=True, reason=str(error).splitlines()[0]))
    else: raise AssertionError('Negative unexpectedly passed: ' + label)

report = dict(result='PASS_OFFLINE_ONLY', baseline=BASELINE, source=source, checks=checks,
              negatives=negatives, hashes={p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
              for p in ['scripts/app/EndlessSession.lua', 'scripts/endless/View.lua']},
              boundary='Actual frozen H5 addCoins/update and EndlessRun pickup vs actual Lua View.Update/Run pickup; fake scene objects only. No Runtime, visual or FPS acceptance.')
output = ROOT / 'docs/migration/evidence/endless-ground-pickup-offline-2026-10-17.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(dict(result=report['result'], cases=len(cases), checks=len(checks), negatives=len(negatives), hashes=report['hashes'])))

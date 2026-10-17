"""Execute frozen 10/15 reactor methods and actual Lua rendering/hit routes."""
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

baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
assert baseline['commit'] == 'b276064942ae09c0227ec28d4cfda1d5ff006455'
source_files = ['three/src/battle/matchView.js', 'three/src/battle/matchSession.js']
for name in source_files:
    actual = (Path(baseline['snapshot']) / name).read_bytes()
    assert hashlib.sha256(actual).hexdigest() == baseline['files'][name]['sha256'], name

golden_program = r'''
const fs=require('fs'),vm=require('vm'),path=require('path');
const b=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const v=fs.readFileSync(path.join(b.snapshot,'three/src/battle/matchView.js'),'utf8');
const s=fs.readFileSync(path.join(b.snapshot,'three/src/battle/matchSession.js'),'utf8');
const lin=x=>(x/=255)<=.04045?x/12.92:((x+.055)/1.055)**2.4;
class Color{constructor(n){this.setHex(n)}setHex(n){this.rgb=[lin(n>>16&255),lin(n>>8&255),lin(n&255)];return this}lerp(c,a){this.rgb=this.rgb.map((v,i)=>v+(c.rgb[i]-v)*a);return this}}
const math=Object.create(Math);math.random=()=>.25;
const Reactor=vm.runInNewContext(v.slice(v.indexOf('export class Reactor'),v.indexOf('// 推车的运输车')).replace('export class','class')+';Reactor',
 {THREE:{Color},TEAM_HEX:{blue:0x2ea8ff,red:0xff4a3d},Math:math});
const Mode=vm.runInNewContext(s.slice(s.indexOf('class ConquestMode'),s.indexOf('class EscortMode'))+';ConquestMode',
 {other:t=>t==='blue'?'red':'blue',Math,sfx:{consumeDamage(){}},cameraListener:()=>({}),THREE:{Vector3:class{}}});
const visuals=[];
for(const team of ['blue','red'])for(const exposed of [false,true]){
 const r=Object.create(Reactor.prototype);Object.assign(r,{t:0,flash:0,team,exposed,center:[12,8,20],root:{rotation:{y:0},position:{x:12}},mat:{color:new Color(0)}});
 r.hit();const frames=[];
 for(const dt of [0,.01,.04,.016,.08,.03,.08,.02,.1]){r.update(dt);frames.push({dt,flash:r.flash,x:r.root.position.x,color:r.mat.color.rgb.slice()})}
 visuals.push({team,exposed,frames});
}
const routes=[];
for(const kind of ['hit','explode'])for(const shield of [false,true])for(const score of [0,20])for(const damage of [0,300])for(const near of [false,true]){
 let count=0,stolen=0;const m=Object.create(Mode.prototype);
 m.s={rules:{shield:{red:shield},steal(t,d){const got=shield?0:Math.min(score,d/150);stolen+=got;return got}},drive:{camera:{}}};
 m.base={red:{reactor:{hit(){count++},distance(){return near?0:10}}}};
 if(kind==='hit')m.hitSpecial({team:'blue'},{owner:{type:near?'reactor':'other',team:'red'},point:[0,0,0]},damage);
 else m.explodeSpecial({team:'blue'},[0,0,0],4,damage);
 routes.push({kind,shield,score,damage,near,count,stolen});
}
console.log(JSON.stringify({visuals,routes}));
'''
golden = json.loads(subprocess.check_output(['node', '-e', golden_program], cwd=ROOT, text=True))

fixture = r'''
local golden=...
package.path='scripts/?.lua;'..package.path
package.preload['render.ObjectiveView']=function()return assert(load(VIEW_SOURCE))()end
package.preload['combat.BattleObjectives']=function()return assert(load(OBJECTIVES_SOURCE))()end
local checks=0
local function Check(ok,label)assert(ok,label);checks=checks+1 end
local function Equal(a,b,label)Check(math.abs(a-b)<1e-10,label..': '..a..' != '..b)end
Vector3=setmetatable({UP={}},{__call=function(_,x,y,z)return {x=x,y=y,z=z}end})
function Color(r,g,b,a)return {r,g,b,a}end
function BoundingBox(a,b)return {min=a,max=b}end
TRIANGLE_LIST=0;OUTSIDE=0
Material={new=function()return {SetSurfaceShader=function()return true end,Dispose=function()end}end}
package.loaded['core.Coord']={Vec=function(x,y,z)return Vector3(-x,y,z)end}
local function Node()
 local node={position=Vector3(0,0,0)}
 function node:CreateChild()return Node()end
 function node:CreateComponent()
  local mesh={commits=0}
  function mesh:BeginGeometry()self.firstColor=nil end
  function mesh:DefineVertex()end
  function mesh:DefineNormal()end
  function mesh:DefineColor(v)self.firstColor=self.firstColor or v end
  function mesh:Commit()self.commits=self.commits+1 end
  return mesh
 end
 function node:Dispose()end
 return node
end
local View=require 'render.ObjectiveView'
local function New()
 local mode={id='conquest',points={},bases={blue={aim={12,8,20}},red={aim={12,8,20}}}}
 return View.New({scene=Node()},mode),{points={},score={blue=50,red=50},shield={blue=true,red=true}}
end
local oldRandom=math.random
math.random=function()error('visual effect consumed gameplay RNG')end
for _,row in ipairs(golden.visuals)do
 local view,rule=New();rule.shield[row.team]=not row.exposed
 view.ReactorRandom=function()return .25 end
 view:HitReactor(row.team)
 for _,frame in ipairs(row.frames)do
  local previous=view.batches['Reactor'..row.team]
  local commits=previous and previous.mesh.commits or 0
  view:Update(frame.dt,rule)
  local batch=view.batches['Reactor'..row.team]
  Equal(view.reactorFlash[row.team],frame.flash,'actual flash decay')
  Equal(batch.node.position.x,-frame.x,'mirrored source jitter')
  if batch.mesh.commits>commits then
   for j=1,3 do Equal(batch.mesh.firstColor[j],frame.color[j],'actual vertex color')end
  else Check(frame.flash==0,'active flash cannot skip rendering refresh')end
 end
end
local view,rule=New();view:Update(.001,rule)
local blue,red=view.batches.Reactorblue.mesh,view.batches.Reactorred.mesh
local a,b=blue.commits,red.commits
view:HitReactor('red');view:Update(.001,rule)
Check(blue.commits==a and red.commits==b+1,'immediate hit refresh affects only its batch')
Check(view.reactorFlash.red==.996,'one hit starts source strength once')
view:Update(.02,rule);view:HitReactor('red');view:Update(.01,rule)
Equal(view.reactorFlash.red,.96,'repeat hit resets instead of accumulating')
Check(view.reactorRandomState~=1,'private visual RNG advances')
view:Update(.3,rule);Equal(view.reactorFlash.red,0,'flash expires')
Equal(view.batches.Reactorred.node.position.x,-12,'expired jitter resets')
local clip=false
local camera={GetComponent=function()return {frustum={IsInsideFast=function()return clip and 1 or OUTSIDE end}}end}
view:HitReactor('red');local count=red.commits
view:Update(.1,rule,camera)
Check(red.commits==count and not red.enabled,'culled hit does not rebuild')
Equal(view.reactorFlash.red,.6,'culled flash still decays')
clip=true;view:Update(.001,rule,camera)
Check(red.enabled and red.commits==count+1,'returning reactor refreshes active flash')
math.random=oldRandom
for _,name in ipairs({'combat.EnemyDriver','construction.Blueprint','drive.VehicleSpec','render.VehicleView','parts.Defs'})do package.loaded[name]={}end
package.loaded['combat.ArenaData']={}
local Objectives=require 'combat.BattleObjectives'
for _,row in ipairs(golden.routes)do
 local count,stolen=0,0
 local rules={shield={red=row.shield},Steal=function(_,team,damage)
  local got=row.shield and 0 or math.min(row.score,damage/150);stolen=stolen+got;return got
 end}
 local obj=setmetatable({id='conquest',battle={rules=rules},bases={red={aim={0,0,0}}},view={HitReactor=function(_,team)
  Check(team=='red','correct victim reactor');count=count+1
 end}},Objectives)
 if row.kind=='hit'then obj:Hit({team='blue'},{point={0,0,0},owner={type=row.near and 'reactor' or 'other',team='red'}},row.damage)
 else obj:Explode({team='blue'},row.near and {0,0,0}or {14,0,0},4,row.damage)end
 Check(count==row.count,'actual source hit/explosion activation gate')
 Equal(stolen,row.stolen,'theft amount and call count unchanged')
end
-- Real rules drain score: the second hit/explosion cannot flash an empty reactor.
local Rules=require 'combat.ConquestRules'
local rules=Rules.New({prep=4},{steal=1,timeLimit=600,overtime=30})
rules.state='live';rules.shield.red=false;rules.score.red=3
local hits=0
local obj=setmetatable({id='conquest',battle={rules=rules},bases={red={aim={0,0,0}}},view={HitReactor=function()hits=hits+1 end}},Objectives)
obj:Hit({team='blue'},{owner={type='reactor',team='red'}},3)
obj:Hit({team='blue'},{owner={type='reactor',team='red'}},3)
obj:Explode({team='blue'},{0,0,0},4,30)
Check(hits==1 and rules.score.red==0,'depleted repeated hit/explosion does not flash')
rules.score.red=10;rules.shield.red=true
obj:Hit({team='blue'},{owner={type='reactor',team='red'}},3)
obj:Explode({team='blue'},{0,0,0},4,30)
Check(hits==1 and rules.score.red==10,'shield excludes ray and explosion feedback')
return {status='PASS',checks=checks,visualScenarios=#golden.visuals,routeScenarios=#golden.routes}
'''

view_source = (ROOT / 'scripts/render/ObjectiveView.lua').read_text(encoding='utf-8')
objectives_source = (ROOT / 'scripts/combat/BattleObjectives.lua').read_text(encoding='utf-8')
def run(view, objectives):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().VIEW_SOURCE = view
    lua.globals().OBJECTIVES_SOURCE = objectives
    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value
    return dict(lua.execute(fixture, convert(golden)))

result = run(view_source, objectives_source)
result['rejectedMutations'] = []
for label, original, replacement, target in [
    ('missing hit state', 'self.reactorFlash[team]=1', 'self.reactorFlash[team]=0', 'view'),
    ('missing decay', 'previous-dt*4', 'previous', 'view'),
    ('missing flash blend', 'math.max(flash,not rule.shield[team]', 'math.max(0,not rule.shield[team]', 'view'),
    ('flash despite zero steal', 'Steal(unit.team,damage)>0', 'Steal(unit.team,damage)>=0', 'objectives'),
]:
    source = view_source if target == 'view' else objectives_source
    assert original in source, label
    mutated = source.replace(original, replacement, 1)
    try:
        run(mutated if target == 'view' else view_source,
            mutated if target == 'objectives' else objectives_source)
    except Exception:
        result['rejectedMutations'].append(label)
    else:
        raise AssertionError('Mutation passed: ' + label)
result['sourceCommit'] = baseline['commit']
result['sourceFiles'] = {name: baseline['files'][name]['sha256'] for name in source_files}
result['files'] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in [
    'scripts/render/ObjectiveView.lua', 'scripts/combat/BattleObjectives.lua']}
result['boundary'] = 'Actual frozen JS methods and full Lua modules with rendering adapters; visual RNG isolated, not identical frames; no hardware, FPS or rendered-pixel acceptance.'
(ROOT / 'docs/migration/evidence/reactor-feedback-1015-offline.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print(json.dumps(result, indent=2))

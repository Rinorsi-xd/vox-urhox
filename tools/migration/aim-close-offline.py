"""Compare actual frozen H5 and Lua weapon algorithms; no engine or production writes."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source=json.loads(subprocess.check_output(['node',str(ROOT/'tools/migration/aim-close-source.mjs')],cwd=ROOT,text=True))
lua=LuaRuntime(unpack_returned_tuples=True)
def table(v):
    if isinstance(v,dict): return lua.table_from({k:table(x) for k,x in v.items()})
    if isinstance(v,list): return lua.table_from([table(x) for x in v])
    return v
resources={p:json.loads((ROOT/'assets'/p).read_text(encoding='utf-8')) for p in ['Combat/Weapons.json','Combat/Drills.json','Parts/Catalog.json']}
lua.globals().resources=table(resources)
lua.globals().fixture=table(source)
script="""
package.path='scripts/?.lua;'..package.path
package.preload['core.ResourceData']=function()return {Read=function(p)return assert(resources[p],p)end}end
-- These fixtures intentionally omit self-body turret ranges. No clearance method is invoked.
package.preload['construction.TurretRange']=function()return {PitchLimits=function()error('Unexpected clearance call')end}end
local W=require 'combat.WeaponSystem'
local V=require 'core.Math3'
local function same(a,b,path)
 if type(b)=='table' then for k,v in pairs(b)do same(a[k],v,path..'.'..k)end
 elseif type(b)=='number' then assert(math.abs(a-b)<1e-9,path..': '..tostring(a)..' != '..b)
 else assert(a==b,path..': '..tostring(a)..' != '..tostring(b))end
end
for _,c in ipairs(fixture.cases)do
 local ws=W.New(c.spec);local w=ws.groups[1].weapons[1]
 ws:Aim(w,1,c.state);local m=ws:Muzzle(w,c.state)
 local dir=V.Normalize(V.Sub(c.state.aim,m.pos))
 same({yaw=w.yaw,pitch=w.pitch,aimPitch=w.aimPitch,limited=w.limited,aligned=ws:Aligned(w),
   muzzle=m.pos,barrel=m.dir,shotDir=dir,backwards=V.Dot(dir,m.dir)<0},c.expected,c.name)
end
scopeResults={}
for _,c in ipairs(fixture.scope)do
 local seed=c.seed
 local ws=W.New(c.spec,function()seed=(seed*1664525+1013904223)&0xffffffff;return seed/4294967296 end)
 local w=ws.groups[1].weapons[1]
 ws.aimed=c.aimed;w.bloom=c.bloom;w.spin=1;w.spinRate=w.rate
 ws:Aim(w,1,c.state);local samples={}
 for i=1,12 do
  ws.energy=100;ws:Fire(w,c.state,{stats={shots=0}})
  local sample={bloom=w.bloom,vel=ws.projectiles[#ws.projectiles].vel};samples[#samples+1]=sample
  same(sample,c.expected[i],'ADS parity '..c.type..' aimed='..tostring(c.aimed)..' bloom='..c.bloom..' shot '..i)
 end
 scopeResults[#scopeResults+1]={aimed=c.aimed,samples=samples}
end
local Assist=require 'combat.AimAssist'
for _,c in ipairs(fixture.assist)do
 local q={x=0,y=0,z=0,w=1}
 local enemy={id='enemy',team='red',alive=true,pos={0,0,c.z},vehicle={body={
  translation=function()return{x=0,y=0,z=c.z}end,rotation=function()return q end,linvel=function()return{x=0,y=0,z=0}end}},
  bp={parts={[7]={id=7,_cells={{0,0,0}}}}}}
 local player={id='player',team='blue',alive=true,pos={0,0,0},vehicle={body={}}}
 local hit=c.hit and {dist=c.hit.dist,point=c.hit.point,owner={ref=enemy}}
 local result=Assist.Apply(c.origin,c.dir,hit,player,{player,enemy},function()
  if c.blocked then return{dist=1,point={0,1,-1},owner={type='ground'}}end
  return{dist=math.sqrt((c.z+2)^2+1.75^2),point={0,.25,c.z},owner={ref=enemy}}
 end,c.stats)
 local actual=result and{point=result.point,ref=result.ref.id,partId=result.partId,slow=result.slow}
 same(actual,c.expected,'assist z='..c.z..' direct='..tostring(c.direct)..' blocked='..tostring(c.blocked))
end
for _,name in ipairs({'ui.DriveFeedback','ui.CombatFeedbackMotion','ui.ReticleState','ui.ReticleTarget','ui.MatchFeedback',
 'urhox-libs/UI','core.Coord','ui.UnitMarkState','ui.PlayerDamageFeedback'})do
 package.preload[name]=function()return{}end
end
local Overlay=require 'ui.DriveOverlay'
for _,c in ipairs(fixture.markers)do
 local ref,other={},{}
 local pointing={limited=c.status=='limited'}
 local s={vehicle={body={}},view={view={root={position={x=0,y=0,z=0},rotation={x=0,y=0,z=0,w=1}}}},
  aimRef=ref,aimHit={owner={ref=c.soft and other or ref}},aimPoint={0,0,20},world={CastRay=function()
   return{dist=5,owner={ref=c.sameTarget and ref or other}}
  end},weapons={pointing=pointing,Muzzle=function()return{pos={0,0,0},dir={0,0,1}}end,Aligned=function()return c.status=='aligned'end}}
 local actual=Overlay.AimMarker({session=s,aim={},Project=function()return 10,10 end})
 same(actual,c.expected,'aim marker soft='..tostring(c.soft)..' sameTarget='..tostring(c.sameTarget)..' status='..c.status)
end
package.preload['controls.TouchPreferences']=function()return{Get=function()return{assist=true}end}end
local DriveAim=require 'controls.DriveAim'
for _,c in ipairs(fixture.look)do
 local s={touch=true,app={},scope=false,assist={point=c.point,slow=.6},yaw=-math.deg(c.yaw),pitch=-math.deg(c.pitch),
  camera={GetNode=function()return{worldPosition={x=-c.camera[1],y=c.camera[2],z=c.camera[3]}}end}}
 DriveAim.Look(s,c.dt)
 same({yaw=-math.rad(s.yaw),pitch=-math.rad(s.pitch)},c.expected,'camera pull mirror coordinates')
end
"""
lua.execute(script)
def plain(t):
    if not hasattr(t,'items'):return t
    keys=list(t.keys())
    if all(isinstance(k,(int,float)) for k in keys):return [plain(t[i]) for i in range(1,len(keys)+1)]
    return {k:plain(v) for k,v in t.items()}
source['luaScope']=plain(lua.globals().scopeResults)
source['checks']={'nearAimCases':len(source['cases']),'nearAimAllMatch':True,
 'scopeCases':len(source['scope']),'scopeShots':len(source['scope'])*12,'scopeAllMatch':True,'assistCases':len(source['assist']),'assistAllMatch':True,
 'markerCases':len(source['markers']),'markerAllMatch':True,'cameraPullCases':len(source['look']),'cameraPullAllMatch':True}
original=(ROOT/'scripts/combat/WeaponSystem.lua').read_text(encoding='utf-8')
negatives=[]
for old,new in [('*(self.aimed and .45 or 1)',''),('(self.aimed and .6 or 1)/(s.rate*s.bloomTime)','1/(s.rate*s.bloomTime)')]:
    assert original.count(old)==1
    lua.execute("package.loaded['combat.WeaponSystem']=nil")
    lua.globals().negativeSource=original.replace(old,new,1)
    lua.execute("package.preload['combat.WeaponSystem']=assert(load(negativeSource,'@ADS-negative'))")
    try:lua.execute(script)
    except Exception as error:
        assert 'ADS parity' in str(error),str(error)
        negatives.append({'mutation':old,'rejected':True,'reason':str(error).splitlines()[0]})
    else:raise AssertionError('ADS negative unexpectedly passed')
lua.globals().negativeSource=original
lua.execute("package.loaded['combat.WeaponSystem']=nil;package.preload['combat.WeaponSystem']=assert(load(negativeSource,'@restored-weapon'))")
overlay=(ROOT/'scripts/ui/DriveOverlay.lua').read_text(encoding='utf-8')
old='s.aimRef and hit.owner and hit.owner.ref==s.aimRef'
new='s.aimHit and hit.owner and s.aimHit.owner and hit.owner.ref==s.aimHit.owner.ref'
assert overlay.count(old)==1
lua.globals().negativeSource=overlay.replace(old,new,1)
lua.execute("package.loaded['ui.DriveOverlay']=nil;package.preload['ui.DriveOverlay']=assert(load(negativeSource,'@marker-negative'))")
try:lua.execute(script)
except Exception as error:
    assert 'aim marker soft=true' in str(error),str(error)
    negatives.append({'mutation':old,'rejected':True,'reason':str(error).splitlines()[0]})
else:raise AssertionError('Marker negative unexpectedly passed')
source['behaviorNegatives']=negatives
source['productionHashes']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['scripts/combat/WeaponSystem.lua','scripts/ui/DriveOverlay.lua','scripts/combat/AimAssist.lua','scripts/controls/DriveAim.lua']}
out=ROOT/'docs/migration/evidence/aim-close-offline-2026-10-17.json'
out.write_text(json.dumps(source,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checks':source['checks'],'behaviorNegatives':negatives,
 'examples':[{'name':c['name'],'pivot':c['spec']['weapons'][0]['pivot'],'target':c['state']['aim'],**c['expected']} for c in source['cases'] if c['name'] in ['laser3-height3-foot1','laser3-height3-foot5','laser3-height3-foot10','laser3-height0-foot1']],
 'evidence':str(out)},indent=2))

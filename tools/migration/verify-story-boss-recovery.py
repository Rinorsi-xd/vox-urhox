"""Actual frozen ending control versus production Lua; no native/GPU claims."""
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-recovery-source.mjs'],text=True,encoding='utf-8'))
data=json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8-sig'))
legacy=ROOT/'.tmp/outgame-cached-1792118750001/scripts/combat/StoryBoss.lua'


def runner(code):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value,dict):return lua.table_from({k:table(v) for k,v in value.items()})
        if isinstance(value,list):return lua.table_from([table(v) for v in value])
        return value
    lua.globals().BossCode=code;lua.globals().BossData=table(data)
    run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'combat.CarUnit','combat.EnemyDriver','core.Coord','audio.StoryRadio'})do package.preload[name]=function()return {}end end
package.preload['core.Coord']=function()return {Vec=function(x,y,z)return {x=-x,y=y,z=z}end}end
Vector3={UP={0,1,0}}
package.preload['core.ResourceData']=function()return {Read=function()return BossData end}end
local Boss=assert(load(BossCode))();local Rules=require 'story.BossRules'
return function(kind,c)
 local rays={};local snaps={};local says={};local self
 local unit={pos={12,4,-18},Position=function(s)return s.pos end}
 local world={CastRay=function(_,origin,direction,length,exclude)
  local i=#rays;rays[#rays+1]={origin=origin,direction=direction,length=length,exclude=exclude}
  if c.collision then
   if c.collision=='none' then return nil end
   return {dist=4,owner={ref=c.collision=='self' and unit or nil}}
  end
  if c.type=='empty' then return nil end
  if c.type=='self' then return {dist=i==3 and 2 or 10,owner={ref=unit}} end
  return {dist=c.type=='wall' and (i==7 and 45 or 5) or 10+i*.1,owner={}}
 end}
 self=setmetatable({unit=unit,world=world,time=10,step=BossData.level.steps[2],
  rules=Rules.New(BossData.boss,150),mission={player={vehicle={body='player'}},voice={Talking=function()return false end}},
  view={Update=function()end},radio={Play=function()end},Ground=function(_,x,z)return 2+x*.01+z*.02 end,
  Fx=function()end,Banner=function()end,Capture=function(_,key,delay)snaps[#snaps+1]={key,delay}end,
  Say=function(_,key)says[#says+1]=BossData.level.steps[2].lines[key]end}, {__index=Boss})
 if kind=='open' then return {angle=self.OpenDir and self:OpenDir(48),rays=rays}end
 if kind=='camera' then
  local root={worldPosition={x=20,y=15,z=35},LookAt=function(s,at)s.target={-at.x,at.y,at.z}end}
  local camera={GetNode=function()return root end};self.session={camera={GetCamera=function()return camera end}};self.cinematic=true
  local frames={}
  for _,frame in ipairs(c.frames)do
   self.CinematicShot=function()return frame.shot.eye,frame.shot.target,frame.shot.blend end
   self:AfterCamera(.016);local p=root.worldPosition
   frames[#frames+1]={shot=frame.shot,eye={-p.x,p.y,p.z},target=root.target}
  end
  return {frames=frames,rays=rays}
 end
 unit.pos={10,4,-20};self.Cockpit=function()return {10,10,-20}end
 if kind=='recovery' then
  self.flow={stage='ending',t=20,open=c.angle,pod={},truck={t=c.time,from=c.from,to=c.to}}
  if not self.RecoveryPose or not self.CinematicShot then return {}end
  local pos,yaw,speed=self:RecoveryPose();local eye,target,blend=self:CinematicShot()
  return {pose={pos,yaw,speed,1},shot={eye=eye,target=target,blend=blend}}
 end
 if kind=='transition' then
  self.Ground=function()return 2 end;self.flow={stage='ending',t=6,open=.7}
  if c.stage~='pod-spawn' then self.flow.pod={from={10,10,-20},t=c.stage=='pod-line' and 1.21 or 7.01}end
  self:Update(0)
  local truck=self.flow.truck
  return {snaps=snaps,says=says,truck=truck and {from=truck.from,to=truck.to,t=truck.t} or false}
 end
 if kind=='cue' then
  self.mission.rules={stats={}};self.rules.events={}
  if c.kind=='ult-start' then self.rules.events={{type='state',state='ult'}}
  else self.rules.events={{type='kneel',kneels=c.kind=='kneel-first' and 1 or 2}}end
  self:Events();return {cues=snaps}
 end
end
''')
    return table,run


def plain(value):
    if hasattr(value,'items'):
        values=dict(value)
        if not values:return []
        if all(isinstance(key,int) for key in values):return [plain(values[key]) for key in range(1,len(values)+1)]
        return {key:plain(item) for key,item in values.items()}
    return value


def equal(left,right):
    if isinstance(left,(float,int)) and isinstance(right,(float,int)):return math.isclose(left,right,rel_tol=1e-10,abs_tol=1e-10)
    if isinstance(left,list) and isinstance(right,list):return len(left)==len(right) and all(equal(a,b) for a,b in zip(left,right))
    if isinstance(left,dict) and isinstance(right,dict):return left.keys()==right.keys() and all(equal(left[k],right[k]) for k in left)
    return left==right


def mismatches(code):
    table,run=runner(code);failures=[];checks=0
    for kind,group,keys in [('open','openCases',['angle','rays']),('recovery','recoveryCases',['pose','shot']),('transition','transitions',['snaps','says','truck']),('cue','captureCues',['cues']),('camera','cameraCases',['frames','rays'])]:
        for case in reference[group]:
            try:actual=plain(run(kind,table(case)))
            except Exception as error:
                failures.append({'kind':kind,'error':str(error)[:100]});continue
            for key in keys:
                checks+=1;expected=case.get(key)
                if expected is None and key=='truck':expected=False
                if not equal(actual.get(key) if isinstance(actual,dict) else None,expected):failures.append({'kind':kind,'case':case.get('type',case.get('time',case.get('stage',case.get('kind')))),'key':key})
    return checks,failures


path='scripts/combat/StoryBoss.lua';code=(ROOT/path).read_text(encoding='utf-8-sig')
checks,failures=mismatches(code);assert not failures,failures
negative={
 'frozen-before-recovery':mismatches(legacy.read_text(encoding='utf-8-sig'))[1],
 'six-second-truck':mismatches(code.replace('truck.t/8','truck.t/6'))[1],
 'linear-truck':mismatches(code.replace('local eased=k*k*(3-2*k)','local eased=k'))[1],
 'missing-pod-capture':mismatches(code.replace(";self:Capture('pod',.2)",''))[1],
 'premature-kneel-capture':mismatches(code.replace("self:Capture('kneel1',1.6)","self:Capture('kneel1',.6)"))[1],
 'missing-camera-target-smoothing':mismatches(code.replace('V.Mix(self.cineAt or at,at,blend)','at'))[1],
}
assert all(negative.values()),negative
paths=['scripts/combat/StoryBoss.lua','scripts/render/BossView.lua','scripts/render/BossSceneCapture.lua']
sha=lambda p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
report={'result':'PASS','checks':checks,'source':reference['source'],'productionHashes':{p:sha(p) for p in paths},
 'inputs':{p:sha(p) for p in ['tools/migration/story-boss-recovery-source.mjs','tools/migration/verify-story-boss-recovery.py']},
 'negativeControls':negative,'boundary':'Actual frozen openDir, BOSS_KIND.update, FoxBoss._kneel/_startUlt; actual Lua selected direction, ending state transitions, truck pose, camera shot and cue dispatch. UI/physics/native geometry are adapters. BossView rendering, native camera smoothing, GPU capture pixels and all natural S5 playback remain unverified.'}
(ROOT/'docs/migration/evidence/story-boss-recovery-offline.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({**report,'negativeControls':{key:len(value) for key,value in negative.items()}},indent=2))

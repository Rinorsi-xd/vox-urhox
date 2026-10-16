"""Actual H5 ending updates versus actual Lua BossView.Update and glow submissions."""
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
reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-pod-motion-source.mjs'],text=True,encoding='utf-8'))
data=json.loads((ROOT/'assets/Story/Boss/View.json').read_text(encoding='utf-8-sig'))
legacy=ROOT/'.tmp/outgame-cached-1792123715225/scripts/render/BossView.lua'
current=ROOT/'scripts/render/BossView.lua'
assert hashlib.sha256(legacy.read_bytes()).hexdigest()=='3a7ee634941773c1596c414727edde1989ddb2d82b90baf1a483d385033037a8'

def runner(code):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(v):
        if isinstance(v,dict):return lua.table_from({k:table(x) for k,x in v.items()})
        if isinstance(v,list):return lua.table_from([table(x) for x in v])
        return v
    lua.globals().ViewCode=code;lua.globals().Data=table(data)
    run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local vector={};vector.__index=vector
local function vec(x,y,z)return setmetatable({x=x,y=y,z=z},vector)end
Vector3=setmetatable({RIGHT=vec(1,0,0),UP=vec(0,1,0),FORWARD=vec(0,0,1)},{__call=function(_,...)return vec(...)end})
local quaternion={};quaternion.__index=quaternion
local function q(w,x,y,z)return setmetatable({w=w,x=x,y=y,z=z},quaternion)end
function quaternion.__mul(a,b)
 if b.w then return q(a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w)end
 local u=q(0,b.x,b.y,b.z);local out=a*u*q(a.w,-a.x,-a.y,-a.z);return vec(out.x,out.y,out.z)
end
Quaternion=setmetatable({IDENTITY=q(1,0,0,0)},{__call=function(_,a,b,c,d)
 if type(b)=='table' then local s=math.sin(math.rad(a)/2);return q(math.cos(math.rad(a)/2),b.x*s,b.y*s,b.z*s)end
 return q(a,b,c,d)
end})
local Node={}
local function node(parent)return setmetatable({parent=parent,position=vec(0,0,0),rotation=q(1,0,0,0),scale=vec(1,1,1),enabled=true,children={}},Node)end
function Node.__index(n,key)
 if key=='worldScale' then local p=n.parent and n.parent.worldScale or vec(1,1,1);return vec(n.scale.x*p.x,n.scale.y*p.y,n.scale.z*p.z)end
 if key=='worldRotation' then return n.parent and n.parent.worldRotation*n.rotation or n.rotation end
 if key=='worldPosition' then
  if not n.parent then return n.position end
  local s=n.parent.worldScale;local v=n.parent.worldRotation*vec(n.position.x*s.x,n.position.y*s.y,n.position.z*s.z);local p=n.parent.worldPosition
  return vec(p.x+v.x,p.y+v.y,p.z+v.z)
 end
 return Node[key]
end
function Node:CreateChild()local child=node(self);self.children[#self.children+1]=child;return child end
function Node:CreateComponent()return {}end
function Node:Dispose()end
local function visible(n,v)n.enabled=v;for _,child in ipairs(n.children)do visible(child,v)end end
package.preload['render.NodeVisibility']=function()return {Set=visible}end
package.preload['core.Coord']=function()return {Vec=function(x,y,z)return vec(-x,y,z)end}end
package.preload['core.ResourceData']=function()return {Read=function()return Data end}end
package.preload['Config']=function()return {HexLinear=function()return {r=1,g=1,b=1}end}end
local discs={}
package.preload['render.EffectBatch']=function()return {New=function()return {Begin=function()end,Finish=function()end,Disc=function(_,p,size)discs[#discs+1]={position=p,size=size}end}end}end
package.preload['render.MissionView']=function()return {New=function()return {HideBeacon=function()end,AlarmOff=function()end,Truck=function()end,Update=function()end}end}end
Material={new=function()return {SetSurfaceShader=function()return true end,SetShaderParameter=function()end}end}
cache={GetResource=function()return {}end};Variant=function(v)return v end
local View=assert(load(ViewCode))()
return function(test,expected)
 local camera={node={worldPosition=vec(0,0,0),worldRotation=q(1,0,0,0)},fov=60}
 local rules={state='dying',t=0,time=100,hp=0,nodes={},config={ult={lift=9},chip={.45,.55,.65,.75,1},lanes={n=6}},Braced=function()return false end,Broken=function()return 0 end}
 local boss={rules=rules,time=0,tails={},missiles={},flow={},session={camera={GetCamera=function()return camera end},combatView={units={}}},
  Nodes=function()end,Cockpit=function()return {0,0,0}end,mission={rules={}},RecoveryPose=function()return {0,0,0},0,0 end}
 local view=View.New(node(),boss);local frames={}
 if test.rig then
  local rig=view:Rig(Data[test.rig]);local root=rig.root;root.position=vec(-12,-2,34)
  root.rotation=Quaternion(math.deg(.3),Vector3.RIGHT)*Quaternion(-math.deg(-.8),Vector3.UP)*Quaternion(-math.deg(.5),Vector3.FORWARD)
  local size=root.scale;root.scale=vec(size.x*test.scale,size.y*test.scale,size.z*test.scale)
  for _,g in ipairs(rig.glows)do local s=g.node.scale;g.node.scale=vec(s.x*test.childScale,s.y*test.childScale,s.z*test.childScale)end
  discs={};view:Glows(rig,{1,0,0},{0,1,0});return discs
 end
 for i,op in ipairs(test.ops)do
  local state=expected[i];discs={};math.random=function()return op.random end
  boss.flow.pod=state.pod;boss.flow.truck=state.truck and {} or nil
  -- Keep the same pod identity between frames, as StoryBoss does.
  if state.pod then view.testPod=view.testPod or {from=state.pod.from};view.testPod.t=state.pod.t;boss.flow.pod=view.testPod end
  view:Update(op.dt)
  local frame={visible=view.pod.root.enabled,discs=discs}
  if frame.visible then local n=view.pod.root;local p=n.position;local r=n.rotation
   frame.position={-p.x,p.y,p.z};frame.quaternion={r.x,-r.y,-r.z,r.w}
  end
  frames[#frames+1]=frame
 end
 return frames
end
''')
    return lambda case:run(table(case['test']),table(case['expected']))

currentRun=runner(current.read_text(encoding='utf-8-sig'))
legacyRun=runner(legacy.read_text(encoding='utf-8-sig'))
checks=0;frames=0;negative=[]
def close(a,b):return abs(a-b)<1e-8
def equal_vector(a,b):return all(close(a[i+1],v) for i,v in enumerate(b))
for case in reference['cases']:
    actual=currentRun(case);old=legacyRun(case);different=0
    for index,wanted in enumerate(case['expected'],1):
        result=actual[index];before=old[index]
        assert result['visible']==wanted['visible'],(case['test']['name'],index,'visibility')
        checks+=1
        if wanted['visible']:
            assert equal_vector(result['position'],wanted['position']),(index,'position')
            assert equal_vector(result['quaternion'],wanted['quaternion']),(index,'rotation')
            assert len(result['discs'])==1,(index,'one visible flame')
            assert equal_vector(result['discs'][1]['position'],wanted['flamePosition']),(index,'flame position')
            assert close(result['discs'][1]['size'],wanted['flameSize']),(index,'flame size',result['discs'][1]['size'],wanted['flameSize'])
            checks+=5
            if not equal_vector(before['quaternion'],wanted['quaternion']) or not close(before['discs'][1]['size'],wanted['flameSize']):different+=1
        else:
            assert len(result['discs'])==0,(index,'hidden flame must not submit')
            checks+=1
        frames+=1
    assert different>0,'Legacy must reproduce actual missing animation'
    negative.append({'name':case['test']['name'],'differentFrames':different})
for control in reference['controls']:
    actual=currentRun(control)
    assert len(actual)==len(control['expected'])
    checks+=1
    for index,wanted in enumerate(control['expected'],1):
        assert equal_vector(actual[index]['position'],wanted['position']),(control['test'],'shared glow position')
        assert close(actual[index]['size'],wanted['size']),(control['test'],'shared glow size')
        checks+=2
digest=lambda p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
tools=['tools/migration/story-boss-pod-motion-source.mjs','tools/migration/verify-story-boss-pod-motion.py']
report={'result':'PASS','checks':checks,'cases':len(reference['cases']),'frames':frames,'sharedGlowControls':len(reference['controls']),'source':reference['source'],
 'production':{p:digest(p) for p in ['scripts/render/BossView.lua','assets/Story/Boss/View.json']},'tools':{p:digest(p) for p in tools},
 'negativeControl':{'path':str(legacy.relative_to(ROOT)),'sha256':hashlib.sha256(legacy.read_bytes()).hexdigest(),'cases':negative},
 'boundary':'Actual complete frozen H5 BOSS_KIND.update with real Three.js pod mesh, Euler/quaternion and sprite world transforms versus actual complete Lua BossView.New/Update/Glows. Native nodes/quaternions/materials/batches are CPU math adapters. Compares root pose, reflected XYZ quaternion, flame world position/absolute size and no draw after recovery truck. No GPU, natural S5 win, visible/audible fidelity or performance acceptance.'}
output=ROOT/'docs/migration/evidence/story-boss-pod-motion-offline.json'
output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':report['result'],'checks':checks,'cases':len(reference['cases']),'frames':frames,'negative':negative}))

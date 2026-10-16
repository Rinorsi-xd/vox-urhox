"""Frozen H5 draw rules and real Lua mesh output; no renderer acceptance."""
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
reference=json.loads(subprocess.check_output(['node','tools/migration/aim-lines-render-source.mjs'],encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
rules=lua.eval("require('render.AimLinesRules')")[0]
checks=0
def near(a,b,label):
    global checks
    assert math.isclose(a,b,rel_tol=2e-12,abs_tol=2e-12),(label,a,b)
    checks+=1
def table(v):
    return lua.table_from({k:table(x) for k,x in v.items()}) if isinstance(v,dict) else lua.table_from([table(x) for x in v]) if isinstance(v,list) else v
for c in reference['cases']:
    style=rules.Style(table(c['pos']),table(c['camera']),c['enemy'],c['k'],c['wind'],c['time'])
    for k in ['width','opacity','glowSize','glowOpacity']:
        near(style[k],c['expected'][k],k)
    for i,v in enumerate(c['expected']['color'],1):
        near(style['color'][i],v,'actual THREE.Color linear RGB')

fixture=lua.execute('''
local function Vec(x,y,z)return {x=x,y=y,z=z}end
Vector3=setmetatable({RIGHT=Vec(1,0,0),UP=Vec(0,1,0),FORWARD=Vec(0,0,1)},{__call=function(_,...)return Vec(...)end})
Vector2=function(x,y)return {x=x,y=y}end
Color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end
TRIANGLE_LIST=1
package.loaded['core.Coord']={Vec=function(x,y,z)return Vec(-x,y,z)end}
Material={new=function()return {SetSurfaceShader=function()return true end,Dispose=function(self)self.disposed=true end}end}
package.loaded['render.EffectBatch']={New=function()
 return {mesh={},discs={},Begin=function(self)self.discs={}end,
 Disc=function(self,pos,size,color,alpha,right,up,thick,profile)self.discs[#self.discs+1]={pos=pos,size=size,color=color,alpha=alpha,profile=profile}end,
 Finish=function()end,Dispose=function(self)self.disposed=true end}
end}
local Node={};Node.__index=Node
function Node:CreateChild()return setmetatable({},Node)end
function Node:CreateComponent()
 local mesh={vertices={}}
 function mesh:BeginGeometry()self.vertices={}end
 function mesh:DefineVertex(p)self.vertices[#self.vertices+1]={position=p}end
 function mesh:DefineColor(c)self.vertices[#self.vertices].color=c end
 function mesh:DefineTexCoord(uv)self.vertices[#self.vertices].uv=uv end
 function mesh:Commit()self.committed=true end
 return mesh
end
function Node:Dispose()self.disposed=true end
local camera={fov=60,nearClip=.1,node={worldPosition=Vec(0,0,0),worldRotation=setmetatable({},{__mul=function(_,v)return v end})}}
function camera:GetNode()return self.node end
local M=require 'render.AimLines'
return function(dpr,height)
 graphics={GetHeight=function()return height end,GetDPR=function()return dpr end}
 local instance=M.New(setmetatable({},Node));instance:Update({},nil,function()error('empty scan must not raycast')end,camera,0)
 return instance,camera
end
''')
for dpr in [1,1.5,2,3,4]:
    for css_height in [378,600,1080]:
        instance,camera=fixture(dpr,css_height*dpr)
        near(instance['height'],css_height,'CSS pixel denominator')
        for wind in [0,.5,1]:
            instance.Draw(instance,table([3,2,100]),table([0,0,1]),table({'point':[3,2,150]}),50,True,.75,wind,table([0,0,0]),.123)
            verts=instance['mesh']['vertices'];a,b=verts[len(verts)-5],verts[len(verts)-4]
            width=math.sqrt(sum((a['position'][k]-b['position'][k])**2 for k in ['x','y','z']))
            projected=width/(100*2*math.tan(math.pi/6))*css_height
            near(projected,2+wind*2,'real mesh projected CSS width')
            discs=instance['glow']['discs']
            assert discs[len(discs)]['profile']==2,'muzzle uses original crossbar profile'
            checks+=1
        instance.Hide(instance)
        assert not instance['mesh']['enabled'] and not instance['glow']['mesh']['enabled']
        checks+=1
        instance.Dispose(instance)
        assert instance['root']['disposed'] and instance['glow']['disposed'] and instance['material']['disposed']
        checks+=1

shader=(ROOT/'assets/Shaders/BLGL/Combat/Glow.shader').read_text()
assert 'depth_test_disabled' not in shader and 'depth_draw_never' in shader
assert reference['gradients'][0][2]==[.45,'rgba(255,255,255,.22)']
assert reference['rects'][-1]==[0,61,128,6]
checks+=3
warmup_output=[]
warmup_lua=LuaRuntime(unpack_returned_tuples=True)
warmup_lua.globals()['print']=lambda *args:warmup_output.append(' '.join(map(str,args)))
warmup_lua.execute((ROOT/'tools/migration/check-combat-warmup.lua').read_text(encoding='utf-8'))
assert warmup_output[-1].startswith('CombatWarmup offline lifecycle: 59 scenarios PASS')
files=['scripts/render/AimLines.lua','scripts/render/AimLinesRules.lua','scripts/render/CombatWarmup.lua',
       'scripts/render/EffectBatch.lua','scripts/render/WarmupSignature.lua','assets/Shaders/BLGL/Combat/Glow.shader']
report={'result':'PASS','checks':checks,'sourceCases':len(reference['cases']),'baseline':reference['baseline'],
        'warmupLifecycle':{'scenarios':59,'result':'PASS','tool':'tools/migration/check-combat-warmup.lua'},
        'sourceHashes':reference['source'],'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in files},
        'boundary':'Actual frozen H5 _draw/THREE.Color and actual Lua draw geometry with native API doubles. Shader source contract only; Web shader compilation, occlusion pixels and visual parity require rendered verification.'}
(ROOT/'docs/migration/evidence/aim-lines-render-offline.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))

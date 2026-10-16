"""Small actual-geometry controls for offscreen objective work and re-entry."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

production = (ROOT / 'scripts/render/ObjectiveView.lua').read_text(encoding='utf-8')
fixture = r'''
package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(ok,label)assert(ok,label);checks=checks+1 end
Vector3=setmetatable({UP={x=0,y=1,z=0}},{__call=function(_,x,y,z)return {x=x,y=y,z=z}end})
function Color(r,g,b,a)return {r=r,g=g,b=b,a=a}end
function BoundingBox(lo,hi)
 Check(lo.x<=hi.x and lo.y<=hi.y and lo.z<=hi.z,'ordered native bounds')
 return {min=lo,max=hi}
end
TRIANGLE_LIST=0;OUTSIDE=0
Material={new=function()return {SetSurfaceShader=function(self,path)self.shader=path;return true end,Dispose=function()end}end}
package.preload['core.Coord']=function()return {Vec=function(x,y,z)return Vector3(-x,y,z)end}end
package.preload['render.ObjectiveView']=function()return assert(load(PRODUCTION))()end
local builds=0
local function Node()
 local node={position=Vector3(0,0,0)}
 function node:CreateChild()return Node()end
 function node:CreateComponent()
  local mesh={vertices={},commits=0}
  function mesh:BeginGeometry()builds=builds+1;self.vertices={}end
  function mesh:DefineVertex(v)self.vertices[#self.vertices+1]=v end
  function mesh:DefineColor(v)self.lastColor=v end
  function mesh:DefineNormal()end
  function mesh:Commit()self.commits=self.commits+1 end
  return mesh
 end
 function node:Dispose()end
 return node
end
local clip,seen=nil,{}
local frustum={IsInsideFast=function(_,box)
 seen[#seen+1]=box
 if not clip then return OUTSIDE end
 for _,axis in ipairs({'x','y','z'})do
  if box.max[axis]<clip.min[axis]or box.min[axis]>clip.max[axis]then return OUTSIDE end
 end
 return 1
end}
local camera={position={x=-200,y=10,z=0},GetComponent=function(_,kind)
 Check(kind=='Camera','resolve Camera from passed Node');return {frustum=frustum}
end}
local mode={id='conquest',points={{pos={100,3,-25},radius=22}},
 bases={blue={aim={200,8,0}},red={aim={-200,8,0}}}}
local rule={points={{v=.5,owner='blue'}},score={blue=100,red=100},shield={blue=true,red=false}}
local View=require 'render.ObjectiveView'
local view=View.New({scene=Node()},mode)
view:Update(.1,rule,camera)
Check(builds==0 and next(view.batches)==nil,'fully offscreen creates no geometry')
Check(view.age==.1,'offscreen animation clock advances')
-- Only the very top of the 90m beam intersects: center-only tests are invalid.
clip={min=Vector3(-103,80,-28),max=Vector3(-97,95,-22)}
view:Update(.001,rule,camera)
Check(view.batches.PointVolume1~=nil and not view.batches.PointRing1,'column top survives floor culling')
local volume=view.batches.PointVolume1
local lo,hi=math.huge,-math.huge
for _,v in ipairs(volume.mesh.vertices)do lo=math.min(lo,v.y);hi=math.max(hi,v.y)end
Check(lo==0 and hi==90,'rebuilt volume retains full source height')
local before=builds
clip=nil;view:Update(.11,rule,camera)
Check(builds==before and not volume.mesh.enabled,'offscreen old geometry hidden without rebuilding')
rule.points[1]={v=-1,owner='red'};rule.score.blue=5
clip={min=Vector3(-1000,-1000,-1000),max=Vector3(1000,1000,1000)}
view:Update(.001,rule,camera)
Check(builds==before+4,'all returning batches refresh before next 10Hz deadline')
Check(volume.mesh.enabled,'returning batch enabled')
Check(view.batches.PointRing1.mesh.material.shader:find('ObjectiveOverlay',1,true)~=nil,'source floor overlay retained')
Check(volume.mesh.material.shader:find('ObjectiveOverlay',1,true)==nil,'volume still depth tests')
Check(#view.batches.Reactorblue.mesh.vertices==24+72,'returning reactor uses latest score')
-- Every generated vertex fits the native analytic bounds, including both tiers.
local bounds={PointRing1={radius=22,lo=0,hi=.3,pos=mode.points[1].pos},
 PointVolume1={radius=22,lo=0,hi=90,pos=mode.points[1].pos},
 Reactorblue={radius=4,lo=-2.5,hi=2.5,pos=mode.bases.blue.aim},
 Reactorred={radius=4,lo=-2.5,hi=2.5,pos=mode.bases.red.aim}}
for name,b in pairs(bounds)do
 local batch=view.batches[name];local p=b.pos
 for _,v in ipairs(batch.mesh.vertices)do
  local x,y,z=v.x+batch.node.position.x,v.y+batch.node.position.y,v.z+batch.node.position.z
  assert(x>=-p[1]-b.radius-1e-8 and x<=-p[1]+b.radius+1e-8 and
   y>=p[2]+b.lo-1e-8 and y<=p[2]+b.hi+1e-8 and
   z>=p[3]-b.radius-1e-8 and z<=p[3]+b.radius+1e-8,'complete animated bounds '..name)
 end
 Check(true,'all actual vertices enclosed '..name)
end
-- Moving halos must not leave their previous on-screen geometry behind.
local payload={id='escort',path={},tuning={checkpoints={}},At=function(_,s)return {pos={s,0,0}}end}
local halo=View.New({scene=Node()},payload)
local state={s=0,idle=0,pushing=0,contested=false}
clip={min=Vector3(-30,-1,-30),max=Vector3(30,1,30)}
halo:Update(.1,state,camera);local mesh=halo.batches.PayloadHalo.mesh
state.s=1000;before=builds;halo:Update(.11,state,camera)
Check(builds==before and not mesh.enabled,'moving offscreen halo hides old location')
state.s=0;halo:Update(.001,state,camera)
Check(builds==before+1 and mesh.enabled,'moving halo re-entry refreshes immediately')
-- Missing camera is deliberately conservative, including tiny-dt re-entry.
clip=nil;halo:Update(.11,state,camera);before=builds
halo:Update(.001,state,nil)
Check(builds==before+1 and mesh.enabled,'camera absent restores conservative drawing')
view:Dispose();halo:Dispose()
return {checks=checks,status='PASS'}
'''


def run(source):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().PRODUCTION = source
    return dict(lua.execute(fixture))


result = run(production)
mutations = {
    'disable visibility gate': ('local outside=frustum and', 'local outside=false and'),
    'column center-only bound': ('p.pos,radius,0,90,due', 'p.pos,radius,0,.3,due'),
    'reverse native minimum X': ('pos[1]+radius,pos[2]+bottom', 'pos[1]-radius,pos[2]+bottom'),
    'delay returning batch': ('if not due and not self.culled[name] then', 'if not due then'),
}
result['rejectedMutations'] = []
for label, (old, new) in mutations.items():
    assert old in production, label
    try:
        run(production.replace(old, new, 1))
    except Exception:
        result['rejectedMutations'].append(label)
    else:
        raise AssertionError('Mutation passed: ' + label)
result['productionSha256'] = hashlib.sha256((ROOT / 'scripts/render/ObjectiveView.lua').read_bytes()).hexdigest()
result['boundary'] = 'Actual Lua geometry and conservative AABB controls; native frustum/rendered pixels/device timing not tested.'
(ROOT / 'docs/migration/evidence/objective-culling-offline.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))

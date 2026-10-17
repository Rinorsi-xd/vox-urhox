"""Actual production hook guard under Lua 5.4, with frozen exported bounds."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
legacy = (root / 'tools/migration/check-salvage-hook-guard.py').read_text(encoding='utf-8')
prelude, test_source = legacy.split("checks = lua.execute(r'''", 1)
prelude = prelude.replace("candidate = root / 'tools/migration/candidates/salvage-hook-guard'", "candidate = root / 'scripts'")
context = {'__file__': str(root / 'tools/migration/check-salvage-hook-guard.py')}
exec(compile(prelude, __file__, 'exec'), context)
lua = context['lua']
stubs = test_source.split("local View=assert(load(candidate_render", 1)[0]
lua.execute(stubs)
checks = lua.execute(r'''
local checks={}
local function Check(ok,label)assert(ok,label);checks[#checks+1]=label end
-- The reference coordinate conversion is independent of the guard's distance math.
local function TransformNode()
 local n={enabled=true,children={},worldScale=Vector3(1,1,1),worldPosition=Vector3(7,3,-2),yaw=.73}
 function n:CreateChild(name)local c=TransformNode();c.name=name;c.parent=self;self.children[#self.children+1]=c;return c end
 function n:SetEnabledRecursive(v)self.enabled=v;for _,c in ipairs(self.children)do c:SetEnabledRecursive(v)end end
 function n:CreateComponent(kind)
  Check(kind=='StaticModel','Only render batch '..#self.children)
  local mesh={node=self,enabled=true,changes=0}
  function mesh:SetEnabled(v)self.enabled=v;self.changes=self.changes+1 end
  self.mesh=mesh;return mesh
 end
 function n:ToWorld(p)
  local x,y,z=p.x*self.worldScale.x,p.y*self.worldScale.y,p.z*self.worldScale.z
  local c,s=math.cos(self.yaw),math.sin(self.yaw);local w=self.worldPosition
  return Vector3(w.x+c*x+s*z,w.y+y,w.z-s*x+c*z)
 end
 function n:WorldToLocal(p)
  local w=self.worldPosition;local x,y,z=p.x-w.x,p.y-w.y,p.z-w.z
  local c,s=math.cos(self.yaw),math.sin(self.yaw)
  return Vector3((c*x-s*z)/self.worldScale.x,y/self.worldScale.y,(s*x+c*z)/self.worldScale.z)
 end
 function n:Dispose()self.disposed=true end
 return n
end
local View=assert(load(candidate_render,'@scripts/render/SalvageCinematics.lua'))()
local view=View.New(TransformNode());local mesh=view.hookMesh
Check(mesh and mesh.model.name=='SalvageCine/model-15.bin','Production caches exact hook')
view.nodes.holder:SetEnabledRecursive(true)
local camera={};local a,b=view.hookMin,view.hookMax
local function At(x,y,z)camera.worldPosition=mesh.node:ToWorld(Vector3(x,y,z))end
local function Reset()view:GuardCamera(camera,false);Check(mesh.enabled and not view.hookHidden,'Reset restores hook')end
for i,scale in ipairs({Vector3(1,1,1),Vector3(1.157142857,1,1.197115385),Vector3(2,.5,3),Vector3(-2,-.5,-3)})do
 mesh.node.worldScale=scale;mesh.node.yaw=i*.41
 for _,axis in ipairs({'x','y','z'})do
  local function Gap(distance)local p=Vector3(0,5.6,0);p[axis]=b[axis]+distance/math.abs(scale[axis]);At(p.x,p.y,p.z)end
  Gap(.41);Reset();Check(not view:GuardCamera(camera,true),'Outside entry face '..i..axis)
  Gap(.39);Check(view:GuardCamera(camera,true),'Inside .4m entry face '..i..axis)
  local writes=mesh.changes
  for n=1,3 do Check(view:GuardCamera(camera,true),'Repeated near stays guarded '..i..axis..n)end
  Check(mesh.changes==writes,'No repeated native writes '..i..axis)
  Gap(.5);Check(view:GuardCamera(camera,true),'Hysteresis .5m face '..i..axis)
  Gap(.59);Check(view:GuardCamera(camera,true),'Inside .6m exit face '..i..axis)
  Gap(.61);Check(not view:GuardCamera(camera,true),'Outside .6m exit face '..i..axis)
 end
 At(b.x+.3/math.abs(scale.x),b.y+.3/math.abs(scale.y),0);Reset()
 Check(not view:GuardCamera(camera,true),'Euclidean corner .424m stays visible '..i)
 At(b.x+.28/math.abs(scale.x),b.y+.28/math.abs(scale.y),0)
 Check(view:GuardCamera(camera,true),'Euclidean corner .396m enters '..i)
 At(b.x+.43/math.abs(scale.x),b.y+.43/math.abs(scale.y),0)
 Check(not view:GuardCamera(camera,true),'Euclidean corner .608m restores '..i)
 At(b.x+.25/math.abs(scale.x),b.y+.25/math.abs(scale.y),b.z+.25/math.abs(scale.z));Reset()
 Check(not view:GuardCamera(camera,true),'3-axis corner .433m stays visible '..i)
 At(0,5.6,0);Check(view:GuardCamera(camera,true),'Inside box guarded '..i)
 Check(not view:GuardCamera(camera,false) and mesh.enabled,'Authored shot restores '..i)
end
mesh.node.worldScale=Vector3(1.1571428775787354,1,1.197115421295166)
At(1.23486328125,5.801732063293457,.134765625)
Check(view:GuardCamera(camera,true),'Actual Runtime near pose still guards with narrower rule')
At(0,6,-12);Check(not view:GuardCamera(camera,true),'Actual Runtime far pose restores')
At(0,5.6,0);view:GuardCamera(camera,true);view.nodes.holder:SetEnabledRecursive(false)
Check(not view:GuardCamera(camera,true) and mesh.enabled,'Disabled holder restores component without enabling holder')
local visited=0
local function Visit(n)
 if n.mesh then visited=visited+1;if n.mesh~=mesh then Check(n.mesh.enabled and n.mesh.changes==0,'Other batch unchanged '..n.mesh.model.name)end end
 for _,c in ipairs(n.children)do Visit(c)end
end
Visit(view.root);Check(visited==32,'Original 32 batches retained')
for _,name in ipairs({'render.CineDeathFilter','ui.SourceDraw','render.SalvageCineDust','salvage.CineMotion','ui.SourceButtonMotion','salvage.Loot'})do package.loaded[name]={}end
package.loaded['render.SalvageCinematics']=View
local Cine=assert(load(candidate_cine,'@scripts/salvage/Cinematics.lua'))()
local captured={};local cameraNode={}
local cine=setmetatable({playing=false,view={GuardCamera=function(_,n,active)captured.node=n;captured.active=active;captured.calls=(captured.calls or 0)+1 end},session={camera={GetNode=function()return cameraNode end}}},Cine)
cine:Camera();Check(captured.active and captured.node==cameraNode,'PostUpdate chase path guards before early return')
cine.playing=true;cine.shot={w=0};cine:Camera();Check(not captured.active,'Authored camera restores before zero-weight early return')
cine.playing=false;cine:Camera();Check(captured.active,'Authored-to-chase transition guards again')
view:Dispose();Check(view.hookMesh==nil and view.hookMin==nil and view.hookMax==nil,'Dispose drops all cached component/bounds references')
Check(view:GuardCamera(camera,true)==false,'Disposed guard is inert')
return checks
''')
sources = {name: hashlib.sha256((root / 'scripts' / name).read_bytes()).hexdigest()
           for name in ['render/SalvageCinematics.lua', 'salvage/Cinematics.lua']}
report = {'result': 'PASS_OFFLINE_ONLY', 'checks': list(checks.values()), 'sources': sources,
          'clearanceMeters': {'enter': .4, 'exit': .6}, 'distanceRule': 'WORLD_EUCLIDEAN_TO_LOCAL_AABB',
          'boundary': 'Actual production Lua with frozen model bounds and reference transforms. No Runtime, rendered, physics or performance acceptance.'}
output = root / 'docs/migration/evidence/salvage-hook-distance-offline.json'
output.write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(report['checks']), 'sources': sources}))

"""Execute isolated candidate Lua with engine stubs; no Runtime/hardware."""
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import zlib

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/lifecycle-python'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
prepared = json.loads((root / '.tmp/outgame-cached-1792189057538/identity.json').read_text(encoding='utf-8'))
manifest = json.loads(Path(prepared['manifest_path']).read_text(encoding='utf-8'))
resources = {r['fs_path']: r for r in manifest['files']}


def resource(name):
    row = resources[name]
    data = (Path(prepared['source_directory']) / 'dist/assets' /
            (row['uuid'] + '-' + row['hash'] + row['ext'])).read_bytes()
    assert len(data) == row['size'] and f'{zlib.crc32(data):08x}' == row['hash']
    return data


def convert(value):
    if isinstance(value, dict):
        return lua.table_from({k: convert(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(v) for v in value])
    return value


def bounds(name):
    data = resource(name)
    values = struct.unpack_from('<6f', data, len(data)-36)
    return lua.table(min=lua.table(x=values[0], y=values[1], z=values[2]),
                     max=lua.table(x=values[3], y=values[4], z=values[5]))


lua.globals().read_resource = lambda name: convert(json.loads(resource(name)))
lua.globals().model_bounds = bounds
candidate = root / 'tools/migration/candidates/salvage-hook-guard'
lua.globals().candidate_render = (candidate / 'render/SalvageCinematics.lua').read_text(encoding='utf-8')
lua.globals().candidate_cine = (candidate / 'salvage/Cinematics.lua').read_text(encoding='utf-8')
checks = lua.execute(r'''
local checks={}
local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
Vector3=setmetatable({RIGHT={},UP={},FORWARD={}},{__call=function(_,x,y,z)return {x=x,y=y,z=z}end})
Quaternion=function(...)return setmetatable({},{__mul=function()return {}end})end
Vector4=function(...)return {}end
Variant=function(v)return v end
Material={new=function()return {SetSurfaceShader=function()return true end,SetShaderParameter=function()end,Dispose=function()end}end}
cache={GetResource=function(_,kind,name)assert(kind=='Model');return {name=name,boundingBox=model_bounds(name)}end}
package.preload['core.ResourceData']=function()return {Read=read_resource}end
local meshes={}
local function Node(parent)
 local node={enabled=true,children={},parent=parent,worldScale=Vector3(1,1,1)}
 function node:CreateChild(name)local n=Node(self);n.name=name;self.children[#self.children+1]=n;return n end
 function node:SetEnabledRecursive(value)self.enabled=value;for _,n in ipairs(self.children)do n:SetEnabledRecursive(value)end end
 function node:CreateComponent(kind)
  assert(kind=='StaticModel','No added physics body/component')
  local mesh={node=self,enabled=true,changes=0}
  function mesh:SetEnabled(value)self.enabled=value;self.changes=self.changes+1 end
  meshes[#meshes+1]=mesh;return mesh
 end
 function node:WorldToLocal(p)return p end
 function node:Dispose()self.disposed=true end
 return node
end
local View=assert(load(candidate_render,'@candidate/render/SalvageCinematics.lua'))()
local view=View.New(Node())
Check(#meshes==32,'Actual New builds the original 32 render batches only')
Check(view.hookMesh.model.name=='SalvageCine/model-15.bin' and view.hookMesh.node.parent==view.nodes.frame,'Caches the exact hook batch under frame')
Check(not view.nodes.holder.enabled and not view.nodes.ship.enabled and view.hookMesh.enabled,'Initial parent visibility is unchanged')
local a,b=view.hookMin,view.hookMax
Check(a.x==-1 and b.x==1 and math.abs(a.y-5.3)<.00001 and math.abs(b.y-5.9)<.00001,'Cached bounds come from the actual frozen hook Model')
local scale=Vector3(1.157142857142857,1,1.1971153846153846)
view.hookMesh.node.worldScale=scale;view.nodes.holder:SetEnabledRecursive(true)
local camera={worldPosition=Vector3(1.2348492713317207,5.801732063293457,.13478404482002687)}
Check(view:GuardCamera(camera,true) and not view.hookMesh.enabled,'Actual brown-screen camera pose hides only top hook')
local changes=view.hookMesh.changes
for i=1,100 do Check(view:GuardCamera(camera,true),'Repeated near pose remains guarded '..i) end
Check(view.hookMesh.changes==changes,'Repeated active frames do not repeat native visibility writes')
camera.worldPosition=Vector3(.6063317464658184,5.801941871643066,.14078314429029648)
Check(view:GuardCamera(camera,true),'Actual hidden-control camera inside hook remains guarded')
camera.worldPosition=Vector3(-.04233224428962144,5.80216646194458,.14694544394264383)
Check(view:GuardCamera(camera,true),'Actual restored-control camera inside hook remains guarded')
camera.worldPosition=Vector3(20,8,0)
Check(not view:GuardCamera(camera,true) and view.hookMesh.enabled,'Far camera restores original hook visibility')
camera.worldPosition=Vector3(b.x+.7/scale.x,5.6,0)
Check(not view:GuardCamera(camera,true),'Visible hook stays visible outside .6m entry clearance')
camera.worldPosition=Vector3(b.x+.5/scale.x,5.6,0)
Check(view:GuardCamera(camera,true),'World scale is accounted for at .5m entry')
camera.worldPosition=Vector3(b.x+.7/scale.x,5.6,0)
Check(view:GuardCamera(camera,true),'Hidden hook remains hidden in hysteresis band')
camera.worldPosition=Vector3(b.x+.9/scale.x,5.6,0)
Check(not view:GuardCamera(camera,true),'Hook restores beyond .85m exit clearance')
for _,axis in ipairs({'x','y','z'})do
 local p=Vector3(0,5.6,0);p[axis]=b[axis]+.59/math.abs(scale[axis]);camera.worldPosition=p
 Check(view:GuardCamera(camera,true),'Inside expanded bound on '..axis)
 p[axis]=b[axis]+.86/math.abs(scale[axis]);Check(not view:GuardCamera(camera,true),'Outside expanded bound on '..axis)
end
camera.worldPosition=Vector3(0,5.6,0);view:GuardCamera(camera,true)
Check(not view:GuardCamera(camera,false) and view.hookMesh.enabled,'Scripted cinematic restores original hook before its camera composition')
view:GuardCamera(camera,true);view.nodes.holder:SetEnabledRecursive(false)
Check(not view:GuardCamera(camera,true) and view.hookMesh.enabled and not view.nodes.holder.enabled,'Inactive parent stays hidden while guard restores its own component flag')
for _,mesh in ipairs(meshes)do if mesh~=view.hookMesh then Check(mesh.enabled and mesh.changes==0,'Other original render batch untouched '..mesh.model.name)end end
Check(not view.nodes.ship.enabled,'Guard does not reveal ship')
for _,name in ipairs({'render.CineDeathFilter','ui.SourceDraw','render.SalvageCineDust','salvage.CineMotion','ui.SourceButtonMotion','salvage.Loot'})do package.loaded[name]={}end
package.loaded['render.SalvageCinematics']=View
local Cine=assert(load(candidate_cine,'@candidate/salvage/Cinematics.lua'))()
local captured={};local cameraNode={}
local cine=setmetatable({playing=false,view={GuardCamera=function(_,node,active)captured.node=node;captured.active=active;captured.calls=(captured.calls or 0)+1 end},session={camera={GetNode=function()return cameraNode end}}},Cine)
cine:Camera();Check(captured.active and captured.node==cameraNode and captured.calls==1,'Actual Camera integrates guard on completed natural drop before early return')
cine.playing=true;cine.shot={w=0};cine:Camera();Check(captured.active==false and captured.calls==2,'Actual Camera bypasses guard during scripted shots')
view:Dispose();Check(view.hookMesh==nil and view.disposed,'Dispose releases cached engine component reference')
Check(view:GuardCamera(camera,true)==false,'Guard safely ignores disposed cache')
return checks
''')
identity = json.loads((candidate / 'identity.json').read_text(encoding='utf-8'))
for name, row in identity['files'].items():
    assert hashlib.sha256((root/'scripts'/name).read_bytes()).hexdigest() == row['originalSha256']
    assert hashlib.sha256((candidate/name).read_bytes()).hexdigest() == row['candidateSha256']
report = {'result': 'PASS_OFFLINE_ONLY', 'checks': list(checks.values()),
          'identity': identity, 'engineApisRead': ['Node.WorldToLocal(Vector3)', 'Node.worldScale',
          'Model.boundingBox', 'Component.SetEnabled(boolean)', 'ThirdPersonCamera.GetNode'],
          'boundary': 'Candidate actual Lua New/Guard/Camera/Dispose executed with engine stubs and frozen Model bounds. Engine transforms, rendered screenshots and device performance still require root Runtime verification. No production or frozen-package files changed.'}
output = root / 'docs/migration/evidence/salvage-hook-guard-offline.json'
output.write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(report['checks']), 'output': str(output)}))

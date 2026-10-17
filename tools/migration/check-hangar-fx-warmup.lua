-- Real HangarFxWarmup, EffectBatch and Coord; native draw API doubles only.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
package.loaded['core.Rotations']={}
local checks=0
local function check(value,label)assert(value,label);checks=checks+1 end
local v={};v.__index=v
function v.__add(a,b)return Vector3(a.x+b.x,a.y+b.y,a.z+b.z)end
function v.__mul(a,b)return Vector3(a.x*b,a.y*b,a.z*b)end
Vector3=setmetatable({}, {__call=function(_,x,y,z)return setmetatable({x=x,y=y,z=z},v)end})
Vector3.RIGHT=Vector3(1,0,0);Vector3.UP=Vector3(0,1,0);Vector3.FORWARD=Vector3(0,0,1)
Vector2=function(x,y)return {x=x,y=y}end
Color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end
Variant=function(value)return value end
TRIANGLE_LIST='triangles'
local shaderPresent=true;local failure=nil;local materials={}
cache={Exists=function(_,name)check(name=='Shaders/BLGL/WeaponFx/Glow.shader','exact shader dependency');return shaderPresent end}
Material={new=function()
 local m={disposed=false,params={}}
 function m:SetSurfaceShader(name)self.shader=name;return true end
 function m:SetShaderParameter(name,value)self.params[name]=value end
 function m:Dispose()check(not self.disposed,'material disposed once');self.disposed=true end
 materials[#materials+1]=m;return m
end}
local Node={};Node.__index=Node
function Node:CreateChild(name)
 check(not self.disposed,'cannot allocate under disposed scene')
 local n=setmetatable({parent=self,scene=self.scene or self,name=name,children={},enabled=true},Node)
 self.children[#self.children+1]=n;return n
end
function Node:GetScene()return self.scene or self end
function Node:CreateComponent(kind)
 check(kind=='CustomGeometry','same weapon drawable kind')
 local d={vertices={},normals={},colors={},uvs={},viewMask=0x12345,enabled=true}
 function d:BeginGeometry(_,primitive)
  if failure=='begin'then error('injected geometry failure')end
  self.primitive=primitive
 end
 function d:DefineVertex(value)self.vertices[#self.vertices+1]=value end
 function d:DefineNormal(value)self.normals[#self.normals+1]=value end
 function d:DefineColor(value)self.colors[#self.colors+1]=value end
 function d:DefineTexCoord(value)self.uvs[#self.uvs+1]=value end
 function d:Commit()self.committed=true end
 self.drawable=d;return d
end
function Node:Dispose()
 check(not self.disposed,'node disposed once');self.disposed=true
 for _,node in ipairs(self.children)do if not node.disposed then node:Dispose()end end
end
local rotation=setmetatable({}, {__mul=function(_,point)return Vector3(-point.z,point.y,point.x)end})
local function fixture()
 shaderPresent=true;failure=nil;materials={}
 local scene=setmetatable({children={}},Node)
 local cameraNode=scene:CreateChild('real-camera');cameraNode.worldPosition=Vector3(11,3,7);cameraNode.worldRotation=rotation
 local camera={node=cameraNode,nearClip=.05,farClip=320}
 return scene,camera
end
local originalRandom=math.random
math.random=function()error('warmup consumed RNG')end
local Warm=WARMUP_SOURCE and assert(load(WARMUP_SOURCE))() or require'render.HangarFxWarmup'
do
 local scene,camera=fixture();local w=Warm.New(scene,camera);local batch=w.batch;local mesh=batch.mesh
 check(#scene.children==2 and w.root.name=='HangarFxWarmupProbe','isolated scene-owned root')
 check(batch.material.shader=='Shaders/BLGL/WeaponFx/Glow.shader','weapon shader, not combat shader')
 check(batch.material.renderOrder==143 and batch.mesh.castShadows==false,'original batch render state')
 check(batch.limit==4 and batch.kind=='Glow'and batch.count==1,'single bounded original batch')
 check(mesh.dynamic and mesh.enabled and mesh.committed,'draw is submitted, not allocation-only')
 check(mesh.primitive==TRIANGLE_LIST and #mesh.vertices==6 and #mesh.colors==6 and #mesh.normals==6 and #mesh.uvs==6,'exact vertex-color normal UV layout')
 local x,y,z=0,0,0
 for _,i in ipairs({1,2,3,6})do local p=mesh.vertices[i];x=x+p.x;y=y+p.y;z=z+p.z end
 check(math.abs(x/4-3)<.000001 and math.abs(y/4-3)<.000001 and math.abs(z/4-7)<.000001,'probe centered along actual rotated camera forward')
 check(batch.material.params.clock==0 and mesh.normals[1].x==.18,'original Glow time and gain attributes')
 check(camera.node.worldPosition.x==11 and camera.node.worldPosition.y==3 and camera.node.worldPosition.z==7,'real camera position unchanged')
 check(camera.node.worldRotation==rotation,'real camera rotation unchanged')
 check(w:Presented()==true and w.completed and w.frames==1,'one actual presented frame completes')
 check(w.disposed and w.root==nil and w.batch==nil and w.scene==nil,'owner releases all references')
 check(batch.node.disposed and batch.material.disposed and not scene.disposed,'only probe resources disposed')
 check(w:Presented()==true and w.frames==1,'repeated presentation idempotent');w:Dispose();scene:Dispose()
end
do
 local scene,camera=fixture();local w=Warm.New(scene,camera);local root=w.root;local mat=w.batch.material
 w:Dispose();check(root.disposed and mat.disposed,'cancel frees probe before scene')
 check(w:Presented()==false and not w.completed and w.frames==0,'cancel never masquerades as presented')
 w:Dispose();scene:Dispose()
end
do
 local scene,camera=fixture();shaderPresent=false
 local ok,err=pcall(Warm.New,scene,camera)
 check(not ok and tostring(err):find('missing Shaders/BLGL/WeaponFx/Glow.shader',1,true),'missing resource fails explicitly')
 check(#scene.children==1 and #materials==0,'missing resource allocates nothing');scene:Dispose()
end
do
 local scene,camera=fixture();failure='begin'
 local ok,err=pcall(Warm.New,scene,camera)
 check(not ok and tostring(err):find('injected geometry failure',1,true),'build failure surfaced')
 check(scene.children[2].disposed and materials[1].disposed,'partially built probe cleaned before propagating error');scene:Dispose()
end
do
 local scene,camera=fixture();camera.nearClip=4;camera.farClip=5
 check(not pcall(Warm.New,scene,camera),'empty camera range fails')
 check(#scene.children==1 and #materials==0,'invalid range allocates no probe');scene:Dispose()
end
do
 local scene,camera=fixture();local other=setmetatable({children={}},Node)
 check(not pcall(Warm.New,other,camera),'foreign camera fails')
 check(#other.children==0 and #materials==0,'foreign camera allocates no probe');scene:Dispose();other:Dispose()
end
math.random=originalRandom
print('HangarFxWarmup real batch: '..checks..' checks PASS')

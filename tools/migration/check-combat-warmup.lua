-- Engine-free lifecycle/ownership check; real GPU compilation still needs Web QA.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local function eq(a,b,label) assert(a==b,(label or 'equality')..': '..tostring(a)..' ~= '..tostring(b)) end
local vector={};vector.__index=vector
function vector.__add(a,b)return Vector3(a.x+b.x,a.y+b.y,a.z+b.z)end
function vector.__sub(a,b)return Vector3(a.x-b.x,a.y-b.y,a.z-b.z)end
function vector.__mul(a,b)if type(a)=='number'then a,b=b,a end;return Vector3(a.x*b,a.y*b,a.z*b)end
function Vector3(x,y,z)return setmetatable({x=x,y=y,z=z},vector)end
Vector3=setmetatable({RIGHT=Vector3(1,0,0),UP=Vector3(0,1,0),FORWARD=Vector3(0,0,1)}, {__call=function(_,x,y,z)return setmetatable({x=x,y=y,z=z},vector)end})
local rotation={__mul=function(_,b)return b end}
Quaternion=setmetatable({IDENTITY=setmetatable({},rotation)},{__call=function()return setmetatable({},rotation)end})
function Color(r,g,b,a)return {r=r,g=g,b=b,a=a or 1}end
function Vector2(x,y)return {x=x,y=y}end
function Vector4(x,y,z,w)return {x=x,y=y,z=z,w=w}end
VAR_NONE=0;OUTSIDE=0;TRIANGLE_LIST=0;LIGHT_POINT=1
function Variant(v)return {value=type(v)=='table'and v.value or v,type=v==nil and VAR_NONE or type(v)=='table'and v.type or 3}end
Material={}
function Material:new()
 local m={params={},disposed=false}
 function m:SetSurfaceShader(s)self.shader=s;return true end
 function m:SetShaderParameter(k,v)self.params[k]=v end
 function m:GetShaderParameter(k)return self.params[k]or Variant()end
 function m:RemoveShaderParameter(k)self.params[k]=nil end
 function m:Dispose()self.disposed=true end
 return m
end
local models={};cache={}
function cache:GetResource(_,name)
 if not models[name]then models[name]={name=name,numGeometries=1,boundingBox={size=Vector3(4,2,8),center=Vector3(2,1,4)}}end
 return models[name]
end
package.loaded['core.Coord']={Vec=function(x,y,z)return Vector3(-x,y,z)end}
package.loaded['Config']={HexLinear=function()return Color(.2,.4,.6,1)end}
package.loaded['render.Quality']={current={name='desktop',weaponArcSegments=128}}
package.loaded['core.ResourceData']={Read=function()return {resources={body={path='body'},glow={path='glow'}},sizes={['3']={l=1,r=.2}}}end}
local Node={};Node.__index=function(self,key)
 if key=='worldPosition'then return self.position elseif key=='worldRotation'then return self.rotation end
 if key=='enabledEffective'then return self.enabled and(not self.parent or self.parent.enabledEffective)end
 return Node[key]
end
function Node:CreateChild(name)
 local n=setmetatable({name=name,parent=self,children={},components={},position=Vector3(0,0,0),rotation=Quaternion.IDENTITY,scale=Vector3(1,1,1),enabled=true},Node)
 self.children[#self.children+1]=n;return n
end
function Node:CreateComponent(kind)
 local c={kind=kind,node=self,enabled=true,viewMask=7,worldBoundingBox={},lightMask=3,shadowMask=5,zoneMask=9,
  castShadows=false,maxLights=4,useInstanceColor=false,useInstanceCustomData=false,zone='zone',instanceColor=Color(1,1,1,1),commits=0}
 setmetatable(c,{__index=function(t,k)if k=='enabledEffective'then return t.enabled and t.node.enabledEffective end end})
 function c:GetMaterial()return self.material end
 function c:SetMaterial(index,material)self.material=material end
 function c:BeginGeometry()self.vertices=0 end
 function c:DefineVertex()self.vertices=self.vertices+1 end
 function c:DefineNormal()end;function c:DefineColor()end;function c:DefineTexCoord()end;function c:DefineTangent()end
 function c:Commit()self.commits=self.commits+1 end
 self.components[#self.components+1]=c;return c
end
function Node:GetComponents(kind,recursive)
 local out={};for _,c in ipairs(self.components)do if c.kind==kind then out[#out+1]=c end end
 if recursive then for _,n in ipairs(self.children)do for _,c in ipairs(n:GetComponents(kind,true))do out[#out+1]=c end end end
 return out
end
function Node:SetScale(v)self.scale=type(v)=='number'and Vector3(v,v,v)or v end
function Node:Dispose()self.disposed=true;for _,n in ipairs(self.children)do n:Dispose()end end
local function scene()
 return setmetatable({children={},components={},enabled=true,position=Vector3(0,0,0),rotation=Quaternion.IDENTITY,scale=Vector3(1,1,1)},Node)
end
local function session()
 local s=scene();local mat={};local model=cache:GetResource('Model','world')
 for i=1,6 do local n=s:CreateChild('real'..i);local d=n:CreateComponent('StaticModel');d.model=model;d.material=mat;d.castShadows=true end
 local n=s:CreateChild('realGeometry');n:CreateComponent('CustomGeometry')
 local camera={node=s:CreateChild('camera'),farClip=2600,frustum={IsInsideFast=function()return 1 end}}
 return {scene=s,camera={GetCamera=function()return camera end},effects=require('render.CombatEffects').New(s)}
end
local Warm=require'render.CombatWarmup'
local function checkRestored(s,before,light,clock)
 for d,mask in pairs(before)do eq(d.viewMask,mask,'view mask restored')end
 eq(s.effects.light.light.range,light.range,'light range');eq(s.effects.light.light.brightness,light.brightness,'light brightness')
 eq(s.effects.light.light.enabled,light.enabled,'light enabled');eq(s.effects.light.node.position,light.position,'light position')
 for _,b in pairs(s.effects.batches)do eq(b.count,0,'batch count');eq(b.mesh.enabled,false,'batch hidden')end
 eq(s.effects.batches.Glow.material:GetShaderParameter('clock').value,clock,'clock restored')
 for _,slot in ipairs(s.effects.chips.slots)do eq(slot.node.enabled,false,'chip hidden');eq(slot.active,false,'chip inactive')end
 for _,node in ipairs(s.effects.missiles.view.slots)do eq(node.enabled,false,'missile hidden')end
 eq(s.effects.missiles.view.count,0,'missile count')
end
local checks=0
for cancelAt=0,14 do
 local s=session();s.effects.batches.Glow.material:SetShaderParameter('clock',Variant(7.5))
 local before={};for _,kind in ipairs({'StaticModel','CustomGeometry'})do for _,d in ipairs(s.scene:GetComponents(kind,true))do before[d]=d.viewMask end end
 local light={range=s.effects.light.light.range,brightness=s.effects.light.light.brightness,enabled=s.effects.light.light.enabled,position=s.effects.light.node.position}
 math.randomseed(841);local expected={math.random(),math.random(),math.random()};math.randomseed(841)
 local w=Warm.New(s,{batchSize=4});eq(#s.effects.chips.slots,32,'actual retained chips');eq(#s.effects.missiles.view.slots,4,'actual retained missiles')
 eq(s.effects.missiles.view.count,4,'first instanced stage')
 for i=1,cancelAt do
  if not w.disposed then w:Presented()end
  if i==1 then eq(s.effects.missiles.view.count,1,'single stage')end
  if i==2 then eq(s.effects.missiles.view.count,4,'point instanced stage');eq(s.effects.light.light.enabled,true,'point light active')end
 end
 w:Dispose();w:Dispose();checkRestored(s,before,light,7.5)
 for _,proxy in ipairs(w.proxies)do eq(proxy.node.disposed,true,'cancel disposes temporary probe')end
 for i=1,3 do eq(math.random(),expected[i],'global random sequence unchanged')end
 eq(s.effects.missiles.view:Reserve(1000),128,'missile reserve capped');eq(s.effects.chips:Reserve(1000),360,'chip reserve capped')
 checks=checks+1
end
do
 local s=session();local w=Warm.New(s,{batchSize=4});local frames=0;local volumeFrames=0
 repeat
  frames=frames+1;assert(frames<30,'bounded frames')
  if w.phase=='point-volume-instanced' or w.phase=='point-volume-single'then volumeFrames=volumeFrames+1 end
 until w:Presented()
 eq(w.completed,true,'normal completion');eq(w.disposed,true,'normal disposal');assert(frames>=5,'must present effects and light stages')
 assert(volumeFrames>=2,'must present both outside-eye volume variants')
 for _,proxy in ipairs(w.proxies)do eq(proxy.node.disposed,true,'completion disposes probe')end
 eq(#s.effects.chips.slots,32,'completion retains chip pool');eq(#s.effects.missiles.view.slots,4,'completion retains missile pool');checks=checks+1
end

do
 local s=session();local models=s.scene:GetComponents('StaticModel',true)
 for i=2,#models do models[i].node.enabled=false end
 local source=models[1];local originalPosition=source.node.position;local originalScale=source.node.scale
 local w=Warm.New(s,{batchSize=4})
 while w.phase~='point-volume-instanced' do assert(not w:Presented(),'volume stage reached')end
 eq(#w.proxies,4,'one real object still warms instanced point-light shader')
 for _,proxy in ipairs(w.proxies)do
  eq(proxy.drawable.model,source.model,'same actual model');eq(proxy.drawable.material,source.material,'same actual material')
  eq(proxy.drawable.viewMask,7,'probe uses original visible mask')
  assert(proxy.node.position.z>6 and proxy.node.position.z<10,'probe in front of real camera')
 end
 eq(s.effects.light.light.range,4,'finite light volume');eq(s.effects.light.node.position.z,8,'eye outside light volume')
 eq(source.node.position,originalPosition,'source position unchanged');eq(source.node.scale,originalScale,'source scale unchanged')
 local root=w.proxyRoot;w:Dispose();eq(root.disposed,true,'temporary parent disposed')
 eq(#s.scene:GetComponents('CollisionShape',true),0,'no physics components on probes');checks=checks+1
end

do
 local s=session();local w=Warm.New(s,{batchSize=4})
 while w.phase~='point-volume-instanced' do assert(not w:Presented(),'volume stage reached')end
 local root=w.proxyRoot;w.proxies[1].drawable.SetMaterial=function()error('probe failure')end
 eq(pcall(w.Presented,w),false,'volume failure propagated');eq(w.disposed,true,'volume failure self-disposes')
 eq(root.disposed,true,'volume failure disposes probes');eq(s.effects.light.light.enabled,false,'volume failure restores light')
 checks=checks+1
end
do
 local s=session();s.effects.beams={{age=1}};local ok=pcall(Warm.New,s);eq(ok,false,'reject active session');eq(#s.effects.beams,1,'active event unchanged');checks=checks+1
end
do
 local s=session();local original=s.effects.chips.Reserve;s.effects.chips.Reserve=function()error('reserve failure')end
 eq(pcall(Warm.New,s),false,'initialization failure');eq(s.effects.light.light.enabled,false,'failure light restored')
 s.effects.chips.Reserve=original;checks=checks+1
end
do
 local s=session();local before={};for _,d in ipairs(s.scene:GetComponents('StaticModel',true))do before[d]=d.viewMask end
 local mesh=s.effects.batches.Glow.mesh;mesh.Commit=function()error('upload failure')end
 eq(pcall(Warm.New,s),false,'geometry submission failure')
 for d,mask in pairs(before)do eq(d.viewMask,mask,'failure restores masks')end
 for _,b in pairs(s.effects.batches)do eq(b.mesh.enabled,false,'failure hides warm geometry')end
 eq(s.effects.light.light.enabled,false,'upload failure restores light');checks=checks+1
end
do
 local s=session();local w=Warm.New(s);s.effects.batches.Glow.mesh.Commit=function()error('second-frame upload failure')end
 eq(pcall(w.Presented,w),false,'presented failure propagated');eq(w.disposed,true,'presented failure self-disposes')
 for _,b in pairs(s.effects.batches)do eq(b.mesh.enabled,false,'presented failure hides warm geometry')end
 eq(s.effects.light.light.enabled,false,'presented failure restores light');checks=checks+1
end
print('CombatWarmup offline lifecycle: '..checks..' scenarios PASS; no GPU/runtime performance claim')

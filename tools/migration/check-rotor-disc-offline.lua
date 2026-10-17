-- Resource/native adapters only. Actual Build/Repaint/ApplyEdits/Bind/Update execute.
package.path='scripts/?.lua;'..package.path
cjson={null={}}
local function Noop()end
package.loaded['core.ResourceData']={Read=function(name)return assert(ASSETS[name],name)end}
local V=require 'core.Math3'
local Vec={};Vec.__index=Vec
function Vector3(x,y,z)return setmetatable({x=x or 0,y=y or 0,z=z or 0},Vec)end
function Vec.__mul(a,b)if type(a)=='number'then a,b=b,a end;return Vector3(a.x*b,a.y*b,a.z*b)end
function Vec.__add(a,b)return Vector3(a.x+b.x,a.y+b.y,a.z+b.z)end
function Vec.__sub(a,b)return Vector3(a.x-b.x,a.y-b.y,a.z-b.z)end
function Vec:Normalized()local k=1/math.sqrt(self.x*self.x+self.y*self.y+self.z*self.z);return self*k end
Vector3=setmetatable({UP=Vector3(0,1,0),ZERO=Vector3()},{__call=function(_,x,y,z)return setmetatable({x=x or 0,y=y or 0,z=z or 0},Vec)end})
local Quat={};Quat.__index=Quat
function Quat.__mul(a,b)
 if b.w then local q=V.QMul(a,b);return setmetatable(q,Quat)end
 local p=V.Rotate(a,{b.x,b.y,b.z});return Vector3(table.unpack(p))
end
Quaternion=setmetatable({},{__call=function(_,a,b,c,d)
 if d~=nil then return setmetatable({w=a,x=b,y=c,z=d},Quat)end
 local half=a*math.pi/360;local s=math.sin(half);return setmetatable({w=math.cos(half),x=b.x*s,y=b.y*s,z=b.z*s},Quat)
end})
Quaternion.IDENTITY=Quaternion(1,0,0,0)
function Vector4(x,y,z,w)return {x=x,y=y,z=z,w=w}end
Vector4=setmetatable({ZERO=Vector4(0,0,0,0)},{__call=function(_,x,y,z,w)return {x=x,y=y,z=z,w=w}end})
function Color(r,g,b,a)return {r=r,g=g,b=b,a=a}end
local Node={};Node.__index=Node
local function NewNode(name)return setmetatable({name=name,children={},position=Vector3(),rotation=Quaternion.IDENTITY,scale=Vector3(1,1,1)},Node)end
function Node:CreateChild(name)local n=NewNode(name);self.children[#self.children+1]=n;n.parent=self;return n end
function Node:CreateComponent()return {SetMaterial=Noop}end
function Node:SetScale(s)self.scale=Vector3(s,s,s)end
function Node:Dispose()self.disposed=true end
local function Plain()return setmetatable({meshes={}},{__index=function()return Noop end})end
package.loaded['render.JoinedMesh']={New=Plain}
package.loaded['render.LiveryLayer']={New=Plain}
package.loaded['render.WeaponPresentation']={slots={},Create=Noop}
package.loaded['render.BuildXray']={}
package.loaded['render.WeaponEffects']={}
package.loaded['render.JoinedSurface']={IsJoined=function()return false end}
package.loaded['render.ShellMaterials']={Apply=Noop,Release=Noop}
package.loaded['parts.Materials']={Get=function()return {}end,DynamicEmission=function()return {}end}
package.loaded['parts.PartAssets']={Get=function(name)return assert(ASSETS['Parts/Rigs/'..name..'.json'])end,Model=function()return {}end,Release=Noop}
package.loaded['parts.MechIK']={}
package.loaded['parts.LegIK']={}
package.loaded['render.WingRig']={}
package.loaded['core.Coord']={Vec=function(x,y,z)return Vector3(-x,y,z)end,CellPos=function(x,y,z)return Vector3(-x,y,z)end,RotQuat=function()return Quaternion.IDENTITY end}
local View=require 'render.VehicleView'
local Rotor=require 'render.RotorView'
local Rotors=require 'construction.Rotors'
return function(part,points)
 local root=NewNode('scene');local view=View.New(root,'vehicle');local vis=view:AddPart(part)
 local function Samples()
  local out={};for _,p in ipairs(points)do
   local s=vis.head.scale;local q=vis.head.rotation*Vector3(-p[1]*s.x,p[2]*s.y,p[3]*s.z)
   out[#out+1]={-q.x,q.y,q.z}
  end;return out
 end
 local frame=Rotors.Frame(part)
 local r={partId=part.id,sign=frame.sign,prev=0,angle=0,pivot=V.Scale(frame.pivot,.5),axis=frame.spin}
 local vehicle={spec={rotorOf={}},rotors={r}}
 local instance={view=view,vis=vis,vehicle=vehicle,initial=Samples()}
 instance.rotor=Rotor.New(view,vehicle)
 function instance:Step(prev,angle,alpha)r.prev=prev;r.angle=angle;self.rotor:Update(alpha);return Samples()end
 function instance:Rebind()self.rotor=Rotor.New(view,vehicle);self.rotor:Update(1);return Samples()end
 function instance:Repaint()self.view:Repaint(part);return Samples()end
 function instance:Refit(nextPart)
  self.view:ApplyEdits({{id=part.id}}, {parts={[part.id]=nextPart}})
  return Samples()
 end
 function instance:ResetAngle()r.prev=0;r.angle=0;self.rotor:Update(1)end
 return instance
end

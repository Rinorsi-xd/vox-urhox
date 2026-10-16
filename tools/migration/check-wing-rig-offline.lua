-- Native transform/resource adapters only; production Bind/Update and wing springs execute unchanged.
package.path='scripts/?.lua;'..package.path
package.loaded.Config={CELL=.5}
package.loaded['core.Rotations']={}
cjson={null={}}
local Vec={};Vec.__index=Vec
function Vec:Normalized() local n=math.sqrt(self.x*self.x+self.y*self.y+self.z*self.z);return Vector3(self.x/n,self.y/n,self.z/n) end
function Vec:Lerp() return self end
function Vector3(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},Vec) end
function Vector4(x,y,z,w) return {x=x,y=y,z=z,w=w} end
Quaternion=setmetatable({IDENTITY={Slerp=function(self)return self end}},{__call=function(_,angle,axis)
    local a=angle*math.pi/360;local s=math.sin(a);return {x=axis.x*s,y=axis.y*s,z=axis.z*s,w=math.cos(a)}
end})
local Node={};Node.__index=Node
function Node:CreateChild(name) local n=setmetatable({name=name},Node);self.children[name]=n;n.children={};return n end
function Node:CreateComponent()return {}end
function Node:Dispose()self.disposed=true end
Material={new=function()return {SetSurfaceShader=function()return true end,Dispose=function()end}end}
local noop=function()end
local adapter={New=function()return {Update=noop}end}
for _,name in ipairs({'render.PartRig','render.VehicleView','render.ActuatorView','render.LegView','render.MechView','render.RotorView','render.EquipmentEffects'}) do package.loaded[name]=adapter end
package.loaded['render.VehicleView'].PartLocalPos=function()return Vector3()end
package.loaded['drive.VehicleSpec']={GEOMETRY={rotations={}}}
package.loaded['core.Coord']={Vec=function(x,y,z)return Vector3(-x,y,z)end,RotQuat=function()return Quaternion.IDENTITY end}
math.random=function()return .37 end
local Wing=require 'render.WingRig'
local Drive=require 'render.DriveView'
return function(segs,wing)
    local root=setmetatable({children={},position=Vector3(),rotation=Quaternion.IDENTITY},Node)
    local vis={node=root,rig={},emissionModels={{}}}
    -- GPU trail adapters are outside this articulation check.
    Wing.Build(root,segs,{},vis,function()end);vis.rig.wing.trail=nil
    local vehicle={wheels={},spec={wings={wing}},native={position=Vector3(),rotation=Quaternion.IDENTITY}}
    local drive=setmetatable({view={root=root,visuals={[17]=vis}},equipment={Bind=noop,Update=noop}},Drive)
    drive:Bind({List=function()return {{id=17,rot=0}}end},vehicle)
    return {vis=vis,vehicle=vehicle,drive=drive,step=function(self,state,dt)
        self.vehicle.wingState=state;self.drive:Update(1,dt);return self.vis.rig.wing
    end}
end

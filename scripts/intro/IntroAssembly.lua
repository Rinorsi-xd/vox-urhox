-- Reveal already prepared original hero parts in the authored montage order.
local M={};M.__index=M
function M.New(view,bp)
 local self=setmetatable({},M);self:init(view,bp);return self
end
function M:init(view,bp)
 self.view=view;self.parts=bp:List();self.index=0;self.drops={};self.homes={};self.scales={};self.axes={};self.flashes={}
 self.material=Material:new();assert(self.material:SetSurfaceShader('Intro/Shaders/BLGL/AssemblyFlash.shader'))
 self.material.depthBias=BiasParameters(-.00004,-1);self.material.renderOrder=130
 self.color=require('Config').HexLinear(0x3fe6ff)
 table.sort(self.parts,function(a,b)return (a.pos[2]-b.pos[2])*4+(math.abs(a.pos[1])+math.abs(a.pos[3])-math.abs(b.pos[1])-math.abs(b.pos[3]))*.3<0 end)
 for _,part in ipairs(self.parts) do
  local vis=assert(view.visuals[part.id],'Original montage part was not prepared')
  assert(not vis.joined,'Original opening montage expects separate source parts')
  self.homes[part.id]=vis.node.position
  self.scales[part.id]=vis.node.scale;local q=vis.node.rotation
  self.axes[part.id]={math.abs((q*Vector3.RIGHT).y)>.5,math.abs((q*Vector3.UP).y)>.5,math.abs((q*Vector3.FORWARD).y)>.5}
  local flashes={};self.flashes[part.id]=flashes
  for _,source in ipairs(vis.models) do if source.castShadows then
   local flash=source.node:CreateComponent('StaticModel');flash.model=source.model;flash.material=self.material
   flash.castShadows=false;flash.enabled=false;flash.instanceColor=Color(self.color.r,self.color.g,self.color.b,0)
   flashes[#flashes+1]=flash
  end end
 end
end
function M:Begin()
 self.index=0;self.drops={}
 for _,part in ipairs(self.parts) do local node=self.view.visuals[part.id].node
  node.position=self.homes[part.id];node.scale=self.scales[part.id];node:SetEnabledRecursive(false)
 end
end
function M:WarmFlash(enabled)
 for _,list in pairs(self.flashes) do for _,model in ipairs(list) do
  model.enabled=enabled;model.instanceColor=Color(self.color.r,self.color.g,self.color.b,enabled and 1 or 0)
 end end
end
function M:Update(age,time,duration)
 local k=math.min(1,age/math.max(.1,duration*.85));k=k<.5 and 4*k^3 or 1-(-2*k+2)^3/2
 local want=math.floor(k*#self.parts)
 while self.index<want do
  self.index=self.index+1;local part=self.parts[self.index];local node=self.view.visuals[part.id].node
  node:SetEnabledRecursive(true);self.drops[#self.drops+1]={id=part.id,node=node,home=self.homes[part.id],start=time}
 end
 for _,drop in ipairs(self.drops) do if not drop.finished then
  local t=math.min(1,(time-drop.start)/.24);local along=.12+.88*(1+2.4*(t-1)^3+1.4*(t-1)^2)
  local side=.8+.2*(1-(1-t)^3);local axes=self.axes[drop.id];local scale=self.scales[drop.id]
  drop.node.scale=Vector3(scale.x*(axes[1] and along or side),scale.y*(axes[2] and along or side),scale.z*(axes[3] and along or side))
  drop.node.position=drop.home+Vector3(0,(along-1)*.5,0)
  local flash=math.max(0,1-(time-drop.start)/.3)^2
  for _,model in ipairs(self.flashes[drop.id]) do model.enabled=flash>0;model.instanceColor=Color(self.color.r,self.color.g,self.color.b,flash) end
  drop.finished=flash==0
 end end
end
function M:Dispose() if self.material then self.material:Dispose();self.material=nil end end
return M

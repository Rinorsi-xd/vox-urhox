-- Source coordinates (metres), 56 x 56 m deck above an 8 m pit:
-- intact:  ========  three support colliders ON; fallen colliders OFF
-- collapsed: \_/_/  intact OFF; 18 authored debris colliders ON
-- A strict rectangle edge is outside; removing support wakes dynamic vehicles.
local Visibility=require 'render.NodeVisibility'
local M={};M.__index=M
local decks=setmetatable({},{__mode='k'})
function M.Get(scene,layout)
    if decks[scene] then return decks[scene] end
    local self=setmetatable({},M);self:init(scene,layout.enginePit.deck);decks[scene]=self;return self
end
function M:init(scene,data)
    assert(data,'EnginePit missing original deck metadata')
    self.scene=scene;self.center=data.center;self.half=data.half;self.yaw=data.yaw;self.top=data.top;self.pitY=data.pitY
    self.intact=assert(scene:GetChild('可塌甲板',true));self.fallen=assert(scene:GetChild('塌掉的甲板',true))
    self.physics={deck={},fallen={}};self.collapsed=false;self.dustT=0
    Visibility.Set(self.fallen,false)
end
function M:Contains(x,z,margin)
    margin=margin or 0;local dx,dz=x-self.center[1],z-self.center[3];local c,s=math.cos(self.yaw),math.sin(self.yaw)
    return math.abs(dx*c-dz*s)<self.half[1]+margin and math.abs(-dx*s-dz*c)<self.half[2]+margin
end
function M:AttachPhysics(native,definition)
    local group=definition.group
    if group=='deck' or group=='fallen' then
        local list=self.physics[group];list[#list+1]=native
        native.enabled=group=='deck' and not self.collapsed or group=='fallen' and self.collapsed
    end
end
function M:SetState(collapsed)
    self.collapsed=collapsed
    Visibility.Set(self.intact,not collapsed);Visibility.Set(self.fallen,collapsed)
    for _,b in ipairs(self.physics.deck) do b.enabled=not collapsed end
    for _,b in ipairs(self.physics.fallen) do b.enabled=collapsed end
end
function M:Collapse()
    if self.collapsed then return end
    self:SetState(true);self.dustT=.9
    for _,b in ipairs(self.scene:GetComponents('RigidBody',true)) do if b.mass>0 and not b.kinematic then b:Activate() end end
end
function M:Reset()
    self:SetState(false);self.dustT=0
    if self.dust then self.dust:SetRate(0) end
end
function M:Update(dt)
    if self.dustT>0 then self.dustT=self.dustT-dt;if self.dust then self.dust:SetRate(self.dustT>0 and 9 or 0) end end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.dust then self.dust:Dispose();self.dust=nil end
    self.physics={deck={},fallen={}};decks[self.scene]=nil
    self.scene=nil;self.intact=nil;self.fallen=nil
end
return M

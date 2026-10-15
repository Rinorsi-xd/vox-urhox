-- Prepare the original montage hero before narration. An inactive native body
-- stays outside the active roster, analytical ray tests and all driver updates.
local M={};M.__index=M
function M.New(session,battle,source,checkpoint)
 local self=setmetatable({},M);self:init(session,battle,source,checkpoint);return self
end
function M:init(session,battle,source,checkpoint)
 self.session=session;self.battle=battle;self.activated=false;self.disposed=false;battle.montage=self
 local world=session.world
 self.unit=require('combat.CarUnit').New(world,source,{name='坠舰陨坑 · 实机演示',
  spawn={pos={66,world:GroundAt(66,-174)+1.5,-174},yaw=0},team='blue',
  externalControl=true,externalView=true,autoRespawn=false,combat=true})
 assert(self.unit.alive,'Invalid original montage hero')
 self.unit.vehicle.native.enabled=false
 for i=#world.viewEvents,1,-1 do if world.viewEvents[i].unit==self.unit then table.remove(world.viewEvents,i) end end
 self.view=require('render.DriveView').New(session.scene,self.unit.bp,self.unit.vehicle,checkpoint,function(view)self.view=view end)
 self:SetWarmVisible(false)
end
function M:SetWarmVisible(visible)
 if self.activated or self.disposed or not self.view then return end
 self.view.view:SetVisible(visible)
 if self.view.equipment.root then self.view.equipment.root:SetEnabledRecursive(visible) end
 if visible then
  local context=self.session.fxContext;self.view:Update(1,0,context);self.view.view:UpdateIdle(0,0,true)
  self.view.view:UpdateWeaponEffects(.04,context)
 end
end
function M:Activate()
 if self.disposed then return nil end
 if self.activated then return self.battle.player end
 local s,b=self.session,self.battle;local unit,view=self.unit,self.view;local old=b.player
 if s.view then s.view:Dispose() end
 if old then old:Dispose() end
 b.player=unit;b.entries[1].unit=unit;b.entries[1].env=b:Environment(unit);s.world.units[1]=unit
 s.world.feedbackPlayer=unit;s.vehicle=unit.vehicle;s.weapons=unit.weapons;s.view=view
 unit.vehicle.native.enabled=true;view.view:SetVisible(true)
 if view.equipment.root then view.equipment.root:SetEnabledRecursive(true) end
 view:ResetPose();view:Update(1,0,s.fxContext)
 self.unit=nil;self.view=nil;self.activated=true
 return unit
end
function M:Dispose()
 if self.disposed then return end;self.disposed=true
 if self.view then self.view:Dispose();self.view=nil end
 if self.unit then
  local unit=self.unit;unit:Dispose();self.unit=nil
  local events=self.session.world.viewEvents
  for i=#events,1,-1 do if events[i].unit==unit then table.remove(events,i) end end
 end
end
return M

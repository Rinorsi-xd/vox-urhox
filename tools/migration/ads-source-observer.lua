-- QA suffix after the ordinary main and existing isolated scope fixture.
do
local WeaponView=require 'render.WeaponView'
local tags=setmetatable({},{__mode='k'})
local tracked={attached=false,emissions={},draws={},restored={},violations=0,sequence=0,scopedSeen=0}
local persistentDepth,motionDepth=0,0
local pending=false
local function Increment(root,key,amount)root[key]=(root[key]or 0)+(amount or 1)end
local function Group(t)local group=t.weapons:Group();return group and group.kind or 'none'end
local function Phase(t)return t.firstPerson and 'scoped'or 'normal'end
local function Attach(t)
 if tracked.attached or not t or not t.effects or not t.view or not t.view.view then return end
 local view=t.view.view;local fx=view.weaponEffects;if not fx then return end
 local persistent=fx.Update
 fx.Update=function(self,...)
  persistentDepth=persistentDepth+1;local result=table.pack(pcall(persistent,self,...));persistentDepth=persistentDepth-1
  if not result[1]then error(result[2],0)end;return table.unpack(result,2,result.n)
 end
 local motion=WeaponView.Update
 WeaponView.Update=function(current,...)
  local own=current==view;if own then motionDepth=motionDepth+1 end
  local result=table.pack(pcall(motion,current,...));if own then motionDepth=motionDepth-1 end
  if not result[1]then error(result[2],0)end;return table.unpack(result,2,result.n)
 end
 local effects=t.effects;local emit=effects.EquipmentEmit
 effects.EquipmentEmit=function(self,kind,p,sourceView,...)
  local before={};for _,list in ipairs({self.particles,self.smoke})do for _,item in ipairs(list)do before[item]=true end end
  local origin=persistentDepth>0 and 'ownPersistent'or motionDepth>0 and 'ownMotion'or 'other'
  local source=sourceView==view and 'own'or sourceView==nil and 'nil'or 'other'
  local result=table.pack(emit(self,kind,p,sourceView,...))
  if origin~='other'and source~='own'then tracked.violations=tracked.violations+1 end
  for _,name in ipairs({'particles','smoke'})do for _,item in ipairs(self[name])do if not before[item]then
   if (kind=='spark'or kind=='mote')and item.sourceView~=sourceView then tracked.violations=tracked.violations+1 end
   local tag={origin=origin,source=source,kind=kind,group=Group(t)};tags[item.pos]=tag
   Increment(tracked.emissions,Group(t)..':'..Phase(t)..':'..origin..':'..source)
  end end end
  return table.unpack(result,1,result.n)
 end
 for _,name in ipairs({'Glow','Smoke'})do local batch=effects.batches[name];local disc=batch.Disc
  batch.Disc=function(self,position,...)
   local tag=tags[position];local before=self.count;local result=table.pack(disc(self,position,...))
   if tag and self.count>before then
    Increment(tracked.draws,Group(t)..':'..Phase(t)..':'..tag.origin..':'..tag.source)
    if not t.firstPerson and tag.source=='own'and tag.seenScoped then Increment(tracked.restored,tag.group..':'..tag.origin)end
   end
   return table.unpack(result,1,result.n)
  end
 end
 tracked.attached=true;print('ADS_SOURCE_READY actual owner-aware emission and accepted draw observers attached')
end
local function Observe(t)
 if not tracked.attached or not t then return end
 if t.firstPerson then for _,name in ipairs({'particles','smoke'})do for _,item in ipairs(t.effects[name])do
  local tag=tags[item.pos]
  if tag and tag.source=='own'then
   if not tag.seenScoped then tracked.scopedSeen=tracked.scopedSeen+1;tag.seenScoped=true end
  end
 end end end
end
local function Snapshot(t)
 tracked.sequence=tracked.sequence+1;local live={};local youngOwnPersistent=0
 if t and tracked.attached then for _,name in ipairs({'particles','smoke'})do for _,item in ipairs(t.effects[name])do
  local tag=tags[item.pos];if tag then Increment(live,tag.origin..':'..tag.source)
   if tag.origin=='ownPersistent'and tag.source=='own'and item.life-item.age>.1 then youngOwnPersistent=youngOwnPersistent+1 end
  end
 end end end
 print('ADS_SOURCE_STATE '..cjson.encode({sequence=tracked.sequence,attached=tracked.attached,
  group=t and Group(t),firstPerson=t and t.firstPerson==true,live=live,
  ownViewMatches=t and t.effects.ownView==t.view.view,ownViewCleared=t and t.effects.ownView==nil,
  emissions=tracked.emissions,draws=tracked.draws,restored=tracked.restored,
  violations=tracked.violations,scopedSeen=tracked.scopedSeen,youngOwnPersistent=youngOwnPersistent,
  boundary='Actual sourceView identity and accepted shared draw calls. ScopedSeen tags actual existing particles; restored counts only those same particles drawn again after release. Synthetic catalog fixture, not natural-gameplay FPS/mobile acceptance.'}))
end
local update=HandleUpdate
function HandleUpdate(...)
 update(...);Attach(app and app.trial)
 if input:GetKeyPress(KEY_F9)then pending=true end
end
local post=HandlePostUpdate
function HandlePostUpdate(...)
 post(...);Observe(app and app.trial)
 if pending then pending=false;Snapshot(app and app.trial)end
end
end

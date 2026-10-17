-- Isolated whole-section timing with reusable guards and existing monitor tokens.
do
local installed,started,stopPending,finished=false,false,false,false
local previous=_G.VOX_EFFECTS_SECTION_PROBE
assert(previous==nil,'Preserve existing effect section observer')
local depth=0;local guards={}
local selected={
 {'render.EffectBatch','Finish','fx.batch.finish'},
 {'render.CombatLight','Update','fx.light.update'},
 {'render.RotorView','Update','view.rotors.update'},
 {'render.ActuatorView','Update','view.actuators.update'},
 {'render.LegView','Update','view.legs.update'},
 {'render.MechView','Update','view.mechs.update'},
 {'render.EquipmentEffects','Update','view.equipment.update'},
}
local guardMt={__close=function(guard,err)
 if guard.token then performance:End(guard.token);guard.token=nil end
 assert(guards[depth]==guard,'Effect section scope stack must unwind in order')
 depth=depth-1
 if err then _G.VOX_EFFECTS_SECTION_PROBE=previous end
end}
for index=1,8 do guards[index]=setmetatable({},guardMt)end
local callback=function(kind,label)
 if not performance or not performance.enabled or not performance.recording then return nil end
 if kind=='begin' then
  depth=depth+1;assert(depth<=#guards,'Bounded effect section depth')
  local guard=guards[depth];assert(not guard.token,'Previous effect scope must close')
  guard.token=performance:Begin(label);return guard
 end
 assert(kind=='mark' and depth>0,'Effect section requires active update')
 local guard=guards[depth]
 performance:End(guard.token);guard.token=performance:Begin(label)
end
_G.VOX_EFFECTS_SECTION_PROBE=callback
local update=HandleUpdate
function HandleUpdate(...)
 local pressed=input:GetKeyPress(KEY_F9)
 update(...)
 if not installed and app and app.trial and app.trial.vehicle and performance then
  assert(performance.enabled,'Keep default monitor enabled')
  for _,entry in ipairs(selected)do
   local module=require(entry[1]);assert(type(module[entry[2]])=='function','Missing semantic method '..entry[1]..'.'..entry[2])
   performance:Wrap(module,entry[2],entry[3])
  end
  installed=true
  print('MONITOR_COMBAT_EFFECTS_READY '..cjson.encode({frame=GetTime().frameNumber,sections=13,methods=#selected,debugUpvalues=false,perPrimitiveWrappers=false}))
 end
 if pressed then
  assert(installed and not finished,'Single effect capture requires actual trial')
  if started then stopPending=true else started=true end
 end
end
local presented=HandleFramePresented
function HandleFramePresented(...)
 presented(...)
 if stopPending then
  assert(depth==0,'No live effects scope at complete-frame export')
  stopPending=false;finished=true;_G.VOX_EFFECTS_SECTION_PROBE=previous
  print('MONITOR_COMBAT_EFFECTS_DONE '..cjson.encode({frame=GetTime().frameNumber,restored=_G.VOX_EFFECTS_SECTION_PROBE==previous,scopeDepth=depth}))
 end
end
end

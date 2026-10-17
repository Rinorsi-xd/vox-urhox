-- Appended after production main + existing scope fixture, inside one QA do block.
local tags=setmetatable({},{__mode='k'})
local state={attached=false,frozen=false,stage='live',records={},frozenFrames=0,randomCalls=0,randomSeedCalls=0}
local ownDepth=0
local ownMotionDepth=0
local WeaponView=require 'render.WeaponView'
local function Copy(value)
 if type(value)~='table'then return value end
 local result={};for key,item in pairs(value)do result[key]=Copy(item)end;return result
end
local function Canonical(value)
 local kind=type(value)
 if kind=='number'then assert(value==value and math.abs(value)<math.huge);return string.format('%.17g',value)end
 if kind~='table'then return cjson.encode(value)end
 local keys={};for key in pairs(value)do keys[#keys+1]=key end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local pieces={};for _,key in ipairs(keys)do pieces[#pieces+1]=Canonical(key)..':'..Canonical(value[key])end
 return '{'..table.concat(pieces,',')..'}'
end
local function Hash(value)
 local text=Canonical(value);local hash=2166136261
 for i=1,#text do hash=((hash~text:byte(i))*16777619)&0xffffffff end
 return string.format('%08x',hash)
end
local function V3(v)return {v.x,v.y,v.z}end
local function Q4(v)return {v.w,v.x,v.y,v.z}end
local function Invariants(t)
 local camera=t.camera:GetNode();local particles={}
 for _,name in ipairs({'particles','smoke','beams','flares','rings','flashes','zaps','trails'})do
  particles[name]={}
  for _,item in ipairs(t.effects[name]or {})do
   local row={};for key,value in pairs(item)do if type(value)=='number'or type(value)=='boolean'or type(value)=='string'then row[key]=value
    elseif type(value)=='table'and (key=='pos'or key=='vel'or key=='from'or key=='to'or key=='dir'or key=='color')then row[key]=Copy(value)end end
   particles[name][#particles[name]+1]=row
  end
 end
 local models,visible=0,0
 for _,model in ipairs(t.view.view.root:GetComponents('StaticModel',true))do models=models+1;if model.enabledEffective then visible=visible+1 end end
 return {camera={position=V3(camera.worldPosition),rotation=Q4(camera.worldRotation),fov=t.camera:GetCamera().fov},
  worldTime=t.world.time,effectsTime=t.effects.time,shots=t.world.stats.shots,energy=t.weapons.energy,
  body=V3(t.vehicle.body.center()),pose=Copy(t.practice.player.current),particles=particles,
  firstPerson=t.firstPerson==true,scope=t.scope==true,models=models,visible=visible,
  persistentVisible=t.view.view.weaponEffects.visible==true}
end
local function Emit()
 local t=app and app.trial
 local current=t and state.attached and Invariants(t)or {}
 if state.frozen then assert(Canonical(current)==state.referenceCanonical,'Frozen state changed before observation')end
 local liveTagged={}
 for name,record in pairs(state.records)do liveTagged[name]={}
  for _,entry in ipairs(record.frame.entries)do if entry.tag then
   local key=entry.tag.owner..':'..entry.tag.origin..':'..entry.tag.kind;liveTagged[name][key]=(liveTagged[name][key]or 0)+1
  end end
 end
 local report={stage=state.stage,frozen=state.frozen,frozenFrames=state.frozenFrames,attached=state.attached,
  digest=Hash(current),referenceDigest=state.referenceDigest,invariants=current.camera,
  randomCalls=state.randomCalls,randomSeedCalls=state.randomSeedCalls,
  randomDelta=state.randomCalls-(state.randomAtFreeze or state.randomCalls),
  randomSeedDelta=state.randomSeedCalls-(state.seedAtFreeze or state.randomSeedCalls),
  replay=state.replay,tagged=state.tagged,liveTagged=liveTagged,freezeRejected=state.freezeRejected,scope={firstPerson=current.firstPerson,scope=current.scope,
   models=current.models,visible=current.visible,persistentVisible=current.persistentVisible},
  centerRegion={left=.25,top=.25,right=.75,bottom=.8},
  boundary='QA geometry attribution only. Same recorded accepted quads and clock; no effects Update(0). outsideOwnPersistent includes own weapon motion. Confirm A1/A2 center pixels and invariant digest before attributing B. Not FPS or mobile acceptance.'}
 print('ADS_PIXEL_STATE '..cjson.encode(report))
end
local random=math.random
math.random=function(...)state.randomCalls=state.randomCalls+1;return random(...)end
local randomseed=math.randomseed
math.randomseed=function(...)state.randomSeedCalls=state.randomSeedCalls+1;return randomseed(...)end
local function Attach(t)
 if state.attached or not t or not t.effects or not t.view or not t.view.view then return end
 local fx=t.view.view.weaponEffects;if not fx then return end
 local ownUpdate=fx.Update
 fx.Update=function(self,...)
  ownDepth=ownDepth+1;local result=table.pack(pcall(ownUpdate,self,...));ownDepth=ownDepth-1
  if not result[1]then error(result[2],0)end;return table.unpack(result,2,result.n)
 end
 local effects=t.effects;local equipment=effects.EquipmentEmit
 local motion=WeaponView.Update
 WeaponView.Update=function(view,...)
  local own=view==t.view.view
  if own then ownMotionDepth=ownMotionDepth+1 end
  local result=table.pack(pcall(motion,view,...))
  if own then ownMotionDepth=ownMotionDepth-1 end
  if not result[1]then error(result[2],0)end;return table.unpack(result,2,result.n)
 end
 effects.EquipmentEmit=function(self,kind,position,...)
  local before={};for _,list in ipairs({self.particles,self.smoke})do for _,item in ipairs(list)do before[item]=true end end
  local owner=ownDepth>0 and 'ownPersistent'or 'outsideOwnPersistent'
  local origin=ownDepth>0 and 'ownPersistent'or ownMotionDepth>0 and 'ownMotion'or 'otherEquipment'
  local result=table.pack(equipment(self,kind,position,...))
  for _,name in ipairs({'particles','smoke'})do for _,item in ipairs(self[name])do if not before[item]then
   tags[item.pos]={owner=owner,origin=origin,kind=kind,list=name}
  end end end
  return table.unpack(result,1,result.n)
 end
 for _,name in ipairs({'Glow','Smoke','Streak'})do
  state.records[name]=AdsPixelBatch.New(effects.batches[name],function(position)return tags[position]end)
 end
 state.attached=true
 print('ADS_PIXEL_READY actual instance recorders attached; F8 freeze; frozen 0 baseline, 8 motionOnly, 9 allEquipment, 7 noStreak; F9 state; F8 resume')
end
local function Replay(stage)
 assert(state.frozen,'Frozen captured frame required');state.stage=stage;state.replay={}
 for _,name in ipairs({'Glow','Smoke','Streak'})do
  local function Omit(entry)
   if stage=='noStreak'then return name=='Streak'end
   if name=='Streak'or not entry.tag then return false end
   if stage=='motionOnly'then return entry.tag.origin=='ownMotion'end
   return stage=='allEquipment'
  end
  state.replay[name]=state.records[name]:Replay(state.frames[name],Omit)
 end
 assert(Canonical(Invariants(app.trial))==state.referenceCanonical,'Camera, FX or simulation changed while frozen')
 Emit()
end
local freezeRequested=false
local snapshotRequested=false
local update=HandleUpdate
function HandleUpdate(...)
 if state.frozen then
  if input:GetKeyPress(KEY_F8)then
   Replay('baseline');state.frozen=false;state.stage='live';print('ADS_PIXEL_RESUMED')
  elseif input:GetKeyPress(KEY_0)then Replay('baseline')
  elseif input:GetKeyPress(KEY_8)then Replay('motionOnly')
  elseif input:GetKeyPress(KEY_9)then Replay('allEquipment')
  elseif input:GetKeyPress(KEY_7)then Replay('noStreak')
  elseif input:GetKeyPress(KEY_F9)then Emit()end
  return
 end
 -- Reserve the QA freeze key before DebugPanel.Update can pause/release ADS.
 -- Keep the last completed production Update/PostUpdate and its actual geometry.
 if input:GetKeyPress(KEY_F8)then freezeRequested=true;return end
 update(...);Attach(app and app.trial)
 if input:GetKeyPress(KEY_F9)then snapshotRequested=true end
end
local post=HandlePostUpdate
function HandlePostUpdate(...)
 if state.frozen then state.frozenFrames=state.frozenFrames+1;return end
 if not freezeRequested then
  post(...)
  if snapshotRequested then snapshotRequested=false;Emit()end
  return
 end
 freezeRequested=false
 local t=app and app.trial
 assert(state.attached and t and t.firstPerson and t.scope,'Freeze only after actual ADS')
 local reference=Invariants(t);state.referenceDigest=Hash(reference);state.referenceCanonical=Canonical(reference)
 state.frames={};state.tagged={}
 for _,name in ipairs({'Glow','Smoke','Streak'})do
  local frame=state.records[name]:Snapshot();state.frames[name]=frame;state.tagged[name]={}
  for _,entry in ipairs(frame.entries)do if entry.tag then
   local key=entry.tag.owner..':'..entry.tag.origin..':'..entry.tag.kind;state.tagged[name][key]=(state.tagged[name][key]or 0)+1
  end end
 end
 local motionCount=0
 for _,entry in ipairs(state.frames.Glow.entries)do if entry.tag and entry.tag.origin=='ownMotion'then motionCount=motionCount+1 end end
 if motionCount==0 then state.freezeRejected='No actual own-motion EquipmentEmit Glow in this frame';Emit();return end
 state.freezeRejected=nil
 state.frozen=true;state.frozenFrames=0;state.randomAtFreeze=state.randomCalls;state.seedAtFreeze=state.randomSeedCalls
 Replay('baseline')
end
local presented=HandleFramePresented
function HandleFramePresented(...)if not state.frozen then return presented(...)end end

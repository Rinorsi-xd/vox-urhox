-- Dedicated QA suffix: unchanged production main/modules, explicit synthetic
-- connected chassis using genuine catalog parts. Never changes persistent saves.
_G.VOX_SKIP_TUTORIAL=true
do
local Blueprint=require 'construction.Blueprint'
local Spec=require 'drive.VehicleSpec'
local UI=require 'urhox-libs/UI'
local Math3=require 'core.Math3'
local ReticleState=require 'ui.ReticleState'
local fixture,target,placement=nil,nil,nil
local sequence=0
local pendingSnapshot=false
local samples={normal=0,scoped=0,hiddenViolations=0,normalMax={},scopedMax={}}
-- QA counters only: these wrappers add observer work and are never a FPS probe.
local emission={attached=false,totals={},draws={},latest={},postUpdateBatches={}}
local particleTags=setmetatable({},{__mode='k'})
local positionTags=setmetatable({},{__mode='k'})
local wrapped=setmetatable({},{__mode='k'})
local ownPersistentDepth=0
local function Bucket(root,key)
 local b=root[key];if not b then b={calls=0,particlesAdded=0,smokeAdded=0,near2m=0,nearHalfMeter=0,behindCamera=0,accepted=0,acceptedNear2m=0,acceptedNearHalfMeter=0,acceptedBehindCamera=0};root[key]=b end;return b
end
local function CameraDistance(t,p)
 local node=t.camera:GetNode();local c=node.worldPosition;local forward=node.worldRotation*Vector3.FORWARD
 local x,y,z=p[1]+c.x,p[2]-c.y,p[3]-c.z
 return x*x+y*y+z*z,x*(-forward.x)+y*forward.y+z*forward.z
end
local function CountDistance(bucket,t,p)
 local d,depth=CameraDistance(t,p)
 if d<=4 then bucket.near2m=bucket.near2m+1 end
 if d<.25 then bucket.nearHalfMeter=bucket.nearHalfMeter+1 end
 if depth<0 then bucket.behindCamera=bucket.behindCamera+1 end
 return d,depth
end
local function AttachEmissionObserver(t)
 local effects=t.effects;local fx=t.view and t.view.view and t.view.view.weaponEffects
 if not effects or not fx then return end
 if not wrapped[fx]then
  wrapped[fx]=true;local original=fx.Update
  fx.Update=function(self,...)
   ownPersistentDepth=ownPersistentDepth+1
   local result=table.pack(pcall(original,self,...));ownPersistentDepth=ownPersistentDepth-1
   if not result[1]then error(result[2],0)end;return table.unpack(result,2,result.n)
  end
 end
 if wrapped[effects]then return end
 wrapped[effects]=true;emission.attached=true;emission.attachedAtSequence=sequence
 emission.boundary='Instance-only QA. ownPersistent identifies actual own WeaponEffects.Update; outsideOwnPersistent includes own WeaponView motion emits and must not be called enemy. Weak keys tag actual new objects; zero random emissions are valid. Counts and screenshots are not timing/FPS evidence.'
 local original=effects.EquipmentEmit
 effects.EquipmentEmit=function(self,kind,p,...)
  local before={};for _,list in ipairs({self.particles,self.smoke})do for _,item in ipairs(list)do before[item]=true end end
  local owner=ownPersistentDepth>0 and 'ownPersistent'or 'outsideOwnPersistent'
  local phase=t.firstPerson==true and 'scoped'or 'normal';local key=phase..':'..owner..':'..tostring(kind)
  local bucket=Bucket(emission.totals,key);bucket.calls=bucket.calls+1
  local result=table.pack(original(self,kind,p,...))
  for _,name in ipairs({'particles','smoke'})do for _,item in ipairs(self[name])do if not before[item]then
   local tag={owner=owner,kind=tostring(kind),emittedPhase=phase,list=name}
   particleTags[item]=tag;positionTags[item.pos]=tag
   local field=name=='particles'and 'particlesAdded'or 'smokeAdded';bucket[field]=bucket[field]+1
  end end end
  if phase=='scoped'then
   local d,depth=CountDistance(bucket,t,p)
   local latest=emission.latest;latest[#latest+1]={owner=owner,kind=tostring(kind),pos={p[1],p[2],p[3]},distanceSquared=d,depth=depth,effectsFirstPerson=self.firstPerson==true,persistentVisible=fx.visible==true}
   if #latest>6 then table.remove(latest,1)end
  end
  return table.unpack(result,1,result.n)
 end
 for _,name in ipairs({'Glow','Smoke'})do local batch=effects.batches[name]
  if batch then local disc=batch.Disc
   batch.Disc=function(self,p,...)
    local tag=positionTags[p];local before=self.count
    local result=table.pack(disc(self,p,...))
    if tag then
     local phase=t.firstPerson==true and 'scoped'or 'normal'
     local bucket=Bucket(emission.draws,phase..':'..tag.owner..':'..tag.kind..':'..name)
     bucket.calls=bucket.calls+1;local d,depth=CountDistance(bucket,t,p)
     if self.count>before then
      bucket.accepted=bucket.accepted+1
      if d<=4 then bucket.acceptedNear2m=bucket.acceptedNear2m+1 end
      if d<.25 then bucket.acceptedNearHalfMeter=bucket.acceptedNearHalfMeter+1 end
      if depth<0 then bucket.acceptedBehindCamera=bucket.acceptedBehindCamera+1 end
     end
    end
    return table.unpack(result,1,result.n)
   end
  end
 end
end
local function EmissionSnapshot(t)
 local live={}
 for _,name in ipairs({'particles','smoke'})do for _,item in ipairs(t.effects[name])do
  local tag=particleTags[item];local key=name..':'..(tag and tag.owner or 'unattributed')..':'..(tag and tag.kind or 'other')
  local bucket=Bucket(live,key);bucket.calls=bucket.calls+1;CountDistance(bucket,t,item.pos)
 end end
 return {attached=emission.attached,attachedAtSequence=emission.attachedAtSequence,boundary=emission.boundary,totals=emission.totals,draws=emission.draws,latest=emission.latest,live=live,postUpdateBatches=emission.postUpdateBatches}
end
local function Finite(n)return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function Validate(v,path,seen)
 local t=type(v)
 if t=='number'then assert(Finite(v),'Nonfinite scope QA '..path)
 elseif t=='table'then assert(not seen[v],'Cyclic scope QA '..path);seen[v]=true;for k,x in pairs(v)do Validate(x,path..'.'..tostring(k),seen)end;seen[v]=nil
 else assert(t=='nil'or t=='string'or t=='boolean','Unsupported scope QA '..path)end
end
local function Checksum(text)
 local hash=2166136261;for i=1,#text do hash=((hash~text:byte(i))*16777619)&0xffffffff end;return hash
end
local function Emit(data)
 Validate(data,'state',{});local text=cjson.encode(data)
 local okay,decoded=pcall(cjson.decode,text);assert(okay and decoded~=nil,'Incomplete scope QA cjson '..#text..' '..text:sub(-100))
 local chunks={};local first=1
 while first<=#text do local last=math.min(first+599,#text)
  while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<192 do last=last-1 end
  chunks[#chunks+1]=text:sub(first,last);first=last+1
 end
 for i,p in ipairs(chunks)do print('SCOPE_FX_CHUNK '..cjson.encode({kind='state-'..sequence,index=i,count=#chunks,bytes=#text,checksum=Checksum(text),data=p}))end
end
local function Build()
 assert(app and app.mode=='hangar' and not app.loadingFlow.active and not fixture,'One isolated fixture per process')
 local bp=Blueprint.New();bp.name='QA T5 scope fixture'
 bp:Add{type='core',pos={0,0,0}}
 for x=-15,15 do if x~=0 then bp:Add{type='cube',pos={x,0,0}}end end
 for i,id in ipairs({'mg5','laser5','sniper5','missile5'})do bp:Add{type=id,pos={-25+i*10,1,0}}end
 local occupied={}
 for _,p in ipairs(bp:List())do for _,c in ipairs(p._cells)do
  local k=table.concat(c,',');assert(not occupied[k],'QA part overlap '..k);occupied[k]=p.id
 end end
 local spec=Spec.Build(bp);assert(spec.ok and spec.dropped==0 and #spec.weapons==4,'Real connected four-weapon spec required')
 fixture={name=bp.name,parts=bp:Size(),weapons={},synthetic=true,source='Imported Catalog T5 parts; connected light-block beam; no mobility or gameplay balance acceptance'}
 for _,w in ipairs(spec.weapons)do fixture.weapons[#fixture.weapons+1]={type=w.type,partId=w.partId}end
 -- The ordinary map loading path reads this blueprint and builds genuine
 -- CarUnit, WeaponSystem and DriveView. No garage store operation is invoked.
 app.blueprint=bp;assert(app:EnterTrial('trial'),'Real trial entry rejected')
end
local function Center(unit)local p=unit.vehicle.body.center();return {p.x,p.y,p.z}end
local function Aim(point)
 local t=app.trial
 for _=1,6 do local p=t.camera:GetNode().worldPosition
  local dx,dy,dz=point[1]+p.x,point[2]-p.y,point[3]-p.z
  t.yaw=-math.atan(dx,dz)*180/math.pi;t.pitch=-math.atan(dy,math.sqrt(dx*dx+dz*dz))*180/math.pi;t:PostUpdate(.016)
 end
end
local function Setup()
 local t=app and app.trial;assert(fixture and t and not app.loadingFlow.active and t.practice,'Loaded actual trial required')
 if not placement then
  for _,unit in ipairs(t.world.units)do if unit~=t.practice.player and unit.alive then target=unit;break end end
  assert(target and target.vehicle,'Actual parked target required')
  local v=t.practice.player.spec.bounds;local chosen=nil
  for _,x in ipairs({145,120,-145,-120})do
   local a={x,0,-105};local b={x,0,70};local flat=true
   for _,z in ipairs({-105,-70,-20,30,70})do if math.abs(t.world:GroundAt(x,z))>.1 then flat=false end end
   if flat and not t.world.space:Raycast({x,3,-105},{0,0,1},175,nil,'car',true,1)then chosen={a,b};break end
  end
  assert(chosen,'No safe actual track lane for lock test')
  t.vehicle:Place(chosen[1],0);t.practice.player:SavePose();t.practice.player.previous=t.practice.player.current
  target.vehicle:Place(chosen[2],math.pi);target:SavePose();target.previous=target.current
  t.view:ResetPose();t:ResetCamera()
  placement={player=chosen[1],target=chosen[2],targetName=target.name,controlled=true,bounds=v}
 end
 local point=Center(target)
 if t.weapons:Group().kind~='missile'then point[2]=point[2]+45 end
 Aim(point)
end
local function Observe()
 local t=app and app.trial;if not fixture or not t or app.loadingFlow.active then return end
 AttachEmissionObserver(t)
 local scoped=t.firstPerson==true;local maxima=scoped and samples.scopedMax or samples.normalMax
 if scoped then samples.scoped=samples.scoped+1 else samples.normal=samples.normal+1 end
 local fx=t.view.view.weaponEffects
 if fx then for kind,b in pairs(fx.batches)do maxima[kind]=math.max(maxima[kind]or 0,b.count)
  if scoped and b.mesh.enabled then samples.hiddenViolations=samples.hiddenViolations+1 end
 end end
 for _,name in ipairs({'Glow','Smoke'})do local b=t.effects.batches[name];if b then emission.postUpdateBatches[name]={count=b.count,enabled=b.mesh.enabled,firstPerson=scoped}end end
end
local function Snapshot()
 if not app then return end;sequence=sequence+1
 local width,height=UI.GetViewportSize();local data={sequence=sequence,samplePhase='post-update',width=width,height=height,mode=app.mode,loading=app.loadingFlow.active,fixture=fixture,placement=placement,widgets={}}
 data.reticle={compact=ReticleState.Compact(),layout=ReticleState.Layout(width,height),physicalWidth=graphics:GetWidth(),physicalHeight=graphics:GetHeight(),dpr=graphics:GetDPR()}
 local tutorial=app.tutorial
 if tutorial and tutorial.visible then for _,b in ipairs(tutorial.page.buttons or{})do
  if Finite(b.x)and Finite(b.y)and Finite(b.w)and Finite(b.h)then data.widgets[#data.widgets+1]={text=b.text,rect={b.x,b.y,b.w,b.h}}end
 end end
 local t=app.trial
 if t then
  local fx=t.view.view.weaponEffects;local group=t.weapons:Group();local camera=t.camera:GetCamera();local models,visible=0,0
  for _,m in ipairs(t.view.view.root:GetComponents('StaticModel',true))do models=models+1;if m.enabledEffective then visible=visible+1 end end
  data.trial={map=t.map.id,captured=t.pointer.captured,firstPerson=t.firstPerson==true,scope=t.scope==true,group=group and group.kind,selected=t.weapons.current,groups={},models=models,visible=visible,
   shots=t.world.stats.shots,energy=t.weapons.energy,projectiles=#t.weapons.projectiles,beams=#t.effects.beams,ownsWeapons=t.effects.ownWeapons==t.weapons,
   effectsFirstPerson=t.effects.firstPerson==true,weaponFx={visible=fx and fx.visible==true,batches={}},lock=t.weapons:LockInfo(),samples=samples,
   position=Center(t.practice.player),camera={fov=camera.fov},alive=t.practice.player.alive}
  data.trial.equipmentEmit=EmissionSnapshot(t)
  local lock=data.trial.lock;if lock then lock.ref=nil end
  for i,g in ipairs(t.weapons.groups)do data.trial.groups[i]={kind=g.kind,types=g.types}end
  if fx then for kind,b in pairs(fx.batches)do data.trial.weaponFx.batches[kind]={count=b.count,enabled=b.mesh.enabled}end end
  local projected=t.effects:Projectiles(t.weapons.projectiles);data.trial.projected=#projected;data.trial.nearOwn=0
  for _,p in ipairs(t.weapons.projectiles)do if p.dist<=(p.fx=='missile'and 6 or 12)then data.trial.nearOwn=data.trial.nearOwn+1 end end
 end
 Emit(data)
end
local update=HandleUpdate
function HandleUpdate(...)
 update(...)
 if input:GetKeyPress(KEY_F7)then Build()end
 if input:GetKeyPress(KEY_F6)then Setup()end
 if input:GetKeyPress(KEY_F9)then pendingSnapshot=true end
end
local post=HandlePostUpdate
function HandlePostUpdate(...)
 post(...);Observe()
 if pendingSnapshot then pendingSnapshot=false;Snapshot()end
end
end

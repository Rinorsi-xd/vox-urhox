local checks,callbacks,cancellations=0,0,0
local function Check(ok,name)assert(ok,name);checks=checks+1 end
local function Equal(a,b,seen)
 if a==b then return true end
 if type(a)~='table' or type(b)~='table' then return false end
 seen=seen or {};if seen[a] then return seen[a]==b end;seen[a]=b
 for k,v in pairs(a)do if not Equal(v,b[k],seen)then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
package.path='scripts/?.lua;'..package.path
package.loaded['core.ResourceData']={Read=read_resource}
package.loaded['combat.EnemyDriver']={New=function(_,unit,role,index)return{unit=unit,role=role,index=index}end}
local liveBodies,liveViews=0,0
package.loaded['render.DriveView']={New=function(_,bp,vehicle,checkpoint,retain)
 local view={disposed=false,vehicle=vehicle,view={SetVisible=function()end},equipment={}}
 function view:Dispose()if not self.disposed then self.disposed=true;liveViews=liveViews-1 end end
 liveViews=liveViews+1;retain(view)
 for i=1,bp:Size()do if checkpoint then checkpoint(i/bp:Size())end end
 return view
end}
local Unit=require 'combat.CarUnit'
local BP=require 'construction.Blueprint'
local Battle=require 'intro.IntroBattle'
local Pool=require 'intro.IntroMontagePool'
local data=read_resource('Intro/Intro.json')
local source=data.actors.hero
local function Session()
 local world={time=0,units={},viewEvents={},stats={}}
 function world:GroundAt()return 3 end
 function world:NewVehicle(spec)
  liveBodies=liveBodies+1;local position={x=0,y=0,z=0};local yaw=0
  local vehicle={native={enabled=true},disposed=false,spec=spec}
  function vehicle:Place(p,y)position={x=p[1],y=p[2],z=p[3]};yaw=y end
  function vehicle:Dispose()if not self.disposed then self.disposed=true;liveBodies=liveBodies-1 end end
  vehicle.body={translation=function()return position end,rotation=function()return{x=0,y=math.sin(yaw/2),z=0,w=math.cos(yaw/2)}end,center=function()return position end}
  return vehicle
 end
 return {world=world,scene={}}
end
local function Dispose(session)
 if session.combat then session.combat:Dispose()end
 for _,unit in ipairs(session.world.units)do unit:Dispose()end
 session.world.units={};session.world.viewEvents={}
 Check(liveBodies==0 and liveViews==0,'all retained native/view adapters retired')
end
local function Snapshot(battle)
 local result={}
 for i,e in ipairs(battle.entries)do local u=e.unit
  result[i]={spec=u.spec,hp=u.hp,bodyHp=u.bodyHp,bodyHpMax=u.bodyHpMax,source=u.source,
   team=u.team,name=u.name,spawnAt=u.spawnAt,position=u:Position(),
   role=e.driver and e.driver.role,index=e.driver and e.driver.index,
   externalView=u.externalView,externalControl=u.externalControl,autoRespawn=u.autoRespawn}
 end
 return result
end
local plain=Session();local expected=Snapshot(Battle.New(plain,data,source))
Check(#expected==9 and plain.combat.player==plain.world.feedbackPlayer,'exact nine-actor roster and damage feedback owner')
Check(expected[1].externalView and expected[1].externalControl and not expected[1].autoRespawn,'source teaching controls preserved')
Check(plain.combat.easy==plain.combat.entries[6].unit and plain.combat.cart==plain.combat.entries[9].unit,'original easy target and cart indices preserved')
Dispose(plain)
local session=Session();local phases={};local previous=-1
local co=coroutine.create(function()
 return Battle.New(session,data,source,function(p,stage)
  callbacks=callbacks+1
  Check(stage=='intro-actors' and p>=previous and p<=1,'battle progress monotonic');previous=p
  local battle=session.combat;local index=#battle.entries;local entry=battle.entries[index]
  Check(entry and entry.unit==session.world.units[index] and #battle.entries==#session.world.units,'partial actor owned by world before every checkpoint')
  local localP=p*9-index+1
  local key=index..':'..(localP<.75 and 'spec' or localP<.85 and 'hp' or localP<.9 and 'graph' or localP<.99999 and 'prebody' or 'complete')
  if not phases[key]then phases[key]=callbacks end
  coroutine.yield(p)
 end)
end)
local result
repeat
 local ok,value=coroutine.resume(co);Check(ok,tostring(value));result=value
until coroutine.status(co)=='dead'
Check(previous==1 and callbacks>1000,'battle forwards real part-level construction checkpoints through completion')
Check(Equal(Snapshot(result),expected),'checkpointed real full specs, health, placement, roles and configs equal synchronous construction')
Dispose(session)
local function CancelBattle(at)
 local s=Session();local count=0
 local task=coroutine.create(function()Battle.New(s,data,source,function()
  count=count+1;if count==at then coroutine.yield('cancel')end
 end)end)
 local ok,value=coroutine.resume(task);Check(ok and value=='cancel','cancel reaches selected actual assembly checkpoint')
 Dispose(s);Check(coroutine.close(task),'cancel closes suspended assembly');Dispose(s);cancellations=cancellations+1
end
local indices={};for _,at in pairs(phases)do indices[#indices+1]=at end;table.sort(indices)
for _,at in ipairs(indices)do CancelBattle(at)end
local function Montage(cancelPhase)
 local s=Session();local battle={};s.combat=battle
 function battle:Dispose()if self.montage then self.montage:Dispose()end end
 local last=-1;local count=0;local bodyAtCancel
 local task=coroutine.create(function()
  return Pool.New(s,battle,source,function(p)
   callbacks=callbacks+1;count=count+1
   Check(p>=last and p<=1,'montage progress monotonic');last=p
   local pool=battle.montage
   Check(pool and pool.unit and pool.unit.source==source,'held unit owned before every checkpoint')
   Check(#s.world.units==0,'standby actor excluded from active roster')
   if p>=.3 then Check(pool.view~=nil,'partially assembled view owned before every view checkpoint')end
   if cancelPhase and ((cancelPhase=='unit' and p<.3)or(cancelPhase=='prebody' and p>=.27 and p<.3)or(cancelPhase=='view' and p>=.3))then
    bodyAtCancel=pool.unit.vehicle;coroutine.yield('cancel')
   end
  end)
 end)
 local ok,value=coroutine.resume(task);Check(ok,tostring(value))
 if cancelPhase then
  Check(value=='cancel','montage cancellation phase reached '..cancelPhase)
  Dispose(s);Check(coroutine.close(task),'held assembly closes at '..cancelPhase);Dispose(s)
  if bodyAtCancel then Check(bodyAtCancel.disposed,'constructed held native body retired')end
  cancellations=cancellations+1
 else
  local pool=value
  Check(coroutine.status(task)=='dead' and pool.unit.alive and pool.unit.bp:Size()==431,'full original hero retains 431 parts')
  Check(not pool.unit.vehicle.native.enabled and #s.world.viewEvents==0,'standby disables native body and removes all own spawn events')
  Check(Equal(pool.unit.spec,expected[1].spec)and Equal(pool.unit.hp,expected[1].hp),'montage exact original actor spec and health unchanged')
  Check(count>431 and last==1,'real unit assembly and all original hero view parts emit checkpoints')
  Dispose(s);Dispose(s)
 end
end
Montage();Montage('unit');Montage('prebody');Montage('view')
return {checks=checks,callbacks=callbacks,cancellationCases=cancellations,battlePhaseCases=#indices,
 actualActors=#expected,originalHeroParts=BP.New():Load(source):Size()}

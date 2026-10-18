local args=GetArguments
GetArguments=function() local a=args();a[#a+1]='-validate';a[#a+1]='-dev';return a end
-- A distinct local namespace prevents the probe from touching player saves.
local Store=require 'storage.BlueprintStore';local new=Store.New
Store.New=function(namespace) return new('vox-delta-20261018-'..(namespace or 'main')) end
require 'main'
local update=HandleUpdate;local views=HandleViewsRendered
local frames=0;local app;local stage='boot';local work;local pending
local function Check(ok,label) assert(ok,label);print('[DELTA GAME] PASS '..label) end
local function Wait(n) for i=1,n do coroutine.yield() end end
local function Shot(name)
 local signal=File('delta-20261018-shot.txt',FILE_WRITE);signal:WriteString(name);signal:Dispose()
 print('[DELTA SHOT] '..name);Wait(90)
end
function HandleViewsRendered(...)
 views(...)
 if pending then local img=Image();graphics:TakeScreenShot(img);Check(img:SavePNG('delta-'..pending..'.png'),'screenshot '..pending);img:Dispose();pending=nil end
end
local function Exercise(s)
 local r=s.salvage;s.Update=function() end
 Check(r.begun and #r.rules.objects>180,'salvage production scene loaded')
 s.pointer.captured=true
 for i=1,600 do s:Tick(1/60,{throttle=0,steer=0});r.cine:Update(1/60);if i%10==0 then Wait(1) end end
 Check(r.landed and not r.cine.blocking,'drop cinematic completes')
 Check(r.player.alive and r.player:Position()[2]>-300,'player stable after landing')
 r.gear.pocket={repair=3,shieldCell=2,smokePack=3,scanner=2}
 r.gear:Tap();r.gear:Move(0,-40);s.hud.Update(s,.016);Wait(3);Shot('gear-wheel')
 r.gear:Use(2);r.gear:Use(3);r.gear:Use(4)
 for i=1,90 do s:Tick(1/60,{throttle=0,steer=0});r.cine:Update(1/60);if i%10==0 then Wait(1) end end
 Check(r.gear.shield>0 and r.gear.smoke and r.gear.scanTime>0,'gear effects live')
 Shot('gear-effects')
 local p=r.player:Position()
 r.rules:AddExtra({id='probe-drop',kind='kill',name='测试掉落',tier=3,g={p[1]+8,p[2],p[3]},loot={{'scrap',2,2,1}}})
 r.markers.combatUntil=0;r.session.firing=false;r.player.hitAt=-100;r.player.weapons.sinceUse=100
 r.markers:Update(.1);Check(r.markers.entries['probe-drop']~=nil,'persistent drop mesh constructed')
 local kindCount=0
 for kind,defs in pairs(require('core.ResourceData').Read('Salvage/RunData.json').enemies) do
  local spec=require('drive.VehicleSpec').Build(require('construction.Blueprint').New():Load(defs[1].source))
  Check(spec.ok,'enemy spec '..kind);kindCount=kindCount+1
 end
 local rival=r.rivals.squads[1];Check(r.rivals:Spawn(rival),'rival squad spawns through production director')
 for i=1,120 do s:Tick(1/60,{throttle=0,steer=0});r.cine:Update(1/60);if i%10==0 then Wait(1) end end
 Check(#rival.units>0 and rival.goal~=nil,'rival chooses crate and drives')
 Shot('salvage-map')
 print('[DELTA GAME] PASS complete enemies='..kindCount)
end
function HandleUpdate(t,e)
 local ok,err=xpcall(function()
  update(t,e);frames=frames+1
  if frames>6000 then error('timeout stage '..stage) end
  if stage=='boot' and VOX_HANGAR and not VOX_HANGAR.app.loadingFlow.active and frames>60 then
   app=VOX_HANGAR.app
   require('ui.GarageHud').GetState().SetLobby('salvage');stage='warehouse'
  elseif stage=='warehouse' and app.warehouse and app.warehouse.ready then
   Check(app:EnterTrial('salvage'),'start production salvage');stage='loading'
  elseif stage=='loading' and app.trial and not app.loadingFlow.active then
   work=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
  elseif stage=='exercise' then
   local good,message=coroutine.resume(work);if not good then error(debug.traceback(work,message)) end
   if coroutine.status(work)=='dead' then stage='done';engine:Exit() end
  end
 end,debug.traceback)
 if not ok then print('[DELTA GAME] FAIL '..tostring(err));stage='failed';engine:Exit() end
end

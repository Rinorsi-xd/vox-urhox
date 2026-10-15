-- Inject only the input command. All actors, physics, weapons, damage, effects
-- and snapshots below are the production opening host on the authored map.
local I=nil;local phase=0;local at=0;local start=nil;local finished=false
local function Shot(name)
 local image=Image:new();V.assert(graphics:TakeScreenShot(image),'live opening screenshot available')
 V.assert(image:SavePNG('docs/migration/evidence/intro-live-'..name..'.png'),'saved actual '..name);image:Dispose()
end
local function Poll()
 if finished then return end
 local app=VOX_HANGAR and VOX_HANGAR.app;if not app or app.loadingFlow.active then return end
 if not I then V.assert(app:StartOpening(),'live opening app entry starts');I=app.opening;return end
 if I.failed then V.assert(false,'live opening error: '..tostring(I.error));I:Finish();V.finish();finished=true;return end
 if not I.ready then return end
 local s=I.host.state.session
 if phase==0 then
  I.thread=nil;I.stage='ad';I:Mark('idyll','garage');phase=1;at=I.time
 elseif phase==1 and I.time-at>3 then
  V.assert(not app.tutorial or not app.tutorial.visible,'opening owns UI without tutorial overlap')
  V.assert(I.host.state.garage.root.enabled and #I.host.state.garage.hovers==3,'original 3 live hover actors and GPU HoloDove enabled')
  Shot('idyll');I:Mark('m-build','garage');I.voiceDuration=I.data.durations.vo_n08;phase=2;at=I.time
 elseif phase==2 and I.time-at>I.data.durations.vo_n08 then
  V.assert(I.host.state.buildIndex==#I.host.state.buildParts,'original hero assembled from all actual part visuals')
  Shot('build');I:Mark('m-drive','crater');I.voiceDuration=I.data.durations.vo_n09;start=s.combat.player:Position();phase=3;at=I.time
 elseif phase==3 and I.time-at>4 then
  local p=s.combat.player:Position();V.assert(math.sqrt((p[1]-start[1])^2+(p[3]-start[3])^2)>2,'S bend live drive moves real rigid body')
  V.assert(s.weapons:Group().kind=='missile','montage selects actual missile group')
  Shot('drive');I:Mark('m-missile','crater');phase=4;at=I.time
 elseif phase==4 and I.time-at>5.3 then
  V.assert(I.host.state.missileLaunched,'real missile salvo launches actual projectiles');Shot('missile')
  local c=s.combat;c.damageScale=.12;c.player.source=app.blueprint:ToTable();c.player:Spawn();c:SyncPlayer()
  c.player.vehicle:Place({62,c.world:GroundAt(62,-176)+1.5,-176},0);s.view:ResetPose()
  if not c.easy.alive then c.easy:Spawn() end;c.easy.vehicle:Place({66,c.world:GroundAt(66,-130)+1.5,-130},math.pi)
  I:Mark('sortie-play','crater');I.playing=true;I.sortie=require('intro.IntroSortie').New(I);I.host.StartSortie(I)
  I.page:OnPointerDown({pointerId=99,pointerType='mouse',x=600,y=500})
  V.assert(s.pointer.captured,'native actual overlay capture hands off controls')
  s.controls.Read=function()
   local p=c.easy:Position();return {throttle=I.sortie.step==1 and 1 or 0,steer=0,handbrake=I.sortie.step~=1,firing=I.sortie.step==2,aim={p[1],p[2]+1,p[3]}}
  end
  phase=5;at=I.time
 elseif phase==5 and I.sortie.step==4 and I.sortie.elapsed>1.9 and not I.checkedStrike then
  I.checkedStrike=true;V.assert(I.host.state.strike and I.host.state.strike.node.enabled,'original ally strike uses live GPU SkyBeam');Shot('strike')
 elseif phase==5 and I.sortie.done then
  V.assert(I.sortie.step==5 and not s.combat.player.alive,'original guided real battle reaches authored destruction')
  V.assert(I.host.state.captures.charge and I.host.state.captures.wreck,'actual battle captures retained for original comic')
  I.playing=false;I.host.EndSortie(I);I:Mark('familiar');phase=6;at=I.time
 elseif phase==6 and I.time-at>1.5 then
  Shot('familiar');I:Finish();V.assert(app.scene==I.host.state.hall and app.car.root.enabled,'live montage returns borrowed hall intact');finished=true;V.finish()
 end
end
for frame=1,3200 do V.atFrame(frame,Poll) end
V.atFrame(3205,function()V.assert(finished,'live opening verification completes');V.finish()end)

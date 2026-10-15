local I;local finished=false;local phase=0;local age=0
local function Shot(name)
 local image=Image:new();V.assert(graphics:TakeScreenShot(image),'actual sortie '..name..' screenshot')
 V.assert(image:SavePNG('docs/migration/evidence/intro-sortie-'..name..'.png'),'saved original sortie '..name);image:Dispose()
end
local function Poll()
 if finished then return end
 local app=VOX_HANGAR and VOX_HANGAR.app;if not app or app.loadingFlow.active then return end
 if not I then
  V.assert(app:StartOpening(),'warmup uses production public opening');I=app.opening
  -- Hidden Runtime has no OS focus. The fixture supplies only focus; browser
  -- natural-flow evidence separately exercises real lock and focus semantics.
  local update=I.Update;I.Update=function(self,dt)return update(self,dt,true)end
  return
 end
 if I.failed then V.assert(false,'opening warmup failed: '..tostring(I.error));I:Finish();finished=true;V.finish();return end
 if not I.ready then
  if I.host.state.warmup and not I.checkedBoot then I.checkedBoot=true;V.assert(I.stage=='boot' and #I.log==0 and not I.playing,'hidden shader warmup never consumes narrative or player control') end
  local warm=I.host.state.warmup
  if warm and warm.phase=='build' and not I.checkedFlashWarmup then
   I.checkedFlashWarmup=true;local seen=false;local flashes={}
   for _,list in pairs(I.host.state.assembly.flashes) do for _,model in ipairs(list) do flashes[model]=true end end
   for _,item in ipairs(warm.batch.items) do if flashes[item.drawable] then seen=true;break end end
   V.assert(seen,'actual visible prewarm batch includes original additive assembly flash shader')
  end
  return
 end
 local state=I.host.state;local s=state.session
 if phase==0 then
  V.assert(state.warmup.completed and state.warmup.index==8,'original scene, crossing and single plus instanced effects warmup poses rendered')
  V.assert(state.warmup.frames>10 and state.warmup.batches>0,'shader warmup advances through actual presented frame batches')
  V.assert(not state.garage.root.enabled and state.garage.time==0,'warmup restores original hidden props and flyby clock')
  local hidden=true;for _,kind in ipairs({'StaticModel','CustomGeometry'}) do for _,drawable in ipairs(state.garage.root:GetComponents(kind,true)) do hidden=hidden and not drawable.enabledEffective end end
  V.assert(hidden,'all original hidden flyby and dove children are effectively disabled after prewarm')
  state.garage:Shot('idyll');local shown=true;for _,kind in ipairs({'StaticModel','CustomGeometry'}) do for _,drawable in ipairs(state.garage.root:GetComponents(kind,true)) do shown=shown and drawable.enabledEffective end end
  V.assert(shown,'idyllic shot effectively enables every original flyby and dove child');state.garage:Shot('sortie-play')
  V.assert(s.combat.player.alive and s.combat.easy.alive and s.combat.stage==0,'warmup leaves original actual actor roster undamaged')
  V.assert(#s.weapons.projectiles==0 and not state.missileLaunched and not state.strike,'warmup never consumes real weapons or creates a real narrative strike')
  V.assert(not state.scene:GetChild('OpeningAllySkyBeam') and #state.scene:GetChildrenWithComponent('CustomGeometry',true)>0,'warmup disposes private effect actors and keeps real map geometry')
  V.assert(state.activeScene=='garage' and not s.pointer.captured,'boot restores original hall and absolute pointer')
  I.heldHero=s.combat.montage.unit;I.heldHeroBody=I.heldHero.vehicle.body;I.heldHeroView=s.combat.montage.view
  V.assert(not I.heldHero.vehicle.native.enabled and #s.combat.entries==9 and #state.world.units==9,'prepared431montage hero stays disabled outside the original nine actor roster')
  V.assert(state.warmup.repeated>0 and state.warmup.frames<750,'actual identical static render combinations are reused within bounded warmup frames')
  I.thread=nil;I.stage='ad';I:Mark('m-build','garage');phase=-1;age=I.time
  I.assemblyModels=#state.hallActor.root:GetComponents('StaticModel',true)
 elseif phase==-1 and I.time-age>I.data.durations.vo_n08+.5 then
  V.assert(state.buildIndex==431 and #state.hallActor.root:GetComponents('StaticModel',true)==I.assemblyModels,'real host montage reveals all original prepared models without rebuilding during voice')
  local full=true;for _,part in ipairs(state.buildParts) do full=full and state.hallActor.visuals[part.id].node.enabled end
  V.assert(full,'actual original hero part nodes are all enabled after source montage')
  Shot('assembly');I:Mark('sortie-play','crater');I.playing=true;I.sortie=require('intro.IntroSortie').New(I);I.host.StartSortie(I)
  I.sortie.origin={table.unpack(s.combat.player:Position())}
  s.HasFocus=function()return true end
  I.page:OnPointerDown({pointerId=99,pointerType='mouse',x=500,y=400});I.sortie:Next(1);phase=1;age=I.time
  s.controls.Read=function()return {throttle=0,steer=0,handbrake=true}end
 elseif phase==1 and I.time-age>.5 then
  V.assert(state.sortieUi.reticle.session==s and state.sortieUi.reticle.hp~=nil,'original shared reticle reads real player life and weapon state')
  Shot('drive');I.sortie:Next(2);phase=2;age=I.time
 elseif phase==2 and I.time-age>.5 then
  local p=s.combat.easy:Position();local x,y=state.sortieUi:Project(p,2.6,1920,1080)
  V.assert(x and y and x>0 and x<1920 and y>0 and y<1080,'original red enemy marker projects actual target on screen')
  Shot('fire');I.sortie:Next(4);phase=3;age=I.time
 elseif phase==3 and I.time-age>1.5 then
  V.assert(I.sortie.step==4 and state.strike,'original ally identification ring runs before real beam destruction')
  Shot('lock');phase=4;age=I.time
 elseif phase==4 and I.sortie.step==5 and I.sortie.elapsed>1.3 then
  V.assert(I.sortie.stamped and not s.combat.player.alive,'authored real destruction reaches original tilted bordered wage stamp')
  Shot('stamp');I.playing=false;I:Mark('m-drive','crater');phase=5;age=I.time;I.montageOrigin=s.combat.player:Position()
  V.assert(s.combat.player==I.heldHero and s.combat.player.vehicle.body==I.heldHeroBody and s.view==I.heldHeroView,'real post-destruction montage transfers exact prepared body and view through actual host')
 elseif phase==5 and I.time-age>2 then
  local p=s.combat.player:Position();local d=math.sqrt((p[1]-I.montageOrigin[1])^2+(p[3]-I.montageOrigin[3])^2)
  V.assert(d>2 and s.combat.player.bp:Size()==431,'prepared original hero drives the real source S bend after activation')
  Shot('montage-drive');I:Mark('m-missile','crater');phase=6;age=I.time
 elseif phase==6 and I.time-age>3 then
  V.assert(state.missileLaunched,'prepared original hero fires real montage missiles without a new Spawn')
  I:Finish();V.assert(app.scene==state.hall and app.car.root.enabled,'warmup and actual teaching/montage finish restore original hall');finished=true;V.finish()
 end
end
for frame=1,1990 do V.atFrame(frame,Poll) end
V.atFrame(1995,function()V.assert(finished,'production shader warmup and original sortie visuals complete');V.finish()end)

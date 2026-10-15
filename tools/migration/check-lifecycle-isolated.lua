-- Real lifecycle modules with engine boundaries stubbed; no Runtime or browser.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local results={}
local function Check(ok,label) assert(ok,label);results[#results+1]=label end
local function Noop() end
local function Module(name,value) package.loaded[name]=value end
local keys={'SPACE','RETURN','ESCAPE','1','2','3','T','BACKSPACE','F5'}
for _,key in ipairs(keys) do _G['KEY_'..key]=key end
MOUSEB_LEFT='left'
input={focus=true,minimized=false,GetMouseButtonPress=function()return false end,
 GetKeyPress=function()return false end,GetKeyDown=function()return false end}
cache={GetNumBackgroundLoadResources=function()return 0 end}
local UI={GetFocus=function()return nil end}
Module('urhox-libs/UI',UI)
Module('Config',{TIERS={{}}})
Module('construction.Blueprint',{})
Module('construction.Prefab',{})
local VehicleView,Hangar,OrbitCamera={},{},{}
Module('render.VehicleView',VehicleView)
Module('scene.Hangar',Hangar)
Module('controls.OrbitCamera',OrbitCamera)
local hud={GetState=function()return nil end,Create=Noop,Refresh=Noop}
Module('ui.GarageHud',hud)
Module('app.HotReload',{})
Module('render.Quality',{})
Module('audio.StoryComms',{Tick=Noop})
Module('storage.BlueprintStore',{UpdateAll=Noop})
Module('app.ResourceGate',{UpdatePending=Noop})
Module('render.RenderTargetLifetime',{Update=Noop})
Module('core.Coord',{Vec=function(...)return {...}end})
Module('intro.IntroShots',{Camera=function()return nil end})
Module('app.SceneLoader',{New=function()return {Update=Noop}end})
local App=require('app.HangarApp')
local Host=require('app.OpeningHost')
local function Owner()
 local calls={update=0,post=0,trialUpdate=0,trialPost=0,loader=0,hidden=0,tick=0}
 local owner=setmetatable({stopped=false,mode='trial',scene={},tier=1,generation=0,view='',partsPage=0,
  music={Update=Noop},previews={Update=Noop},loader={state='ready',Update=function()calls.loader=calls.loader+1 end},
  graphicsSettings={Update=function()calls.update=calls.update+1 end,PostUpdate=function()calls.post=calls.post+1 end,
   SetSceneVisible=function(_,visible)if not visible then calls.hidden=calls.hidden+1 end end,Apply=Noop,Show=Noop},
  loadingFlow={active=false,finished=false,pageVisible=true,Advance=Noop,Observe=Noop},
  tutorial={Keys=function()return false end,DetachVoice=Noop}},App)
 local trial={Update=function()calls.trialUpdate=calls.trialUpdate+1 end,
  PostUpdate=function()calls.trialPost=calls.trialPost+1 end}
 owner.trial=trial
 return owner,calls,trial
end
local function Frame(owner) owner:Update(1/60);owner:PostUpdate(1/60) end
do
 local app,c=Owner();app.loadingFlow.active=true
 Frame(app)
 Check(c.trialUpdate==0 and c.trialPost==0,'covered old trial does not update or post-update')
 Check(c.update==1 and c.post==1,'covered load keeps one graphics update and post-update')
 Check(c.hidden==1,'covered pre-commit scene stays hidden')
 app.loadingFlow.finished=true;Frame(app)
 Check(c.trialUpdate==0 and c.trialPost==1,'installed candidate post-update survives warm-up cover')
 Check(c.hidden==1,'candidate warm-up is not hidden again after Finish')
 app.loadingFlow.active=false;Frame(app)
 Check(c.trialUpdate==1 and c.trialPost==2,'ordinary trial resumes after loading closes')
end
for _,phase in ipairs({'boot','warmup','ready','playing','failed','finish'}) do
 local app,c=Owner();app.trial=nil
 local host=Host.New(app);local state=host.state
 state.activeScene='crater'
 local session={pointer={captured=false,Poll=Noop},Pause=Noop,
  Tick=function()c.tick=c.tick+1 end,PostUpdate=function()c.trialPost=c.trialPost+1 end}
 local I={active=true,ready=phase=='ready' or phase=='playing' or phase=='finish',failed=phase=='failed',
  playing=phase=='playing',shot='blank',age=0,time=0}
 if phase~='boot' then state.session=session end
 if phase=='warmup' then state.warmup={disposed=false} end
 I.KeyDown=Noop;I.KeyUp=Noop
 I.Update=function(self,dt)
  host.Update(dt,self)
  if phase=='finish' then self.active=false;app.opening=nil end
 end
 I.Camera=function(self)host.CameraShot(self.shot,0,self,{})end
 app.opening=I
 Frame(app)
 Check(c.update==1,phase..': exactly one graphics Update')
 Check(c.post==1,phase..': exactly one graphics PostUpdate')
 if phase=='boot' or phase=='warmup' or phase=='failed' then
  Check(c.tick==0,phase..': no battle Tick before readiness')
 else Check(c.tick==1,phase..': one ready scene Tick') end
 if phase=='playing' then Check(c.trialPost==1,'playing sortie camera still updates session') end
end
do
 local app,c,oldTrial=Owner();local oldScene=app.scene
 oldScene.Dispose=function(self)self.disposed=true end
 oldTrial.world={};oldTrial.scene=oldScene
 oldTrial.ReleaseAssets=Noop
 oldTrial.Dispose=function(self)self.disposed=true;self.world=nil;self.scene=nil end
 local function Hall()
  return {SetTier=Noop,SetEnvelope=Noop,SetInfoSource=Noop,Welcome=Noop,SetGrid=Noop}
 end
 Hangar.Bind=Hall
 OrbitCamera.New=function()return {camera={},node={}}end
 VehicleView.New=function()return {root={},Rebuild=Noop}end
 Module('scene.HangarConfig',{layout={cameraLimit={}}})
 Module('controls.PreviewRoom',{New=function()return {}end})
 Module('app.HomeVehicleSwitch',{New=function()return {}end})
 app.editor={bounds={}};app.blueprint={Size=function()return 1 end};app.bays={}
 app.ownsScene=true;app.HomeView=Noop;app.GroundDisplay=Noop
 app.DeferAssetRelease=function(self,release)self.releasePending=release end
 local hall={GetChild=function()return nil end}
 app:Install(hall)
 Check(oldTrial.disposed and oldTrial.world==nil and oldTrial.scene==nil,'Install disposes old trial and clears its world/scene')
 Check(oldScene.disposed,'Install disposes old scene')
 Check(app.trial==nil and app.mode=='hangar' and app.scene==hall,'Install clears trial owner and installs hall')
 Check(type(app.releasePending)=='function','old asset release remains deferred past scene commit')
 -- Holding no scene exits the ordinary Update after common lifecycle work.
 app.scene=nil;Frame(app)
 Check(c.trialUpdate==0 and c.trialPost==0,'subsequent frames do not invoke retired trial')
end
return results

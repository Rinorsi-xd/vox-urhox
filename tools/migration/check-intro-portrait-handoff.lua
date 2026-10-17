package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
for name,source in pairs(PRODUCTION_OVERRIDES or {})do
 package.preload[name]=assert(load(source,'@scripts/'..name:gsub('%.','/')..'.lua'))
end
local checks={}
local function check(ok,label) assert(ok,label);checks[#checks+1]=label end
local function none()end
local counts={scene=0,material=0,retire=0,videoDelete=0,videoCreate=0,decode=0,sourceDispose=0,sceneCreate=0,materialCreate=0,targetCreate=0}
local Widget={};Widget.__index=Widget
assert(load('local Widget=...;'..ENGINE_EXTEND..';return Widget'))(Widget)
YGNodeNew=function()return {}end
assert(load('local Widget=...;local Style={NormalizeColorProps=function()end};local SCROLL_UPGRADEABLE_={};'..ENGINE_SETTERS..';'..ENGINE_NEW))(Widget)
function Widget:Init()end
function Widget:Destroy()self.destroyCalls=(self.destroyCalls or 0)+1 end
local UI={Widget=Widget,CancelPointer=none,ClearFocus=none,PopOverlay=none,GetRoot=none,SetRoot=none,UnregisterGlobalComponent=none}
package.loaded['urhox-libs/UI']=UI
local context={};local activeContext=context
package.loaded['urhox-libs/UI/Core/ImageCache']={GetContext=function()return activeContext end}
for _,name in ipairs({'ui.SourceDraw','ui.IntroFrame','ui.SourceParagraph','ui.WorkshopPaint','ui.CommsFrame','construction.Blueprint','core.Coord','audio.UiSound','story.TutorialRules'})do package.loaded[name]={}end
-- These eager imports belong to rendering/physics paths not exercised here.
-- Keep the actual ownership modules below; reject accidental use of a stub.
for _,name in ipairs({'parts.Dependencies','ui.WeaponIconResources','render.MissileView',
 'scene.Crater','app.OpeningRetirement','intro.IntroWarmup','render.VehicleView',
 'intro.IntroAssembly','intro.IntroGarage','drive.CraterWorld','drive.CraterPhysics',
 'intro.IntroSortieCar','intro.IntroBattle','ui.IntroSortieUi','intro.IntroMontagePool',
 'intro.IntroShots','ui.ReticleState','controls.DriveAim','controls.ChaseState',
 'intro.IntroStrike','intro.IntroSceneCapture','ui.IntroImageWarmup','ui.SourceRichText',
 'ui.IntroTerminalFx','urhox-libs/UI/Core/Theme','ui.IntroTypography','ui.IntroWipe',
 'controls.TouchMode','ui.TutorialPage'})do
 package.loaded[name]=setmetatable({},{__index=function(_,key)error('Unused boundary invoked: '..name..'.'..tostring(key))end})
end
package.loaded['ui.IntroComic']={Dispose=function(page)page.comicReleased=true end}
package.loaded['ui.GarageHud']={Dispose=none}
package.loaded['app.SceneLoader']={New=function()return {}end}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function()return true end}
package.loaded['render.RenderTargetLifetime']={Retire=function(texture)counts.retire=counts.retire+1;texture.retired=true end}
package.loaded['audio.AudioLevels']={SetSpeaking=none}
package.loaded['audio.StoryCommsCues']={Dependencies=function()return {'Sounds/cue.ogg'}end,
 New=function()return {Dispose=none}end}
local resources={};local available={};local downloadMode='success';local pending={}
cache={Exists=function(_,path)return available[path]==true end,
 GetFile=function(_,path)
  local text=READ_RESOURCE(path)
  return {size=#text,Read=function()return {ReadString=function()return text end,Clear=none}end,Dispose=none}
 end,
 GetResource=function(_,kind,path)
  assert(kind=='Texture2D');counts.decode=counts.decode+1
  if not resources[path]then resources[path]={width=1856,height=2304,path=path,Dispose=function()counts.sourceDispose=counts.sourceDispose+1 end}end
  return resources[path]
 end,
 DownloadResources=function(_,paths,done)
  pending[#pending+1]={paths=paths,done=done};local id=#pending
  if downloadMode=='success'then for _,path in ipairs(paths)do available[path]=true end;done(true,0)
  elseif downloadMode=='failure'then done(false,1)end
  return id
 end,CancelDownloadGroup=none}
graphics={GetDPR=function()return 1 end}
Graphics={GetRGBAFormat=function()return 1 end}
Vector2=function(x,y)return {x=x,y=y}end
Vector3=function(x,y,z)return {x=x,y=y,z=z}end
Variant=function(value)return value end
TRIANGLE_LIST=1;TEXTURE_RENDERTARGET=2;FILTER_BILINEAR=3;COORD_U=4;COORD_V=5;ADDRESS_CLAMP=6;SURFACE_MANUALUPDATE=7
local function component(kind)
 if kind=='Camera'then return {node={}}end
 if kind=='SoundSource'then return {SetSoundType=none,StopImmediate=none}end
 return {BeginGeometry=none,DefineVertex=none,DefineNormal=none,DefineTexCoord=none,Commit=none,SetMaterial=none}
end
Scene=function()counts.sceneCreate=counts.sceneCreate+1;return {CreateComponent=function(_,kind)return component(kind)end,
 CreateChild=function()return {CreateComponent=function(_,kind)return component(kind)end}end,
 Dispose=function(self)check(not self.dead,'native scene disposed once');self.dead=true;counts.scene=counts.scene+1 end}end
XMLFile={new=function()return {FromString=function()return true end,Dispose=none}end}
renderer={GetDefaultRenderPath=function()return {Clone=function()return {Load=function()return true end}end}end}
Material={new=function()counts.materialCreate=counts.materialCreate+1;return {params={},SetSurfaceShader=function()return true end,
 SetSurfaceTexture=function(self,key,value)self[key]=value end,
 SetShaderParameter=function(self,key,value)self.params[key]=value end,
 Dispose=function(self)check(not self.dead,'native material disposed once');self.dead=true;counts.material=counts.material+1 end}end}
Texture2D={new=function()counts.targetCreate=counts.targetCreate+1;local surface={SetViewport=none,SetNumViewports=function(self,n)self.viewports=n end,QueueUpdate=none}
 return {SetNumLevels=none,SetSRGB=none,SetSize=function()return true end,SetFilterMode=none,SetAddressMode=none,
 GetRenderSurface=function()return surface end}end}
Viewport={new=function()return {SetRenderPath=none}end}
for _,name in ipairs({'nvgSave','nvgRestore','nvgTranslate','nvgScale','nvgBeginPath','nvgRect','nvgFillPaint','nvgFill','nvgGlobalCompositeBlendFuncSeparate'})do _G[name]=none end
nvgImagePatternTinted=none;nvgImagePattern=none;nvgRGBA=none
nvgCreateVideo=function()counts.videoCreate=counts.videoCreate+1;return counts.videoCreate end
nvgDeleteVideo=function()counts.videoDelete=counts.videoDelete+1 end
local Portrait=require 'ui.CommsPortrait'
local Card=require 'ui.CommsCard'
local Story=require 'audio.StoryComms'
local Gate=require 'app.ResourceGate'
local Tutorial=require 'story.Tutorial'
local Host=require 'app.OpeningHost'
local captured
local extend=Widget.Extend
function Widget:Extend(name)local class=extend(self,name);if name=='VoxOpeningPage'then captured=class end;return class end
require 'ui.IntroPage'
function captured:Init()end
local function warm()
 local p=Portrait.New('nono')
 for _,face in ipairs({'talk','smile','deadpan','stamp'})do available[Portrait.Path('nono',face)]=true;p:Texture(face)end
 p.width=460;p.height=640;p:Prepare(17,'deadpan',false);p:Draw(context,{x=0,y=0,w=330,h=410})
 return p
end
local function setup(p)
 local tutorial={page={CancelInput=none},DetachVoice=none}
 local app={scene={},mode='hangar',tutorial=tutorial,camera={camera={fov=45},node={position={},rotation={}}},car={root={enabled=true},SetVisible=none}}
 local I={signed=true,active=false,disposed=true};local host=Host.New(app);I.host=host;app.opening=I;host.Begin(I)
 local page=captured:new({});page.owner=I;page.pointers={};page.portrait=p
 page.imageWarmup={Dispose=function(self)self.calls=(self.calls or 0)+1 end};I.page=page
 return page,I,app,host
end
check(Portrait.Path('nono','nono_talk')=='Intro/Images/nono_talk.png','canonical Nono prefix normalization')
check(Portrait.Path('huhu','huhu_angry')=='UI/Faces/huhu_angry.png','other speaker path unchanged')
local p=warm();local faces=p.faces;local textures=p.textures;local materials=p.materials;local handles=p.images[context]
local page,I,app,host=setup(p);local priorDecode=counts.decode;local priorVideo=counts.videoCreate
page:Close()
check(Card.GetPortrait('nono')==p and page.portrait==nil and not p.disposed,'actual Widget page close transfers sole ownership')
check(page.comicReleased and page.destroyCalls==1 and page.imageWarmup.calls==1,'successful handoff still closes opening page resources')
check(p.width==330 and p.height==410,'logical card dimensions restored')
check(p.glitch==0 and p.nextGlitch==3 and p.lastTime==0 and p.face==nil and p.ready==false and p.requested==false,'presentation timing and pending frame reset')
for _,m in ipairs(p.materials)do check(m.params.canvas_size.x==330 and m.params.canvas_size.y==410,'both material canvas sizes restored')end
check(p.faces==faces and p.textures==textures and p.materials==materials and p.images[context]==handles,'all warmed GPU/source objects retain identity')
check(Card.AdoptPortrait(p,context),'repeated same-owner adoption is idempotent')
p:Prepare(.1,'nono_talk',true);p:Draw(context,{x=0,y=0,w=150,h=196})
check(counts.decode==priorDecode and counts.videoCreate==priorVideo,'first tutorial card does not decode faces or recreate video handles')
page:Close();check(not p.disposed and Card.GetPortrait('nono')==p,'repeated page close cannot release transferred portrait')
local beforeScene,beforeMaterial,beforeRetire,beforeVideo=counts.scene,counts.material,counts.retire,counts.videoDelete
Story.Shutdown();Story.Shutdown();p:Dispose()
check(Card.GetPortrait('nono')==nil and p.disposed,'shutdown before first voice releases adopted portrait')
check(counts.scene-beforeScene==2 and counts.material-beforeMaterial==2 and counts.retire-beforeRetire==2 and counts.videoDelete-beforeVideo==2,'shutdown and duplicate Dispose release two native owners once')
check(counts.sourceDispose==0,'cache-owned source textures never explicitly disposed')
local rejectCases={
 {'unsigned',function(_,i)i.signed=false end},
 {'failed',function(_,i)i.failed=true end},
 {'stopped',function(_,_,a)a.stopped=true end},
 {'different restore owner',function(_,_,a)a.openingRestoreOwner={}end},
 {'different opening',function(_,_,a)a.opening={}end},
 {'different intro',function(_,_,_,h)h.state.intro={}end},
 {'different scene',function(_,_,a)a.scene={}end},
 {'build active',function(_,_,a)a.build={}end},
 {'not in hall',function(_,_,a)a.mode='drive'end},
 {'tutorial replaced',function(_,_,a)a.tutorial={}end},
 {'tutorial disposed',function(_,_,a)a.tutorial.disposed=true end},
 {'tutorial page replaced',function(_,_,a)a.tutorial.page={}end},
 {'host disposed',function(_,_,_,h)h.state.disposed=true end},
 {'page replaced',function(_,i)i.page={}end},
 {'VG context replaced',function()activeContext={}end},
 {'portrait incomplete',function(page)page.portrait.faces.smile=nil end},
 {'portrait not ready',function(page)page.portrait.ready=false end},
 {'portrait has no handles',function(page)page.portrait.images={}end},
 {'portrait missing RT',function(page)table.remove(page.portrait.textures)end},
 {'portrait missing material',function(page)table.remove(page.portrait.materials)end},
}
for _,case in ipairs(rejectCases)do
 activeContext=context;local rejected=warm();local pg,ii,aa,hh=setup(rejected)
 local imageOwner=rejected.images;local targetOwner={table.unpack(rejected.textures)};local materialOwner={table.unpack(rejected.materials)}
 case[2](pg,ii,aa,hh)
 check(not hh.TakeTutorialPortrait(ii,rejected,activeContext),case[1]..' host/card explicitly refuses ownership')
 -- Restore deliberately incomplete fixture containers before testing teardown.
 rejected.images=imageOwner;rejected.textures=targetOwner;rejected.materials=materialOwner;ii.signed=false
 pg:Close()
 check(rejected.disposed and pg.portrait==nil and Card.GetPortrait('nono')==nil,case[1]..' closes through original Dispose')
 activeContext=context
end
local missing=warm();local pg,ii,aa,hh=setup(missing);aa.tutorial=nil;pg:Close()
check(missing.disposed,'no tutorial rejects handoff')
local old=warm();check(Card.AdoptPortrait(old,context),'first replacement candidate adopted')
local replacement=warm();local replacementPage=setup(replacement);replacementPage:Close()
check(old.disposed and not replacement.disposed and Card.GetPortrait('nono')==replacement,'new opening replaces and disposes previous shared portrait')
local voice=Story.New(nil,{voices={}},false);Story.Shutdown();Story.Shutdown()
check(replacement.disposed and Card.GetPortrait('nono')==nil,'normal audio shared shutdown disposes adopted portrait')
check(counts.scene==counts.sceneCreate and counts.material==counts.materialCreate and counts.retire==counts.targetCreate
 and counts.videoDelete==counts.videoCreate,'all constructed scenes/materials/targets/video handles released exactly once')
available={};pending={};downloadMode='success'
local direct=setmetatable({gate=Gate.New(cache),data={voices={a={path='Sounds/tutorial.ogg'}}}},Tutorial)
direct:Prepare()
check(direct.gate.state=='ready' and #pending==1,'direct tutorial entry still downloads through actual resource gate')
local expected={['Intro/Images/nono_talk.png']=true,['Intro/Images/nono_deadpan.png']=true,['Intro/Images/nono_smile.png']=true,['Sounds/tutorial.ogg']=true,['Sounds/cue.ogg']=true}
for _,path in ipairs(pending[1].paths)do check(expected[path]==true,'direct tutorial dependency '..path);expected[path]=nil end
check(next(expected)==nil,'direct tutorial retains portrait, voice and cue dependencies')
direct:Prepare();check(#pending==1,'ready tutorial does not restart gate')
available={};pending={};downloadMode='failure';direct.gate=Gate.New(cache);direct:Prepare()
check(direct.gate.state=='failed','tutorial failed download remains observable')
downloadMode='pending';direct:Prepare();local late=pending[#pending];direct.gate:Cancel();late.done(true,0)
check(direct.gate.state=='idle','late download completion after cancellation cannot revive gate')
return {count=#checks,checks=checks}

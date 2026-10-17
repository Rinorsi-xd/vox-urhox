package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks={}
local function check(ok,label)assert(ok,label);checks[#checks+1]=label end
local function none()end
local counts={scenes=0,sceneDispose=0,materials=0,materialDispose=0,targets=0,retire=0,videos=0,videoDelete=0,decode=0,queue=0,save=0,restore=0}
local context={};local activeContext=context
package.loaded['urhox-libs/UI/Core/ImageCache']={GetContext=function()return activeContext end}
for _,name in ipairs({'ui.SourceDraw','ui.CommsFrame','ui.SourceParagraph'})do package.loaded[name]={}end
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function()return true end}
package.loaded['render.RenderTargetLifetime']={Retire=function(texture)check(not texture.retired,'target retired once');texture.retired=true;counts.retire=counts.retire+1 end}
local available,resources,pending={},{},{}
local mode='success';local unavailable
cache={Exists=function(_,path)return available[path]==true end,
 GetResource=function(_,kind,path)
  check(kind=='Texture2D','portrait decodes only its original texture');counts.decode=counts.decode+1
  if unavailable==path then return nil end
  if not resources[path]then resources[path]={width=1856,height=2304,path=path}end
  return resources[path]
 end,
 DownloadResources=function(_,paths,done)
  pending[#pending+1]={paths=paths,done=done};local id=#pending
  if mode=='success'then for _,path in ipairs(paths)do available[path]=true end;done(true,0)
  elseif mode=='failure'then done(false,1)end
  return id
 end,CancelDownloadGroup=none}
time={frameNumber=1};graphics={GetDPR=function()return 1 end};Graphics={GetRGBAFormat=function()return 1 end}
Vector2=function(x,y)return {x=x,y=y}end;Vector3=function(x,y,z)return {x=x,y=y,z=z}end
Vector4=function(x,y,z,w)return {x=x,y=y,z=z,w=w}end
Variant=function(value)return value end
TRIANGLE_LIST=1;TEXTURE_RENDERTARGET=2;FILTER_BILINEAR=3;COORD_U=4;COORD_V=5;ADDRESS_CLAMP=6;SURFACE_MANUALUPDATE=7
local function component(kind)
 if kind=='Camera'then return {node={}}end
 return {BeginGeometry=none,DefineVertex=none,DefineNormal=none,DefineTexCoord=none,Commit=none,SetMaterial=none}
end
Scene=function()counts.scenes=counts.scenes+1;return {CreateComponent=function(_,kind)return component(kind)end,
 CreateChild=function()return {CreateComponent=function(_,kind)return component(kind)end}end,
 Dispose=function(self)check(not self.dead,'scene disposed once');self.dead=true;counts.sceneDispose=counts.sceneDispose+1 end}end
XMLFile={new=function()return {FromString=function()return true end,Dispose=none}end}
renderer={GetDefaultRenderPath=function()return {Clone=function()return {Load=function()return true end}end}end}
Material={new=function()counts.materials=counts.materials+1;return {params={},SetSurfaceShader=function()return true end,
 SetSurfaceTexture=function(self,key,value)self[key]=value end,SetShaderParameter=function(self,key,value)self.params[key]=value end,
 Dispose=function(self)check(not self.dead,'material disposed once');self.dead=true;counts.materialDispose=counts.materialDispose+1 end}end}
Texture2D={new=function()counts.targets=counts.targets+1;local surface={SetViewport=none,SetNumViewports=none,QueueUpdate=function()counts.queue=counts.queue+1 end}
 return {SetNumLevels=none,SetSRGB=none,SetSize=function()return true end,SetFilterMode=none,SetAddressMode=none,
 GetRenderSurface=function()return surface end}end}
Viewport={new=function()return {SetRenderPath=none}end}
for _,name in ipairs({'nvgTranslate','nvgScale','nvgBeginPath','nvgRect','nvgFillPaint','nvgFill','nvgGlobalCompositeBlendFuncSeparate','nvgImagePatternTinted','nvgImagePattern','nvgRGBA'})do _G[name]=none end
nvgSave=function()counts.save=counts.save+1 end;nvgRestore=function()counts.restore=counts.restore+1 end
nvgCreateVideo=function()counts.videos=counts.videos+1;return counts.videos end
nvgDeleteVideo=function()counts.videoDelete=counts.videoDelete+1 end
if CARD_SOURCE then package.preload['ui.CommsCard']=function()return assert(load(CARD_SOURCE,'@candidate-CommsCard.lua'))()end end
if WARMUP_SOURCE then package.preload['ui.CommsWarmup']=function()return assert(load(WARMUP_SOURCE,'@candidate-CommsWarmup.lua'))()end end
local Portrait=require 'ui.CommsPortrait';local Card=require 'ui.CommsCard';local Warmup=require 'ui.CommsWarmup'
local fields={'width','height','glitch','nextGlitch','lastTime','face','ready','requested'}
local function state(p)local out={};for _,key in ipairs(fields)do out[key]=p[key]end;return out end
local function same(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function frame(w)
 time.frameNumber=time.frameNumber+1;w:Draw(activeContext);return w:Presented()
end
local function finish(w)
 check(not frame(w),'first submitted frame cannot finish warmup')
 local done,message=frame(w);check(done,'second submitted frame completes warmup: '..tostring(message))
end
local function clean()Card.Dispose();activeContext=context;unavailable=nil;mode='success'end
check(Warmup.Begin('yun')==nil and #Warmup.Dependencies('boss')==0,'non-GPU speakers do not allocate or download')
local deps=Warmup.Dependencies('huhu','huhu_angry')
check(#deps==3 and deps[1]=='UI/Faces/huhu_angry.png' and deps[2]=='UI/Faces/huhu_smug.png' and deps[3]=='Shaders/BLGL/UI/CommsPortrait.shader','only actual first face, closed mouth and shader are requested')
local first=Warmup.Begin('nono','nono_talk');local before=counts.targets
check(counts.targets==before and not first:Presented(),'download and Presented alone do not construct or complete a portrait')
first:Draw({});check(counts.targets==before,'foreign UI context cannot upload or draw')
first:Draw(context);local p=first.portrait;local handles=p.images[context];local targets=p.textures;local mats=p.materials
check(p.width==330 and p.height==410 and counts.targets-before==2,'Nono retains original 330 by 410 dimensions and two targets')
check(Card.GetPortrait('nono')==nil,'new owner is not exposed before actual presentation')
local queue=counts.queue;local videos=counts.videos;first:Draw(context)
check(counts.queue==queue and counts.videos==videos,'duplicate Draw in the same rendered frame cannot queue twice')
check(not first:Presented() and not first:Presented() and first.frames==1,'duplicate Presented cannot count a second frame')
check(frame(first),'next actual submitted frame completes handoff')
check(Card.GetPortrait('nono')==p and p.textures==targets and p.materials==mats and p.images[context]==handles,'retained owner keeps exact targets, materials and UI bridge handles')
check(p.glitch==0 and p.nextGlitch==3 and p.lastTime==0 and p.face==nil and p.ready==false and p.requested==false,'new retained owner resets presentation timing and pending requests')
local control=Portrait.New('nono');local decoded=counts.decode;videos=counts.videos
p:Prepare(.1,'nono_talk',true);p:Draw(context,{x=0,y=0,w=150,h=196});control:Prepare(.1,'nono_talk',true)
check(counts.decode==decoded+2 and counts.videos==videos,'first live warmed face performs no extra decode or bridge creation')
check(same(state(p),state(control)) and same(p.materials[1].params,control.materials[1].params) and same(p.materials[2].params,control.materials[2].params),'first live timing, glitch, mouth, transform and material values match cold owner')
first:Dispose();first:Dispose();check(not p.disposed and Card.GetPortrait('nono')==p,'closing successful warmup leaves sole ownership with CommsCard')
control:Dispose();clean()
local huhu=Warmup.Begin('huhu','angry');finish(huhu);local h=Card.GetPortrait('huhu')
check(h.width==156 and h.height==195 and h.faces.angry and h.faces.smug and not h.faces.talk,'Huhu preserves 156 by 195 dimensions and only the actual first pose')
huhu:Dispose();clean()
local seeded=Warmup.Begin('nono','talk');finish(seeded);seeded:Dispose();p=Card.GetPortrait('nono')
available[Portrait.Path('nono','deadpan')]=true;p:Prepare(17,'deadpan',false)
local saved=state(p);local borrowed=Warmup.Begin('nono','talk');frame(borrowed);borrowed:Dispose()
check(not p.disposed and same(state(p),saved) and Card.GetPortrait('nono')==p,'cancelled borrowed portrait restores every presentation field and remains owned')
borrowed=Warmup.Begin('nono','talk');finish(borrowed);borrowed:Dispose()
check(not p.disposed and same(state(p),saved),'successful borrowed warmup preserves existing timing, pose, dimensions and pending state')
local targetCount,materialCount,videoCount,decodeCount=counts.targets,counts.materials,counts.videos,counts.decode
for _=1,20 do local repeated=Warmup.Begin('nono','talk');finish(repeated);repeated:Dispose()end
check(counts.targets==targetCount and counts.materials==materialCount and counts.videos==videoCount and counts.decode==decodeCount,'twenty repeated hall loads reuse all targets, materials, bridges and decoded faces')
clean()
for _,borrow in ipairs({false,true})do
 if borrow then local w=Warmup.Begin('nono','talk');finish(w);w:Dispose()end
 local w=Warmup.Begin('nono','talk');frame(w);local old=w.portrait;activeContext={}
 local done,err=w:Presented();check(not done and err and (old.disposed==true)==not borrow,'context replacement aborts and disposes only newly owned portrait')
 activeContext=context;w:Dispose();clean()
end
local changed=Warmup.Begin('nono','talk');frame(changed);local candidate=changed.portrait
local replacement=Portrait.New('nono');replacement:Prepare(0,'talk',false);replacement:Draw(context,{x=0,y=0,w=330,h=410})
check(Card.RetainWarmPortrait(replacement,context,nil,'talk'),'independent valid owner can win ownership while warmup is pending')
local done,err=changed:Presented();check(not done and err and candidate.disposed and not replacement.disposed and Card.GetPortrait('nono')==replacement,'stale owner cannot replace or dispose a newer retained owner');clean()
mode='pending';available={};pending={};local cancelled=Warmup.Begin('huhu','angry');local late=pending[1]
cancelled:Dispose();for _,path in ipairs(late.paths)do available[path]=true end;late.done(true,0)
before=counts.targets;cancelled:Draw(context);check(not cancelled.downloaded and counts.targets==before,'late download completion cannot revive cancelled warmup')
mode='failure';available={};local failure=Warmup.Begin('nono','talk');local ok,message=failure:Draw(context)
check(not ok and message and failure.disposed and counts.targets==before,'failed dependency gate reports failure before allocation');clean()
local missing=Warmup.Begin('nono','talk');unavailable=Portrait.Path('nono','talk');ok,message=missing:Draw(context)
check(not ok and message and missing.disposed and Card.GetPortrait('nono')==nil,'missing actual texture aborts and releases newly built portrait');clean()
for _,method in ipairs({'Queue','Draw'})do
 local broken=Warmup.Begin('nono','talk');broken:Draw(context);local owner=broken.portrait
 owner[method]=function()error('injected '..method..' failure')end;time.frameNumber=time.frameNumber+1
 ok,message=broken:Draw(context);check(not ok and message and owner.disposed,'thrown '..method..' failure releases only new resources');clean()
end
local invalid=Warmup.Begin('huhu','talk');frame(invalid);invalid.portrait.images[context][1]=0
ok,message=frame(invalid);check(not ok and message and invalid.disposed,'invalid UI bridge cannot be retained');clean()
check(counts.scenes==counts.sceneDispose and counts.materials==counts.materialDispose and counts.targets==counts.retire and counts.videos==counts.videoDelete,'all constructed scenes, materials, targets and UI videos reach their sole final disposal')
check(counts.save==counts.restore,'every successful and failed warmup restores the UI draw state')
return {count=#checks,checks=checks,counts=counts}

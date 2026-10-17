-- Isolated real UI render fixture. No App, audio, inventory or save session.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Promo=require 'ui.IntroPromo'
local Decision=require 'ui.IntroDecisionFx'
local Opacity=require 'ui.IntroOpacity'
local Images=require 'urhox-libs/UI/Core/ImageCache'
local Fonts=require 'ui.SourceFonts'
local TouchMode=require 'controls.TouchMode'
local ResourceGate=require 'app.ResourceGate'
local Data=require('core.ResourceData').Read('Intro/Intro.json')
local imageSizes={machinist_idle={2304,2304},machinist_hero={2304,2304},['company-emblem']={261,263}}
local Stage=UI.Widget:Extend('DecisionFeedbackFixture')
local stages={{'hold-zero','decide',0,1.2},{'hold-half','decide',.5,1.85},{'hold-full','decide',1,2.5},
 {'decided-early','decided',1,.2},{'decided-late','decided',1,1}}
local page=nil ---@type table?
local index=1
local frames=0
local sent=false
local finished=false
local row=nil ---@type table?
local gate=nil ---@type table?
local resourcesReady=false
local holdDraw={}
local sourceText=D.Text
D.Text=function(vg,text,x,y,size,color,font,align,spacing,baseline,lineHeight,...)
 if text=='按住'or text=='按住 鼠标左键 / 空格 · 做出决定'then
  holdDraw[text=='按住'and'label'or'instruction']={x=x,y=y,size=size,font=font,spacing=spacing or 0,baseline=baseline or false,lineHeight=lineHeight}
 end
 return sourceText(vg,text,x,y,size,color,font,align,spacing,baseline,lineHeight,...)
end
local function Emit(kind,value)print('DECISION_FEEDBACK_'..kind..' '..cjson.encode(value))end
local function Owner(stage)
 local shot=stage[2];local age=stage[4];local time=shot=='decide' and 20+age or 23+age
 return {shot=shot,age=age,time=time,holdProgress=stage[3],deciding=shot=='decide',downloaded=true,
  caption=Data.caps[shot=='decide' and 'n06' or 'n07'],data=Data,
  log={{shot='idyll',t=0},{shot='sortie-play',t=3},{shot='decide',t=20}}}
end
function Stage:Render(vg)
 if finished then return end
 assert(resourcesReady,'UI rendered before fixture resources downloaded')
 D.Begin(vg)
 local vw,vh=UI.GetViewportSize();local k=math.min(vw/1920,vh/1080);local w,h=vw/k,vh/k
 self.k=k;self.owner=Owner(stages[index])
 local loaded={}
 for _,name in ipairs({'machinist_idle','machinist_hero','company-emblem'})do
  local path=Data.images[name];local handle=Images.Get(path);local iw,ih=Images.GetSize(path)
  local size=imageSizes[name]
  assert(handle and handle>0 and iw==size[1] and ih==size[2],'Opening image is not frozen full-size artwork: '..path..' '..tostring(iw)..'x'..tostring(ih))
  loaded[name]={path=path,handle=handle,width=iw,height=ih}
 end
 holdDraw={};Opacity.Push(vg,1);nvgScale(vg,k,k);Promo.Draw(self,vg,w,h,h/100);Opacity.Pop(vg)
 frames=frames+1
 row={stage=stages[index][1],fixture=true,frames=frames,owner={shot=self.owner.shot,age=self.owner.age,time=self.owner.time,
  progress=self.owner.holdProgress,caption=self.owner.caption},plan=Decision.Plan(self.owner),images=loaded,
  hold=holdDraw,viewport={vw,vh},design={w,h},scale=UI.GetScale(),dpr=graphics:GetDPR()}
end
local function Fail(message)
 finished=true;Emit('DONE',{status='FAIL',error=tostring(message),fixture=true})
end
function Start()
 SubscribeToEvent('Update','DecisionFeedbackUpdate')
 local paths={'Fonts/VoxIndustrial-Bold.otf','Fonts/BarlowCondensed-BoldItalic.ttf',
  'Fonts/VoxDisplayTabular-BoldItalic.ttf','Fonts/SmileySans-Oblique.ttf','Fonts/Anonymous Pro.ttf'}
 for name in pairs(imageSizes)do paths[#paths+1]=assert(Data.images[name])end
 gate=ResourceGate.New()
 gate:Start(paths,function(ok,message)
  if not ok then Fail(message);return end
  for _,path in ipairs(paths)do assert(cache:Exists(path),'Downloaded fixture resource absent: '..path)end
  resourcesReady=true
  local fonts=Fonts.Resolve()
  UI.Init({theme='default-dark',scale=TouchMode.Scale('home'),fonts={{family='sans',weights={normal=fonts.body,bold=fonts.bold}}}})
  input.mouseMode=MM_ABSOLUTE
  page=Stage{position='absolute',left=0,top=0,width='100%',height='100%',pointerEvents='none'}
  UI.SetRoot(page)
 end)
end
function DecisionFeedbackUpdate(_,eventData)
 if finished then return end
 local ok,message=pcall(function()
  ResourceGate.UpdatePending(eventData and eventData:GetFloat('TimeStep')or 1/60)
  if not sent and frames>=10 and row then sent=true;Emit('SNAPSHOT',row)
  elseif sent and input:GetKeyPress(KEY_F8)then
   index=index+1;frames=0;sent=false;row=nil
   if index>#stages then
    finished=true;UI.SetRoot(nil);page:Destroy();page=nil;Images.Clear();UI.Shutdown()
    Emit('DONE',{status='PASS',stages=#stages,fixture=true,released=true,
     boundary='Frozen actual IntroPromo, SourceDraw fonts and image handles with synthetic presentation clocks. No App/normal playback/audio/gameplay/save/performance acceptance.'})
   end
  end
 end)
 if not ok then Fail(message)end
end
function Stop()
 UnsubscribeFromEvent('Update')
 D.Text=sourceText
 if gate then gate:Cancel();gate=nil end
 if page then UI.SetRoot(nil);page:Destroy();page=nil;Images.Clear();UI.Shutdown()end
end

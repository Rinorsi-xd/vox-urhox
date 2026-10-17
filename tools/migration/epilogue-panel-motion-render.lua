-- Isolated extension of the existing staged UI fixture pattern; no normal App.
local UI=require 'urhox-libs/UI'
local Epilogue=require 'ui.Epilogue'
local Images=require 'urhox-libs/UI/Core/ImageCache'
local Fonts=require 'ui.SourceFonts'
local Gate=require 'app.ResourceGate'
local Resource=require('core.ResourceData').Read('Story/Boss/Epilogue.json')
local stages={{'panel-mid',1,.16},{'panel-settled',1,.32},{'impact-mid',2,.27},{'impact-settled',2,.4},
 {'zoom-mid',3,.4},{'zoom-settled',3,1.6},{'deal-impact-mid',4,1.76},{'deal-impact-settled',4,1.9}}
local gate,scene,root,ep=nil,nil,nil,nil
local index,frames=1,0
local ready,sent,finished=false,false,false
local function Emit(kind,row)print('EPILOGUE_PANEL_MOTION_'..kind..' '..cjson.encode(row))end
local function Stage()
 if ep then ep:Dispose();ep=nil end
 local s=stages[index]
 ep=Epilogue.Attach(scene,root,function()end)
 ep.rules.current={kind='panel'};ep.rules.time=10+s[3];ep.rules.age=s[3]
 ep.panels=ep.motion:Add({panel=Resource.data.scenes[s[2]].panel,at=10},true)
 ep.motion.current.shakeStarts={}
 frames=0;sent=false
end
function Start()
 SubscribeToEvent('Update','EpiloguePanelMotionUpdate')
 local paths=Epilogue.Dependencies()
 for _,path in ipairs({'Fonts/VoxIndustrial-Bold.otf','Fonts/BarlowCondensed-BoldItalic.ttf','Fonts/VoxDisplayTabular-BoldItalic.ttf','Fonts/SmileySans-Oblique.ttf','Fonts/Anonymous Pro.ttf'})do paths[#paths+1]=path end
 gate=Gate.New()
 gate:Start(paths,function(ok,message)
  assert(ok,tostring(message))
  for _,p in ipairs(paths)do assert(cache:Exists(p),'Missing fixture dependency '..p)end
  local fonts=Fonts.Resolve();UI.Init({theme='default-dark',scale=UI.Scale.DEFAULT,fonts={{family='sans',weights={normal=fonts.body,bold=fonts.bold}}}})
  scene=Scene();root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root)
  input.mouseMode=MM_ABSOLUTE;ready=true;Stage()
 end)
end
function EpiloguePanelMotionUpdate(_,eventData)
 if finished then return end
 local ok,message=pcall(function()
  Gate.UpdatePending(eventData:GetFloat('TimeStep'))
  if not ready then return end
  frames=frames+1
  if not sent and frames>=10 then
   local images={}
   for name,image in pairs(Resource.images)do local handle=Images.Get(image.path);local w,h=Images.GetSize(image.path);images[name]={handle=handle,width=w,height=h};assert(handle and handle>0 and w>0 and h>0)end
   local s=stages[index];sent=true
   Emit('SNAPSHOT',{stage=s[1],panel=s[2],age=s[3],fixture=true,frames=frames,images=images})
  elseif sent and input:GetKeyPress(KEY_F8)then
   index=index+1
   if index>#stages then
    ep:Dispose();ep=nil;UI.SetRoot(nil);root:Destroy();root=nil;scene:Dispose();scene=nil;Images.Clear();UI.Shutdown()
    finished=true;Emit('DONE',{status='PASS',stages=#stages,released=true,
     boundary='Synthetic frozen presentation times over actual authored panels and production UI. No natural story/audio/performance claim.'})
   else Stage()end
  end
 end)
 if not ok then finished=true;Emit('DONE',{status='FAIL',error=tostring(message)})end
end
function Stop()
 UnsubscribeFromEvent('Update')
 if gate then gate:Cancel()end
 if ep then ep:Dispose();ep=nil end
 if root then UI.SetRoot(nil);root:Destroy();root=nil;UI.Shutdown()end
 if scene then scene:Dispose();scene=nil end
end

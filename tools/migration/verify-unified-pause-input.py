"""Execute production trial/input/menu modules with CPU engine/UI adapters."""
from pathlib import Path
import hashlib,json,re,sys,subprocess
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
FILES=['app/TrialSession','controls/DrivePointer','controls/MouseDeltaFilter','ui/GameSettings','ui/PauseMenu','ui/DialogHost','combat/MatchActions']
def run(old=False):
 lua=LuaRuntime(unpack_returned_tuples=True)
 codes={n:(ROOT/('scripts/'+n+'.lua')).read_text(encoding='utf-8-sig') for n in FILES}
 if old:
  # Frozen submitted baseline rather than a moving working-tree expectation.
  codes['app/TrialSession']=subprocess.check_output(['git','show','48ef15f2c9c95c400f91ee6e34309399d02b3733:scripts/app/TrialSession.lua'],cwd=ROOT).decode()
 lua.globals().codes=lua.table_from(codes)
 deps=set()
 for code in codes.values(): deps.update(re.findall(r"require\s*\(?\s*['\"]([^'\"]+)",code))
 lua.globals().deps=lua.table_from(sorted(deps))
 return lua.execute(r"""
local noop=function()end
local function Check(ok,label) assert(ok,label); checks=checks+1 end
checks=0
for _,name in ipairs(deps)do package.preload[name]=function()return {}end end
for name,code in pairs(codes)do package.preload[(name:gsub('/','.'))]=assert(load(code,'@scripts/'..name..'.lua')) end
for _,name in ipairs({'ESCAPE','T','R','BACKSPACE','I','C','N','E','F','G','V','RETURN','SPACE','TAB','A','D','LEFT','RIGHT','1','2','3','4','5','6','7','8','9','0'})do _G['KEY_'..name]=name end
MM_ABSOLUTE='absolute';MM_RELATIVE='relative';MOUSEB_LEFT=1;MOUSEB_RIGHT=2;MOUSEB_MIDDLE=4
local events={};local presses={};local web=false;local touch=false
input={focus=true,minimized=false,mouseMode=MM_ABSOLUTE,mouseLocked=false,mouseMoveX=0,mouseMoveY=0,
 GetKeyPress=function(_,key)return presses[key]==true end,GetKeyDown=function()return false end,
 GetMouseButtonDown=function()return false end,GetMouseMoveWheel=function()return 0 end}
Time={GetSystemTime=function()return 1000 end}
Node=function()return {CreateScriptObject=function()return {SubscribeToEvent=function(_,event,fn)events[event]=fn end}end,Dispose=function()events={}end}end
local function Widget(props)
 local w={props=props or {},children={},isOpen_=false}
 function w:AddChild(child) self.children[#self.children+1]=child end
 function w:AddContent(child) self:AddChild(child) end
 function w:SetHeight(h)self.props.height=h end
 function w:Open()self.isOpen_=true end
 function w:Close(immediate)self.isOpen_=false;if self.props.onClose then self.props.onClose(self)end;if immediate then self:Destroy()end end
 function w:Destroy()if self.props.onDispose then self.props.onDispose(self)end end
 function w:AdvanceClose()self:Destroy()end
 return w
end
local Panel=setmetatable({Extend=function()return setmetatable({},{__call=function(_,props)return Widget(props)end})end},{__call=function(_,props)return Widget(props)end})
local UI={Panel=Panel,ScrollView=Widget,GetScale=function()return 1 end,GetViewportSize=function()return 1600,900 end,GetFocus=function()return nil end}
package.loaded['urhox-libs/UI']=UI;package.loaded['ui.SourceModal']={}
package.loaded['ui.SourceModal']=setmetatable({},{__call=function(_,props)return Widget(props)end})
package.loaded['ui.SourceButton']=Widget;package.loaded['ui.SourceHint']=Widget
package.loaded['controls.TouchMode']={Enabled=function()return touch end}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function()return web end}
package.loaded['combat.KillImpact']={Step=function(_,dt)return dt end}
package.loaded['controls.ChaseState']={Look=function(y,p)return y,p end}
package.loaded['controls.DriveAim']={Look=function()return 1 end}
package.loaded['combat.Matchmaker']={ResetIntro=function()return true end,Record=function()return {}end}
graphics={GetWidth=function()return 1600 end,GetHeight=function()return 900 end,GetDPR=function()return 1 end}
local Host=require 'ui.DialogHost'
local function Child(owner,options)
 local m=Host.Open(owner,'child');m.actions={done=Widget{onClick=options.onDone}};return m
end
package.loaded['ui.GraphicsPanel']={Open=Child};package.loaded['ui.AudioSettings']={Open=Child};package.loaded['ui.TouchSettings']={Open=Child}
package.loaded['ui.GarageDialogs']={Help=function(owner)return Host.Open(owner,'help')end}
local Trial=require 'app.TrialSession';local Pointer=require 'controls.DrivePointer';local Settings=require 'ui.GameSettings'
local function Stub()return setmetatable({},{__index=function()return noop end})end
local function New(mode,isWeb,isTouch)
 web=isWeb;touch=isTouch;input.focus=true;input.minimized=false;input.mouseMode=MM_ABSOLUTE;input.mouseLocked=false
 local s=setmetatable({app={lobby='hangar',store={},toasts=Stub()},touch=touch,enteredTime=1,map={name='test'},controls={held={},Clear=function(self)self.held={}end,Look=noop,Read=function()return {}end,TakeLook=function()return 0,0 end,Command=noop},
 weaponAudio=Stub(),drivingAudio=Stub(),feedbackAudio=Stub(),drillSpeed=Stub(),safeReset=Stub(),weapons={drill=Stub(),Group=function()return nil end},vehicle={speed=0,spec={}},yaw=0,pitch=0,lookIdle=0,
 Tick=function(self,dt,cmd)self.tickCommand=cmd end,Zoom=noop,accumulator=0,hud={width=1600,height=900,Clear=noop,Update=noop},onReturn=noop},Trial)
 local c={player={alive=true},rules={state='live',finished=false},HandleKey=function()return false end,Key=function()return false end,Update=noop,Events=noop,Banner=noop}
 s.combat=c
 if mode=='battle'then c.sounds=Stub();c.voice=Stub();c.session=s;s.battle=c
 elseif mode=='story'then c.voice=Stub();s.story=c
 elseif mode=='endless'then c.RestorePresentation=noop;c.run={state='live'};s.endless=c
 elseif mode=='salvage'then c.cine={Update=noop};s.salvage=c
 else s.practice=c end
 s.pointer=Pointer.New(s)
 s.pointer.SetMouseMode=function(_,mode) input.mouseMode=mode;if mode==MM_ABSOLUTE then input.mouseLocked=false end end
 return s
end
local function Capture(s)
 s:Resume();if s.pointer.pending then input.mouseLocked=true;s.pointer:Poll(.016)end
 s.pointer:Poll(.016);s.pointer:Poll(.016)
 Check(s.pointer.captured,'captures genuine pointer')
end
local function Frame(s,keys)
 presses=keys or {};s:Update(1/60);presses={}
end
local count=0
for _,mode in ipairs({'battle','story','practice','endless','salvage'})do
 for _,isWeb in ipairs({false,true})do
  local s=New(mode,isWeb,false);Capture(s)
  -- Use actual registered edge callbacks before an actual Update key poll.
  events.MouseButtonDown(nil,nil,{GetInt=function()return MOUSEB_LEFT end})
  Check(s.controls.held.fire,'real Lua pointer callback sets firing')
  Frame(s,{ESCAPE=true,T=true})
  local m=s.dialog;Check(m and m.unifiedSettings,'first Escape opens unified menu: '..mode)
  Check(not s.pointer.captured and not s.pointer.pending and not s.controls.held.fire,'release clears held fire/capture')
  Check(not s.wantsReturn,'Escape consumes simultaneous T')
  Check(m.actions.resume and m.actions['return'] and m.actions.audio and m.actions.graphics,'single menu has all direct entries')
  Check(Settings.Open(s)==m,'repeated open preserves identical modal')
  Frame(s);Check(s.dialog==m,'held/no-new-edge frame preserves menu')
  for _,id in ipairs({'audio','graphics','help'})do
   m.actions[id].props.onClick();Check(s.dialog~=m,'actual parent button opens child '..id)
   Frame(s,{ESCAPE=true});m=s.dialog;Check(m and m.unifiedSettings and not s.pointer.captured,'child Escape returns to same menu type')
  end
  Frame(s,{ESCAPE=true});Check(s.dialog==nil,'menu Escape closes')
  if isWeb then Check(s.pointer.pending,'Web resume awaits genuine lock');input.mouseLocked=true end
  Frame(s);Check(s.pointer.captured,'next Escape resumes without second menu')
  if isWeb then
   input.mouseLocked=false;Frame(s)
   Check(s.dialog and s.dialog.unifiedSettings,'browser-consumed Escape lock loss opens menu')
   m=s.dialog;Frame(s);Check(s.dialog==m,'lock loss opens only once')
  else Frame(s,{ESCAPE=true});m=s.dialog end
  m.actions.resume.props.onClick();if isWeb then input.mouseLocked=true end;Frame(s)
  Check(s.dialog==nil and s.pointer.captured,'visible continue retains capture')
  Frame(s,{ESCAPE=true});m=s.dialog;m.actions['return'].props.onClick()
  if mode=='battle'then
   Check(s.dialog and s.dialog.matchLeave and not s.wantsReturn,'battle return keeps defeat confirmation')
   Frame(s,{ESCAPE=true});Check(s.dialog.unifiedSettings and not s.wantsReturn,'confirmation Escape returns unified menu')
  else Check(s.wantsReturn,'return preserves existing mode commit/return gate')end
  Host.Dispose(s);s:Pause();count=count+1
 end
end
-- Capture denial leaves an actionable single menu, late unlock cannot recapture.
local s=New('practice',true,false);Capture(s);Frame(s,{ESCAPE=true});s.dialog.actions.resume.props.onClick();input.mouseLocked=false
for _=1,125 do Frame(s)end
Check(s.dialog and s.dialog.unifiedSettings and not s.pointer.pending,'denied resume returns to actionable menu')
local m=s.dialog;input.mouseLocked=true;input.mouseMode=MM_RELATIVE;Frame(s)
Check(s.dialog==m and not s.pointer.captured,'late browser capture does not dismiss menu')
-- Touch HUD uses exactly the same retained menu and Resume action.
s=New('practice',false,true);Capture(s);m=Settings.Open(s)
Check(m.actions.touch and not m.actions.help,'touch keeps direct settings entry')
m.actions.touch.props.onClick();Frame(s,{ESCAPE=true});Check(s.dialog.unifiedSettings,'touch child returns to unified menu')
s.dialog.actions.resume.props.onClick();Frame(s);Check(s.pointer.captured,'touch continue preserves control')
return checks,count
""")
checks,cases=run()
try:run(True);negative={'detected':False}
except Exception as e:negative={'detected':True,'error':str(e).splitlines()[0]}
assert negative['detected']
report={'status':'PASS','checks':checks,'modePlatformScenarios':cases,'baseline':'2026-10-15/b276064942ae09c0227ec28d4cfda1d5ff006455','negativeControl':negative,'sha256':{n:hashlib.sha256((ROOT/('scripts/'+n+'.lua')).read_bytes()).hexdigest() for n in FILES},'boundary':'Actual Lua Update/PollKeys/Pointer events/Host/PauseMenu executed; CPU engine/UI adapters, no browser lock API, rendering, audio, GPU or mobile performance acceptance.'}
out=ROOT/'docs/migration/evidence/unified-pause-input-offline.json';out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False,indent=2))

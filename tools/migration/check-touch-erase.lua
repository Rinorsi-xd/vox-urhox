package.path='scripts/?.lua;?.lua;'..package.path
local checks=0
local function Check(ok,label)checks=checks+1;assert(ok,label)end
cjson={null={}}
package.preload['core.ResourceData']=function()return {Read=READ_RESOURCE}end
local BP=require 'construction.Blueprint';local Editor=require 'construction.BuildEditor';local Controls=require 'controls.BuildInput'
local width,height=800,360
local Widget={}
function Widget:Extend(name)
 local class={_super=self};class.__index=class;return setmetatable(class,{__index=self,__call=function(cls,p)return setmetatable({props=p or {},children={},state={}},cls)end})
end
function Widget:AddChild(child)self.children[#self.children+1]=child;child.parent=self end
function Widget:SetStyle(p)for k,v in pairs(p)do self.props[k]=v end end
function Widget:SetVisible(on)self.props.visible=on end
function Widget:GetAbsoluteLayoutForHitTest()
 local x,y=self.props.left or 0,self.props.top or 0
 if self.parent then local r=self.parent:GetAbsoluteLayoutForHitTest();x=x+r.x;y=y+r.y end
 return {x=x,y=y,w=type(self.props.width)=='number' and self.props.width or width,h=type(self.props.height)=='number' and self.props.height or height}
end
local Panel=Widget:Extend('Panel')
local UI={Widget=Widget,Panel=Panel,GetViewportSize=function()return width,height end,GetSafeAreaInsets=function()return {}end,ClearFocus=function()end,CancelPointer=function()end}
package.preload['urhox-libs/UI']=function()return UI end
package.preload['ui.TouchEditorWidgets']=function()return {Button=Panel,Surface=Panel}end
package.preload['ui.SourceTouchDriveWidgets']=function()return {Stick=Panel}end
graphics={GetWidth=function()return width end,GetHeight=function()return height end,GetDPR=function()return 1 end}
KEY_SHIFT=1;KEY_CTRL=2;KEY_SPACE=3
input={focus=true,minimized=false,GetKeyDown=function()return false end}
local function Hit(id)return id and {partId=id,cell={(id-1)*2,4,0},place={(id-1)*2,5,0},normal={0,1,0}} or nil end
local function Make(case)
 local bp=BP.New();for _,p in ipairs(case.parts)do bp:Add(p)end
 local sounds={};local e=Editor.New(bp,nil,function(id)sounds[#sounds+1]=id end);e.mirror=false;e.tool=case.tool or 'build';e.pasting=case.pasting or false
 if case.select then for id in pairs(bp.parts)do e.selection[id]=true end;e:SelectionChanged()end
 local s={editor=e,selecting=case.select or false,buildCamera={mode=case.mode,touch=true,captured=true,held={}},hud={touchControls={prefs={build=case.build or 'aim'}}},app={touchPrefs={build=case.build or 'aim',size=1,sens=1}},inventory={hotbar={},active=1},inspection={Get=function()return {stats={budget=0,fitTier={id=1}}}end},camera={}}
 function s:Trace()e.hit=Hit(self.aim)end
 function s:Refresh()self.refreshes=(self.refreshes or 0)+1 end
 s.controls=Controls.New(s)
 return s,sounds
end
local function Rows(s,expected,sounds,label)
 local ids={};for id in pairs(s.editor.bp.parts)do ids[#ids+1]=id end;table.sort(ids)
 Check(#ids==#expected.ids,label..' remaining count');for i,id in ipairs(ids)do Check(id==expected.ids[i],label..' remembered/actual target')end
 local selection=s.editor:Selected();local selected={};for _,p in ipairs(selection)do selected[#selected+1]=p.id end;table.sort(selected)
 Check(#selected==#expected.selection,label..' selection count');for i,id in ipairs(selected)do Check(id==expected.selection[i],label..' selected id')end
 Check(#s.editor.history.undoStack==expected.transactions,label..' undo transactions');Check(#sounds==#expected.sounds,label..' cue count')
 for i,id in ipairs(sounds)do Check(id==expected.sounds[i],label..' original cue')end
end
for _,case in ipairs(SOURCE.cases)do
 local s,sounds=Make(case)
 for i,step in ipairs(case.steps)do
  local op,value,target=step[1],step[2],step[3]
  if op=='down' then s.aim=value;if case.build~='tap' then s.controls:TouchErase(true)end
  elseif op=='aim' then s.aim=value;s:Trace()
  elseif op=='tick' then s.aim=target;s.controls:Update(value)
  elseif op=='up' and case.build~='tap' then s.controls:TouchErase(false)end
  Rows(s,case.states[i],sounds,case.name..' step '..i)
 end
end
local basic={mode='orbit',parts=SOURCE.cases[1].parts}
for _,gate in ipairs({'dialog','inventoryPanel','disposed'})do
 local s=Make(basic);s.aim=1;s[gate]=true;s.controls:TouchErase(true)
 Check(not s.controls.touchErase and s.editor.bp:Size()==3,'press blocked by '..gate)
 s[gate]=nil;s.controls:TouchErase(true);s[gate]=true;s.controls:TouchErase(false)
 Check(s.editor.bp:Size()==3,'release blocked by '..gate)
 s[gate]=nil;s.controls:TouchErase(true);s[gate]=true;s.controls:Update(.5)
 Check(not s.controls.touchErase and s.editor.bp:Size()==3,'active hold cancelled by '..gate)
end
for _,mode in ipairs({'orbit','fp'})do
 for _,reason in ipairs({'cancel','focus','clear'})do
  local s=Make({mode=mode,parts=basic.parts});s.aim=1;s.controls:TouchErase(true);local before=s.editor.bp:Size()
  if reason=='cancel' then s.controls:TouchErase(false,true)
  elseif reason=='focus' then input.focus=false;s.controls:Update(.5);input.focus=true
  else s.controls:Cancel()end
  s.controls:Update(.5);Check(s.editor.bp:Size()==before and not s.controls.touchErase,'no release edit or lingering hold after '..mode..' '..reason)
 end
end
for _,phase in ipairs({'rect','height','selection'})do
 local s=Make({mode='fp',parts=basic.parts});s.aim=1;s.editor.stretch={phase=phase,type='cube',rot=0,n={0,1,0},a=2,anchor={0,6,0},cur={0,6,0},h=1,adj=0,hd={0,1,0}};s.controls:TouchErase(true)
 Check(s.editor.bp:Size()==3 and #s.editor.history.undoStack==0,'stretch secondary does not remove blueprint')
 Check(phase=='height' and s.editor.stretch.phase=='rect' or phase~='height' and not s.editor.stretch,'stretch existing secondary transition '..phase)
 s.controls:Update(.5);Check(s.editor.bp:Size()==3,'stretch secondary does not repeat')
end
local Touch=require 'ui.TouchBuildControls'
local function Event(x,y)return {x=x,y=y,pointerId=7,IsTouch=function()return true end,StopPropagation=function()end,PreventDefault=function()end}end
for _,mode in ipairs({'orbit','fp'})do
 local s,sounds=Make({mode=mode,parts=basic.parts});s.aim=1;local root=Panel{};local play=Panel{};root:AddChild(play)
 local layer=Touch.Create(s,root,play);s.hud.touchControls=layer
 Check(layer.buttons.erase.props.visible~=false,'source aim delete button visible '..mode)
 local r=layer.buttons.erase:GetAbsoluteLayoutForHitTest();local ev=Event(r.x+r.w/2,r.y+r.h/2)
 layer.buttons.erase:OnPointerDown(ev)
 Check(s.editor.bp:Size()==(mode=='orbit' and 3 or 2),'actual bound erase pointerdown '..mode)
 layer.buttons.erase:OnPointerUp(ev)
 Check(s.editor.bp:Size()==2 and #sounds==1 and sounds[1]=='remove' and not layer.eraseTap,'actual bound erase release removes once without toggling tap flag '..mode)
 layer.Dispose();Check(layer.disposed and not s.controls.touchErase,'dispose clears actual gesture-held erase '..mode)
end
local s=Make({mode='orbit',parts=basic.parts,build='tap'});s.aim=1;local layer=Touch.Create(s,Panel{},Panel{});s.hud.touchControls=layer
Check(layer.buttons.erase.props.visible==false,'source tap hides aim erase button');layer.Action('erase');Check(layer.eraseTap,'existing tap erase toggle preserved')
layer.Dispose()
for name,value in pairs(SOURCE.sourceLimits)do Check(value,'documented source touch limitation '..name)end
package.preload['render.BuildGhost']=function()return {}end
package.preload['ui.BuildHud']=function()return {}end
local Session=require 'app.BuildSession'
local function EscapeSession(case,touch)
 local s=Make({mode='fp',parts=basic.parts,select=case.state=='selection',tool=case.state=='paint' and 'paint' or 'build',pasting=case.state=='paste'})
 s.closes=0;s.pauses=0;s.releases=0;s.buildCamera.touch=touch;s.buildCamera.captured=case.captured;s.buildCamera.pending=case.pending;s.hud.colorOpen=false
 s.buildCamera.Release=function(self)s.releases=s.releases+1;self.captured=false;self.pending=false end
 s.OpenPause=function()s.pauses=s.pauses+1 end
 if case.state=='dialog' then s.dialog={Close=function()s.closes=s.closes+1;s.dialog=nil end}end
 if case.state=='inventory' then s.inventoryPanel={Close=function()s.closes=s.closes+1;s.inventoryPanel=nil end}end
 if case.state=='stretch' then s.editor.stretch={phase='rect'}end
 return s
end
for _,case in ipairs(SOURCE.escapeCases)do
 local s=EscapeSession(case,true);Session.Escape(s)
 local label='actual source Escape '..case.state..' captured='..tostring(case.captured)..' pending='..tostring(case.pending)
 Check(s.editor.pasting==case.pasting,label..' cancels paste first key')
 Check(#s.editor:Selected()==#case.selection,label..' selection');Check(s.editor.tool==case.tool,label..' tool')
 Check((s.editor.stretch~=nil)==case.stretch,label..' stretch');Check(s.pauses==case.pauses and s.closes==case.closes,label..' modal/pause route')
 Check(s.releases==0,label..' touch camera activity is not mouse lock');Check(s.editor.history.revision==0 and s.editor.bp:Size()==3,label..' no mutation')
end
for _,state in ipairs({{captured=true,pending=false},{captured=false,pending=true}})do
 state.state='paste';local s=EscapeSession(state,false);Session.Escape(s)
 Check(s.releases==1 and s.editor.pasting,'PC real/pending mouse lock still releases before commands')
 Session.Escape(s);Check(not s.editor.pasting and s.releases==1,'PC second key cancels paste after mouse release')
end
local Old=assert(load('local M={};'..OLD_ESCAPE_BODY..';return M'))()
local old=EscapeSession({state='paste',captured=true,pending=false},true);Old.Escape(old)
Check(old.editor.pasting and old.releases==1,'old production condition reproduces observed first Escape failure')
return checks

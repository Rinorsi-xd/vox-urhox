package.path='scripts/?.lua;?.lua;'..package.path
package.preload['core.ResourceData']=function()return {Read=READ_RESOURCE}end
package.preload['urhox-libs/UI']=function()return {GetFocus=function()end}end
package.preload['render.BuildGhost']=function()return {}end
package.preload['ui.BuildHud']=function()return {}end
local web=false
package.preload['urhox-libs.Platform.PlatformUtils']=function()return {IsWebPlatform=function()return web end}end
local Session=assert(loadfile(INPUT_SESSION_MODULE))()
local Controls=assert(loadfile(INPUT_CONTROLS_MODULE))()
local BP=require 'construction.Blueprint';local Editor=require 'construction.BuildEditor'
local checks=0;local failures={}
local function Check(v,msg)checks=checks+1;if not v then failures[#failures+1]=msg end end
local function Same(a,b,msg)Check(JSON(a)==JSON(b),msg)end
for _,name in ipairs({'SHIFT','CTRL','ALT','Z','Y','TAB','SPACE'})do _G['KEY_'..name]=name end
local down,pressed={},{}
input={GetKeyDown=function(_,k)return down[k] or false end,GetKeyPress=function(_,k)return pressed[k]or false end}
local function Make()
 local bp=BP.New()
 for i,spec in ipairs({{0,'cube',9},{1,'cube',9},{2,'slope',0}})do bp:Add({type=spec[2],pos={spec[1],4,0},rot=0,color=0x336699,g=spec[3]})end
 local e=Editor.New(bp);e.mirror=false;e.selection={[1]=true,[2]=true,[3]=true}
 local s=setmetatable({editor=e,buildCamera={mode='orbit'},camera={dist=20,minDist=2,maxDist=80,yaw=0,pitch=0},wheelAcc=23,hud={},inventory={active=1,hotbar={'cube','slope'}},refreshes=0},{__index=Session})
 s.controls=Controls.New(s)
 function s:Refresh()self.refreshes=self.refreshes+1 end
 function s:Trace()end
 function s:Act()error('Unexpected placement')end
 function s:BoxSelect()error('Unexpected box selection')end
 return s,e,bp
end
for _,isWeb in ipairs({false,true})do web=isWeb
 for i,c in ipairs(fixtures.wheels)do
  down={[KEY_SHIFT]=c.modifiers=='shift',[KEY_CTRL]=c.modifiers=='ctrl',[KEY_ALT]=c.modifiers=='alt'};pressed={}
  local s,e=Make();s.buildCamera.mode=c.mode
  e.stretch={phase=c.phase,h=8,adj=3,seeds={},n={0,1,0},a=2,anchor={0,4,0},cur={0,4,0},hd={0,1,0},type='cube',rot=0}
  s:Wheel(-c.pixels/(isWeb and 1 or 100))
  -- Rectangle/height geometry updates are real; height phase derives h from
  -- base + adj. Source height h is materialised in its separate update pass.
  local expectedH=c.phase=='height' and (c.modifiers=='none' or c.modifiers=='alt') and math.max(1,math.min(48,1+c.adj)) or c.h
  Check(e.stretch.h==expectedH and e.stretch.adj==c.adj,'wheel state '..tostring(isWeb)..'/'..i)
  Check(s.wheelAcc==c.acc and math.abs(s.camera.dist-c.dist)<1e-10,'wheel priority/accumulator '..tostring(isWeb)..'/'..i)
 end
end
for i,c in ipairs(fixtures.keys)do
 down={[KEY_CTRL]=true,[KEY_SHIFT]=c.shift};pressed={[c.code=='KeyZ' and KEY_Z or KEY_Y]=true}
 local s,e,bp=Make()
 e.history:Commit({{op='add',data={id=4,type='cube',pos={3,4,0},rot=0,color=0x336699,g=0}}})
 -- Both stacks exist, so cancelling must neither undo nor redo a prior edit.
 e.history:Commit({{op='add',data={id=5,type='cube',pos={4,4,0},rot=0,color=0x336699,g=0}}});e:Undo()
 local before=JSON(bp:ToTable());local undo=#e.history.undoStack;local redo=#e.history.redoStack
 e.stretch={phase='selection',h=2};s:Keys()
 Check(not e.stretch and #e.history.undoStack==undo and #e.history.redoStack==redo and JSON(bp:ToTable())==before,'stretch cancel preserves real blueprint/history '..i)
 Check(c.stretch==false and c.undo==1 and c.redo==0,'source cancel fixture '..i)
end
local function Keys(t)local out={};for k in pairs(t)do out[#out+1]=k end;table.sort(out);return out end
for i,c in ipairs(fixtures.pointers)do
 down={};pressed={};local s,e,bp=Make();s.selecting=c.tool=='select';e.tool=c.tool=='select' and 'build' or c.tool or 'build'
 e.hit=c.press and {partId=c.press}or nil
 local function Event(x,y)return {pointerId=1,x=x,y=y,IsTouch=function()return false end,IsSecondaryButton=function()return c.button==2 end,IsPrimaryButton=function()return false end}end
 s.controls:Down(Event(10,10))
 if c.excursion then s.controls:Move(Event(16,16));s.controls:Move(Event(10,10))end
 if c.dx or c.dy then s.controls:Move(Event(10+(c.dx or 0),10+(c.dy or 0)))end
 e.hit=c.release and {partId=c.release}or nil
 s.controls:Up(Event(10+(c.dx or 0),10+(c.dy or 0)))
 Same(Keys(bp.parts),c.parts,'pointer actual blueprint '..c.name)
 Same(Keys(e.selection),c.selection,'pointer group/selection '..c.name)
 Check((s.selecting and 'select' or e.tool)==c.tool and e.type==c.type and e.color==c.color,'pointer picked part/finish/mode '..c.name)
end
-- Touch still uses cumulative gesture travel, so a long orbit that returns
-- to its starting pixel cannot accidentally place a part on release.
do
 local s=Make();local actions=0;s.Act=function()actions=actions+1 end
 local function E(x,y)return {pointerId=1,x=x,y=y,IsTouch=function()return true end,IsSecondaryButton=function()return false end,IsPrimaryButton=function()return true end}end
 s.controls:Down(E(10,10));s.controls:Move(E(16,16));s.controls:Move(E(10,10));s.controls:Up(E(10,10))
 Check(actions==0,'touch orbit return to origin is not a tap')
 s.controls:Down(E(10,10));s.controls:Up(E(10,10));Check(actions==1,'touch tap still places once')
end
return {checks=checks,failures=failures,passed=#failures==0}

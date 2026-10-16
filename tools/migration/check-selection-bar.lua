package.path='scripts/?.lua;?.lua;'..package.path
local checks=0
local function Check(v,msg)checks=checks+1;assert(v,msg)end
cjson={null={}}
package.preload['core.ResourceData']=function()return {Read=READ_RESOURCE}end
local BP=require 'construction.Blueprint';local Editor=require 'construction.BuildEditor'
local function Rows(e,expected,label)
 local count=0;for _ in pairs(e.bp.parts)do count=count+1 end;Check(count==#expected,label..' count')
 for _,row in ipairs(expected)do local p=e.bp.parts[row.id];Check(p~=nil,label..' id');Check(p.type==row.type,label..' type');Check(p.color==row.color,label..' color');Check(p.shellColor==row.shellColor,label..' shellColor')end
end
for _,case in ipairs(SOURCE.cases)do
 local bp=BP.New();for _,data in ipairs(case.parts)do bp:Add(data)end
 local sounds={};local e=Editor.New(bp,nil,function(id)sounds[#sounds+1]=id end)
 e.mirror=case.mirror or false;e.autoColor=case.auto or false;e.paintChannel=case.channel or 'shell';e.color=0xd0182a;e.tool=case.tool or 'build'
 for _,id in ipairs(case.selection)do e.selection[id]=true end
 Rows(e,case.before,case.name..' before')
 local ok,message=e:PaintSelection();Rows(e,case.after,case.name..' painted')
 Check(ok==(case.undoCount>0),case.name..' actual transaction success');Check(message==case.messages[1],case.name..' source toast')
 Check(#sounds==#case.sounds,case.name..' source sounds');for i,id in ipairs(sounds)do Check(id==case.sounds[i],case.name..' cue')end
 Check(#e.history.undoStack==case.undoCount,case.name..' one undo transaction')
 if ok then e:Undo();Rows(e,case.undone,case.name..' undo');Check(#e.history.undoStack==0,case.name..' one-step undo');e:Redo();Rows(e,case.redone,case.name..' redo');Check(#sounds==1,case.name..' undo redo silent')end
end
Check(not package.loaded['audio.UiSound'],'paint selection domain does not import runtime sound')
local widget={}
function widget:AddChild(child)child.parent=self;self.children[#self.children+1]=child;return child end
function widget:SetStyle(props)for k,v in pairs(props)do self.props[k]=v end end
function widget:SetWidth(v)self.props.width=v end
function widget:SetVisible(v)self.props.visible=v end
function widget:GetAbsoluteLayout()return {x=20,y=40,w=type(self.props.width)=='number' and self.props.width or 100,h=type(self.props.height)=='number' and self.props.height or 40}end
function widget:Extend(name)
 local class={_super=self};class.__index=class;setmetatable(class,{__index=self,__call=function(cls,props)return setmetatable({props=props or {},state={},children={}},cls)end});return class
end
function widget:OnClick(event)if self.props.onClick then return self.props.onClick(self,event)end end
local Panel=widget:Extend('Panel')
local w,h=1920,1080;local UI={Panel=Panel,ScrollView=Panel,GetViewportSize=function()return w,h end,ClearFocus=function()end}
package.preload['urhox-libs/UI']=function()return UI end
package.preload['urhox-libs/UI/Widgets/Panel']=function()return Panel end
package.preload['urhox-libs/UI/Widgets/Button']=function()return widget:Extend('EngineButton')end
package.preload['ui.SourceFonts']=function()return {GetBodyFace=function()end}end
local Text=require 'ui.SourceTextLayout';local draw={}
package.preload['ui.SourceDraw']=function()return {orange={122,216,255,255},Begin=function()end,Width=function(_,text,size,font,spacing)return Text.Width(assert(Text.Get(tostring(text),font)),size,spacing or 0)end,
 Rect=function(_,x,y,width,height,c)draw[#draw+1]={kind='rect',x=x,y=y,w=width,h=height,c=c}end,
 Text=function(_,text,x,y,size,c,font)draw[#draw+1]={kind='text',text=text,x=x,y=y,size=size,c=c,font=font}end,
 Icon=function(_,icon,x,y,size,c)draw[#draw+1]={kind='icon',icon=icon,x=x,y=y,size=size,c=c}end}end
local shadowsDisposed=0
package.preload['ui.SourceBoxShadow']=function()return {New=function()return {Draw=function()end,Dispose=function()shadowsDisposed=shadowsDisposed+1 end}end}end
nvgRGBA=function(...)return {...}end
package.preload['render.BuildGhost']=function()return {}end
package.preload['controls.BuildInput']=function()return {}end
package.preload['ui.BuildHud']=function()return {}end
local Session=require 'app.BuildSession'
local selected={1,2};local e={pasting=false,color=0x123456,autoColor=false,Selected=function()return selected end}
local calls={};local session={editor=e,SelectionAction=function(_,action)calls[#calls+1]=action end}
local Bar=require 'ui.SourceSelectionBar';local parent=Panel{}
local bar=Bar.Create(session,parent)
Check(#bar.row.children==8,'original count and seven buttons');Check(#parent.children==1,'single original selection strip')
for _,entry in ipairs(SOURCE.entries)do local b=bar.buttons[entry.action];Check(b and b.props.text==entry.text and b.props.icon==entry.icon,'all original labels/icons: '..entry.action)
 b:OnClick({IsPrimaryAction=function()return false end});Check(#calls==0,'secondary selection button silent: '..entry.action)
 b:OnClick({IsPrimaryAction=function()return true end});Check(calls[1]==entry.action,'primary real callback route: '..entry.action);calls={}
end
for _,case in ipairs(SOURCE.bars)do
 selected={};for i=1,case.count do selected[i]=i end;e.pasting=case.pasting;e.autoColor=case.auto;bar:Sync()
 Check(bar.shown==case.show,'actual source visibility');Check(bar.count==case.count,'source selection count');Check(bar.brush==(case.auto and 0xc9ced6 or 0x123456),'source current brush')
 if bar.shown then bar.root:Update(.18);Check(bar.root.props.opacity==1 and bar.root.props.translateY==0,'source menuIn completion')end
end
selected={1};e.pasting=false;bar:Sync();session.inventoryPanel={};bar:Sync();Check(not bar.shown,'inventory hides source selection strip');session.inventoryPanel=nil;session.dialog={};bar:Sync();Check(not bar.shown,'dialog prevents stale strip actions');session.dialog=nil;bar:Sync()
Check(bar.shown,'selection returns after overlays close');bar.root:Update(0);Check(bar.root.props.opacity==0 and bar.root.props.translateY==10,'source menuIn starting pose');bar.root:Update(.09);Check(bar.root.props.opacity>.5 and bar.root.props.opacity<1,'source ease-out menu timing')
for _,view in ipairs({{1920,1080},{1440,810},{1280,720},{1333.333,600},{800,360},{640,360}})do
 w,h=view[1],view[2];bar:Sync();local l=bar.layout
 Check(l.bottom==(h<=600 and 108 or 128),'source landscape bottom');Check(l.buttonHeight==(h<=600 and 44 or 40),'source landscape touch height')
 Check(l.width<=w-24 or h>600,'horizontal overflow stays within source viewport bound')
 for i,entry in ipairs(SOURCE.entries)do
  local b=bar.buttons[entry.action];Check(b.props.key==(w>1440 and entry.key or ''),'1440 source key visibility')
  local width=Text.Width(assert(Text.Get(entry.text,'vox-title')),14,0)
  Check(32+width<=b.props.width-10+1e-8,'label fits fixed source button: '..entry.action)
 end
end
draw={};bar.root:Render({});Check(draw[1].c[1]==22 and draw[1].c[2]==45 and draw[1].c[3]==67,'final utility panel color')
for _,entry in ipairs(SOURCE.entries)do local b=bar.buttons[entry.action];draw={};b:Update(.12);b:Render({});local found=false;for _,op in ipairs(draw)do if op.kind=='text' and op.text==entry.text then found=op.font=='vox-title' and op.size==14 end end;Check(found,'source final font and size: '..entry.action)end
bar:Dispose();bar:Dispose();Check(shadowsDisposed==1,'selection shadow ownership disposed exactly once')
for _,case in ipairs(SOURCE.actions)do
 local recorded={};local ed={pasting=false,selection={[1]=true},selectionCorners={{}},clipboard={{}},bp={Size=function()return 2 end}}
 local names={Copy='copy',ToggleForm='toggleForm',SetTool='setTool',PaintSelection='paintSelection',DeleteSelection='deleteSelection',SelectionChanged='clearSelection'}
 for target,source in pairs(names)do ed[target]=function(_,...)recorded[#recorded+1]={source,...};return true end end
 local s=setmetatable({editor=ed,controls={Cancel=function()end},Notify=function(_,text)if case.action=='move' then recorded[#recorded+1]={'toast',text}end end,Refresh=function()end},{__index=Session})
 s:SelectionAction(case.action)
 Check(recorded[1][1]==case.calls[1][1],'actual source action dispatch: '..case.action)
 if case.action=='stretch' then Check(recorded[1][2]=='stretch' and not s.selecting and #ed.selectionCorners==0,'stretch exact tool plus transient reset')end
 if case.action=='clear' then Check(next(ed.selection)==nil and #ed.selectionCorners==0,'clear source selection and corners')end
 for _,gate in ipairs({'dialog','inventoryPanel','disposed'})do s[gate]=true;recorded={};Check(not s:SelectionAction(case.action) and #recorded==0,'action blocked by '..gate);s[gate]=nil end
 ed.pasting=true;recorded={};Check(not s:SelectionAction(case.action) and #recorded==0,'source pasting hides and gates selection action')
end
return checks

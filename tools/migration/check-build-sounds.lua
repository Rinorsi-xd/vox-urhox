package.path='scripts/?.lua;?.lua;'..package.path
local checks=0
local function Check(v,msg)checks=checks+1;assert(v,msg)end
local sounds={}
local function Reset()sounds={}end
local function Same(expected,label)
 Check(#sounds==#expected,label..' sound count')
 for i,id in ipairs(expected)do Check(sounds[i]==id,label..' cue')end
end
package.preload['core.ResourceData']=function()return {Read=READ_RESOURCE}end
package.preload['audio.UiSound']=function()return {Play=function(id)sounds[#sounds+1]=id;return true end}end
local BP=require 'construction.Blueprint';local Editor=require 'construction.BuildEditor';local Placement=require 'construction.Placement'
for _,case in ipairs(fixtures.cases)do
 Reset();local bp=BP.New();for _,data in ipairs(case.initial)do bp:Add(data)end
 local e=Editor.New(bp,nil,function(id)sounds[#sounds+1]=id end);e.mirror=case.params.mirror or false;local p=case.params;local name=case.name
 if name:sub(1,6)=='place-' then
  if p.pos then e.preview={type='cube',pos=p.pos,rot=0,res=bp:Check('cube',p.pos,0,e.bounds),normal={0,1,0},mirror=p.mirror and Placement.Mirror('cube',p.pos,0)or nil}end
  e:Place()
 elseif name:sub(1,7)=='remove-' then e:Remove(p.hit)
 elseif name:sub(1,6)=='paint-' then e.tool=p.tool;e.paintChannel=p.channel;e.color=p.color;e.hit={partId=1};e:Paint()
 elseif name:sub(1,6)=='paste-' then e.preview={paste=p.paste,ok=p.ok};e:CommitPaste()
 elseif name:sub(1,6)=='rotor-' then e.hit={partId=1};e:SetRotorMode(p.index+1)
 elseif name:sub(1,5)=='join-' then if p.selected then e.selection={[1]=true,[2]=true}end;e:ToggleForm()
 else error(name)end
 Same(case.sounds,name);Check(bp:Size()==case.count,name..' actual blueprint count matches source')
 Reset();e:Undo();e:Redo();Check(#sounds==0,name..' undo/redo remain silent')
end
local Stretch=require 'construction.BuildStretch'
Check(not package.loaded['audio.UiSound'],'editor loads without UI sound runtime')
local silent=Editor.New(BP.New());silent:Cue('place');Check(#sounds==0,'editor without cue adapter is silent')
local bp=BP.New();bp:Add({type='cube',pos={0,4,0},rot=0});local e=Editor.New(bp,nil,function(id)sounds[#sounds+1]=id end);e.mirror=false
e.preview={type='cube',pos={0,5,0},rot=0,normal={0,1,0},res=bp:Check('cube',{0,5,0},0,e.bounds)}
Reset();Check(Stretch.Click(e),'start actual rectangle');Check(#sounds==0,'stretch initial preview silent')
Check(Stretch.Click(e),'actual height phase');Check(#sounds==0,'height preview silent')
Check(Stretch.Click(e),'actual stretch commit');Same({'place'},'stretch successful commit')
e.preview={type='cube',pos={0,6,0},rot=0,normal={0,1,0},res=bp:Check('cube',{0,6,0},0,e.bounds)}
Reset();Stretch.Click(e);Stretch.Right(e);Check(#sounds==0 and not e.stretch,'cancelled stretch silent')
local widget={}
function widget:AddChild(child)self.children[#self.children+1]=child;return child end
function widget:AddContent(child)return self:AddChild(child)end
for _,n in ipairs({'SetHeight','SetWidth','SetStyle','Open','Destroy','Close','SetPart','ScrollToTop','SetValue'})do widget[n]=function()end end
local function New(props)return setmetatable({props=props or {},children={}}, {__index=widget})end
function widget:Extend()local class={};class.__index=class;setmetatable(class,{__index=widget,__call=function(_,props)local w=New(props);return setmetatable(w,{__index=class})end});return class end
local UI={Panel=setmetatable({}, {__index=widget,__call=function(_,props)return New(props)end}),ScrollView=New,VirtualList=New,Label=New,
 GetViewportSize=function()return 1920,1080 end,GetFocus=function()end,GetScale=function()return 1 end,FindWidgetAt=function()end,ClearFocus=function()end}
package.preload['urhox-libs/UI']=function()return UI end
package.preload['urhox-libs/UI/Core/Input']=function()return {On=function()return 1 end,Off=function()end}end
package.preload['ui.VoxTheme']=function()return {}end
package.preload['ui.SourceDraw']=function()return {}end
package.preload['ui.InventoryChrome']=function()return {Modal=New,Button=New,Title=function()return New()end,MaterialHeader=function()return New()end,Footer=function()return New()end,icons={}}end
package.preload['ui.InventoryList']=function()return function(props)local w=New(props);w.contentContainer_=New();return w end end
for _,n in ipairs({'ui.InventorySearch','ui.InventoryDetail','ui.InventoryDetailScroll'})do package.preload[n]=function()return New end end
package.preload['ui.BuildHotbar']=function()return {Create=function()return {root=New({width=1000})}end}end
package.preload['render.SceneBackdrop']=function()return {New=function()end}end
package.preload['controls.TouchMode']=function()return {Enabled=function()return false end}end
local Inventory=require 'ui.InventoryPanel';Inventory.Fill=function()end;Inventory.Detail=function()end
local session={app={},model={},inventory={Current=function()return 'cube'end},buildCamera={Release=function()end},controls={Cancel=function()end},editor={},ghost={Refresh=function()end},Refresh=function()end}
Reset()
for _,case in ipairs(fixtures.inventory)do
 Reset()
 if case.force then Inventory.Open(session)else session.inventoryPanel=nil end
 Same(case.sounds,'actual inventory repeated toggle '..tostring(case.force))
end
session.inventoryPanel=nil;Reset();Inventory.Open(session,{shown='cube'});Check(#sounds==0,'inventory responsive reconstruction does not replay open')
package.preload['render.BuildGhost']=function()return {}end;package.preload['controls.BuildInput']=function()return {}end;package.preload['ui.BuildHud']=function()return {}end
local Session=require 'app.BuildSession'
for _,case in ipairs(fixtures.saves)do
 Reset();local s=setmetatable({app={bays={active=1,Save=function()return case.ok and not case.blocked end},store={Flush=function()end}},Notify=function()end,OpenLibrary=function()end},{__index=Session})
 s:SaveSlot();Same(case.sounds,'actual BuildSession save '..tostring(case.ok)..'/'..tostring(case.blocked))
end
package.preload['ui.SourceButton']=function()return New end
package.preload['ui.ActionButton']=function()return New end
local Card=setmetatable({Delete=New},{__call=function(_,props)return New(props)end})
package.preload['ui.SourceLibraryCard']=function()return Card end
package.preload['ui.BayPreviews']=function()return {New=function()return {FinishJob=function()end,Dispose=function()end,Update=function()end,Add=function()return New()end}end}end
local confirm
package.preload['ui.DialogHost']=function()return {Open=function()return New()end,Close=function()end,Notify=function()end,Confirm=function(_,_,_,yes)confirm=yes end}end
local Library=require 'ui.BlueprintLibrary'
for _,ok in ipairs({true,false})do
 local slots={};for i=1,20 do slots[i]=false end
 local owner={app={bays={Slots=function()return slots end,Save=function()return ok end},store={SaveMessage=function(_,s)return s end}}}
 Reset();local modal=Library.Open(owner,'save');Check(#sounds==0,'opening save library has no stamp')
 modal.cards[1].props.onClick();Same(ok and {'stamp'}or {},'actual library empty save success/fail')
 slots[1]={name='original'};Reset();modal=Library.Open(owner,'save');modal.cards[1].props.onClick()
 Check(#sounds==0 and type(confirm)=='function','overwrite confirmation waits silently')
 confirm();Same(ok and {'stamp'}or {},'actual overwrite result success/fail')
end
local Live=require 'construction.LiverySession'
for _,case in ipairs(fixtures.livery)do
 local list={};for i=1,case.size do list[i]={s=case.sticker,p={2,3,4},n={0,0,1},r=0,w=3}end
 local app={blueprint={livery=list},car={livery={Set=function()end,SetPreview=function()end}},bays={Changed=function()end},toasts={Push=function()end}}
 local s=Live.New(app,function(id)sounds[#sounds+1]=id end);s.pick=case.pick and case.sticker or false;s.mirrorNew=case.mirror;s.sel=case.selected and 1 or 0
 Reset();if case.kind=='place'then s:Place({p={2,3,4},n={0,0,1}})else s:Remove()end
 Same(case.sounds,'actual livery '..case.kind..'/'..case.size);Check(#s:List()==case.count,'actual livery count matches source')
 Reset();s:Undo();s:Undo(true);Check(#sounds==0,'livery undo/redo silent')
end
return checks

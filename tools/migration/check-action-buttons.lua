package.path='scripts/?.lua;?.lua;'..package.path
MOUSEB_LEFT=0;MOUSEB_MIDDLE=1;MOUSEB_RIGHT=2
local checks=0
local function Check(value,msg) checks=checks+1;assert(value,msg) end
local classes={}
local Widget={};Widget.__index=Widget
assert(load('local Widget=...;'..ENGINE_EXTEND..';return Widget'))(Widget)
local originalExtend=Widget.Extend
function Widget:Extend(name)
    local class=originalExtend(self,name);classes[#classes+1]=class;return class
end
function Widget:SetState(values) for key,value in pairs(values) do self.state[key]=value end end
function Widget:OnFocus() end
function Widget:OnBlur() end
function Widget:OnPointerCancel() end
function Widget:DispatchEvent(name,instance,event)
    Check(name=='click' and instance==self,'native button click listener signature')
    self.events[#self.events+1]=event or false
end
local UI={Panel=Widget,Slider=Widget,Widget=Widget}
package.preload['urhox-libs/UI']=function() return UI end
package.preload['urhox-libs/UI/Core/UI']=function() return UI end
package.preload['urhox-libs/UI/Core/Widget']=function() return Widget end
for _,name in ipairs({'Theme','Style','Transition','ImageCache'}) do
    package.preload['urhox-libs/UI/Core/'..name]=function() return {} end
end
for _,name in ipairs({'Panel','Slider','TextField'}) do
    package.preload['urhox-libs/UI/Widgets/'..name]=function() return Widget end
end
for _,name in ipairs({'ui.SourceDraw','ui.SourceRelief','ui.SourceButtonMotion','ui.VoxTheme',
    'parts.Defs','ui.InventoryFeedback','ui.InventoryShadows','construction.LiveryData','ui.WorkshopPaint',
    'ui.SourceParagraph','story.MissionResultRows','ui.MusicDraw','ui.StoryFrame','ui.StoryPageLayout',
    'ui.SourceTextLayout','ui.SourceBoxShadow'}) do
    package.preload[name]=function() return {} end
end
package.preload['ui.SourcePopover']=function() return Widget end
package.preload['ui.OwnedModal']=function() return Widget end
package.preload['core.ResourceData']=function() return {Read=function(name)return TEST_RESOURCES[name] end} end
local PointerEvent=require 'urhox-libs/UI/Core/PointerEvent'
local Base=require 'urhox-libs/UI/Widgets/Button';UI.Button=Base
local Action=require 'ui.ActionButton'
for _,name in ipairs(TEST_MODULES) do require(name) end
assert(load('local UI,PointerEvent,hit=...;local scale_=1;local pressedWidgets_={};local hoveredWidgets_={};local focusedWidget_;'..
    'local function findWidgetAt()return hit() end;local function screenToWidgetLocal(_,x,y)return x,y end;'..
    'local function clearHoveredPointer()end;local enabled_=true;'..ENGINE_HANDLERS))(UI,PointerEvent,function()return TEST_HIT end)
local function Instance(class,disabled)
    local props={disabled=disabled,text='unchanged',onClick=function(self,event)
        self.callbacks[#self.callbacks+1]=event or false
    end}
    return setmetatable({props=props,state={},events={},callbacks={},TransitionToStateBgColor=function()end},class)
end
local function Event(kind,button,primary,id)
    return PointerEvent.new('PointerUp',{pointerType=kind,button=button,isPrimary=primary,pointerId=id or 0,x=20,y=30})
end
local old=Instance(Base,false);TEST_HIT=old
UI.HandlePointerDown(Event('mouse',MOUSEB_RIGHT,true));UI.HandlePointerUp(Event('mouse',MOUSEB_RIGHT,true))
Check(#old.callbacks==1 and #old.events==1,'reproduce actual old native Button right-click activation')
local oldReproduced=true
local tested={};local matrix=0
for _,class in ipairs(classes) do
    local ancestor=class;local project=false
    while ancestor do if ancestor==Action then project=true;break end;ancestor=rawget(ancestor,'_super') end
    if project then
        tested[#tested+1]=class._className
        Check(class.OnClick==Action.OnClick,'all actual project classes inherit guarded click '..class._className)
        Check(class.OnPointerUp==Base.OnPointerUp,'native pointer release retained '..class._className)
        for _,disabled in ipairs({false,true}) do
            for _,spec in ipairs({
                {'mouse',MOUSEB_LEFT,true,0,true}, {'mouse',MOUSEB_RIGHT,true,0,false},
                {'mouse',MOUSEB_MIDDLE,true,0,false}, {'pen',MOUSEB_LEFT,true,1,true},
                {'pen',MOUSEB_RIGHT,true,1,false}, {'touch',MOUSEB_LEFT,true,7,true},
                {'touch',MOUSEB_LEFT,false,8,true},
            }) do
                matrix=matrix+1
                local button=Instance(class,disabled);local props=button.props;TEST_HIT=button
                local event=Event(spec[1],spec[2],spec[3],spec[4])
                UI.HandlePointerDown(event);UI.HandlePointerUp(event)
                local count=spec[5] and not disabled and 1 or 0
                Check(#button.callbacks==count and #button.events==count,'pointer matrix '..class._className)
                Check(button.props==props and button.props.text=='unchanged','props identity retained')
                if count==1 then Check(button.callbacks[1]==event and button.events[1]==event,'same native event delivered once') end
            end
            for _,event in ipairs({false,{}, {type='keydown',key='Enter'}, {type='keyup',key='Space'}}) do
                matrix=matrix+1
                local button=Instance(class,disabled)
                button:OnClick(event or nil)
                Check(#button.callbacks==(disabled and 0 or 1) and #button.events==(disabled and 0 or 1),'keyboard/programmatic activation retained')
            end
        end
        local button=Instance(class,false);TEST_HIT=button
        UI.HandlePointerDown(Event('mouse',MOUSEB_LEFT,true));TEST_HIT=nil;UI.HandlePointerUp(Event('mouse',MOUSEB_LEFT,true))
        Check(#button.callbacks==0,'release outside retains native no-click')
        TEST_HIT=button;UI.HandlePointerDown(Event('mouse',MOUSEB_LEFT,true));UI.HandlePointerCancel(Event('mouse',MOUSEB_LEFT,true))
        UI.HandlePointerUp(Event('mouse',MOUSEB_LEFT,true));Check(#button.callbacks==0,'cancel retains native no-click')
        button.OnKeyDown=function(self,key) self:OnClick(nil);self.key=key end
        UI.HandlePointerDown(Event('mouse',MOUSEB_LEFT,true));UI.HandleKeyDown(13)
        Check(#button.callbacks==1 and button.key==13,'actual focused key dispatcher can activate without pointer')
    end
end
Check(#tested==25,'ActionButton and all24 actual descendant classes enumerated')
table.sort(tested)
return {checks=checks,classes=tested,matrixCases=matrix,oldRightClickReproduced=oldReproduced}

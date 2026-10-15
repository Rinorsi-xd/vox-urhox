local UI=require 'urhox-libs/UI'
local Event=require 'urhox-libs/UI/Core/PointerEvent'
local Menu=require 'ui.PauseMenu'
local Host=require 'ui.DialogHost'
local Touch=require 'controls.TouchMode'
local Maker=require 'combat.Matchmaker'
local profile={rating=1234,recent={'原对手'},games=7,wins=4,level=3,xp=19,introSeen={elimination=true,conquest=true,payload=true}}
local store={Read=function(_,key) if key=='match-profile' then return profile end end,Write=function(_,key,data) assert(key=='match-profile');profile=data;return true end}
local owner={app={store=store,tutorial={},lobby='arena'},message=require('ui.SourceToasts').New()}
local modal,root,saved= nil,nil,0
local function Click(widget)
    UI.Layout();local r=widget:GetAbsoluteLayoutForHitTest();local k=UI.GetScale()
    local p={pointerId=1,pointerType='mouse',x=(r.x+r.w/2)*k,y=(r.y+r.h/2)*k,button=MOUSEB_LEFT}
    UI.HandlePointerEvent(Event.new('PointerDown',p));UI.HandlePointerEvent(Event.new('PointerUp',p))
end
local function Rows(expected)
    local count=0;for _ in pairs(modal.actions) do count=count+1 end
    V.assert(count==expected,'source pause row count '..expected)
    V.assert(modal.actions.modeIntro and modal.actions.audio,'original mode introduction and audio entries exist')
    V.assert(modal.actions.tutorial.props.text=='新手引导' and modal.actions.tutorial.props.subtitle=='让诺诺从头再带一遍','source tutorial labels match frozen shell')
    V.assert(modal.modalLayout_ and math.abs(modal.modalLayout_.w-480*modal.sourceScale)<1,'actual rendered pause source width')
end
V.atFrame(3,function()
    UI.Init({scale=1});root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root)
    Touch.override=false;modal=Menu.Open(owner)
end)
V.atFrame(48,function()
    Rows(7);V.assert(modal.actions.help and modal.actions.keys.props.disabled and not modal.actions.touch,'PC source help and disabled key settings')
    V.assert(math.abs(modal.modalLayout_.h-616*modal.sourceScale)<1,'actual home card matches source 616 reference height')
    Click(modal.actions.modeIntro)
    V.assert(not owner.dialog,'real mode introduction pointer click closes menu')
    for _,mode in ipairs({'elimination','conquest','payload'}) do V.assert(not Maker.IntroSeen(store,mode),'next '..mode..' shows full introduction') end
    V.assert(profile.rating==1234 and profile.games==7 and profile.wins==4 and profile.recent[1]=='原对手','replay preference preserves rating and history')
    V.assert(owner.message:GetText()=='下一局对战会重新播放完整的模式介绍','source replay confirmation is visible')
    Host.Dispose(owner);owner.editor={};owner.SaveSlot=function() saved=saved+1 end;modal=Menu.Open(owner)
end)
V.atFrame(95,function()
    Rows(9);V.assert(modal.actions.save.props.subtitle=='存进车位（Ctrl+S）' and modal.actions.home,'PC edit save and return rows')
    V.assert(math.abs(modal.modalLayout_.h-760*modal.sourceScale)<1,'actual editor card matches source 760 reference height')
    Click(modal.actions.save);V.assert(saved==1,'real save row calls existing editor save')
    Host.Dispose(owner);Touch.override=true;modal=Menu.Open(owner)
end)
V.atFrame(142,function()
    Rows(8);V.assert(not modal.actions.help and not modal.actions.keys and modal.actions.touch,'touch menu removes desktop-only rows')
    V.assert(modal.actions.save.props.subtitle=='存进车位','touch source save omits Ctrl+S')
    V.assert(modal.actions.touch.props.subtitle=='灵敏度、按钮大小、瞄准辅助、建造方式','touch entry describes actual original preferences')
    Host.Dispose(owner);Touch.override=nil;UI.SetRoot(nil);root:Destroy();UI.Shutdown()
    require('render.RenderTargetLifetime').Flush();V.finish()
end)

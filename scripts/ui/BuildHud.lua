-- PC source composition. Rendering, stats and native input stay separate.
local UI=require 'urhox-libs/UI'
local Button=require 'ui.BuildButton'
local D=require 'ui.SourceDraw'
local Config=require 'Config'
local M={}
function M.Create(session)
    require('controls.TouchMode').Apply('build')
    local controls=session.controls;local editor=session.editor
    local width,height=UI.GetViewportSize();local safe=UI.GetSafeAreaInsets()
    local narrow=width<900
    local layout=require('ui.SourceBuildLayout').ForWidth(width)
    local root=UI.Panel{width='100%',height='100%',pointerEvents='box-none'}
    local state={root=root,width=width,height=height,safe=safe,buttons={},colorOpen=false,disposed=false}
    local function Action(parent,key,text,icon,kind,fn,props)
        props=props or {};props.text=text;props.icon=icon;props.kind=kind
        props.onClick=function()
            controls:Cancel();if kind~='tool' or key~='color' then state.SetColor(false) end
            UI.ClearFocus();fn();if not session.disposed then session:Refresh() end
        end
        local b=Button(props);parent:AddChild(b);state.buttons[key]=b;return b
    end
    local playfield=UI.Panel{position='absolute',width='100%',height='100%',
        onPointerDown=function(e) controls:Down(e) end,onPointerMove=function(e) controls:Move(e) end,
        onPointerUp=function(e) controls:Up(e) end,onPointerCancel=function() controls:Cancel() end,
        onPointerLeave=function() controls:Cancel() end,onPointerEnter=function(e) controls:Position(e) end}
    state.playfield=playfield;root:AddChild(playfield)
    local Overlay=require 'ui.BuildOverlay'
    local shade=Overlay{shade=true,position='absolute',width='100%',height='100%',pointerEvents='none'};shade.session=session;root:AddChild(shade)
    local box=UI.Panel{position='absolute',left=0,top=0,width=0,height=0,pointerEvents='none',borderWidth=1,borderColor='#ff6a13',backgroundColor={255,106,19,20}};root:AddChild(box)
    local toolbar=UI.Panel{position='absolute',top=12,left=18,right=18,height=narrow and 102 or 46,pointerEvents='box-none'};root:AddChild(toolbar);state.toolbar=toolbar
    Action(toolbar,'home','机库','back','back',function() session.app:ExitBuild() end,{position='absolute',left=0,top=3,width=92,height=40})
    local function Rename(field)
        if state.disposed then return end
        local value=field:GetValue():match('^%s*(.-)%s*$');if value=='' then value='未命名战车' end
        if value~=editor.bp.name then local ok,err=session.app.bays:Rename(value);if not ok then session:Notify(err,'bad') end end
        field:SetValue(editor.bp.name)
    end
    local name=require('ui.BuildNameField'){value=editor.bp.name,maxLength=20,position='absolute',left=100,top=1,width=narrow and width-150 or layout.nameWidth,height=44,sourceFontSize=layout.nameSize,onBlur=Rename,
        onSubmit=function(field) Rename(field);UI.ClearFocus() end};toolbar:AddChild(name);state.name=name
    local right=UI.Panel{position='absolute',right=0,top=narrow and 54 or 0,width=575.0625,height=46,flexDirection='row',alignItems='center',gap=8};toolbar:AddChild(right)
    for _,spec in ipairs({{'undo','undo',function() editor:Undo() end},{'redo','redo',function() editor:Redo() end},
        {'liftUp','liftUp',function() editor:Lift(1) end},{'liftDown','liftDown',function() editor:Lift(-1) end}}) do
        Action(right,spec[1],'',spec[2],'icon',spec[3],{width=42,height=42})
    end
    Action(right,'help','','help','icon',function() session.buildCamera:Release();session.app.tutorial:Replay() end,{width=42,height=42,tooltip='再看一遍拼装教学'})
    Action(right,'trial','试车','wheel','side',function() session.app:EnterTrial() end,{width=138.015625,height=46,key='T'})
    Action(right,'save','保存','save','save',function() session:SaveSlot() end,{width=179.046875,height=46,key='Ctrl+S'})
    local stats=require('ui.BuildStats').Create(session);root:AddChild(stats.root);state.stats=stats
    if narrow then stats.root:SetStyle({top=130,height=math.min(350,height-430)}) end
    if require('controls.TouchMode').Enabled() and not narrow then stats.root:SetStyle({top=82,height=math.max(100,height-210)}) end
    local overlay=Overlay{position='absolute',width='100%',height='100%',pointerEvents='none'};overlay.session=session;root:AddChild(overlay)
    state.SetColor=function() state.colorOpen=false end
    require('ui.BuildDock').Create(session,state,Action,root,layout)
    local hotbar=state.hotbar
    local hover=require('ui.BuildHover'){position='absolute',width='100%',height='100%',pointerEvents='none'}
    hover.session=session;root:AddChild(hover);state.hover=hover
    local badge=require('ui.BuildModeBadge'){position='absolute',width='100%',height='100%',pointerEvents='none'}
    badge.session=session;root:AddChild(badge);state.modeBadge=badge
    local rotor=require('ui.RotorHud'){position='absolute',width='100%',height='100%',pointerEvents='none'}
    rotor.session=session;root:AddChild(rotor);state.rotor=rotor
    local owned={};for _,child in ipairs(root.children) do owned[#owned+1]=child end
    local pointerModes={};for _,child in ipairs(owned) do pointerModes[child]=child.props.pointerEvents or 'auto' end
    local blockedPointer=false;local inventoryHidden=false
    function state.Refresh()
        if state.disposed then return end
        local fly=session.buildCamera;local block=fly.mode=='fp' and fly.captured and not fly.touch
        if blockedPointer~=block then
            blockedPointer=block;root:SetStyle({pointerEvents=block and 'none' or 'box-none'})
            for child,mode in pairs(pointerModes) do child:SetStyle({pointerEvents=block and 'none' or mode}) end
        end
        local hidden=session.inventoryPanel~=nil
        if inventoryHidden~=hidden then
            inventoryHidden=hidden
            for _,child in ipairs(owned) do if child~=shade then child:SetVisible(not hidden) end end
            if hidden then state.SetColor(false) end
        end
        state.RefreshDock()
        state.buttons.mirror.props.selected=editor.mirror;state.buttons.xray.props.selected=session.app.buildXray==true
        state.buttons.shell.props.selected=editor.paintChannel=='shell';state.buttons.accent.props.selected=editor.paintChannel=='accent'
        for i,c in ipairs(Config.PALETTE) do state.swatches[i].props.selected=not editor.autoColor and c.hex==editor.color end
        if not name.state.focused and name:GetValue()~=editor.bp.name then name:SetValue(editor.bp.name);name.state.cursorPos=0 end
        local b=controls.selectionBox
        box:SetStyle(b and {left=math.min(b.x0,b.x1),top=math.min(b.y0,b.y1),width=math.abs(b.x1-b.x0),height=math.abs(b.y1-b.y0)} or {width=0,height=0})
        hotbar.Refresh();stats.Refresh();hover:Sync();badge:Sync();rotor:Sync()
    end
    function state.Dispose()
        if state.disposed then return end;state.disposed=true;controls:Cancel()
        if UI.GetFocus()==name then UI.ClearFocus() end
        if UI.GetRoot()==root then UI.SetRoot(nil) end
        if root.node then root:Destroy() end
    end
    function state.ViewState()
        local _,scrollY=stats.root:GetScroll()
        return {expanded=stats.pane.expanded,statsY=scrollY,name=name:GetValue(),focused=UI.GetFocus()==name,
            cursor=name.state.cursorPos,selection=name.state.selectionStart,selectionEnd=name.state.selectionEnd}
    end
    function state.RestoreView(view)
        stats.pane.expanded=view.expanded;stats.pane.more.props.selected=view.expanded
        stats.pane.more.props.text=view.expanded and '收起详细数据' or '详细数据'
        stats.root:SetScrollDirect(0,view.statsY or 0)
        if view.focused then
            name:SetValue(view.name);UI.SetFocus(name);name.state.cursorPos=view.cursor
            name.state.selectionStart=view.selection;name.state.selectionEnd=view.selectionEnd
        end
    end
    UI.SetRoot(root,true);return state
end
return M

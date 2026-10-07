-- PC source composition. Rendering, stats and native input stay separate.
local UI=require 'urhox-libs/UI'
local Button=require 'ui.BuildButton'
local D=require 'ui.SourceDraw'
local Config=require 'Config'
local PaintLabel=require('urhox-libs/UI/Widgets/Panel'):Extend('VoxPaintRegionLabel')
function PaintLabel:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout()
    self.paragraph=self.paragraph or require('ui.SourceParagraph').New(13,'normal')
    self.paragraph:Draw(vg,'涂装区域',r.x,r.y,r.w)
end
local M={}
function M.Create(session)
    require('controls.TouchMode').Apply('build')
    local controls=session.controls;local editor=session.editor
    local width,height=UI.GetViewportSize();local safe=UI.GetSafeAreaInsets()
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
    local toolbar=UI.Panel{position='absolute',top=12,left=18,right=18,height=46,pointerEvents='box-none'};root:AddChild(toolbar);state.toolbar=toolbar
    Action(toolbar,'home','机库','back','back',function() session.app:ExitBuild() end,{position='absolute',left=0,top=3,width=84.8125,height=40})
    local function Rename(field)
        if state.disposed then return end
        local value=field:GetValue():match('^%s*(.-)%s*$');if value=='' then value='未命名战车' end
        if value~=editor.bp.name then local ok,err=session.app.bays:Rename(value);if not ok then session:Notify(err,'bad') end end
        field:SetValue(editor.bp.name)
    end
    local name=require('ui.BuildNameField'){value=editor.bp.name,maxLength=20,position='absolute',left=92.8125,top=1,width=layout.nameWidth,height=44,sourceFontSize=layout.nameSize,onBlur=Rename,
        onSubmit=function(field) Rename(field);UI.ClearFocus() end};toolbar:AddChild(name);state.name=name
    local right=UI.Panel{position='absolute',right=0,top=0,width=493.5,height=46,flexDirection='row',alignItems='center',gap=8};toolbar:AddChild(right)
    for _,spec in ipairs({{'undo','undo',function() editor:Undo() end},{'redo','redo',function() editor:Redo() end},
        {'liftUp','liftUp',function() editor:Lift(1) end},{'liftDown','liftDown',function() editor:Lift(-1) end}}) do
        Action(right,spec[1],'',spec[2],'icon',spec[3],{width=42,height=42})
    end
    Action(right,'trial','试车','wheel','side',function() session.app:EnterTrial() end,{width=127.609375,height=46,key='T'})
    Action(right,'save','保存','save','save',function() session:SaveSlot() end,{width=157.890625,height=46,key='Ctrl+S'})
    local stats=require('ui.BuildStats').Create(session);root:AddChild(stats.root);state.stats=stats
    local overlay=Overlay{position='absolute',width='100%',height='100%',pointerEvents='none'};overlay.session=session;root:AddChild(overlay)
    local dock=UI.Panel{position='absolute',left=(width-layout.dock)/2,bottom=18,width=layout.dock,height=76,flexDirection='row',alignItems='flex-end',gap=16,pointerEvents='box-none'};root:AddChild(dock);state.dock=dock
    local tools=UI.Panel{width=layout.tools,height=76,flexDirection='row',gap=5};dock:AddChild(tools)
    for _,t in ipairs({{'build','放置','build','1-0'},{'erase','删除','erase','X'},{'paint','涂装','brush','P'}}) do
        Action(tools,t[1],t[2],t[3],'tool',function() editor:SetTool(t[1]);session.selecting=false end,{width=layout.tool,height=76,key=t[4]})
    end
    Action(tools,'color','颜色',nil,'tool',function() state.SetColor(not state.colorOpen) end,{width=layout.tool,height=76,key='C 取色',hex=editor.color})
    local hotbar=require('ui.BuildHotbar').Create(session);dock:AddChild(hotbar.root);state.hotbar=hotbar
    local paint=UI.Panel{width=layout.paint,height=76,flexDirection='row',alignItems='center',gap=12,paddingHorizontal=20,visible=false};dock:AddChild(paint);state.paint=paint
    local label=PaintLabel{width=52,height=16,flexShrink=0}
    paint:AddChild(label);state.paintLabel=label
    for _,channel in ipairs({{'shell','外壳'},{'accent','饰色'}}) do Action(paint,channel[1],channel[2],nil,'channel',function() editor.paintChannel=channel[1] end,{width=layout.tool,height=76}) end
    function paint:OnWheel(_,dy) if dy~=0 then editor.paintChannel=editor.paintChannel=='shell' and 'accent' or 'shell';session:Refresh() end;return true end
    local toggles=UI.Panel{width=layout.toggles,height=74,gap=4};dock:AddChild(toggles)
    Action(toggles,'mirror','镜像','mirror','toggle',function() editor.mirror=not editor.mirror end,{width=layout.toggles,height=22,key='M'})
    Action(toggles,'xray','透视','eye','toggle',function() session:ToggleXray() end,{width=layout.toggles,height=22,key='V'})
    Action(toggles,'camera','第一人称','fp','toggle',function() session.buildCamera:Toggle() end,{width=layout.toggles,height=22,key='Tab'})
    state.cameraButton=state.buttons.camera;state.xrayButton=state.buttons.xray
    if require('controls.TouchMode').Enabled() then
        -- Orbit is the initial mobile editor camera; direct controls expose
        -- keyboard-only essentials without replacing the original build dock.
        state.cameraButton:SetText('归中视角')
        state.cameraButton.props.onClick=function() session.buildCamera:Focus() end
        local function TouchAction(key,text,offset,fn)
            return Action(root,key,text,nil,'side',fn,{position='absolute',right=20+offset,bottom=114,width=88,height=54})
        end
        TouchAction('parts','零件库',0,function() session:OpenInventory() end)
        TouchAction('rotate','旋转',96,function() editor:Rotate(1) end)
        TouchAction('tilt','翻转',192,function() editor:Tilt(1) end)
        TouchAction('zoomIn','拉近',288,function() session.camera.dist=math.max(2.5,session.camera.dist*.8) end)
        TouchAction('zoomOut','拉远',384,function() session.camera.dist=math.min(60,session.camera.dist*1.25) end)
    end
    local scrim=UI.Panel{position='absolute',width='100%',height='100%',visible=false,onPointerDown=function() state.SetColor(false) end};root:AddChild(scrim)
    local Palette=require 'ui.BuildPalette'
    local palette=Palette.Create();root:AddChild(palette);state.palette=palette
    state.swatches={}
    for i,c in ipairs(Config.PALETTE) do
        local b=Action(palette,'swatch'..i,'',nil,'swatch',function() editor.color=c.hex;editor:SetTool('paint');state.SetColor(false) end,
            {hex=c.hex,position='absolute',padding=0,paddingHorizontal=0,paddingVertical=0,minWidth=0,minHeight=0,left=12+(i-1)%8*Palette.stride,top=Palette.gridTop+math.floor((i-1)/8)*Palette.stride,width=Palette.swatchSize,height=Palette.swatchSize})
        state.swatches[i]=b
    end
    function state.SetColor(open)
        controls:Cancel();state.colorOpen=open;palette:SetOpen(open);scrim:SetVisible(open)
        if open then session.buildCamera:Release() end
    end
    local hover=require('ui.BuildHover'){position='absolute',width='100%',height='100%',pointerEvents='none'}
    hover.session=session;root:AddChild(hover);state.hover=hover
    local owned={};for _,child in ipairs(root.children) do owned[#owned+1]=child end
    local pointerModes={};for _,child in ipairs(owned) do pointerModes[child]=child.props.pointerEvents or 'auto' end
    local blockedPointer=false;local inventoryHidden=false;local paintMode=false
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
            for _,child in ipairs(owned) do if child~=shade and child~=scrim and child~=palette then child:SetVisible(not hidden) end end
            if hidden then state.SetColor(false) end
        end
        local painting=editor.tool=='paint'
        if paintMode~=painting then
            paintMode=painting;hotbar.root:SetVisible(not painting);paint:SetVisible(painting)
            local dw=painting and layout.paintDock or layout.dock;dock:SetStyle({width=dw,left=(width-dw)/2})
            local tw=painting and layout.paintToggles or layout.toggles;toggles:SetWidth(tw)
            for _,key in ipairs({'mirror','xray','camera'}) do state.buttons[key]:SetWidth(tw) end
        end
        local colorRect=state.buttons.color:GetAbsoluteLayoutForHitTest()
        if state.colorOpen then palette:SetStyle({left=math.max(10,colorRect.x-20),bottom=height-colorRect.y+14}) end
        for _,tool in ipairs({'build','erase','paint'}) do local b=state.buttons[tool];local active=editor.tool==tool and not editor.pasting;b.props.selected=active;b:SetStyle({top=active and -6 or 0}) end
        state.buttons.color.props.hex=editor.color
        state.buttons.mirror.props.selected=editor.mirror;state.buttons.xray.props.selected=session.app.buildXray==true;state.buttons.camera.props.selected=fly.mode=='fp'
        state.buttons.shell.props.selected=editor.paintChannel=='shell';state.buttons.accent.props.selected=editor.paintChannel=='accent'
        for i,c in ipairs(Config.PALETTE) do state.swatches[i].props.selected=c.hex==editor.color end
        if not name.state.focused and name:GetValue()~=editor.bp.name then name:SetValue(editor.bp.name);name.state.cursorPos=0 end
        local b=controls.selectionBox
        box:SetStyle(b and {left=math.min(b.x0,b.x1),top=math.min(b.y0,b.y1),width=math.abs(b.x1-b.x0),height=math.abs(b.y1-b.y0)} or {width=0,height=0})
        hotbar.Refresh();stats.Refresh();hover:Sync()
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

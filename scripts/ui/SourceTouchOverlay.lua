local UI=require 'urhox-libs/UI'
local Widgets=require 'ui.SourceTouchWidgets'
local Gestures=require 'controls.TouchGestures'
local Layout=require 'ui.SourceTouchLayout'
local D=require 'ui.SourceDraw'
local Instructions=UI.Widget:Extend('VoxTouchInstructions')
function Instructions:Render(vg)
    local font=Widgets.Font(vg);local r=self:GetAbsoluteLayout();local k=self.props.touchScale
    for i,text in ipairs({'左摇杆移动 · 滑动画面转向','按住开火并拖动也能瞄准','机库双指平移 / 缩放 · 驾驶双指缩放'}) do
        D.Text(vg,text,r.x,r.y+(i-1)*20.8*k,13*k,{177,208,224,255},font,nil,0,false,20.8*k)
    end
end
local M={}
function M.Create(root,playfield,adapter,actions,options,extras)
    local width,height=UI.GetViewportSize();local dpr=graphics:GetDPR()
    local cssWidth,cssHeight=graphics:GetWidth()/dpr,graphics:GetHeight()/dpr
    local layout=adapter.mode=='drive' and Layout.Drive(width,height,cssWidth,cssHeight,UI.GetSafeAreaInsets(),false,adapter.prefs and adapter.prefs.size) or Layout.Calculate(width,height,cssWidth,cssHeight,UI.GetSafeAreaInsets(),adapter.mode,actions)
    local drive=adapter.mode=='drive';local DriveWidgets=drive and require('ui.SourceTouchDriveWidgets')
    local k=layout.k;adapter.width=cssWidth;adapter.height=cssHeight
    local layer={playfield=playfield,buttons={},menuButtons={},menu=false,blocked=false,disposed=false,layout=layout,aux='boost',prefs=adapter.prefs}
    local container=UI.Panel{position='absolute',width='100%',height='100%',pointerEvents='box-none'}
    root:AddChild(container);layer.root=container
    local gesture=Gestures.New(adapter);layer.gestures=gesture
    local stick=(drive and DriveWidgets.Stick or Widgets.Stick){position='absolute',touchScale=k,pointerEvents=drive and 'none' or 'auto'};stick:SetStyle(layout.stick);container:AddChild(stick);layer.stick=stick
    local move=adapter.Move
    adapter.Move=function(x,y) stick.axisX=x;stick.axisY=-y;move(x,y) end
    if drive then
        adapter.floating=true
        adapter.PlaceStick=function(r,live) stick:SetStyle{left=r.x*k,top=r.y*k,width=r.w*k,height=r.h*k};stick.live=live end
        adapter.HomeStick=function() stick:SetStyle(layer.layout.stick);stick.live=false end
    end
    local function Rect(widget)
        local r=widget:GetAbsoluteLayoutForHitTest();return {x=r.x/k,y=r.y/k,w=r.w/k,h=r.h/k}
    end
    local function Bind(widget,action)
        widget.OnPointerDown=function(self,e)
            if not e:IsTouch() or layer.blocked or layer.menu or adapter.Ready and not adapter.Ready() then return end
            e:StopPropagation();e:PreventDefault()
            local resolved=action;local rect=Rect(widget)
            if drive and action=='look' then
                local z=layer.layout.zone;local x,y=e.x/k,e.y/k
                if x>=z[1] and y>=z[2] and x<=z[3] and y<=z[4] then resolved='move';rect=Rect(stick) end
            end
            if gesture:Down(resolved,e.pointerId,e.x/k,e.y/k,rect) then widget.touchHeld=true end
        end
        local function Owns(p) return p and (p.action==action or drive and action=='look' and p.action=='move') end
        widget.OnPointerMove=function(self,e) local p=gesture.pointers[e.pointerId];if Owns(p) then e:StopPropagation();gesture:Move(e.pointerId,e.x/k,e.y/k) end end
        local function End(self,e,cancelled)
            local p=gesture.pointers[e.pointerId]
            if Owns(p) then e:StopPropagation();gesture:Up(e.pointerId,e.x/k,e.y/k,cancelled);widget.touchHeld=gesture:Held(action) end
        end
        widget.OnPointerUp=function(self,e) End(self,e,false) end
        widget.OnPointerCancel=function(self,e) End(self,e,true) end
        -- Hover exit must not cancel a captured touch; the dispatcher owns it.
        if action=='look' then widget.props.onPointerLeave=nil;widget.props.onPointerEnter=nil end
    end
    Bind(playfield,'look');if not drive then Bind(stick,'move') end
    local function Button(parent,id,text,props)
        props=props or {};props.touchScale=k;props.text=text;props.padding=0;props.minWidth=0;props.minHeight=0
        if drive then props.sourceScale=k;props.kind='segment' end
        local b=(drive and require('ui.TouchEditorWidgets').Button or Widgets.Button)(props);parent:AddChild(b);return b
    end
    for _,id in ipairs(actions) do if layout.actions[id] then
        local b
        if drive then
            b=DriveWidgets.Button{position='absolute',touchScale=k,unit=layout.u,padding=0,minWidth=0,minHeight=0,
                kind=id=='primary' and 'fire' or id=='interact' and 'context' or id:sub(1,7)=='rudder-' and 'small' or id=='board' and 'menu' or 'arc',
                icon=id=='primary' and 'fire' or id=='aux' and 'down' or id:sub(1,7)=='rudder-' and 'rudder' or id,
                flipX=id=='rudder-r',weapon=id=='weapon'};container:AddChild(b)
        else b=Button(container,id,id,{position='absolute',primary=id=='primary'}) end
        b:SetStyle(layout.actions[id]);Bind(b,id);layer.buttons[id]=b
    end end
    if drive then
        local ready=DriveWidgets.Readiness{position='absolute',pointerEvents='none'};ready:SetStyle(layout.readiness);container:AddChild(ready);layer.readiness=ready
    end
    local panel=UI.ScrollView{position='absolute',visible=false,scrollY=true,bounces=false,showScrollbar=true,
        padding=layout.padding,backgroundColor={22,44,67,255},borderWidth=0,borderRadius=0}
    panel:SetStyle(layout.panel);container:AddChild(panel);layer.panel=panel
    if not drive then panel:AddChild(Instructions{height=72.4*k,flexShrink=0,touchScale=k,pointerEvents='none'}) end
    local contentWidth=layout.panel.width-2*layout.padding-2*k
    local optionWidth=(contentWidth-(layout.columns-1)*8*k)/layout.columns
    local function Options(parent,entries)
        local row
        for i,item in ipairs(entries) do
            if (i-1)%layout.columns==0 then row=UI.Panel{width='100%',flexDirection='row',gap=8*k,marginBottom=8*k,flexShrink=0};parent:AddChild(row) end
            local id=item[1];local b=Button(row,id,item[2],{width=optionWidth,height=44*k,flexShrink=0,onClick=function()
                if layer.disposed then return end
                if id=='menu' then layer.SetMenu(false) else layer.SetMenu(false,id=='settings');adapter.Action(id) end
            end})
            layer.menuButtons[id]=b
        end
    end
    Options(panel,options)
    if extras then
        local extra=UI.Panel{width='100%',flexShrink=0,visible=false};layer.extra=extra
        local toggle=Button(panel,'extra','更多建造操作',{width='100%',height=44*k,disclosure=true,onClick=function(self)
            layer.expanded=not layer.expanded;extra:SetVisible(layer.expanded);self.props.selected=layer.expanded
        end});layer.menuButtons.extra=toggle;panel:AddChild(extra);Options(extra,extras)
    end
    local toggle
    if drive then
        toggle=DriveWidgets.Button{position='absolute',touchScale=k,unit=layout.u,kind='menu',icon='menu',padding=0,minWidth=0,minHeight=0,onClick=function() layer.SetMenu(not layer.menu) end};container:AddChild(toggle)
    else toggle=Button(container,'menu','操作',{position='absolute',onClick=function() layer.SetMenu(not layer.menu) end}) end
    toggle:SetStyle(layout.toggle);layer.toggle=toggle
    function layer.Clear()
        local ids={};for id in pairs(gesture.pointers) do ids[#ids+1]=id end
        for _,id in ipairs(ids) do UI.CancelPointer(id,'touch') end
        gesture:Reset();stick.touchHeld=false;playfield.touchHeld=false
        for _,b in pairs(layer.buttons) do b.touchHeld=false end
        if adapter.Reset then adapter.Reset() end
    end
    function layer.SetMenu(open,suppressResume)
        if layer.disposed then return end
        layer.Clear();layer.menu=open;panel:SetVisible(open and not layer.blocked)
        stick:SetVisible(not open and not layer.blocked)
        for _,b in pairs(layer.buttons) do b:SetVisible(not open and not layer.blocked) end
        playfield:SetVisible(not open and not layer.blocked)
        toggle.props.selected=open
        if adapter.Menu and not suppressResume then adapter.Menu(open) end
    end
    function layer.Update(blocked)
        if layer.disposed then return end
        if blocked~=layer.blocked then layer.blocked=blocked;if blocked then layer.Clear() end end
        container:SetVisible(not blocked);panel:SetVisible(layer.menu and not blocked)
        stick:SetVisible(not layer.menu and not blocked)
        for _,b in pairs(layer.buttons) do b:SetVisible(not layer.menu and not blocked) end
        if layer.readiness then layer.readiness:SetVisible(not layer.menu and not blocked) end
        playfield:SetVisible(not layer.menu and not blocked)
        if adapter.Labels then adapter.Labels(layer) end
    end
    function layer.Relayout(planeKeys,size)
        if not drive or layer.planeKeys==planeKeys and layer.size==size then return end
        layer.planeKeys=planeKeys;layer.size=size;layout=Layout.Drive(width,height,cssWidth,cssHeight,UI.GetSafeAreaInsets(),planeKeys,size);layer.layout=layout
        for id,b in pairs(layer.buttons) do if layout.actions[id] then b:SetStyle(layout.actions[id]) end end
        for _,b in pairs(layer.buttons) do b.props.unit=layout.u end
        toggle:SetStyle(layout.toggle);toggle.props.unit=layout.u
        panel:SetStyle(layout.panel)
        if layer.readiness then layer.readiness:SetStyle(layout.readiness) end
        if not gesture:Held('move') then stick:SetStyle(layout.stick) end
    end
    function layer.Dispose() if layer.disposed then return end;layer.Clear();layer.disposed=true end
    return layer
end
return M

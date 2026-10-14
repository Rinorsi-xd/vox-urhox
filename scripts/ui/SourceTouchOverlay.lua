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
    local layout=Layout.Calculate(width,height,cssWidth,cssHeight,UI.GetSafeAreaInsets(),adapter.mode,actions)
    local k=layout.k;adapter.width=cssWidth;adapter.height=cssHeight
    local layer={playfield=playfield,buttons={},menuButtons={},menu=false,blocked=false,disposed=false,layout=layout,aux='boost'}
    local container=UI.Panel{position='absolute',width='100%',height='100%',pointerEvents='box-none'}
    root:AddChild(container);layer.root=container
    local gesture=Gestures.New(adapter);layer.gestures=gesture
    local stick=Widgets.Stick{position='absolute',touchScale=k};stick:SetStyle(layout.stick);container:AddChild(stick);layer.stick=stick
    local move=adapter.Move
    adapter.Move=function(x,y) stick.axisX=x;stick.axisY=-y;move(x,y) end
    local function Rect(widget)
        local r=widget:GetAbsoluteLayoutForHitTest();return {x=r.x/k,y=r.y/k,w=r.w/k,h=r.h/k}
    end
    local function Bind(widget,action)
        widget.OnPointerDown=function(self,e)
            if not e:IsTouch() or layer.blocked or layer.menu or adapter.Ready and not adapter.Ready() then return end
            e:StopPropagation();e:PreventDefault()
            if gesture:Down(action,e.pointerId,e.x/k,e.y/k,Rect(widget)) then widget.touchHeld=true end
        end
        widget.OnPointerMove=function(self,e) local p=gesture.pointers[e.pointerId];if p and p.action==action then e:StopPropagation();gesture:Move(e.pointerId,e.x/k,e.y/k) end end
        local function End(self,e,cancelled)
            local p=gesture.pointers[e.pointerId]
            if p and p.action==action then e:StopPropagation();gesture:Up(e.pointerId,e.x/k,e.y/k,cancelled);widget.touchHeld=gesture:Held(action) end
        end
        widget.OnPointerUp=function(self,e) End(self,e,false) end
        widget.OnPointerCancel=function(self,e) End(self,e,true) end
        -- Hover exit must not cancel a captured touch; the dispatcher owns it.
        if action=='look' then widget.props.onPointerLeave=nil;widget.props.onPointerEnter=nil end
    end
    Bind(playfield,'look');Bind(stick,'move')
    local function Button(parent,id,text,props)
        props=props or {};props.touchScale=k;props.text=text;props.padding=0;props.minWidth=0;props.minHeight=0
        local b=Widgets.Button(props);parent:AddChild(b);return b
    end
    for _,id in ipairs(actions) do if layout.actions[id] then
        local b=Button(container,id,id,{position='absolute',primary=id=='primary'})
        b:SetStyle(layout.actions[id]);Bind(b,id);layer.buttons[id]=b
    end end
    local panel=UI.ScrollView{position='absolute',visible=false,scrollY=true,bounces=false,showScrollbar=true,
        padding=layout.padding,backgroundColor={10,21,38,242},borderColor={122,216,255,136},borderWidth=k,borderRadius=12*k}
    panel:SetStyle(layout.panel);container:AddChild(panel);layer.panel=panel
    panel:AddChild(Instructions{height=72.4*k,flexShrink=0,touchScale=k,pointerEvents='none'})
    local contentWidth=layout.panel.width-2*layout.padding-2*k
    local optionWidth=(contentWidth-(layout.columns-1)*8*k)/layout.columns
    local function Options(parent,entries)
        local row
        for i,item in ipairs(entries) do
            if (i-1)%layout.columns==0 then row=UI.Panel{width='100%',flexDirection='row',gap=8*k,marginBottom=8*k,flexShrink=0};parent:AddChild(row) end
            local id=item[1];local b=Button(row,id,item[2],{width=optionWidth,height=44*k,flexShrink=0,onClick=function()
                if layer.disposed then return end
                if id=='menu' then layer.SetMenu(false) else layer.SetMenu(false);adapter.Action(id) end
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
    local toggle=Button(container,'menu','操作',{position='absolute',onClick=function() layer.SetMenu(not layer.menu) end})
    toggle:SetStyle(layout.toggle);layer.toggle=toggle
    function layer.Clear()
        local ids={};for id in pairs(gesture.pointers) do ids[#ids+1]=id end
        for _,id in ipairs(ids) do UI.CancelPointer(id,'touch') end
        gesture:Reset();stick.touchHeld=false;playfield.touchHeld=false
        for _,b in pairs(layer.buttons) do b.touchHeld=false end
        if adapter.Reset then adapter.Reset() end
    end
    function layer.SetMenu(open)
        if layer.disposed then return end
        layer.Clear();layer.menu=open;panel:SetVisible(open and not layer.blocked)
        stick:SetVisible(not open and not layer.blocked)
        for _,b in pairs(layer.buttons) do b:SetVisible(not open and not layer.blocked) end
        playfield:SetVisible(not open and not layer.blocked)
        toggle.props.selected=open
        if adapter.Menu then adapter.Menu(open) end
    end
    function layer.Update(blocked)
        if layer.disposed then return end
        if blocked~=layer.blocked then layer.blocked=blocked;if blocked then layer.Clear() end end
        container:SetVisible(not blocked);panel:SetVisible(layer.menu and not blocked)
        stick:SetVisible(not layer.menu and not blocked)
        for _,b in pairs(layer.buttons) do b:SetVisible(not layer.menu and not blocked) end
        playfield:SetVisible(not layer.menu and not blocked)
        if adapter.Labels then adapter.Labels(layer) end
    end
    function layer.Dispose() if layer.disposed then return end;layer.Clear();layer.disposed=true end
    return layer
end
return M

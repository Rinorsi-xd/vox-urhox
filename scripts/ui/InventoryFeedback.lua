-- Frozen inventory controls: CSS ease, final keyboard styles, owned UI transforms.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Motion=require 'ui.SourceButtonMotion'
local M={}
local function Tween(v) return {value=v,start=v,target=v,elapsed=0,duration=0} end
function M.Focused(widget)
    local owner=widget.inventoryKeyOwner
    return owner and owner.keyboardFocus==widget and UI.GetFocus()==widget or false
end
function M.Color(c,focused)
    if not focused then return c end
    return {math.min(255,c[1]*1.18),math.min(255,c[2]*1.18),math.min(255,c[3]*1.18),c[4] or 255}
end
function M.Mix(a,b,t)
    return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t,(a[4] or 255)+((b[4] or 255)-(a[4] or 255))*t}
end
function M.Button(widget,dt)
    local m=widget.inventoryFeedback
    if not m then m={x=Tween(0),y=Tween(0),hover=Tween(0),arrow=Tween(widget.props.selected and 1 or 0)};widget.inventoryFeedback=m end
    local p=widget.props;local hover=not p.disabled and widget.state.hovered
    local press=not p.disabled and widget.state.pressed;local material=p.kind=='material'
    local compact=material or p.kind==nil
    local duration=material and .15 or .16
    Motion.Step(m.x,not compact and 0 or material and 0 or press and 2 or hover and -2 or 0,duration,dt,'ease')
    Motion.Step(m.y,not compact and 0 or material and (hover and -2 or 0) or press and 2 or hover and -2 or 0,duration,dt,'ease')
    Motion.Step(m.hover,hover and 1 or 0,duration,dt,'ease')
    Motion.Step(m.arrow,p.selected and 1 or 0,.18,dt,'ease')
    local x,y=m.x.value,m.y.value+(compact and not material and press and 1 or 0)
    if p.translateX~=x or p.translateY~=y then widget:SetStyle({translateX=x,translateY=y}) end
end
function M.Slot(widget,dt)
    local p=widget.props;if not p.inventoryStyle then return end
    local m=widget.inventoryFeedback
    if not m then m={y=Tween(p.active and -5 or 0),hover=Tween(0),active=Tween(p.active and 1 or 0),drop=Tween(0)};widget.inventoryFeedback=m end
    Motion.Step(m.y,p.active and -5 or widget.state.hovered and -3 or 0,.18,dt,'ease')
    Motion.Step(m.hover,widget.state.hovered and 1 or 0,.18,dt,'ease')
    Motion.Step(m.active,p.active and 1 or 0,.18,dt,'ease')
    Motion.Step(m.drop,p.dropTarget and 1 or 0,.18,dt,'ease')
    if p.translateY~=m.y.value then widget:SetStyle({translateY=m.y.value}) end
end
function M.Edges(vg,r,points,selected,focused,status)
    local top=focused and {219,238,255,204} or selected and {142,198,249,80} or {142,198,249,128}
    local bottom=focused and (status or D.orange) or selected and D.orange or {11,36,75,128}
    for _,edge in ipairs({{r.y,(focused or selected) and 1 or 1.5,top},{r.y+r.h-(focused and 3 or selected and 2 or 1.5),focused and 3 or selected and 2 or 1.5,bottom}}) do
        nvgSave(vg);nvgIntersectScissor(vg,r.x,edge[1],r.w,edge[2]);D.Path(vg,points);nvgFillColor(vg,D.Color(M.Color(edge[3],focused)));nvgFill(vg);nvgRestore(vg)
    end
end
return M

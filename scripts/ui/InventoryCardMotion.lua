-- Frozen new-ui-inventory.css: tile .28s/12ms stagger, hover .18s,
-- image .22s, budget .15s. Pooled cells inherit the list's animation clock.
local UI=require("urhox-libs/UI")

local Motion=require 'ui.SourceButtonMotion'
local M={}
local function Tween(value) return {value=value,start=value,target=value,elapsed=0,duration=0} end
function M.Bind(card,index,elapsed)
    card.inventoryMotion={entry=elapsed-math.min(index-1,24)*.012,x=Tween(0),y=Tween(0),hover=Tween(0),image=Tween(0),budget=Tween(0),shadowPress=Tween(0)}
    local entry=Motion.Ease(math.max(0,math.min(1,card.inventoryMotion.entry/.28)),false)
    card:SetStyle({translateX=0,translateY=10*(1-entry),opacity=entry})
end
function M.Update(card,dt)
    local m=card.inventoryMotion;if not m then return end
    local enabled=not card.props.disabled
    local focused=card.inventoryOwner and card.inventoryOwner.keyboardFocus==card and UI.GetFocus()==card
    local hovered=enabled and (card.state.hovered or focused)
    local pressed=enabled and card.state.pressed
    Motion.Step(m.x,pressed and 2 or hovered and -2 or 0,.18,dt,false)
    Motion.Step(m.y,pressed and 2 or hovered and -4 or 0,.18,dt,false)
    Motion.Step(m.hover,hovered and 1 or 0,.18,dt,'ease')
    Motion.Step(m.shadowPress,pressed and 1 or 0,.18,dt,'ease')
    Motion.Step(m.image,hovered and 1 or 0,.22,dt,false)
    Motion.Step(m.budget,hovered and 1 or 0,.15,dt,'ease')
    m.entry=math.min(.28,m.entry+math.max(0,dt))
    local entry=Motion.Ease(math.max(0,m.entry)/.28,false)
    local x,y,opacity=m.x.value*entry,m.y.value*entry+10*(1-entry),entry
    if card.props.translateX~=x or card.props.translateY~=y or card.props.opacity~=opacity then
        card:SetStyle({translateX=x,translateY=y,opacity=opacity})
    end
end
return M

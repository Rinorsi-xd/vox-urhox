-- PC home anchors from shared/css/style.css; no portrait branch.
local M={}
function M.Apply(s,w,h,safe)
    s.width=w;s.height=h;s.safe=safe;s.cardWidth=212;s.cardHeight=126
    local function Place(widget,x,y,width,height) widget:SetStyle({position='absolute',left=x,top=y,width=width,height=height}) end
    Place(s.nav,0,0,w,60)
    local x=175.8125
    for _,spec in ipairs({{'hangar',106.609375},{'workshop',142.203125},{'shop',106.609375}}) do Place(s.buttons[spec[1]],x,0,spec[2],60);x=x+spec[2] end
    Place(s.buttons.help,w-106,10,40,40);Place(s.buttons.settings,w-60,10,40,40)
    Place(s.info,28,82,380,math.max(100,h-(require('controls.TouchMode').Enabled() and 342 or 90)))
    local bottom=s.tab=='hangar' and 168 or 40
    Place(s.cta,(w-846)/2,h-bottom-68,846,68)
    Place(s.buttons.edit,0,0,236,68);Place(s.buttons.trial,610,0,236,68);Place(s.buttons.battle,218,0,410,68)
    Place(s.actions,w-282,h-217,254,38)
    local stripWidth=math.min(math.max(216,#(s.cards or {})*222-6),w-56-220)
    Place(s.leftArrow,28,h-156,30,138);Place(s.bayScroll,66,h-156,stripWidth,138)
    Place(s.rightArrow,74+stripWidth,h-156,30,138);Place(s.buttons.new,112+stripWidth,h-156,136,138)
    s.bayStrip:SetStyle({height=138,width=math.max(216,#(s.cards or {})*222-6),paddingTop=6,paddingLeft=2,gap=10})
    if s.tab=='battle' then Place(s.page,28,60,require('controls.TouchMode').Enabled() and 512 or math.min(560,w*.4)-44,math.max(280,h-190))
    else Place(s.page,0,60,w,h-60) end
    local menuHeight=require('ui.HomeNewMenu').height
    if s.menu then Place(s.menu,112+stripWidth+136-320,h-166-menuHeight,320,menuHeight) end
    M.Visibility(s)
end
function M.Visibility(s)
    local home=s.tab=='hangar'
    s.cta:SetVisible(not require('controls.TouchMode').Enabled() or home or s.tab=='battle')
    s.info:SetVisible(home);s.actions:SetVisible(home);s.bayScroll:SetVisible(home)
    s.leftArrow:SetVisible(home);s.rightArrow:SetVisible(home);s.buttons.new:SetVisible(home)
    s.page:SetVisible(not home)
end
return M

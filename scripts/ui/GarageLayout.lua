local HomeNewMenu=require("ui.HomeNewMenu")

local M={}
function M.Apply(s,w,h,safe)
    s.width=w;s.height=h;s.safe=safe or {};s.cardWidth=184;s.cardHeight=90
    local left=math.max(28,s.safe.left or 0);local right=math.max(28,s.safe.right or 0);local top=s.safe.top or 0;local bottom=s.safe.bottom or 0
    s.navHeight=(s.tab=='hangar' and 64 or 60)+top;s.infoWidth=292
    local function Place(widget,x,y,width,height) widget:SetStyle({position='absolute',left=x,top=y,width=width,height=height}) end
    Place(s.nav,0,0,w,s.navHeight)
    local home=s.tab=='hangar'
    local x=home and 201 or 195;local widths=home and {121,121,163,121} or {115,115,159,115}
    for i,id in ipairs({'hangar','livery','workshop','shop'}) do s.buttons[id].props.headerHangar=home;Place(s.buttons[id],x,top,widths[i],s.navHeight-top);x=x+widths[i] end
    if s.buttons.intro then Place(s.buttons.intro,w-(home and 273 or 263),top+(home and 12 or 10),151,40) end
    Place(s.buttons.help,w-(home and 116 or 106),top+(home and 12 or 10),40,40);Place(s.buttons.settings,w-(home and 70 or 60),top+(home and 12 or 10),40,40)
    s.buttons.help:SetVisible(true)
    local stripY=h-bottom-115
    local ctaWidth=672
    local ctaHeight=74
    local ctaY=s.tab=='hangar' and h-bottom-225 or h-bottom-98
    Place(s.cta,(w-ctaWidth)/2,ctaY,ctaWidth,ctaHeight)
    if s.tab=='shop' then Place(s.cta,(w-ctaWidth)/2,h-bottom-98,ctaWidth,ctaHeight) end
    if s.modeStrip then
        local modeWidth=434
        Place(s.modeStrip,(w-modeWidth)/2,h-bottom-279,modeWidth,51)
        Place(s.buttons.arena,0,0,215,51);Place(s.buttons.salvage,219,0,215,51)
    end
    Place(s.buttons.edit,0,0,174,74);Place(s.buttons.battle,160,0,352,74);Place(s.buttons.trial,498,0,174,74)
    local infoHeight=math.min(s.detailsOpen and 585 or 332.96875,math.max(48,h-top-bottom-290))
    Place(s.info,left,top+88,s.infoWidth,infoHeight)
    Place(s.loadout,w-right-254,top+88,254,math.min(infoHeight,s.loadoutHeight or 168))
    Place(s.actions,w-321,h-bottom-183,283,58)
    if s.musicConsole then
        local cw=graphics:GetWidth()/graphics:GetDPR();local k=w/cw
        s.musicConsole.small=cw<=760;s.musicConsole.consoleScale=k
        if cw<=760 then Place(s.musicConsole,12*k,h-180*k,218*k,70*k)
        else Place(s.musicConsole,28,h-262,336,98) end
    end
    if s.buttons.manage then Place(s.buttons.manage,w-158,h-bottom-150,122,32) end
    local stripWidth=math.min(math.max(190,#(s.cards or {})*193-3),w-36*2-30*2-102-24)
    Place(s.leftArrow,36,stripY,30,100);Place(s.bayScroll,74,stripY,stripWidth,100)
    Place(s.rightArrow,82+stripWidth,stripY,30,100);Place(s.buttons.new,120+stripWidth,stripY,102,100)
    s.bayStrip:SetStyle({height=100,width=math.max(190,#(s.cards or {})*193-3),paddingTop=5,paddingLeft=3,gap=9})
    Place(s.page,0,s.navHeight,w,h-s.navHeight-bottom)
    if s.tab=='salvage' or s.tab=='story' or s.tab=='workshop' or s.tab=='battle' or s.tab=='shop' or s.tab=='livery' then Place(s.page,0,0,w,h-bottom) end
    if s.menu then Place(s.menu,math.max(left,math.min(w-right-264,222+stripWidth-264)),stripY-12-HomeNewMenu.height,264,HomeNewMenu.height) end
    M.Visibility(s)
end
function M.Visibility(s)
    local home=s.tab=='hangar'
    s.nav:SetVisible(s.tab~='salvage' and s.tab~='story')
    if s.modeStrip then s.modeStrip:SetVisible(home) end
    if s.musicConsole then s.musicConsole:SetVisible(home) end
    s.cta:SetVisible(home or s.tab=='shop');s.info:SetVisible(home);s.loadout:SetVisible(home)
    s.actions:SetVisible(home and s.manageOpen==true);s.bayScroll:SetVisible(home)
    if s.buttons.manage then s.buttons.manage:SetVisible(home) end
    s.leftArrow:SetVisible(home);s.rightArrow:SetVisible(home);s.buttons.new:SetVisible(home);s.page:SetVisible(not home)
end
return M

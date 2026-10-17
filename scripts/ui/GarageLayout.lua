local HomeNewMenu=require("ui.HomeNewMenu")

local M={}
function M.Apply(s,w,h,safe)
    s.width=w;s.height=h;s.safe=safe or {}
    -- 源 mobile.css：手机紧凑界面车位卡 168×74
    s.cardWidth=s.compact and 168 or 184;s.cardHeight=s.compact and 74 or 90
    local left=math.max(28,s.safe.left or 0);local right=math.max(28,s.safe.right or 0);local top=s.safe.top or 0;local bottom=s.safe.bottom or 0
    s.navHeight=(s.tab=='hangar' and 64 or 60)+top;s.infoWidth=292
    local function Place(widget,x,y,width,height) widget:SetStyle({position='absolute',left=x,top=y,width=width,height=height}) end
    Place(s.nav,0,0,w,s.navHeight)
    local home=s.tab=='hangar'
    local x=home and 201 or 195;local widths=home and {121,121,163,121} or {115,115,159,115}
    for i,id in ipairs({'hangar','livery','workshop','shop'}) do s.buttons[id].props.headerHangar=home;Place(s.buttons[id],x,top,widths[i],s.navHeight-top);x=x+widths[i] end
    if s.buttons.intro then Place(s.buttons.intro,w-(home and 273 or 263),top+(home and 12 or 10),151,40) end
    Place(s.buttons.help,w-(home and 116 or 106),top+(home and 12 or 10),40,40);Place(s.buttons.settings,w-(home and 70 or 60),top+(home and 12 or 10),40,40)
    -- 源 mobile.css：顶栏「？」是键位说明（H），触屏不显示
    s.buttons.help:SetVisible(not s.touch)
    local stripY=h-bottom-115
    -- 手机紧凑界面：车是主角。改装/出战/试车整组缩到 .72 并贴到车位条上方；模式切换放右栏（配件清单下、
    -- 出战右上方），都不压战车（按钮按 sourceScale 等比绘制，点击区域跟着布局一起缩）
    local k=s.compact and .6 or 1
    local km=s.compact and .72 or 1 -- 模式切换字更小会看不清，单独保留 .72
    local ctaWidth=672*k
    local ctaHeight=74*k
    local ctaY=s.tab=='hangar' and (s.compact and stripY-8-ctaHeight or h-bottom-225) or h-bottom-98
    Place(s.cta,(w-ctaWidth)/2,ctaY,ctaWidth,ctaHeight)
    if s.tab=='shop' then Place(s.cta,(w-ctaWidth)/2,h-bottom-98,ctaWidth,ctaHeight) end
    local modeWidth=434*km
    if s.modeStrip then
        if s.compact then Place(s.modeStrip,w-right-modeWidth,ctaY-51*km-10,modeWidth,51*km)
        else Place(s.modeStrip,(w-modeWidth)/2,h-bottom-279,modeWidth,51) end
        Place(s.buttons.arena,0,0,215*km,51*km);Place(s.buttons.salvage,219*km,0,215*km,51*km)
    end
    Place(s.buttons.edit,0,0,174*k,74*k);Place(s.buttons.battle,160*k,0,352*k,74*k);Place(s.buttons.trial,498*k,0,174*k,74*k)
    for _,id in ipairs({'edit','battle','trial'}) do if s.buttons[id] then s.buttons[id].props.sourceScale=k end end
    for _,id in ipairs({'arena','salvage'}) do if s.buttons[id] then s.buttons[id].props.sourceScale=km end end
    local infoHeight=math.min(s.detailsOpen and 585 or 332.96875,math.max(48,h-top-bottom-290))
    -- 紧凑界面左栏下面是音乐盒，信息栏收在它上方，不让「车辆详情」被压掉半截
    if s.compact and s.tab=='hangar' then infoHeight=math.max(48,math.min(infoHeight,ctaY+ctaHeight-70*.72-4-(top+88))) end
    -- 紧凑机库：左侧整备信息和右侧配件清单缩到 .8（绘制与点击一起缩），让车成为画面主体；
    -- 配件清单放到右侧中段、模式切换上方，和车并排
    local side=s.compact and s.tab=='hangar' and .8 or 1
    if side<1 then infoHeight=infoHeight/side end
    Place(s.info,left,top+(side<1 and 78 or 88),s.infoWidth,infoHeight)
    s.info:SetStyle({scale=side,transformOrigin='top-left'})
    local loadoutHeight=math.min(infoHeight,s.loadoutHeight or 168)
    local loadoutTop=top+88
    if side<1 then loadoutTop=math.max(top+78,(s.navHeight+ctaY-51*km-10)/2-loadoutHeight*side/2-10) end
    Place(s.loadout,w-right-254,loadoutTop,254,loadoutHeight)
    s.loadout:SetStyle({scale=side,transformOrigin='top-right'})
    Place(s.actions,w-321,h-bottom-183,283,58)
    if s.musicConsole then
        local cw=graphics:GetWidth()/graphics:GetDPR();local k=w/cw
        s.musicConsole.small=cw<=760 or s.compact==true;s.musicConsole.consoleScale=k
        -- 源 mobile.css：手机紧凑界面把音乐盒缩成左下一条小卡（left 18 / bottom 168 / 250×66），不压改装按钮
        -- 16:9 一类较窄的屏上居中的改装/出战/试车会伸到左下，音乐盒相应缩窄，不压按钮
        -- 紧凑界面用小号音乐盒（218×70 设计）缩到 .72，底边和出战按钮对齐
        if s.compact then s.musicConsole.small=true;s.musicConsole.consoleScale=.72;Place(s.musicConsole,18,ctaY+ctaHeight-70*.72,218*.72,70*.72)
        elseif cw<=760 then Place(s.musicConsole,12*k,h-180*k,218*k,70*k)
        else Place(s.musicConsole,28,h-262,336,98) end
    end
    if s.buttons.manage then Place(s.buttons.manage,w-158,h-bottom-150,122,32) end
    local stripWidth=math.min(math.max(190,#(s.cards or {})*(s.cardWidth+9)-3),w-36*2-30*2-102-24)
    Place(s.leftArrow,36,stripY,30,100);Place(s.bayScroll,74,stripY,stripWidth,100)
    Place(s.rightArrow,82+stripWidth,stripY,30,100);Place(s.buttons.new,120+stripWidth,stripY,102,100)
    s.bayStrip:SetStyle({height=100,width=math.max(190,#(s.cards or {})*193-3),paddingTop=5,paddingLeft=3,gap=9})
    local pk=s.page.pageScale or 1 -- HomePages 缩放过的页面按放大后的逻辑尺寸占位
    Place(s.page,0,s.navHeight,w/pk,(h-s.navHeight-bottom)/pk)
    if s.tab=='salvage' or s.tab=='story' or s.tab=='workshop' or s.tab=='battle' or s.tab=='shop' or s.tab=='livery' then Place(s.page,0,0,w/pk,(h-bottom)/pk) end
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

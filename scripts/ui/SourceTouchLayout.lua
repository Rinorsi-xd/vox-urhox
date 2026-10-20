-- Source physical CSS-pixel sizes remain independent of the scaled HUD.
local M={}
-- custom：玩家在「触屏操作 → 自定义局内布局」里拖过的控件，{[id]={x,y,s}}，x/y 为中心在安全区里的占比。
-- 返回的 centers 是每个控件的中心（CSS px，相对安全区左上角）和缩放，布局编辑器按它摆预览。
function M.Drive(width,height,cssWidth,cssHeight,safe,planeKeys,size,custom)
    local k=width/math.max(1,cssWidth);safe=safe or {};custom=custom or {}
    local left,top=(safe.left or 0)/k,(safe.top or 0)/k
    local w=cssWidth-left-(safe.right or 0)/k;local h=cssHeight-top-(safe.bottom or 0)/k
    local u=math.max(.78,math.min(1.35,math.min(w,h)/390))*(size or 1)
    local fx,fy=w-74*u,h-82*u
    local centers={}
    local function Rect(id,x,y,rw,rh)
        local c=custom[id];local s=1
        if c then x,y,s=c.x*w,c.y*h,c.s end
        centers[id]={x=x,y=y,s=s,w=rw,h=rh}
        return {left=(left+x-rw*u*s/2)*k,top=(top+y-rh*u*s/2)*k,width=rw*u*s*k,height=rh*u*s*k}
    end
    local actions={primary=Rect('primary',fx,fy,76,76),interact=Rect('interact',fx+6*u,fy-150*u,108,40),
        ['rudder-l']=Rect('rudder-l',fx-168*u,fy-40*u,46,40),['rudder-r']=Rect('rudder-r',fx-168*u,fy+14*u,46,40)}
    -- 弧形三键按「位置」自定义：飞机键位模式下 aux 和 scope 互换位置，自定义的格子跟着互换
    for i,id in ipairs({'scope','up','aux'}) do local a=math.rad(({182,222,262})[i]);actions[id]=Rect(id,fx+82*u*math.cos(a),fy+82*u*math.sin(a),54,46) end
    if planeKeys then actions.aux,actions.scope=actions.scope,actions.aux end
    local a=math.rad(142);actions.weapon=Rect('weapon',fx+82*u*math.cos(a),fy+82*u*math.sin(a),54,46)
    local toggle=Rect('toggle',w-30*u,106*u,40,36)
    actions.board=Rect('board',w-78*u,106*u,40,36)
    local fire=centers.primary
    local stick=Rect('stick',100*u,h-96*u,108,108);local home=centers.stick
    -- 浮动摇杆的按下区域：默认左下 45%；摇杆被挪走时把它的位置也包进来（手势层限制摇杆中心不过屏幕中线）
    local reach=54*u*home.s+24*u
    local zone={left,top+math.min(h*.22,home.y-reach),left+math.min(w*.5,math.max(w*.45,home.x+reach)),top+h}
    local pw=math.min(540*k,width-16*k)
    return {k=k,u=u,cssWidth=cssWidth,cssHeight=cssHeight,actions=actions,toggle=toggle,centers=centers,safeRect={left,top,w,h},
        stick=stick,home={left+home.x,top+home.y},
        zone=zone,
        readiness={left=(left+fire.x-30*u*fire.s)*k,top=(top+fire.y+46*u*fire.s)*k,width=60*u*fire.s*k,height=5*u*k},
        panel={left=(width-pw)/2,top=52*u*k,width=pw,height=height-52*u*k-8*k},padding=14*k,columns=3}
end
function M.Calculate(width,height,cssWidth,cssHeight,safe,mode,actions)
    if mode=='drive' then return M.Drive(width,height,cssWidth,cssHeight,safe) end
    local k=width/math.max(1,cssWidth);safe=safe or {};local compact=cssWidth<=600 or cssHeight<=360
    local tiny=cssWidth<=360 and cssHeight<=360
    local stick=cssWidth<=300 and 76 or compact and 88 or 112
    local edge=cssWidth<=300 and 8 or compact and 10 or 18
    local col=tiny and 44 or compact and 48 or 56;local gap=tiny and 4 or compact and 6 or 8
    local columns=tiny and 1 or 2;local rows={};local filtered={}
    for _,id in ipairs(actions) do
        if not tiny or id~='scope' and id~='interact' and id~='slot-prev' and id~='slot-next' then filtered[#filtered+1]=id end
    end
    -- The final source .tc-actions button rule overrides .tc-primary's height.
    local buttonHeight=tiny and 44 or 48;local rowCount=math.ceil(#filtered/columns)
    local baseY=height-(safe.bottom or 0)-(edge+rowCount*buttonHeight+(rowCount-1)*gap)*k
    local baseX=width-(safe.right or 0)-(edge+columns*col+(columns-1)*gap)*k
    for i,id in ipairs(filtered) do rows[id]={left=baseX+(i-1)%columns*(col+gap)*k,top=baseY+math.floor((i-1)/columns)*(buttonHeight+gap)*k,width=col*k,height=buttonHeight*k} end
    local panelWidth=math.min(420*k,width-(safe.left or 0)-(safe.right or 0)-16*k)
    return {k=k,cssWidth=cssWidth,cssHeight=cssHeight,actions=rows,
        stick={left=(safe.left or 0)+edge*k,bottom=(safe.bottom or 0)+edge*k,width=stick*k,height=stick*k},
        toggle={left=mode=='edit' and width/2-24*k or (safe.left or 0)+8*k,top=(safe.top or 0)+8*k,width=48*k,height=44*k},
        panel={left=((safe.left or 0)+width-(safe.right or 0)-panelWidth)/2,top=(safe.top or 0)+62*k,width=panelWidth,height=math.max(1,height-(safe.top or 0)-(safe.bottom or 0)-70*k)},
        padding=(cssWidth<=300 and 8 or 12)*k,columns=cssWidth<=300 and 2 or 3}
end
return M

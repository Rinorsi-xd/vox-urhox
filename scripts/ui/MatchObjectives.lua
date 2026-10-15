-- Frozen MatchSession._objectives and matchHud._marks/_cap.
local D=require 'ui.SourceDraw'
local Coord=require 'core.Coord'
local M={}
local blue={46,168,255,255};local red={255,74,61,255};local orange={255,106,19,255}
local function Clamp(x,a,b) return math.max(a,math.min(b,x)) end
function M.Project(x,y,behind,w,h)
    local off=false
    if behind then x=w-x;y=h-40 end
    if behind or x<40 or x>w-40 or y<110 or y>h-40 then
        off=true
        local dx,dy=x-w/2,y-h/2
        local k=math.min(1,(w/2-40)/math.max(1,math.abs(dx)),(h/2-40)/math.max(1,math.abs(dy)))
        x=w/2+dx*k;y=Clamp(h/2+dy*k,110,h-40)
    end
    return x,y,off
end
function M.Data(session,w,h)
    local b=session.battle;local r=b.rules;local marks={};local cap
    if r.state=='over' or b.intro then return marks,nil end
    local camera=session.camera:GetCamera();local me=b.player;local player=me:Position()
    local function Put(pos,lift,data)
        local point=Coord.Vec(pos[1],pos[2]+lift,pos[3]);local uv=camera:WorldToScreenPoint(point)
        data.x,data.y,data.off=M.Project(uv.x*w,uv.y*h,camera.node:WorldToLocal(point).z<0,w,h)
        data.dist=me.alive and math.sqrt((player[1]-pos[1])^2+(player[3]-pos[3])^2) or 0
        marks[#marks+1]=data
    end
    if b.mode=='conquest' then
        for _,p in ipairs(b.objectives.points) do
            local st;for _,q in ipairs(r.points) do if q.id==p.id then st=q;break end end
            if me.alive and require('combat.BattleObjectives').InPoint(me,p) then cap={id=p.id,v=st.v,owner=st.owner,contested=st.contested,count=st.count}
            else Put(p.pos,7,{id=p.id,v=st.v,owner=st.owner,contested=st.contested}) end
        end
    elseif b.mode=='escort' then
        Put(b.objectives:At(r.s).pos,6,{cart=true,note=r.contested and '争夺中' or r.attack=='blue' and '推车' or '拦截',pushing=r.pushing>0 and not r.contested,contested=r.contested})
    end
    return marks,cap
end
function M.Ring(vg,x,y,v)
    for i=0,2 do
        local a=-math.pi/2+i*math.pi*2/3+.11;local span=math.pi*2/3-.22
        nvgBeginPath(vg);nvgArc(vg,x,y,22,a,a+span,NVG_CW);nvgStrokeWidth(vg,5);nvgStrokeColor(vg,nvgRGBA(0,0,0,128));nvgStroke(vg)
        local f=Clamp(math.abs(v)*3-i,0,1)
        if f>.01 then nvgBeginPath(vg);nvgArc(vg,x,y,22,a,a+span*f,NVG_CW);nvgStrokeWidth(vg,4);nvgStrokeColor(vg,D.Color(v>0 and blue or red));nvgStroke(vg) end
    end
end
function M.Mark(vg,m,time)
    local x,y=m.x,m.y;local c=m.cart and (m.pushing and {111,227,154,255} or {255,208,96,255}) or m.owner=='blue' and blue or m.owner=='red' and red or {42,46,53,224}
    if m.contested and math.floor(time/.225)%2==1 then c=orange end
    nvgSave(vg);nvgGlobalAlpha(vg,m.off and .85 or 1)
    if m.cart then D.Path(vg,{x-13,y-12,x+17,y-12,x+13,y+12,x-17,y+12})
    else M.Ring(vg,x,y,m.v);D.Path(vg,{x,y-14,x+14,y,x,y+14,x-14,y}) end
    nvgFillColor(vg,D.Color(c));nvgFill(vg)
    D.Text(vg,m.cart and '运输' or m.id,x,y-(m.cart and 5.5 or 8.5),m.cart and 11 or 17,m.cart and {26,18,6,255} or D.white,'vox-title',NVG_ALIGN_CENTER,m.cart and 1 or 0)
    D.Text(vg,math.floor(m.dist+.5)..'M'..(m.note and ' · '..m.note or ''),x,y+22,13,D.white,'vox-title',NVG_ALIGN_CENTER,1,false,nil,{{x=0,y=1,blur=3,color={0,0,0,255}}})
    nvgRestore(vg)
end
function M.CapText(c)
    local side=c.v>0 and 'blue' or c.v<0 and 'red'
    return c.contested and '争夺中 · 进度暂停' or c.owner=='blue' and (c.count.red>0 and '正在被抢' or '已占领 · 守住它') or c.count.blue>0 and (side=='red' and '正在清除敌方节点' or '正在占领') or ''
end
function M.Cap(vg,c,w,age)
    if not c then return end
    local t=math.min(1,(age or .25)/.25);local ease=1-(1-t)^3;local y=178+8*(1-ease);local fill=math.abs(c.v)*3
    local what=M.CapText(c);local nodes=math.floor(fill+1e-6)..' / 3 节点'
    local titleWidth=D.Width(vg,what,18,'vox-title',3);local nodeWidth=D.Width(vg,nodes,14,'vox-title',3);local total=30+titleWidth+nodeWidth+24
    local x=(w-total)/2
    nvgSave(vg);nvgGlobalAlpha(vg,ease)
    local color=c.owner=='blue' and blue or c.owner=='red' and red or {42,46,53,255}
    D.Path(vg,{x+15,y,x+30,y+15,x+15,y+30,x,y+15});nvgFillColor(vg,D.Color(color));nvgFill(vg)
    D.Text(vg,c.id,x+15,y+6,18,D.white,'vox-title',NVG_ALIGN_CENTER)
    D.Text(vg,what,x+42,y+6,18,c.contested and orange or D.white,'vox-title',nil,3)
    D.Text(vg,nodes,x+54+titleWidth,y+8,14,D.white,'vox-title',nil,3)
    local width=(400-12)/3;local left=(w-400)/2
    for i=0,2 do
        local sx=left+i*(width+6);local sy=y+38;local skew=math.tan(math.rad(25))*10
        local points={sx+skew,sy,sx+width+skew,sy,sx+width,sy+10,sx,sy+10}
        D.Path(vg,points);nvgFillColor(vg,nvgRGBA(11,13,17,176));nvgFill(vg);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(255,255,255,38));nvgStroke(vg)
        local f=Clamp(fill-i,0,1);if f>0 then
            nvgSave(vg);nvgIntersectScissor(vg,c.v<0 and sx+width*(1-f) or sx,sy,width*f+skew,10)
            D.Path(vg,points);nvgFillColor(vg,D.Color(c.v>0 and blue or red));nvgFill(vg);nvgRestore(vg)
        end
    end
    local a='我方 '..c.count.blue;local b=' · ';local d='敌方 '..c.count.red
    local wa,wb,wd=D.Width(vg,a,12,'vox-title',2),D.Width(vg,b,12,'vox-title',2),D.Width(vg,d,12,'vox-title',2)
    local tx=(w-wa-wb-wd)/2
    D.Text(vg,a,tx,y+54,12,{127,200,255,255},'vox-title',nil,2);D.Text(vg,b,tx+wa,y+54,12,{255,255,255,176},'vox-title',nil,2);D.Text(vg,d,tx+wa+wb,y+54,12,{255,138,128,255},'vox-title',nil,2)
    nvgRestore(vg)
end
function M.Draw(vg,session,w,h,k)
    k=k or 1;local marks,cap=M.Data(session,w*k,h*k)
    -- World markers are excluded from uiScale.js; keep their CSS screen pixels.
    nvgSave(vg);nvgScale(vg,1/k,1/k)
    for _,mark in ipairs(marks) do M.Mark(vg,mark,Time:GetSystemTime()/1000) end
    nvgRestore(vg)
    M.Cap(vg,cap,w,session.battle.captureAge)
end
function M.Update(session,dt)
    local b=session.battle;local _,cap=M.Data(session,1920,1080)
    local id=cap and cap.id
    if id~=b.captureId then b.captureId=id;b.captureAge=0 else b.captureAge=(b.captureAge or 0)+dt end
end
return M

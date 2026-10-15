-- Frozen matchHud.js TOP_FRAME and _layoutMode (2026-10-14 baseline).
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local M={}
local blue={63,178,255,255};local red={255,85,71,255};local amber={255,106,19,255}
local function Line(vg,points,c,width)
    nvgBeginPath(vg);nvgMoveTo(vg,points[1],points[2]);for i=3,#points,2 do nvgLineTo(vg,points[i],points[i+1]) end
    nvgStrokeColor(vg,D.Color(c));nvgStrokeWidth(vg,width or 1);nvgStroke(vg)
end
local function Ring(vg,x,y,v,r)
    for i=0,2 do
        local a=-math.pi/2+i*math.pi*2/3+.11;local span=math.pi*2/3-.22
        nvgBeginPath(vg);nvgArc(vg,x,y,r,a,a+span,NVG_CW);nvgStrokeColor(vg,nvgRGBA(255,255,255,36));nvgStrokeWidth(vg,3);nvgStroke(vg)
        local f=math.max(0,math.min(1,math.abs(v)*3-i));if f>.01 then
            nvgBeginPath(vg);nvgArc(vg,x,y,r,a,a+span*f,NVG_CW);nvgStrokeColor(vg,D.Color(v>0 and {46,168,255,255} or {255,74,61,255}));nvgStroke(vg)
        end
    end
end
M.Ring=Ring
function M.Draw(vg,b,w)
    local r=b.rules;local x=w/2-490;D.HudFont(vg)
    nvgSave(vg);nvgTranslate(vg,x,0)
    D.Path(vg,{300,1.5,334,63,646,63,680,1.5});D.Gradient(vg,300,1.5,380,61.5,{6,8,11,184},{6,8,11,87})
    for _,span in ipairs({{0,216,0,87},{216,764,87,87},{764,980,87,0}}) do
        D.Path(vg,{span[1],.9,span[2],.9,span[2],2.1,span[1],2.1});D.Gradient(vg,span[1],.9,span[2]-span[1],1.2,{255,255,255,span[3]},{255,255,255,span[4]},true)
    end
    Line(vg,{300,1.5,334,63,646,63,680,1.5},{255,255,255,82},1.2)
    Line(vg,{314,1.5,342,53,638,53,666,1.5},{255,255,255,38})
    Line(vg,{20,23.5,284,23.5,296,2},{63,178,255,140})
    Line(vg,{960,23.5,696,23.5,684,2},{255,85,71,140})
    Line(vg,{466,63,514,63},amber,2.4);Line(vg,{334,63,328,69},{255,255,255,82},1.2);Line(vg,{646,63,652,69},{255,255,255,82},1.2)
    for _,team in ipairs({'blue','red'}) do
        local left=team=='blue';local c=left and blue or red;local side=left and 22 or 686
        local count=b.mode=='elimination' and (r.cfg.winRounds or 2) or b.mode=='conquest' and 10 or 0
        local cw=b.mode=='elimination' and 46 or 22;local value=b.mode=='conquest' and r.score[team]/10 or r.score[team]
        for i=1,count do
            local px=left and side+266-i*cw-(i-1)*4 or side+6+(i-1)*(cw+4);local skew=math.tan(math.rad(34))*13*(left and 1 or -1)
            local points={px+skew/2,6,px+cw+skew/2,6,px+cw-skew/2,19,px-skew/2,19}
            D.Path(vg,points);nvgFillColor(vg,nvgRGBA(6,8,11,64));nvgFill(vg)
            nvgStrokeColor(vg,nvgRGBA(c[1],c[2],c[3],184));nvgStrokeWidth(vg,1);nvgStroke(vg)
            local f=math.max(0,math.min(1,value-i+1));if f>0 then
                nvgSave(vg);nvgIntersectScissor(vg,left and px+cw*(1-f) or px,6,cw*f,13);D.Path(vg,points);nvgFillColor(vg,D.Color(c));nvgFill(vg);nvgRestore(vg)
            end
        end
        local index=0
        for _,e in ipairs(b.entries) do if e.unit.team==team then
            local u=e.unit;local px=left and side+270-34-index*39 or side+2+index*39;index=index+1
            local border=not u.alive and {255,255,255,38} or u==b.player and amber or {c[1],c[2],c[3],153}
            local points={px,28,px+26,28,px+34,36,px+34,66,px,66};D.Path(vg,points);nvgFillColor(vg,D.Color(border));nvgFill(vg)
            local inner={px+1,29,px+25.4,29,px+33,36.6,px+33,65,px+1,65}
            nvgSave(vg);nvgGlobalAlpha(vg,u.alive and 1 or .28);Paint.Image(vg,'UI/Avatars/'..e.member.avatar..'.jpg',{x=px+1,y=29,w=32,h=36},1,.5,inner);nvgRestore(vg)
            if u.alive and left then
                local hp=u:Health();D.Rect(vg,px+1,62,32,3,{0,0,0,170});D.Rect(vg,px+1,62,32*hp,3,hp<.3 and {255,176,46,255} or {127,240,200,255})
            elseif not u.alive then Line(vg,{px-2,61,px+36,32},red,1.5) end
        end end
        if b.mode=='conquest' then local on=r.shield and r.shield[team];D.Text(vg,on and '◆ 护盾' or '◆ 护盾熄灭',left and side+6 or side+266,68,10,on and {255,255,255,144} or {255,176,46,255},'vox-body',left and nil or NVG_ALIGN_RIGHT,2) end
        local score=r.score[team]
        if b.mode=='escort' then
            score='-';for _,result in ipairs(r.results or {}) do if result.attack==team then score=math.floor(result.dist+.5) end end
            if score=='-' and r.attack==team then score=math.floor(r.s+.5) end
        else score=math.floor(score) end
        D.Text(vg,score,left and 448 or 532,12,42,left and {92,194,255,255} or {255,106,94,255},'vox-hud',left and NVG_ALIGN_RIGHT or nil,0,false,42)
        if b.mode=='escort' then D.Text(vg,'米',left and 451 or 535+D.Width(vg,score,42,'vox-hud'),36,12,{255,255,255,144},'vox-hud-medium',nil,1) end
    end
    local left=math.max(0,math.ceil(r:TimeLeft()));local sd=b.mode=='elimination' and r.sudden and r.state=='live'
    local clock=string.format('%d:%02d',math.floor(left/60),left%60)
    D.Text(vg,clock,490,12,19,sd and {255,106,94,255} or r.state=='live' and left<30 and {255,176,46,255} or {255,255,255,216},'vox-hud-medium',NVG_ALIGN_CENTER,1.5,false,19)
    local state=r.state=='over' and '对局结束' or b.mode=='elimination' and (r:Final() and '决胜局' or '第 '..r.round..' 回合') or b.mode=='conquest' and (r.overtime and '加时' or '先到 100%') or r.half==1 and '上半场' or '下半场'
    D.Text(vg,state,490,35,11,{255,255,255,156},'vox-body',NVG_ALIGN_CENTER,2,false,11)
    if b.mode=='elimination' and sd then D.Text(vg,'决胜时刻 · 维修失效',490,66,11,{255,138,106,255},'vox-body',NVG_ALIGN_CENTER,2)
    elseif b.mode=='conquest' then
        for i,id in ipairs({'A','C','B'}) do for _,p in ipairs(r.points) do if p.id==id then
            local px=490+(i-2)*54;Ring(vg,px,83,p.v,14.28)
            local c=p.contested and math.floor((b.clock or 0)/.225)%2==1 and {255,106,19,224} or p.owner=='blue' and {31,132,214,224} or p.owner=='red' and {200,54,44,224} or {11,14,18,192}
            D.Path(vg,{px-4.6,71.5,px+4.6,71.5,px+11.5,78.4,px+11.5,87.6,px+4.6,94.5,px-4.6,94.5,px-11.5,87.6,px-11.5,78.4});nvgFillColor(vg,D.Color(c));nvgFill(vg)
            D.Text(vg,id,px,76,13,{232,238,242,255},'vox-hud',NVG_ALIGN_CENTER,0,false,13)
        end end end
    elseif b.mode=='escort' then
        local note=r.contested and '争夺中 · 车停了' or r.pushing>0 and r.pushing..' 辆在推' or r.overtime and '加时 · 没人推 5 秒结束' or r.idle>=8 and '没人推 · 车在后退' or '推得远的一方获胜'
        D.Text(vg,(r.attack=='blue' and '我方进攻' or '我方防守')..'  '..math.floor(r.s+.5)..' / '..math.floor(r.length+.5)..' 米  · '..note,490,66,11,{255,255,255,176},'vox-body',NVG_ALIGN_CENTER,2)
        local progress=math.max(0,math.min(1,r.s/r.length));D.Rect(vg,300,87,380,4,{255,255,255,31});D.Rect(vg,300,87,380*progress,4,amber)
        for _,f in ipairs({.333,.667}) do D.Rect(vg,300+380*f,83,1.5,12,{255,255,255,176}) end
        local px=300+380*progress;D.Path(vg,{px,81,px+6,86.6,px+6,97,px-6,97,px-6,86.6});nvgFillColor(vg,D.Color(r.contested and amber or r.idle>=8 and red or r.pushing>0 and {111,227,154,255} or D.white));nvgFill(vg)
    end
    nvgRestore(vg)
end
return M

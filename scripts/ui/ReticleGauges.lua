local D=require 'ui.SourceDraw'
local R=require 'ui.ReticleDraw'
local State=require 'ui.ReticleState'
local M={}
local function Fill(vg,l,r,a,b,f,c,w,glow) R.Arc(vg,l.cx,l.cy,r,b,b+(a-b)*State.Clamp(f),c,w*l.k,glow and glow*l.k) end
function M.Render(vg,v,l)
    local k,cx,cy,r=l.k,l.cx,l.cy,l.radius;local s=v.session;local story=s.story~=nil
    local hp=v.hp or 1;local energy=s.weapons.offline and 0 or State.Clamp(s.weapons.energy/s.weapons.energyMax)
    local repair=v.repair;local hpColor=hp<.3 and R.red or R.hp
    if (v.hurtUntil or 0)>(v.clock or 0) or (v.doneUntil or 0)>(v.clock or 0) then hpColor=R.white elseif repair then hpColor={143,247,255,255} end
    for _,angles in ipairs({{184,238},{302,356}}) do
        R.Arc(vg,cx,cy,r,angles[1],angles[2],{255,255,255,160},1.8*k)
        for a=angles[1]+2,angles[2]-2,3 do R.Spoke(vg,cx,cy,r-((a-angles[1])%12==2 and 13 or 7)*k,r-3*k,a,{255,255,255,112},1.2*k) end
        for _,a in ipairs(angles) do R.Spoke(vg,cx,cy,r-14*k,r+14*k,a,{255,255,255,208},2.2*k) end
    end
    for _,angles in ipairs({{222,234},{306,318},{188,194},{346,352}}) do R.Arc(vg,cx,cy,r+9*k,angles[1],angles[2],{255,255,255,208},5*k) end
    for _,g in ipairs({{176,122,hp,hpColor},{4,58,s.weapons.offline and 1 or energy,R.en}}) do
        R.Arc(vg,cx,cy,r,g[1],g[2],{10,15,20,89},17*k)
        nvgSave(vg);if g[1]==4 and s.weapons.offline then nvgGlobalAlpha(vg,math.floor((v.clock or 0)/.25)%2==0 and 1 or .3);g[4]=R.red end
        Fill(vg,l,r,g[1],g[2],g[3],g[4],13,4);nvgRestore(vg)
        for _,f in ipairs({0,.25,.5,.75,1}) do R.Spoke(vg,cx,cy,r+8.5*k,r+13.5*k,g[2]+(g[1]-g[2])*f,{255,255,255,120},1.2*k) end
    end
    for i=0,19 do
        local a=122+54*i/20;local filled=i<math.ceil((v.structure or 1)*20-.01)
        R.Arc(vg,cx,cy,l.inner,a,a+54/20*.8,filled and R.white or {255,255,255,36},5*k)
    end
    if repair and hp>.02 then
        local start=122+54*((v.clock or 0)/.7%1)*hp
        R.Arc(vg,cx,cy,r,start,math.min(122+54*hp,start+18*k/r*180/math.pi),R.white,9*k,5*k)
    end
    local function Label(a,label,value,c,dir)
        local x,y=cx+math.cos(a*math.pi/180)*(r+20*k),cy+math.sin(a*math.pi/180)*(r+20*k)
        local align=dir<0 and NVG_ALIGN_RIGHT or NVG_ALIGN_LEFT
        R.Text(vg,label,x,y-2*k,15*k,c,align,story,true,3);R.Text(vg,tostring(math.floor(value*100+.5)),x+dir*4*k,y+40*k,44*k,c,align,story)
    end
    Label(176,'HP',hp,hpColor,-1);Label(4,'EN',energy,R.busy,1)
    local fraction=v.structure or 1
    if repair or fraction<.995 then
        local a=122*math.pi/180
        R.Text(vg,repair and '▲ 修复中' or ((s.combat and s.combat.player.structure and '结构 ' or '完整度 ')..math.floor(fraction*100+.5)..'%'),cx+math.cos(a)*(r+20*k)-2*k,cy+math.sin(a)*(r+20*k)+22*k,14*k,repair and {143,247,255,255} or R.muted,NVG_ALIGN_RIGHT,story)
    end
    local speed=math.abs(s.vehicle.speed or 0)*3.6;local max=(s.vehicle.spec.motion.topSpeed or 0)*3.6
    R.Text(vg,tostring(math.floor(speed+.5)),cx-r-30*k,cy-r*.5+4*k,52*k,R.white,NVG_ALIGN_RIGHT,story)
    R.Text(vg,'KM/H',cx-r-30*k,cy-r*.5+24*k,13*k,R.muted,NVG_ALIGN_RIGHT,story)
    do
        R.Arc(vg,cx,cy,r,184,238,{10,15,20,64},9*k)
        R.Arc(vg,cx,cy,r,356,302,{10,15,20,64},9*k)
        if max>0 then R.Arc(vg,cx,cy,r,184,184+54*State.Clamp(speed/max),speed>max*1.02 and R.busy or R.white,6*k,3*k) end
        local fire=v.fire
        if fire then
            local color=R[fire.tone] or R.white
            R.Arc(vg,cx,cy,r,356,356-54*fire.frac,color,6*k,3*k)
            local fx,fy=s.scope and cx+58*k or cx+r+40*k,s.scope and cy-30*k or cy-r*.5-10*k
            D.Rect(vg,fx-14*k,fy-8*k,7*k,7*k,color)
            nvgSave(vg);local age=(v.clock or 0)-(v.wordAt or 0)
            if age<.3 then nvgGlobalAlpha(vg,age<.1 and .2 or age<.2 and 1 or .5) end
            R.Text(vg,fire.word,fx,fy,21*k,fire.tone=='warn' and {255,208,138,255} or R.white,nil,false,false,4);nvgRestore(vg)
            R.Text(vg,fire.sub,fx,fy+19*k,13*k,fire.tone=='warn' and {255,207,138,208} or R.muted,nil,false,true,2)
        end
    end
end
function M.Compass(vg,v,l)
    local k,cx=l.k,l.cx;local head=((v.session.yaw or 0)%360+360)%360
    nvgSave(vg)
    if v.session.battle then
        nvgTranslate(vg,0,100*require('ui.MatchBanner').Scale(l.width,l.height,v.session.touch))
    end
    local names={[0]='N',[45]='NE',[90]='E',[135]='SE',[180]='S',[225]='SW',[270]='W',[315]='NW'}
    local half,y=320*k,40*k
    for d=math.ceil((head-60)/5)*5,head+60,5 do
        local x=cx+(d-head)*half/60;nvgSave(vg);nvgGlobalAlpha(vg,1-math.abs(x-cx)/half)
        D.Line(vg,x,y,x,y-(d%15==0 and 11 or 5)*k,{255,255,255,102},1.2*k)
        if names[d%360] then R.Text(vg,names[d%360],x,y-17*k,14*k,R.muted,NVG_ALIGN_CENTER,v.session.story~=nil) end
        nvgRestore(vg)
    end
    require('ui.ReticleNavigation').Render(vg,l,head,v.waypoint)
    R.Poly(vg,{cx,y+3*k,cx-6*k,y+12*k,cx+6*k,y+12*k},R.white)
    R.Text(vg,string.format('%03d',math.floor(head+.5)%360),cx,y+32*k,20*k,R.white,NVG_ALIGN_CENTER,v.session.story~=nil)
    nvgRestore(vg)
end
return M

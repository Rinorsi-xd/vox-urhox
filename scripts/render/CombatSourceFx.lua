-- Parameters and event formulas from the frozen 2026-10-14 H5 baseline.
local V=require 'core.Math3'
local M={}
local function At(p,d,k)return V.Add(p,V.Scale(d,k))end
function M.Color(hex)
    local function Channel(n)local c=n/255;return c<=.04045 and c/12.92 or ((c+.055)/1.055)^2.4 end
    return {Channel((hex>>16)&255),Channel((hex>>8)&255),Channel(hex&255)}
end
function M.Bolt(streak,glow,p,color)
    local speed=V.Length(p.vel);local t=p.s.tier;local dir=V.Scale(p.vel,speed>0 and 1/speed or 1)
    local k=(p.bright and 1.25 or 1)*(.88+(p.seed or .5)*.24);local flick=.85+math.random()*.3
    local len=math.min(speed*(.036+t*.002)*k,p.dist+.05)
    local function Back(d)return At(p.pos,dir,-math.min(d,p.dist+.05))end
    streak:Segment(Back(len),p.pos,(.2+t*.025)*k,color.glow,.55*flick,.3,0,1,true,.97)
    streak:Segment(Back(len*.75),p.pos,(.075+t*.01)*k,color.core,1,.75,0,1,true,.95)
    glow(p.pos,(.2+t*.025)*k*flick,color.inner);glow(p.pos,(.08+t*.01)*k,color.core)
end
function M.ForwardSparks(f,p,dir,n,speed,jitter,spread,color,size,life,drag)
    for _=1,n do
        local vel={};for j=1,3 do vel[j]=dir[j]*(speed+math.random()*jitter)+(math.random()-.5)*spread end
        f:Spark(p,vel,color,size,life,drag)
    end
end
function M.VentSparks(f,e,color)
    local t=e.tier;local right=V.Normalize(V.Cross(e.dir,{0,1,0}))
    for _,side in ipairs({-1,1})do if math.random()<=.55 then
        local p=At(At(e.pos,e.dir,-(t==5 and 1.9 or 1.4)),right,side*(t==5 and .45 or .32));local vel={}
        for j=1,3 do vel[j]=right[j]*side*(2.5+math.random()*2)+(j==2 and 1+math.random() or math.random()-.5)end
        f:Spark(p,vel,color,.04,.18,4,2)
    end end
end
function M.Recovery(f,e)
    if e.type=='plateBreak'then
        f:Flash(e.pos,2.6,.16,M.Color(0x3aa6ff));f.light:Emit(e.pos,60,0x3aa6ff)
        f:Burst(e.pos,34,9,{.7,1.8,4.5},nil,.1,.5)
    elseif e.type=='repair'then
        local sz=math.min(3,.9+(e.cells or 1)^(1/3)*.5)
        f:Flash(e.pos,sz*1.8,.28,M.Color(0x3fe6ff));f.light:Emit(e.pos,45,0x3fe6ff,10)
        f:Burst(e.pos,16,2.6,{.6,3.2,4.2},nil,.07,.7,-2,1.6)
        for i=0,9 do
            local a=i/10*math.pi*2;local r=sz*.9;local c,s=math.cos(a),math.sin(a)
            f:Spark({e.pos[1]+c*r,e.pos[2]+(math.random()-.5)*.4,e.pos[3]+s*r},{-c*r*3,.6,-s*r*3},{.8,3.6,4.6},.06,.32,3)
        end
    elseif e.type=='heal'then
        local r=e.radius or 2
        for _=1,9 do
            local a=math.random()*math.pi*2;local d=r*(.4+math.random()*.6)
            local p={e.pos[1]+math.cos(a)*d,e.pos[2]-r*.3+math.random()*r*.8,e.pos[3]+math.sin(a)*d}
            f:Spark(p,{0,1.2+math.random()*1.4,0},{.4,2.4,3.2},.05+math.random()*.04,.6+math.random()*.5,1,-1)
        end
    end
end
return M

-- Source weaponFx.js missile branches. Budgets share CombatEffects batches.
local V=require 'core.Math3'
local View=require 'render.MissileView'
local Quality=require 'render.Quality'
local M={};M.__index=M
local C={flame={.5,1.7,5.2},core={5,7,9},trail={.12,.55,2.3},spark={2,4.5,8},glow={.22,.85,3.2},flash={.274,.745,1},flare={.6,1.9,5}}
local sizes=require('core.ResourceData').Read('Combat/MissileView.json').sizes
local function At(p,d,k) return V.Add(p,V.Scale(d,k)) end
function M.New(owner)
    return setmetatable({owner=owner,booms={},log={},view=nil,trailStride=Quality.current.name=='mobile' and 3 or 1},M)
end
function M:Shot(e)
    local f=self.owner;local t=e.tier;local p=At(e.pos,e.dir,.05);local lk=e.locked and 1.25 or 1
    f:Flash(At(p,e.dir,.12),(.32+t*.05)*lk,.08,C.flash);f.light:Emit(p,(14+t*5)*lk,0x5ac8ff,9)
    f:Ring(p,e.dir,.06,.28+t*.05,.16,C.glow,.8*lk,.22)
    f:Flare(p,e.dir,3,.3+t*.05,.12+t*.015,C.flare,.3,.07)
    f:Burst(p,3+t,7,C.spark,e.dir,.035,.16,0);f:Puff(At(p,e.dir,-.1),t>=4 and 2 or 1,.2+t*.03,.8,.62)
end
function M:Blast(e)
    local f=self.owner;local t=e.tier or 3;local n=e.normal or e.dir and V.Scale(e.dir,-1) or {0,1,0};local p=At(e.pos,n,.08)
    for i=#self.log,1,-1 do if f.time-self.log[i].t>=.5 then table.remove(self.log,i) end end
    local combo=0;for _,entry in ipairs(self.log) do if V.Length(V.Sub(entry.p,p))<5 then combo=combo+1 end end
    if #self.log<128 then self.log[#self.log+1]={t=f.time,p=p} end
    local big=math.min(2,1+combo*.1);local r=(e.radius or 2.5)*big;local dim=1/math.sqrt(1+combo*.6)
    if combo%4==0 then f:Flash(p,r*1.3,.1,{.807,.965,1}) end
    f:Flash(p,r*.8,.45,C.flash);f.light:Emit(p,(120+t*40)*big*dim,0x7fd8ff,6)
    if #self.booms<64 then self.booms[#self.booms+1]={pos=p,r=r,dim=dim,white=combo%4==0,age=0,life=.55+.1*big} end
    f:Ring(p,n,.3,r*1.2,.32,C.glow,1.2,.22)
    f:Ring({p[1],p[2]-math.min(1.2,r*.3),p[3]},{0,1,0},.4,r*2.2,.55,{.3,1.2,3},.9,.12,.03)
    f:Ring(p,{n[3]~=0 and n[3] or .0001,0,-n[1]},.2,r*1.5,.42,C.glow,.7,.14,.06)
    f:Flare(p,n,10+t*2,r*.9,.18+t*.03,C.flare,1.5,.16);f:Flare(p,{0,1,0},6,r*1.1,.14,{1.5,3.5,7},.9,.2)
    f:Burst(p,math.floor((30+t*8)*math.min(1.6,big)+.5),14,C.spark,n,.09,.8,9);f:Burst(p,14,7,{6,7.5,9},nil,.05,.35,2)
    local u=V.Normalize(V.Cross(math.abs(n[2])<.9 and {0,1,0} or {1,0,0},n));local v=V.Cross(n,u)
    for _=1,7+t*2 do if #f.zaps<64 then
        local a=math.random()*math.pi*2;local d=V.Normalize(At(V.Add(V.Scale(u,math.cos(a)),V.Scale(v,math.sin(a))),n,.1+math.random()*.9))
        f.zaps[#f.zaps+1]={a=p,b=At(p,d,r*(.5+math.random()*.6)),age=0,life=.18+math.random()*.22,width=.06+t*.008}
    end end
    f:Puff(p,4+t,r*.32,1.8,.3);f:Puff({p[1],p[2]+r*.3,p[3]},3,r*.22,2.4,.22)
end
function M:Update(dt,projectiles,glow)
    local f=self.owner;local b=f.batches
    if self.view then self.view:Begin() end
    for _,p in ipairs(projectiles) do if p.fx=='missile' then
        if not self.view then self.view=View.New(f.root,Quality.current.name=='mobile' and 64 or 128);self.view:Begin() end
        self.view:Add(p)
        local t=p.s.tier;local dir=V.Normalize(p.vel);local flick=.85+math.random()*.3;local tail=At(p.pos,dir,-sizes[tostring(t)].l)
        glow(tail,(.45+t*.06)*flick,C.flame);glow(tail,(.18+t*.02)*flick,C.core)
        b.Streak:Segment(At(tail,dir,-(.8+t*.12)*flick),tail,.2+t*.02,C.flame,.95,.5,0,.95,true)
        local trail=p.trail;local n=trail and #trail-1 or 0
        for i=1,n,self.trailStride do
            local last=math.min(n+1,i+self.trailStride);local a=(last-1)/n;local fade=a^1.4;local width=.1+(1-(i-1)/n)*.32+t*.015
            b.Ribbon:Segment(trail[i],trail[last],width,C.trail,fade*.45,0,(i-1)/n,a)
            b.Ribbon:Segment(trail[i],trail[last],.05+t*.006,C.flame,fade*fade*.8,.5,(i-1)/n,a)
        end
        if n>0 then b.Ribbon:Segment(trail[n+1],tail,.06,C.trail,.6,.3,.95,1) end
        if math.random()<dt*9 then f:Puff(tail,1,.14+(p.seed or .5)*.05,.6+math.random()*.4,.22) end
    end end
    if self.view then self.view:Finish() end
    for i=#self.booms,1,-1 do
        local e=self.booms[i];e.age=e.age+dt;local k=e.age/e.life
        if k>=1 then table.remove(self.booms,i) else
            local grow=1-(1-math.min(1,k*1.6))^3;local fade=(1-k)^1.5*e.dim;local r=e.r
            glow(e.pos,r*(.35+.25*grow)*math.max(0,1-k*2.2),V.Scale(C.core,1.6))
            glow(e.pos,r*(.55+.9*grow),V.Scale(C.glow,2.2*fade));glow(e.pos,r*(.9+1.4*grow),{.5*fade,.35*fade,1.6*fade})
            if e.white and e.age<.1 then glow(e.pos,r*2.2,V.Scale({.9,1.3,2},1-e.age/.1)) end
        end
    end
end
function M:Clear() self.booms={};self.log={};if self.view then self.view:Clear() end end
function M:Dispose() if self.view then self.view:Dispose();self.view=nil end;self:Clear() end
return M

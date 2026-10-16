-- Source: three/src/drive/{weaponFx,effects}.js. Rendering consumes events only;
-- damage remains in WeaponSystem. Bounded transient lists, five base batches,
-- a lazy non-noisy arc batch and one scene-owned transient point light.
local CombatLight=require("render.CombatLight")
local MissileEffects=require("render.MissileEffects")
local MissileView=require("render.MissileView")
local DrillEffects=require("render.DrillEffects")

local V=require "core.Math3"
local Batch=require "render.EffectBatch"
local Quality=require "render.Quality"
local Chips=require "render.ChipEffects"
local SourceFx=require 'render.CombatSourceFx'
local M={};M.__index=M
local LASER={glow={.2,.8,3.1},helix={.18,.65,2.7},spark={2,4,8},flare={.5,1.6,4.4}}
local RAIL={core={2.1,2.8,4.4},glow={.16,.5,2.3},helix={.28,.85,3.3},spark={3.5,4.5,7},flare={1.6,2.3,4.2}}
local BOLT={glow={3.6,2.3,.6},halo={.9,.6,.15},inner={2.8,1.85,.5},core={8,6.6,3.6},mote={3,2.4,1},spark={7,4.2,1.2},flare={4.2,2.6,.7}}
local function At(p,d,l) return V.Add(p,V.Scale(d,l)) end
local function Basis(d)
    local u=V.Normalize(V.Cross(math.abs(d[2])<.9 and {0,1,0} or {1,0,0},d));return u,V.Cross(d,u)
end
local function Add(list,item,cap) if #list<cap then list[#list+1]=item end end
local function Advance(list,dt,draw)
    local i=1
    while i<=#list do
        local e=list[i];e.age=e.age+dt
        if e.age>=e.life+(e.delay or 0) then list[i]=list[#list];list[#list]=nil
        else draw(e);i=i+1 end
    end
end
function M.New(scene,groundAt)
    local self=setmetatable({},M)
    self.root=scene:CreateChild("CombatEffects");self.time=0;self.events=0;self.disposed=false
    self.light=CombatLight.New(self.root)
    local mobile=Quality.current.name=="mobile"
    self.groundAt=groundAt or function() return 0 end
    self.chips=Chips.New(self.root,mobile and 96 or 360,self.groundAt)
    self.maxParticles=mobile and 240 or 1000;self.maxSmoke=mobile and 64 or 240;self.maxHelix=mobile and 96 or 300
    self.batches={Ribbon=Batch.New(self.root,"Ribbon",mobile and 640 or 2400),
        Streak=Batch.New(self.root,"Streak",mobile and 240 or 1000),Glow=Batch.New(self.root,"Glow",mobile and 640 or 2200),
        Ring=Batch.New(self.root,"Ring",40),Smoke=Batch.New(self.root,"Smoke",self.maxSmoke)}
    self.missiles=MissileEffects.New(self)
    self:Clear();return self
end
function M:Reserve(options)
    options=options or {}
    if options.arc and not self.batches.Arc then
        self.batches.Arc=Batch.New(self.root,'Ribbon',Quality.current.weaponArcSegments,'Shaders/BLGL/WeaponFx/')
    end
    if (options.chips or 0)>0 then self.chips:Reserve(options.chips) end
    if (options.missiles or 0)>0 then
        if not self.missiles.view then
            self.missiles.view=MissileView.New(self.root,Quality.current.name=='mobile' and 64 or 128)
        end
        self.missiles.view:Reserve(options.missiles)
    end
end
function M:Clear()
    self.light:Clear()
    self.chips:Clear()
    self.missiles:Clear()
    self.beams={};self.flares={};self.rings={};self.particles={};self.smoke={};self.flashes={};self.zaps={};self.trails={}
    for _,b in pairs(self.batches) do b.count=0;b.mesh.enabled=false end
end
function M:Flash(p,size,life,color)
    Add(self.flashes,{pos=p,size=size*(.8+math.random()*.4),life=life,age=0,color=color},32)
end
function M:Ring(p,d,r0,r1,life,color,alpha,thick,delay)
    Add(self.rings,{pos=p,dir=d,r0=r0,r1=r1,life=life,color=color,alpha=alpha or 1,thick=thick or .18,delay=delay or 0,age=0},40)
end
function M:Spark(p,vel,color,size,life,drag,gravity,grow)
    Add(self.particles,{pos={table.unpack(p)},vel=vel,color=color,size=size,life=life,age=0,drag=drag or 0,grav=gravity or 0,grow=grow or 0},self.maxParticles)
end
function M:Burst(p,n,speed,color,normal,size,life,gravity,up)
    for _=1,n do
        local d={math.random()*2-1,math.random()*2-1+(up or .4),math.random()*2-1}
        if normal then d=At(d,normal,1.2) end
        Add(self.particles,{pos={table.unpack(p)},vel=V.Scale(V.Normalize(d),speed*(.4+math.random()*.8)),color=color,
            size=(size or .08)*(.6+math.random()*.8),life=(life or .45)*(.5+math.random()),age=0,drag=2,grav=gravity or 12},self.maxParticles)
    end
end
function M:Puff(p,n,size,life,gray)
    for _=1,n do
        local g=(gray or .35)*(.8+math.random()*.4)
        Add(self.smoke,{pos={p[1]+(math.random()-.5)*size,p[2]+(math.random()-.5)*size,p[3]+(math.random()-.5)*size},
            vel={(math.random()-.5)*3,math.random()*2.2+.4,(math.random()-.5)*3},color={g,g*.97,g*.94},
            size=size*(.7+math.random()*.6),grow=size*1.4,life=life*(.7+math.random()*.6),age=0,drag=1.5,grav=0},self.maxSmoke)
    end
end
function M:EquipmentEmit(kind,p)
    if kind=='fizzle' then self:Burst(p,10,4,{3,4.5,8},nil,.04,.35,5);self:Puff(p,2,.25,1,.35)
    elseif kind=='boot' then self:Flash(p,.5,.1,SourceFx.Color(0x9fd4ff));self:Burst(p,4,2,{2,4,8},nil,.03,.25,0)
    elseif kind=='spark' then
        Add(self.particles,{pos=p,vel={(math.random()-.5)*3,math.random()*2,(math.random()-.5)*3},color=BOLT.spark,
            size=.03+math.random()*.02,life=.15+math.random()*.15,age=0,drag=3,grav=3},self.maxParticles)
    elseif kind=='mote' then
        Add(self.particles,{pos=p,vel={(math.random()-.5)*.4,.3+math.random()*.5,(math.random()-.5)*.4},color=LASER.spark,
            size=.04,life=.5+math.random()*.4,age=0,drag=1.5,grav=-.3},self.maxParticles)
    end
end
function M:Flare(p,d,n,len,width,color,spread,life)
    local u,v=Basis(d)
    for _=1,n do
        local angle=math.random()*math.pi*2;local s=spread*math.sqrt(math.random())
        local dir=V.Normalize(V.Add(d,V.Scale(V.Add(V.Scale(u,math.cos(angle)),V.Scale(v,math.sin(angle))),s)))
        Add(self.flares,{base=p,tip=At(p,dir,len*(.6+math.random()*.6)),width=width*(.75+math.random()*.5),color=color,
            life=life*(.8+math.random()*.4),age=0},128)
    end
end
function M:Shot(e)
    local t=e.tier or 1;local big=t>=4;local p=At(e.pos,e.dir,e.kind=="sniper" and .1 or .06)
    if e.kind=="mg" then
        self:Flash(At(p,e.dir,.12),.22+t*.04,.07,SourceFx.Color(0xffe2b0))
        self.light:Emit(p,(5+t*2.5)*(.85+math.random()*.25),0xffa050,7,.6)
        self:Flare(p,e.dir,t==5 and 5 or 3,.45+t*.1,.16+t*.025,BOLT.flare,.16,.065)
        if t==4 then self:Flare(p,e.dir,4,.35,.14,BOLT.flare,1.1,.045) end
        if (e.spin or 0)>.9 then SourceFx.ForwardSparks(self,p,e.dir,big and 3 or 1,9,7,4,BOLT.spark,.05,.1,5) end
        if big then SourceFx.VentSparks(self,e,BOLT.spark) end
    elseif e.kind=="laser" then
        self:Flash(At(p,e.dir,.1),.25+t*.05,.06,SourceFx.Color(0x6cc8ff))
        self:Flare(p,e.dir,4,.35+t*.08,.13+t*.02,LASER.flare,.22,.07)
        self.light:Emit(p,12+t*5,0x4aa8ff)
        self:Ring(p,e.dir,.06,.24+t*.04,.1,LASER.glow,.55,.2)
        if big then
            self:Ring(At(p,e.dir,.25),e.dir,.1,.6+(t-4)*.2,.2,LASER.glow,.9,.2,.02)
            SourceFx.ForwardSparks(self,p,e.dir,8,8,8,4,LASER.spark,.05,.14,4)
        end
    elseif e.kind=='missile' then self.missiles:Shot(e)
    else
        self:Flash(At(p,e.dir,.2),.6+t*.18,.1,SourceFx.Color(0xdcefff))
        self:Flare(p,e.dir,5+t,.9+t*.25,.22+t*.04,RAIL.flare,.12,.09)
        self:Flare(p,e.dir,4,.5,.18,RAIL.flare,1.3,.07)
        self.light:Emit(p,40+t*15,0x9fd4ff)
        self:Ring(p,e.dir,.15,.7+t*.18,.24,RAIL.glow,1,.22)
        self:Ring(At(p,e.dir,.4),e.dir,.1,1.1+t*.25,.34,RAIL.glow,.7,.12,.04)
        self:Burst(p,8+t*3,7,RAIL.spark,e.dir,.06,.3,4);self:Puff(p,2+t,.35,.9,.55)
    end
end
function M:Beam(e)
    local t=e.tier or 1;local rail=e.kind=="sniper";local len=V.Length(V.Sub(e.to,e.from));local grow=rail and .035 or .05
    local b={};for k,v in pairs(e) do b[k]=v end
    b.len=len;b.age=0;b.grow=grow;b.life=grow+(rail and (.32+t*.03) or (t>=4 and .15 or .11));b.phase=math.random()*6.28;b.hitDone=not e.hit
    Add(self.beams,b,64)
    if t>=4 then
        local count=math.min(rail and 12 or 8,math.floor(len/(rail and 5 or 4)))
        for i=1,count do
            local f=i/(count+1);local p=At(e.from,V.Sub(e.to,e.from),f)
            self:Ring(p,e.dir,rail and .12 or .06,rail and (.55+t*.08) or (.24+(t-4)*.08),rail and .28 or .1,
                rail and RAIL.glow or LASER.glow,rail and .55 or .75,rail and .16 or .3,f*(rail and .06 or .05))
        end
    end
    if rail and t==5 then Add(self.trails,{from=e.from,to=e.to,dir=e.dir,len=len,age=0,life=.75,next=0},32) end
end
function M:Hit(e)
    local t=e.tier or 1;local rail=e.kind=="sniper";local n=e.normal or V.Scale(e.dir,-1);local p=At(e.to,n,.04)
    self:Flash(p,rail and (1.6+t*.4) or (.5+t*.1),rail and .16 or .08,SourceFx.Color(rail and 0xdcefff or 0x6cc8ff))
    self:Flash(p,rail and .7 or (.22+t*.03),rail and .5 or .42,SourceFx.Color(rail and 0x6cb8ff or 0x3f9dff))
    self.light:Emit(p,rail and (50+t*20) or (8+t*3),rail and 0x9fd4ff or 0x4aa8ff)
    self:Burst(p,rail and (18+t*5) or (6+t*2),rail and 10 or 6,rail and RAIL.spark or e.target and {3,4,9} or LASER.spark,n,rail and .07 or .045,rail and .5 or .32)
    if rail then
        self:Puff(p,3+t,.5,1.4,.4);self:Ring(p,n,.2,1.4+t*.35,.32,RAIL.glow,.9,.16)
        local u,v=Basis(n)
        for _=1,t>=4 and 7 or 3 do
            local a=math.random()*math.pi*2;local d=V.Normalize(At(V.Add(V.Scale(u,math.cos(a)),V.Scale(v,math.sin(a))),n,.3+math.random()*.9))
            Add(self.zaps,{a=p,b=At(p,d,.5+math.random()*math.max(t>=4 and 1.1 or .6,(e.splash or 0)*.8)),age=0,life=.14+math.random()*.14,width=.05+t*.008},64)
        end
    else
        if t>=4 then self:Ring(p,n,.08,.45+(t-4)*.12,.18,LASER.glow,.8,.25) end
        if math.random()<.4 then self:Puff(p,1,.22,.6,.45) end
    end
end
function M:Consume(events,remote)
    for _,e in ipairs(events) do
        if self.onEvent then self.onEvent(e,remote) end
        self.events=self.events+1
        if e.type=='drill' then DrillEffects.Event(self,e)
        elseif e.type=="shot" then self:Shot(e)
        elseif e.type=='blast' and e.kind=='missile' then self.missiles:Blast(e)
        elseif e.type=="beam" then self:Beam(e)
        elseif e.type=="impact" then
            local t=e.tier or 3;local n=e.normal or V.Scale(e.dir,-1);local p=At(e.pos,n,.03)
            self:Flash(p,(.6+t*.09)*(e.bright and 1.4 or 1),.09,SourceFx.Color(0xffd080))
            self.light:Emit(p,40+t*12,0xffb050,14)
            self:Burst(p,9+t*2,8.5,e.target and {7,2.4,.7} or BOLT.spark,n,.06,.38)
            self:Ring(p,n,.05,.35+(t-3)*.1,.13,{4,1.6,.4},.75,.3)
            if e.material=='metal' or e.target then for _=1,3 do
                self.chips:Emit({p[1],p[2],p[3]},{n[1]*6+(math.random()-.5)*8,n[2]*6+math.random()*6,n[3]*6+(math.random()-.5)*8},
                    .03+math.random()*.04,0xffa040,.5+math.random()*.4)
            end end
            if math.random()<.4 then self:Puff(p,1,.3,.8,.35) end
        elseif e.type=="dry" then
            local p=At(e.pos,e.dir,.05);self:Flash(p,.3,.05,{1,1,1})
            self:Burst(p,5,3.5,e.kind=="mg" and {5,2.4,.8} or e.kind=='sniper' and RAIL.spark or LASER.spark,e.dir,.035,.22,6);self:Puff(p,1,.18,.7,.32)
        elseif e.type=='plateBreak' or e.type=='repair' or e.type=='heal' then SourceFx.Recovery(self,e)
        elseif e.type=="break" then
            self.chips:Break(e);self:Burst(e.pos,10,6,{5,2.6,.9},nil,.08,.4);self:Puff(e.pos,3,.45,1.1,.4)
        elseif e.type=="explode" then
            local radius=e.radius or 2
            self.light:Emit(e.pos,140)
            self:Flash(e.pos,radius*3.2,.2,SourceFx.Color(0xffa040));self:Burst(e.pos,46,12,{6,2.4,.6},nil,.14,.7)
            self:Puff(e.pos,16,radius*.8,2.2,.3)
        end
    end
end
function M:Path(points,width,color,alpha,core,arc,segments)
    local batch=self.batches.Ribbon
    if arc then
        if not self.batches.Arc then
            self.batches.Arc=Batch.New(self.root,'Ribbon',Quality.current.weaponArcSegments,'Shaders/BLGL/WeaponFx/')
            self.batches.Arc:Begin(self.camera,self.time)
        end
        batch=self.batches.Arc
    end
    local n=segments or #points-1
    for i=1,n do batch:Segment(points[i],points[i+1],width,color,alpha,core,(i-1)/n,i/n) end
end
function M:Helix(b,tip,len,radius,width,color,alpha,spin)
    local u,v=Basis(b.dir);local turns=len/1.1;local n=math.max(1,math.min(self.maxHelix,math.ceil(turns*14)))
    -- Reuse the sampled path. Each sample previously allocated the subtraction
    -- plus six temporary vectors before the batch copied it into its buffer.
    local pts=self.helixPoints or {};self.helixPoints=pts
    local dx,dy,dz=tip[1]-b.from[1],tip[2]-b.from[2],tip[3]-b.from[3]
    for i=0,n do
        local s=i/n;local a=s*turns*math.pi*2+b.phase+spin;local r=radius*math.min(1,s*len/.6)
        local cr,sr=math.cos(a)*r,math.sin(a)*r
        local p=pts[i+1] or {};pts[i+1]=p
        p[1]=((b.from[1]+dx*s)+u[1]*cr)+v[1]*sr
        p[2]=((b.from[2]+dy*s)+u[2]*cr)+v[2]*sr
        p[3]=((b.from[3]+dz*s)+u[3]*cr)+v[3]*sr
    end
    -- The cache can contain a longer previous path; submit only this sample count.
    self:Path(pts,width,color,alpha,.3,true,n)
end
function M:Update(dt,projectiles,camera)
    if self.disposed then return end
    self.time=self.time+dt
    self.chips:Update(dt)
    local p=camera.worldPosition;local cam={-p.x,p.y,p.z}
    self.camera=cam
    local x=camera.worldRotation*Vector3.RIGHT;local y=camera.worldRotation*Vector3.UP
    local right,up={-x.x,x.y,x.z},{-y.x,y.y,y.z}
    local b=self.batches
    for _,batch in pairs(b) do batch:Begin(cam,self.time) end
    local function Glow(pos,size,color,alpha) b.Glow:Disc(pos,size,color,alpha or 1,right,up) end
    for _,proj in ipairs(projectiles) do
        if proj.fx=="bolt" then
            SourceFx.Bolt(b.Streak,Glow,proj,BOLT)
        end
    end
    self.missiles:Update(dt,projectiles,Glow)
    Advance(self.flares,dt,function(f)
        local k=f.age/f.life;b.Streak:Segment(f.tip,f.base,f.width*(1-.3*k),f.color,1-k*k,.45,0,1,true,.95)
    end)
    Advance(self.trails,dt,function(e)
        local f=1-e.age/e.life;b.Ribbon:Segment(e.from,e.to,.5,RAIL.glow,f*f*.22*(.7+.3*math.random()),0)
        e.next=e.next-dt
        if e.next<=0 and f>.2 then
            e.next=.03+math.random()*.05
            local a=At(e.from,V.Sub(e.to,e.from),math.random())
            local u,v=Basis(e.dir);local angle=math.random()*math.pi*2;local length=.4+math.random()*.8
            local tip={}
            for i=1,3 do tip[i]=a[i]+(u[i]*math.cos(angle)+v[i]*math.sin(angle))*length*.6+e.dir[i]*(math.random()-.5)*length end
            Add(self.zaps,{a=a,b=tip,age=0,life=.08+math.random()*.08,width=.04},64)
        end
    end)
    Advance(self.beams,dt,function(e)
        local t=e.tier or 1;local rail=e.kind=="sniper";local f=math.min(1,e.age/e.grow);local fade=math.max(0,e.age-e.grow)/(e.life-e.grow)
        if f>=1 and not e.hitDone then e.hitDone=true;self:Hit(e) end
        local tip=At(e.from,V.Sub(e.to,e.from),f);local len=e.len*f
        if f<1 or fade<.15 then
            local a=f<1 and 1 or 1-fade/.15
            b.Streak:Segment(At(tip,e.dir,-math.min(len,rail and 3 or 1.6)),tip,rail and (.5+t*.08) or (.32+t*.05),rail and RAIL.core or LASER.flare,a,.5,0,1,true,.9)
            Glow(tip,(rail and (1.2+t*.15) or (.7+t*.1))*a,rail and RAIL.glow or LASER.glow,.6*a)
            Glow(tip,(rail and .4 or .25)*a+.05,{6,7,9},a)
        end
        if rail then
            b.Ribbon:Segment(e.from,tip,(.42+t*.08)*(1+fade*.7),RAIL.glow,(1-fade)^1.4*.65,0)
            b.Ribbon:Segment(e.from,tip,(.1+t*.02)*(1-fade*.5),RAIL.core,(1-fade)^3,.55)
            if t>=4 then self:Helix(e,tip,len,.15+fade*.35,.038+t*.005,RAIL.helix,(1-fade)^2,-3*self.time) end
        else
            local a=(1-fade)^1.5
            if t>=4 then b.Ribbon:Segment(e.from,tip,.7+(t-4)*.25,LASER.glow,a*.22,0) end
            b.Ribbon:Segment(e.from,tip,.24+t*.045,LASER.glow,a,.2)
            if t>=4 then self:Helix(e,tip,len,.09+(t-4)*.03,.03,LASER.helix,a*.8,40*self.time) end
        end
    end)
    Advance(self.zaps,dt,function(e)
        local u,v=Basis(V.Normalize(V.Sub(e.b,e.a)));local pts={}
        for i=0,8 do local s=i/8;local amp=.12*math.sin(math.pi*s)
            pts[#pts+1]=At(At(At(e.a,V.Sub(e.b,e.a),s),u,(math.random()*2-1)*amp),v,(math.random()*2-1)*amp) end
        local f=1-e.age/e.life;self:Path(pts,e.width*2.6,RAIL.glow,f*.6,0,true);self:Path(pts,e.width,RAIL.helix,f,.3,true)
    end)
    Advance(self.rings,dt,function(e)
        if e.age<e.delay then return end
        local t=(e.age-e.delay)/e.life;local r=e.r0+(e.r1-e.r0)*(1-(1-t)^2);local u,v=Basis(e.dir)
        b.Ring:Disc(e.pos,r*2,e.color,e.alpha*(1-t)^1.5,u,v,e.thick)
    end)
    Advance(self.flashes,dt,function(e) local t=e.age/e.life;b.Glow:Disc(e.pos,e.size*(.6+t*.6),e.color,1-t,right,up,nil,1) end)
    local function Particles(list,smoke)
        Advance(list,dt,function(e)
            local k=math.max(0,1-e.drag*dt)
            for i=1,3 do e.vel[i]=e.vel[i]*k end
            e.vel[2]=e.vel[2]-e.grav*dt
            for i=1,3 do e.pos[i]=e.pos[i]+e.vel[i]*dt end
            -- Point particles bounce 2 cm above the active map's visual ground.
            -- Smoke/weightless motes never sample or collide with this surface.
            if e.grav>0 then
                local floor=self.groundAt(e.pos[1],e.pos[3])+.02
                if e.pos[2]<floor then e.pos[2]=floor;e.vel[2]=e.vel[2]*-.3 end
            end
            e.size=e.size+(e.grow or 0)*dt;local t=e.age/e.life
            if smoke then b.Smoke:Disc(e.pos,e.size,e.color,math.min(1,t*6)*(1-t),right,up)
            else b.Glow:Disc(e.pos,e.size,e.color,1-t*t,right,up,nil,1) end
        end)
    end
    Particles(self.particles,false);Particles(self.smoke,true)
    self.light:Update(dt)
    for _,batch in pairs(b) do batch:Finish() end
end
function M:Dispose()
    if self.disposed then return end
    self.disposed=true;self:Clear()
    self.chips:Dispose()
    self.missiles:Dispose()
    self.light:Dispose()
    for _,batch in pairs(self.batches) do batch:Dispose() end
    self.root:Dispose()
    self.groundAt=nil
end
return M

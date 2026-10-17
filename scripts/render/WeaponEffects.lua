-- Source weaponRig persistent FX. One lazily allocated set of bounded batches per
-- vehicle, in world metres; transforms follow the final aimed/recoiling head.
local Config=require("Config")

local V=require 'core.Math3'
local Coord=require 'core.Coord'
local Batch=require 'render.EffectBatch'
local Q=require('render.Quality').current
local M={};M.__index=M
local TAU=math.pi*2
local function Smooth(x) x=V.Clamp(x,0,1);return x*x*(3-2*x) end
local function Source(p) return {-p.x,p.y,p.z} end
local function World(head,p) return Source(head:LocalToWorld(Coord.Vec(table.unpack(p)))) end
local function Random(item)
    if item.random then return item.random() end
    item.seed=(item.seed*48271)%2147483647;return item.seed/2147483647
end
local function NewMote(item,axis,life)
    local function R() return Random(item) end
    return {axis=axis,a=R()*TAU,r0=.5+R()*.3,z=item.z0+R()*(item.z1-item.z0),v=.25+R()*.45,
        w=(R()<.5 and -1 or 1)*(.8+R()*1.6),s=.05+R()*.05,ph=R()*6.28,life=life,dur=.5+R()*.6}
end
function M.New(view,random)
    return setmetatable({view=view,items={},batches={},disposed=false,random=random,visible=true},M)
end
function M:SetVisible(visible)
    self.visible=visible==true
    for _,b in pairs(self.batches) do b.mesh.enabled=self.visible and b.count>0 end
end
function M:Batch(kind)
    local b=self.batches[kind]
    if not b then
        if not self.root then self.root=self.view.root:GetScene():CreateChild('WeaponEffects') end
        local limits={Glow=Q.weaponMotes,Band=64,Swirl=Q.weaponSwirlSegments*16,Ribbon=Q.weaponArcSegments}
        b=Batch.New(self.root,kind,limits[kind],'Shaders/BLGL/WeaponFx/');self.batches[kind]=b
        b:Begin(self.camera,self.time)
    end
    return b
end
function M:Item(id,vis)
    local old=self.items[id];if old and old.vis==vis then return old end
    local m=vis.weaponMotion;local g=vis.data.weapon
    local item={vis=vis,random=self.random,seed=math.max(1,math.floor(vis.variation*2147483646)),motes={},bands={},arcs={},arcTimer=0}
    item.z0=g.pivot[3]+(m.kind=='sniper' and .6 or .9);item.z1=g.muzzle[3]-.15
    item.rail=(m.tier==5 and .31 or m.tier==4 and .32 or m.tier==3 and .21 or .15)*m.scale[1]
    item.angles=m.tier==5 and {90,210,330} or {45,135,225,315}
    local axes=g.muzzles or {g.muzzle}
    if m.big and m.kind~='mg' then
        local count=Q.name=='mobile' and (m.tier==5 and 24 or 16) or (m.tier==5 and 56 or 36)
        for i=1,count do item.motes[i]=NewMote(item,axes[(i-1)%#axes+1],Random(item)) end
    end
    if m.big and m.kind=='laser' then
        local coils=m.parts.coils or {};local r=.3;local z0=g.pivot[3]
        if #coils>0 then
            local c=coils[1].definition;r=(c.max[2]-c.min[2])*.5+.06;z0=math.huge
            for _,p in ipairs(coils) do z0=math.min(z0,p.definition.min[3]-.2) end
        end
        for _,a in ipairs(axes) do for i=1,m.tier==5 and 2 or 1 do
            item.bands[#item.bands+1]={axis=a,phase=(i-1)*.5+(a[1]>0 and .25 or 0),z0=z0,z1=g.muzzle[3]-.05,r=r}
        end end
    end
    self.items[id]=item;return item
end
function M:Bands(item,dt,m,head,scale)
    if #item.bands==0 then return end
    local batch=self:Batch('Band');local r=Source(head.worldRotation*Vector3.LEFT);local u=Source(head.worldRotation*Vector3.UP)
    for _,band in ipairs(item.bands) do
        band.phase=(band.phase+dt*(.45+m.load*1.6)*m.power)%1;local f=band.phase
        local alpha=math.sin(f*math.pi)*(.55+.6*m.load)*m.power
        batch:Disc(World(head,{band.axis[1],band.axis[2],band.z0+(band.z1-band.z0)*f}),2*band.r*(1-.25*f)*scale,
            {.25,.9,3.2},1,r,u,alpha)
    end
end
function M:Motes(item,dt,m,head,scale)
    if #item.motes==0 then return end
    local batch=self:Batch('Glow');local suck=m.kind=='sniper'
    local energy=suck and ((m.charge<1 and 1.4 or .35)+m.windup*3) or 1+m.load*2.5
    for i,particle in ipairs(item.motes) do
        local r,alpha,size
        if suck then
            particle.life=particle.life+dt*energy/particle.dur
            if particle.life>=1 then particle=NewMote(item,particle.axis,0);item.motes[i]=particle end
            local f=Smooth(particle.life);r=particle.r0+.3-(particle.r0+.3-item.rail)*f
            particle.a=particle.a+dt*particle.w*.6
            alpha=math.sin(particle.life*math.pi)*((m.charge<1 or m.windup>0) and 1 or .35)
            size=particle.s*(.6+.6*f)
        else
            particle.z=particle.z+particle.v*dt*energy;particle.a=particle.a+particle.w*dt*energy
            if particle.z>item.z1 then particle.z=item.z0;particle.r0=.5+Random(item)*.3 end
            local f=(particle.z-item.z0)/math.max(.00001,item.z1-item.z0);r=particle.r0*(1-.45*f)
            alpha=math.sin(f*math.pi)*(.55+.45*math.sin(self.time*7+particle.ph))*(.75+m.load*.7)
            size=particle.s*(1+m.load*.6)
        end
        local p=World(head,{particle.axis[1]+math.cos(particle.a)*r,particle.axis[2]+math.sin(particle.a)*r,particle.z})
        -- Match source point size: .9 * viewportHeight / viewDepth, minimum 1 px.
        local depth=math.max(.001,V.Dot(V.Sub(p,self.camera),self.forward))
        local diameter=math.max(size*scale*.9*self.projection,depth*self.projection/self.height)
        batch:Disc(p,diameter,suck and {1.4,2.4,4.8} or {.55,1.5,4.5},1,self.right,self.up,alpha*m.power)
    end
end
function M:Swirl(item,dt,m,head)
    if not m.big or m.kind~='mg' then return end
    local v=Smooth((m.spinV-.88)/.12);if v<=.01 then return end
    local batch=self:Batch('Swirl');local r=(m.tier==5 and .46 or .38)*m.scale[1];local h=.9*m.scale[3]
    local center=m:Muzzle(-.42);local spin=-self.time*9;local c,s=math.cos(spin),math.sin(spin)
    local alpha=v*(.7+.3*math.sin(self.time*31))*(m.tier==5 and 1.25 or 1)
    local function Point(u,top)
        local theta=u*TAU;local radius=r*(top and 1.35 or 1);local x,y=math.sin(theta)*radius,-math.cos(theta)*radius
        return World(head,{center[1]+x*c-y*s,center[2]+x*s+y*c,center[3]+(top and .5 or -.5)*h})
    end
    for i=1,Q.weaponSwirlSegments do local a,b=(i-1)/Q.weaponSwirlSegments,i/Q.weaponSwirlSegments
        batch:Quad({Point(a,false),Point(b,false),Point(a,true),Point(b,true)},{{a,0},{b,0},{a,1},{b,1}},{3.4,1.4,.35},1,{alpha,0,0})
    end
    if m.tier==5 and v>.5 and Random(item)<dt*14 and self.emitter then
        self.emitter:EquipmentEmit('spark',World(head,m:Muzzle(-.2-Random(item)*.4)),self.view)
    end
end
function M:SpawnArc(item,m)
    if #item.arcs>=Q.weaponArcsPerRig then return end
    local function R() return Random(item) end
    local g=m.data.weapon;local z0,z1=g.pivot[3]+.8,g.muzzle[3]-.12;local z=z0+R()*(z1-z0)
    local a0=item.angles[math.floor(R()*#item.angles)+1];local across=R()<.75
    local a1=across and a0+360/#item.angles*(R()<.5 and -1 or 1) or a0
    local zb=across and z+(R()-.5)*.25 or math.min(z1,z+.3+R()*.5)
    item.arcs[#item.arcs+1]={a0=a0*math.pi/180,a1=a1*math.pi/180,za=z,zb=zb,
        life=(m.windup>0 and .05 or .08)+R()*.08,age=0,amp=.05+R()*.05,w=m.windup>0 and .09 or .065}
end
function M:Path(head,points,width,color,alpha,core,scale)
    local batch=self:Batch('Ribbon');local a=World(head,points[1]);local n=#points-1
    -- T5 channel intensity can exceed 1; UNORM alpha must not clamp its HDR gain.
    local radiance=V.Scale(color,alpha)
    for i=1,n do local b=World(head,points[i+1]);batch:Segment(a,b,width*scale,radiance,1,core,(i-1)/n,i/n);a=b end
end
function M:Arcs(item,dt,m,head,scale)
    if not m.big or m.kind~='sniper' then return end
    local rate=m.offline and 0 or m.windup>0 and 40 or m.charge<1 and 3+m.charge*4 or m.tier==5 and 3 or 2
    -- Never accumulate a backlog while offscreen/offline. Limit work after stalls.
    item.arcTimer=rate==0 and 0 or item.arcTimer-dt
    local spawns=0
    while rate>0 and item.arcTimer<=0 and spawns<4 do
        self:SpawnArc(item,m);if m.windup>.5 then self:SpawnArc(item,m) end
        item.arcTimer=item.arcTimer-math.log(math.max(.000001,1-Random(item)))/rate;spawns=spawns+1
    end
    if spawns==4 then item.arcTimer=math.max(0,item.arcTimer) end
    local g=m.data.weapon;local alive={}
    for _,arc in ipairs(item.arcs) do
        arc.age=arc.age+dt
        if arc.age<arc.life then
            alive[#alive+1]=arc;local points={}
            for k=0,8 do
                local u=k/8;local bell=math.sin(u*math.pi)
                local angle=arc.a0+(arc.a1-arc.a0)*u+(Random(item)-.5)*bell*.25
                local radius=item.rail+bell*arc.amp*(.3+Random(item))
                points[#points+1]={g.muzzle[1]+math.cos(angle)*radius,g.muzzle[2]+math.sin(angle)*radius,
                    arc.za+(arc.zb-arc.za)*u+(Random(item)-.5)*bell*arc.amp}
            end
            local f=1-arc.age/arc.life
            self:Path(head,points,arc.w*2.6,{.7,1.7,5.5},f*.6,0,scale)
            self:Path(head,points,arc.w,{.7,1.7,5.5},f,.28,scale)
        end
    end
    item.arcs=alive
    if m.tier==5 and not m.offline and m.charge>.6 then
        local alpha=(m.charge-.6)/.4*(.35+m.windup*.9)*(.55+.45*Random(item));local points={};local z0=g.pivot[3]+.3
        for k=0,10 do points[#points+1]={g.muzzle[1]+(Random(item)-.5)*.02,g.muzzle[2]+(Random(item)-.5)*.02,z0+(g.muzzle[3]-z0)*k/10} end
        self:Path(head,points,.16+m.windup*.14,{.7,1.7,5.5},alpha*.5,0,scale)
        self:Path(head,points,.05+m.windup*.04,{2.4,3.2,5},alpha,.4,scale)
    end
end
function M:Update(dt,context,emitter)
    if self.disposed or not context or not context.camera then return end
    local camera=context.camera;self.camera=Source(camera.worldPosition);self.time=context.time or 0;self.emitter=emitter
    self.right=Source(camera.worldRotation*Vector3.RIGHT);self.up=Source(camera.worldRotation*Vector3.UP)
    self.forward=Source(camera.worldRotation*Vector3.FORWARD);self.projection=2*math.tan((context.fov or 60)*math.pi/360)
    self.height=math.max(1,graphics:GetHeight());dt=V.Clamp(dt,0,.1)
    for _,b in pairs(self.batches) do b:Begin(self.camera,self.time) end
    local candidates={}
    for id,vis in pairs(self.view.visuals) do if vis.weaponMotion then
        local d=(vis.node.worldPosition-camera.worldPosition):Length()
        if d<Q.equipmentFar then candidates[#candidates+1]={id=id,vis=vis,d=d} end
    end end
    table.sort(candidates,function(a,b) return a.d==b.d and a.id<b.id or a.d<b.d end)
    local retained={}
    for i,c in ipairs(candidates) do if i<=Q.weaponFxRigs then
        local item=self:Item(c.id,c.vis);retained[c.id]=item
        local m=c.vis.weaponMotion;local head=c.vis.head;local scale=head.worldScale.x
        self:Bands(item,dt,m,head,scale);self:Swirl(item,dt,m,head);self:Arcs(item,dt,m,head,scale)
        if c.d<Q.equipmentLod then self:Motes(item,dt,m,head,scale) end
        if m.orb and m.orb.alpha>.004 then
            local color=Config.HexLinear(0xd8f0ff)
            self:Batch('Glow'):Disc(World(head,m.data.weapon.muzzle),m.orb.size*scale,{color.r,color.g,color.b},1,self.right,self.up,m.orb.alpha)
        end
    end end
    self.items=retained
    for _,b in pairs(self.batches) do b:Finish();if not self.visible then b.mesh.enabled=false end end
end
function M:Reset()
    self.items={};for _,b in pairs(self.batches) do b.count=0;b.mesh.enabled=false end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    for _,b in pairs(self.batches) do b:Dispose() end
    if self.root then self.root:Dispose() end
    self.items={};self.batches={}
end
return M

-- Original crater smoke origins, wind, lifetime and dust-devil motion.
-- Fixed billboard pools: no per-frame node/material allocation.
local CraterDust=require("render.CraterDust")
local CraterShield=require("render.CraterShield")

local Coord=require 'core.Coord'
local M={};M.__index=M
local windX,windZ=.9161573349,.400818834
local puffCorners={{-1,-1,0,0},{1,-1,1,0},{-1,1,0,1},{-1,1,0,1},{1,-1,1,0},{1,1,1,1}}
local origins={{-160,16,0,1.6,4.5,.85},{-158,12,21,.8,3.2,.7},{94,52,92,1.1,4,.6}}
-- Three PointLight intensity is candela. Native point lights already use
-- inverse-square attenuation; dividing intensity by 100 darkened the interior.
local lamps={{95,14,0,1400,0xffd2a0},{25,14,0,1400,0xffd2a0},{-45,14,0,1400,0xffd2a0},{-110,14,0,1400,0xffd2a0},
    {0,15.5,-279,160,0xe6f2ff},{0,15.5,279,160,0xffd8d0}}
local function LinearColor(hex)
    local function Channel(v) v=v/255;return v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end
    return Color(Channel((hex>>16)&255),Channel((hex>>8)&255),Channel(hex&255))
end
local function Batch(root,name,count,color)
    local node=root:CreateChild(name);local batch=node:CreateComponent('CustomGeometry');batch.dynamic=true
    local mat=Material:new();assert(mat:SetSurfaceShader('Shaders/BLGL/Crater/Puff.shader'));mat:SetShaderParameter('uColor',Variant(Vector3(table.unpack(color))));mat.renderOrder=140;batch.material=mat
    return {node=node,batch=batch,material=mat}
end
function M.New(scene,layout,options)
    options=options or {}
    local self=setmetatable({root=scene:CreateChild('CraterAtmosphere'),parts={},acc={0,0,0},layout=layout,devils={},shields={},options=options,origins=options.origins or origins,area=options.area or 270,limit=options.limit or 300},M)
    self.smoke=Batch(self.root,'ShipSmoke',420,{.042,.033,.027})
    self.dust=Batch(self.root,'DustDevils',104,{.522,.417,.288})
    self.air=CraterDust.New(self.root,self)
    for i=1,4 do local d={seed=math.random()};self:SpawnDevil(d);d.age=math.random()*d.life;self.devils[i]=d end
    for i,b in ipairs(options.noShields and {} or {layout.base,layout.enemyBase}) do
        self.shields[i]=CraterShield.New(self.root,b.shield,i==1 and 'own' or 'enemy')
    end
    for _,p in ipairs(options.noLamps and {} or lamps) do
        local n=self.root:CreateChild('InteriorLamp');n.position=Coord.Vec(p[1],p[2],p[3])
        local l=n:CreateComponent('Light');l.lightType=LIGHT_POINT;l.range=90
        l.useTemperature=false;l.color=LinearColor(p[5]);l.brightness=p[4];l.castShadows=false
    end
    for i=1,200 do self:Smoke(.1) end
    return self
end
function M:Height(x,z)
    local h=self.layout.terrain;local n=h.n;local u=math.max(0,math.min(n,(x/h.size+.5)*n));local v=math.max(0,math.min(n,(z/h.size+.5)*n))
    local i,j=math.min(n-1,math.floor(u)),math.min(n-1,math.floor(v));local a,b=u-i,v-j
    local p=h.heights;local k=i*(n+1)+j+1
    return (p[k]*(1-b)+p[k+1]*b)*(1-a)+(p[k+n+1]*(1-b)+p[k+n+2]*b)*a
end
function M:SpawnDevil(d)
    for i=1,40 do
        local x,z=(math.random()*2-1)*self.area,(math.random()*2-1)*self.area
        if self.air:Flat(x,z,.96) and not self.air:Blocked(x,z,20) and (not self.options.allowed or self.options.allowed(x,z)) then
            d.x=x;d.z=z;d.age=0;d.life=35+math.random()*30;d.h=18+math.random()*22;d.r=1.5+math.random()*1.5
            d.vx=windX*(2+math.random()*2)+(math.random()-.5);d.vz=windZ*(2+math.random()*2)+(math.random()-.5);return
        end
    end
    d.x=d.x or 0;d.z=d.z or 0;d.age=0;d.life=1;d.h=d.h or 18;d.r=d.r or 1.5;d.vx=0;d.vz=0
end
function M:Smoke(dt)
    for i,o in ipairs(self.origins) do
        self.acc[i]=self.acc[i]+dt*o[4]
        while self.acc[i]>1 and #self.parts<420 do
            self.acc[i]=self.acc[i]-1
            self.parts[#self.parts+1]={x=o[1]+(math.random()-.5)*o[5],y=o[2],z=o[3]+(math.random()-.5)*o[5],vx=(math.random()-.5)*.8,vy=3.2+math.random()*1.8,vz=(math.random()-.5)*.8,r=o[5]*(.7+math.random()*.5),age=0,life=16+math.random()*8,seed=math.random(),dark=o[6],rot=math.random()*360}
        end
    end
    for i=#self.parts,1,-1 do
        local p=self.parts[i];p.age=p.age+dt
        if p.age>p.life then table.remove(self.parts,i)
        else p.vx=p.vx+windX*dt*.9;p.vz=p.vz+windZ*dt*.9;p.vy=p.vy*(1-dt*.08);p.x=p.x+p.vx*dt;p.y=p.y+p.vy*dt;p.z=p.z+p.vz*dt end
    end
end
local function Puff(b,rightAxis,upAxis,x,y,z,r,alpha,seed,brightness,rotation)
    local center=Coord.Vec(x,y,z);local angle=rotation*math.pi/180
    local right=rightAxis*math.cos(angle)+upAxis*math.sin(angle)
    local up=upAxis*math.cos(angle)-rightAxis*math.sin(angle)
    for _,p in ipairs(puffCorners) do
        b:DefineVertex(center+right*(p[1]*r)+up*(p[2]*r));b:DefineNormal(Vector3.UP);b:DefineTexCoord(Vector2(p[3],p[4]));b:DefineColor(Color(seed%1,math.min(1,brightness),1,alpha))
    end
end
function M:Update(dt,t,camera)
    self:Smoke(math.min(dt,.1));self.smoke.material:SetShaderParameter('uTime',Variant(t));self.dust.material:SetShaderParameter('uTime',Variant(t))
    local right=camera.rotation*Vector3.RIGHT;local up=camera.rotation*Vector3.UP
    self.smoke.batch:BeginGeometry(0,TRIANGLE_LIST);self.dust.batch:BeginGeometry(0,TRIANGLE_LIST)
    for i,p in ipairs(self.parts) do local k=p.age/p.life;Puff(self.smoke.batch,right,up,p.x,p.y,p.z,p.r*(1+k*3.2),math.min(1,p.age/1.5)*(1-k)^1.4*(.35+.4*p.dark),p.seed,.85+.6*(1-p.dark)*k,p.rot+p.age*4.58) end
    self.smoke.batch:Commit()
    for i,d in ipairs(self.devils) do
        d.age=d.age+dt;d.x=d.x+d.vx*dt;d.z=d.z+d.vz*dt
        if d.age>d.life or math.abs(d.x)>self.limit or math.abs(d.z)>self.limit then self:SpawnDevil(d) end
        local x,z=d.x,d.z;local ground=self:Height(x,z);local life=math.min(1,d.age/5)*math.min(1,(d.life-d.age)/6)
        for j=0,25 do local f=j/26;local a=t*(2.4-f)+j*2.399+d.seed*10;local r=d.r*(1+f*4.5);local lean=f*f*6
            Puff(self.dust.batch,right,up,x+math.cos(a)*r*.6+windX*lean,ground+f*d.h+.8,z+math.sin(a)*r*.6+windZ*lean,r*.9+1.2,life*.16*(1-f)^.8*math.min(1,f/.08),d.seed+j*.37,1.05,a*180/math.pi)
        end
    end
    self.dust.batch:Commit();for _,shield in ipairs(self.shields) do shield:Update(t) end
    self.air:Update(t,camera)
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.air then self.air:Dispose();self.air=nil end
    for _,shield in ipairs(self.shields) do shield:Dispose() end
    self.root:Dispose();self.smoke.material:Dispose();self.dust.material:Dispose()
    self.root=nil;self.smoke=nil;self.dust=nil;self.layout=nil;self.options=nil
    self.parts={};self.shields={};self.devils={}
end
return M

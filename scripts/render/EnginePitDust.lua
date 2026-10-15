-- Frozen airFx.buildSmoke, independent bounded pool for the eight deck origins.
local Coord=require 'core.Coord'
local M={};M.__index=M
local corners={{-1,-1,0,0},{1,-1,1,0},{-1,1,0,1},{-1,1,0,1},{1,-1,1,0},{1,1,1,1}}
local wx,wz=.8/math.sqrt(.8*.8+.35*.35),.35/math.sqrt(.8*.8+.35*.35)
local function Smooth(a,b,x) local k=math.max(0,math.min(1,(x-a)/(b-a)));return k*k*(3-2*k) end
function M.New(scene,deck,random)
    local self=setmetatable({},M);self:init(scene,deck,random);return self
end
function M:init(scene,deck,random)
    self.parts={};self.origins={};self.acc={};self.random=random or math.random
    local c,s=math.cos(deck.yaw),math.sin(deck.yaw)
    for k=0,7 do local a=k*math.pi/4;local u,v=math.cos(a)*22,math.sin(a)*22
        self.origins[k+1]={pos={deck.center[1]+u*c-v*s,deck.top-1,deck.center[3]-u*s-v*c},rate=0,size=6,dark=.1};self.acc[k+1]=0
    end
    self.node=scene:CreateChild('EnginePitDeckDust');self.batch=self.node:CreateComponent('CustomGeometry');self.batch.dynamic=true;self.batch.enabled=false
    self.material=Material:new();assert(self.material:SetSurfaceShader('Shaders/BLGL/EnginePit/DeckDust.shader'));self.material.renderOrder=140;self.batch.material=self.material
end
function M:SetRate(rate) for _,o in ipairs(self.origins) do o.rate=rate end end
function M:Step(dt)
    local rnd=self.random
    for i,o in ipairs(self.origins) do self.acc[i]=self.acc[i]+dt*o.rate
        while self.acc[i]>1 and #self.parts<420 do self.acc[i]=self.acc[i]-1
            self.parts[#self.parts+1]={x=o.pos[1]+(rnd()-.5)*o.size,y=o.pos[2],z=o.pos[3]+(rnd()-.5)*o.size,
                vx=(rnd()-.5)*.8,vy=3.2+rnd()*1.8,vz=(rnd()-.5)*.8,r=o.size*(.7+rnd()*.5),age=0,life=16+rnd()*8,seed=rnd(),dark=o.dark,rot=rnd()*6.28}
        end
    end
    for i=#self.parts,1,-1 do local p=self.parts[i];p.age=p.age+dt
        if p.age>p.life then table.remove(self.parts,i)
        else p.vx=p.vx+wx*dt*.9;p.vz=p.vz+wz*dt*.9;p.vy=p.vy*(1-dt*.08);p.x=p.x+p.vx*dt;p.y=p.y+p.vy*dt;p.z=p.z+p.vz*dt end
    end
end
function M:Update(dt,time,camera)
    self:Step(dt);self.batch.enabled=#self.parts>0;if #self.parts==0 then return end
    self.material:SetShaderParameter('uTime',Variant(time));self.batch:BeginGeometry(0,TRIANGLE_LIST)
    local right=camera.rotation*Vector3.RIGHT;local up=camera.rotation*Vector3.UP
    for i=#self.parts,1,-1 do local p=self.parts[i];local k=p.age/p.life;local r=p.r*(1+k*3.2);local angle=p.rot+p.age*.08
        local center=Coord.Vec(p.x,p.y,p.z);local d=(center-camera.position).length
        local fade=Smooth(r*.6,r*2.2,d)*(1-Smooth(900,1400,d));local alpha=math.min(1,p.age/1.5)*(1-k)^1.4*(.35+.4*p.dark)
        local color=Color(p.seed,(.85+.6*(1-p.dark)*k)/2,fade,alpha)
        -- X handedness reflection reverses the original on-screen sprite rotation.
        local rx=right*math.cos(angle)-up*math.sin(angle);local uy=up*math.cos(angle)+right*math.sin(angle)
        for _,v in ipairs(corners) do self.batch:DefineVertex(center+rx*(v[1]*r)+uy*(v[2]*r));self.batch:DefineNormal(Vector3.UP);self.batch:DefineTexCoord(Vector2(v[3],v[4]));self.batch:DefineColor(color) end
    end
    self.batch:Commit()
end
function M:Dispose() self.node:Dispose();self.material:Dispose();self.parts={} end
return M

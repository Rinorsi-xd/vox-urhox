-- Source ZoneMarker/Reactor/RouteLine, shared bounded geometry at 10 Hz.
local Coord=require 'core.Coord'
local M={};M.__index=M
local colors={none={.85,.87,.89},blue={.18,.66,1},red={1,.29,.24},contest={1,.42,.075},push={.44,.83,.44}}
function M.New(world,mode)
    local self=setmetatable({world=world,mode=mode,age=0,nextUpdate=0},M)
    self.root=world.scene:CreateChild('BattleObjectives');self.mesh=self.root:CreateComponent('CustomGeometry');self.mesh.dynamic=true;self.mesh.castShadows=false
    self.material=Material:new();assert(self.material:SetSurfaceShader('Shaders/BLGL/Combat/Objective.shader'));self.material.renderOrder=144;self.mesh.material=self.material
    return self
end
function M:Vertex(x,y,z,color,alpha)
    self.mesh:DefineVertex(Coord.Vec(x,y,z));self.mesh:DefineNormal(Vector3.UP);self.mesh:DefineColor(Color(color[1],color[2],color[3],alpha))
end
function M:Ring(pos,inner,outer,start,span,color,alpha)
    local n=math.max(1,math.ceil(span/math.pi*24))
    for i=0,n-1 do
        local a,b=start+span*i/n,start+span*(i+1)/n
        local function V(angle,r) self:Vertex(pos[1]+math.cos(angle)*r,pos[2],pos[3]+math.sin(angle)*r,color,alpha) end
        V(a,inner);V(a,outer);V(b,outer);V(a,inner);V(b,outer);V(b,inner)
    end
end
function M:Beam(pos,r0,r1,height,color,alpha)
    for i=0,15 do local a,b=i/16*math.pi*2,(i+1)/16*math.pi*2
        local function V(angle,r,y) self:Vertex(pos[1]+math.cos(angle)*r,pos[2]+y,pos[3]+math.sin(angle)*r,color,alpha) end
        V(a,r0,0);V(b,r0,0);V(b,r1,height);V(a,r0,0);V(b,r1,height);V(a,r1,height)
    end
end
function M:Crystal(pos,color,alpha)
    for _,s in ipairs({-1,1}) do for i=0,3 do local a,b=i*math.pi/2,(i+1)*math.pi/2
        self:Vertex(pos[1],pos[2]+s*1.12,pos[3],color,alpha)
        self:Vertex(pos[1]+math.cos(a)*.56,pos[2],pos[3]+math.sin(a)*.56,color,alpha)
        self:Vertex(pos[1]+math.cos(b)*.56,pos[2],pos[3]+math.sin(b)*.56,color,alpha)
    end end
end
function M:Update(dt,rule,camera)
    self.age=self.age+dt;if self.age<self.nextUpdate then return end;self.nextUpdate=self.age+.1
    self.mesh:BeginGeometry(0,TRIANGLE_LIST);local t=self.age
    if self.mode.id=='conquest' then
        for i,p in ipairs(self.mode.points) do local st=rule.points[i]
            local c=colors[st.contested and 'contest' or st.owner or 'none'];local pos={p.pos[1],p.pos[2]+.25,p.pos[3]}
            self:Ring(pos,15.4,16,0,math.pi*2,c,.7+.2*math.sin(t*4))
            local near=camera and (camera.position-Coord.Vec(table.unpack(pos))):Length() or 99;local far=math.max(0,math.min(1,(near-35)/60))
            self:Ring(pos,0,15.4,0,math.pi*2,c,.03+.07*far);self:Beam(pos,1.8,1.2,90,c,(.16+.08*math.sin(t*3))*far)
            for seg=0,2 do
                local a=math.pi/2-seg*math.pi*2/3-.06;local length=math.pi*2/3-.12
                self:Ring(pos,13,15,a-length,length,{0,0,0},.25)
                local f=math.max(0,math.min(1,math.abs(st.v)*3-seg))
                if f>.002 then self:Ring(pos,13,15,a-length*f,length*f,colors[st.v>=0 and 'blue' or 'red'],.95) end
            end
        end
        for _,team in ipairs({'blue','red'}) do local base=self.mode.bases[team];local center=base.aim
            local c=colors[not rule.shield[team] and 'red' or team]
            for i=0,math.ceil(rule.score[team]/5)-1 do local ring=i<10 and 0 or 1;local a=i%10/10*math.pi*2+ring*.31+t*.12
                self:Crystal({center[1]+math.cos(a)*(2.2+ring*.8),center[2]+ring*1.6-.8,center[3]+math.sin(a)*(2.2+ring*.8)},c,.95)
            end
            self:Beam({center[1],center[2]-2.5,center[3]},.5,.5,5,c,.35)
        end
    else
        for i=2,#self.mode.path do local a,b=self.mode.path[i-1],self.mode.path[i];local dx,dz=b[1]-a[1],b[3]-a[3];local len=math.sqrt(dx*dx+dz*dz)
            if len>.01 then local sx,sz=-dz/len*.12,dx/len*.12;local c=colors.push
                self:Vertex(a[1]+sx,a[2]+.2,a[3]+sz,c,.5);self:Vertex(a[1]-sx,a[2]+.2,a[3]-sz,c,.5);self:Vertex(b[1]-sx,b[2]+.2,b[3]-sz,c,.5)
                self:Vertex(a[1]+sx,a[2]+.2,a[3]+sz,c,.5);self:Vertex(b[1]-sx,b[2]+.2,b[3]-sz,c,.5);self:Vertex(b[1]+sx,b[2]+.2,b[3]+sz,c,.5)
            end
        end
        for _,k in ipairs(self.mode.tuning.checkpoints) do local p=self.mode:At(k*self.mode.length).pos;self:Ring({p[1],p[2]+.3,p[3]},6.5,7,0,math.pi*2,colors.none,.7) end
        local p=self.mode:At(rule.s).pos
        self:Ring({p[1],p[2]+.3,p[3]},21.3,22,0,math.pi*2,colors[rule.contested and 'contest' or rule.idle>=8 and 'red' or rule.pushing>0 and 'push' or 'none'],.35+.2*math.sin(t*5))
    end
    self.mesh:Commit()
end
function M:Dispose() self.root:Dispose();self.material:Dispose() end
return M

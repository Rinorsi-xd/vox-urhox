-- Source ZoneMarker/Reactor/RouteLine, shared bounded geometry at 10 Hz.
local ObjectiveRoute=require("render.ObjectiveRoute")

local Coord=require 'core.Coord'
local M={};M.__index=M
local function Hex(n)
    local function Linear(v) v=v/255;return v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end
    return {Linear((n>>16)&255),Linear((n>>8)&255),Linear(n&255)}
end
local colors={none=Hex(0xd8dde3),blue=Hex(0x2ea8ff),red=Hex(0xff4a3d),contest=Hex(0xff6a13),push=Hex(0x6fd36f),white={1,1,1}}
function M.Geometry(scene)
    local self=setmetatable({age=0,nextUpdate=0,culled={},reactorFlash={},reactorRandomState=1},M)
    self.root=scene:CreateChild('BattleObjectives');self.materials={};self.batches={}
    for i,shader in ipairs({'Objective','ObjectiveOverlay'}) do
        local m=Material:new();assert(m:SetSurfaceShader('Shaders/BLGL/Combat/'..shader..'.shader'));m.renderOrder=144;self.materials[i]=m
    end
    return self
end
function M.New(world,mode)
    local self=M.Geometry(world.scene);self.world=world;self.mode=mode
    if mode.id~='conquest' then self.route=ObjectiveRoute.New(self.root,mode,self.materials[1],colors.contest) end
    return self
end
function M:Begin(name,pos,overlay)
    local batch=self.batches[name]
    if not batch then
        local node=self.root:CreateChild(name);local mesh=node:CreateComponent('CustomGeometry')
        mesh.dynamic=true;mesh.castShadows=false;mesh.occluder=false;mesh.material=self.materials[overlay and 2 or 1]
        batch={node=node,mesh=mesh};self.batches[name]=batch
    end
    batch.node.position=Coord.Vec(table.unpack(pos));self.origin=pos;self.mesh=batch.mesh;self.mesh:BeginGeometry(0,TRIANGLE_LIST)
end
function M:Vertex(x,y,z,color,alpha)
    local o=self.origin
    self.mesh:DefineVertex(Coord.Vec(x-o[1],y-o[2],z-o[3]));self.mesh:DefineNormal(Vector3.UP);self.mesh:DefineColor(Color(color[1],color[2],color[3],alpha))
end
local function Emit(mesh,origin,x,y,z,normal,color)
    mesh:DefineVertex(Coord.Vec(x-origin[1],y-origin[2],z-origin[3]));mesh:DefineNormal(normal);mesh:DefineColor(color)
end
function M:Ring(pos,inner,outer,start,span,color,alpha,segments)
    local n=segments or math.max(1,math.ceil(span/math.pi*48))
    local mesh,origin,normal=self.mesh,self.origin,Vector3.UP
    local rgba=Color(color[1],color[2],color[3],alpha)
    for i=0,n-1 do
        local a,b=start+span*i/n,start+span*(i+1)/n
        local ca,sa,cb,sb=math.cos(a),math.sin(a),math.cos(b),math.sin(b)
        local aiX,aiZ=pos[1]+ca*inner,pos[3]-sa*inner
        local aoX,aoZ=pos[1]+ca*outer,pos[3]-sa*outer
        local biX,biZ=pos[1]+cb*inner,pos[3]-sb*inner
        local boX,boZ=pos[1]+cb*outer,pos[3]-sb*outer
        Emit(mesh,origin,aiX,pos[2],aiZ,normal,rgba);Emit(mesh,origin,aoX,pos[2],aoZ,normal,rgba);Emit(mesh,origin,boX,pos[2],boZ,normal,rgba)
        Emit(mesh,origin,aiX,pos[2],aiZ,normal,rgba);Emit(mesh,origin,boX,pos[2],boZ,normal,rgba);Emit(mesh,origin,biX,pos[2],biZ,normal,rgba)
    end
end
function M:Beam(pos,r0,r1,height,color,alpha,segments)
    local n=segments or 16
    local mesh,origin,normal=self.mesh,self.origin,Vector3.UP
    local rgba=Color(color[1],color[2],color[3],alpha)
    for i=0,n-1 do local a,b=i/n*math.pi*2,(i+1)/n*math.pi*2
        local ca,sa,cb,sb=math.cos(a),math.sin(a),math.cos(b),math.sin(b)
        local a0X,a0Z=pos[1]+ca*r0,pos[3]+sa*r0
        local b0X,b0Z=pos[1]+cb*r0,pos[3]+sb*r0
        local a1X,a1Z=pos[1]+ca*r1,pos[3]+sa*r1
        local b1X,b1Z=pos[1]+cb*r1,pos[3]+sb*r1
        Emit(mesh,origin,a0X,pos[2]+0,a0Z,normal,rgba);Emit(mesh,origin,b0X,pos[2]+0,b0Z,normal,rgba);Emit(mesh,origin,b1X,pos[2]+height,b1Z,normal,rgba)
        Emit(mesh,origin,a0X,pos[2]+0,a0Z,normal,rgba);Emit(mesh,origin,b1X,pos[2]+height,b1Z,normal,rgba);Emit(mesh,origin,a1X,pos[2]+height,a1Z,normal,rgba)
    end
end
function M:Crystal(pos,color,alpha)
    local mesh,origin,normal=self.mesh,self.origin,Vector3.UP
    local rgba=Color(color[1],color[2],color[3],alpha)
    for _,s in ipairs({-1,1}) do for i=0,3 do local a,b=i*math.pi/2,(i+1)*math.pi/2
        Emit(mesh,origin,pos[1],pos[2]+s*1.12,pos[3],normal,rgba)
        Emit(mesh,origin,pos[1]+math.cos(a)*.56,pos[2],pos[3]+math.sin(a)*.56,normal,rgba)
        Emit(mesh,origin,pos[1]+math.cos(b)*.56,pos[2],pos[3]+math.sin(b)*.56,normal,rgba)
    end end
end
function M:Refresh(name,frustum,pos,radius,bottom,top,due)
    if not due and not self.culled[name] then return false end
    -- Use the full animated volume, including the 90m column above a zone.
    -- Coord mirrors X, so the source maximum X becomes the native minimum.
    local outside=frustum and frustum:IsInsideFast(BoundingBox(
        Coord.Vec(pos[1]+radius,pos[2]+bottom,pos[3]-radius),
        Coord.Vec(pos[1]-radius,pos[2]+top,pos[3]+radius)))==OUTSIDE
    self.culled[name]=outside or nil
    local batch=self.batches[name]
    if batch then batch.mesh.enabled=not outside end
    return not outside
end
function M:HitReactor(team) self.reactorFlash[team]=1 end
function M:ReactorRandom()
    -- Visual jitter must not consume the vehicle/weapon gameplay random stream.
    self.reactorRandomState=(self.reactorRandomState*1664525+1013904223)&0xffffffff
    return self.reactorRandomState/4294967296
end
function M:Update(dt,rule,camera)
    self.age=self.age+dt;local due=self.age>=self.nextUpdate
    if due then self.nextUpdate=self.age+.1 end
    -- BattleObjectives passes the camera Node, not the Camera component.
    local component=camera and camera.GetComponent and camera:GetComponent('Camera')
    local frustum=component and component.frustum
    local t=self.age
    if self.mode.id=='conquest' then
        for i,p in ipairs(self.mode.points) do local st=rule.points[i]
            local c=colors[st.contested and 'contest' or st.owner or 'none'];local pos={p.pos[1],p.pos[2]+.25,p.pos[3]}
            local radius=p.radius
            if self:Refresh('PointRing'..i,frustum,p.pos,radius,0,.3,due) then
            self:Begin('PointRing'..i,p.pos,true)
            self:Ring(pos,radius-.6,radius,0,math.pi*2,c,.7+.2*math.sin(t*4),96)
            for seg=0,2 do
                local a=math.pi/2-seg*math.pi*2/3-.06;local length=math.pi*2/3-.12
                local progress={p.pos[1],p.pos[2]+.3,p.pos[3]}
                self:Ring(progress,radius-3,radius-1,a-length,length,{0,0,0},.25,48)
                local f=math.max(0,math.min(1,math.abs(st.v)*3-seg))
                if f>.002 then self:Ring(progress,radius-3,radius-1,a-length*f,length*f,colors[st.v>=0 and 'blue' or 'red'],.95,48) end
            end
            self.mesh:Commit()
            end
            if self:Refresh('PointVolume'..i,frustum,p.pos,radius,0,90,due) then
            self:Begin('PointVolume'..i,p.pos,false)
            local near=camera and math.sqrt((camera.position.x+p.pos[1])^2+(camera.position.z-p.pos[3])^2) or 99
            local far=math.max(0,math.min(1,(near-35)/60))
            self:Ring({p.pos[1],p.pos[2]+.2,p.pos[3]},0,radius-.6,0,math.pi*2,c,.03+.07*far,96)
            self:Beam(p.pos,radius,radius,3,c,.16,96)
            if far>0 then self:Beam(p.pos,1.8,1.2,90,c,(.16+.08*math.sin(t*3))*far) end
            self.mesh:Commit()
            end
        end
        for _,team in ipairs({'blue','red'}) do local base=self.mode.bases[team];local center=base.aim
            local previous=self.reactorFlash[team] or 0
            local flash=math.max(0,previous-dt*4);self.reactorFlash[team]=flash
            if self:Refresh('Reactor'..team,frustum,center,4,-2.5,2.5,due or previous>0) then
            self:Begin('Reactor'..team,center,false)
            local base=colors[not rule.shield[team] and 'contest' or team];local c={}
            local warn=math.max(flash,not rule.shield[team] and (.5+.5*math.sin(t*8))*.3 or 0)
            for j=1,3 do c[j]=base[j]+(1-base[j])*warn end
            for i=0,math.ceil(rule.score[team]/5-1e-6)-1 do local ring=i<10 and 0 or 1;local a=i%10/10*math.pi*2+ring*.31-t*.4
                self:Crystal({center[1]+math.cos(a)*(2.2+ring*.8),center[2]+ring*1.6-.8,center[3]+math.sin(a)*(2.2+ring*.8)},c,.95)
            end
            self:Beam({center[1],center[2]-2.5,center[3]},.5,.5,5,colors[team],.35,12);self.mesh:Commit()
            if flash>0 then self.batches['Reactor'..team].node.position=Coord.Vec(center[1]+(self:ReactorRandom()-.5)*flash*.3,center[2],center[3]) end
            end
        end
    else
        local p=self.mode:At(rule.s).pos
        if self:Refresh('PayloadHalo',frustum,p,22,0,.3,due) then
        self:Begin('PayloadHalo',p,true)
        self:Ring({p[1],p[2]+.3,p[3]},21.3,22,0,math.pi*2,colors[rule.contested and 'contest' or rule.idle>=8 and 'red' or rule.pushing>0 and 'push' or 'white'],.35+.2*math.sin(t*5),128)
        self.mesh:Commit()
        end
    end
end
function M:Dispose() self.root:Dispose();for _,m in ipairs(self.materials) do m:Dispose() end end
return M

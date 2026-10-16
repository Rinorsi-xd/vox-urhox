-- Geometry is exported from the frozen H5 factories, preserving their hierarchy.
local EffectBatch=require("render.EffectBatch")
local MissionView=require("render.MissionView")

local Data=require('core.ResourceData').Read('Story/Boss/View.json')
local Coord=require 'core.Coord'
local V=require 'core.Math3'
local Visibility=require 'render.NodeVisibility'
local Config=require 'Config'
local M={};M.__index=M
local function Vec(p) return Coord.Vec(table.unpack(p)) end
local function Scale(n,x,y,z) n.scale=Vector3(x,y or x,z or x) end
local function Opacity(m,a) m:SetShaderParameter('opacity',Variant(math.max(0,a))) end
local colors={}
local function RGB(hex) if not colors[hex] then local c=Config.HexLinear(hex);colors[hex]={c.r,c.g,c.b} end;return colors[hex] end
local function Ease(k) return k*k*(3-2*k) end
function M.Dependencies()
    local out={'Story/Boss/View.json','Shaders/BLGL/Story/MissionBody.shader','Shaders/BLGL/Story/MissionUnlit.shader','Shaders/BLGL/Story/BossAlpha.shader','Shaders/BLGL/Story/BossGlow.shader'}
    for _,m in ipairs(Data.models) do out[#out+1]=m.path end
    for _,name in ipairs({'Glow','Ribbon'}) do out[#out+1]='Shaders/BLGL/Combat/'..name..'.shader' end;return out
end
function M.New(scene,boss)
    local self=setmetatable({root=scene:CreateChild('FoxBossPresentation'),boss=boss,objects={},missiles={},planes={},nodes={}},M)
    self.warn=self:Rig(Data.ring);self.slam=self:Rig(Data.ring);self.sector=self:Rig(Data.sector);self.lanes={}
    for i=1,boss.rules.config.lanes.n do self.lanes[i]=self:Rig(Data.lane) end
    self.pod=self:Rig(Data.pod);Visibility.Set(self.pod.root,false)
    self.shield=self:Mesh(Data.shield,{shader='Alpha',color=RGB(0xff4048),alpha=.16});Scale(self.shield.root,6.5);self.shield.material.fillMode=FILL_WIREFRAME
    self.dome=self:Mesh(Data.dome,{shader='Alpha',color=RGB(0xff2a20),alpha=0});self.dome.root.enabled=false
    self.shock=self:Mesh(Data.shock,{shader='Alpha',color=RGB(0xffc8a0),alpha=0});self.shock.root.enabled=false
    for i=1,4 do self.nodes[i]=self:Mesh(Data.node,{shader='Unlit',color=RGB(0xffb02e),alpha=1}) end
    local Batch=EffectBatch;self.glow=Batch.New(self.root,'BossGlow',64,'Shaders/BLGL/Story/');self.ribbon=Batch.New(self.root,'Ribbon',300)
    self.truck=MissionView.New(scene);self.truck:HideBeacon();self.truck:AlarmOff()
    return self
end
function M:Material(d)
    local m=Material:new();assert(m:SetSurfaceShader('Shaders/BLGL/Story/'..(d.shader=='Alpha' and 'BossAlpha' or 'Mission'..d.shader)..'.shader'))
    m:SetShaderParameter('uColor',Variant(Vector3(table.unpack(d.color))));Opacity(m,d.alpha or 1)
    if d.shader=='Body' then m:SetShaderParameter('roughness',Variant(d.roughness or .5));m:SetShaderParameter('metalness',Variant(d.metalness or 0));m:SetShaderParameter('emission',Variant(Vector3(table.unpack(d.emission or {0,0,0})))) end
    m.renderOrder=d.shader=='Alpha' and 146 or 0;return m
end
function M:Mesh(id,d)
    local n=self.root:CreateChild('BossMesh');local sm=n:CreateComponent('StaticModel');sm.model=assert(cache:GetResource('Model',Data.models[id].path))
    local material=self:Material(d);sm.material=material;sm.castShadows=d.shader=='Body'
    local obj={root=n,model=sm,material=material,nodes={n},materials={material},materialByNode={[1]=material}};self.objects[#self.objects+1]=obj;return obj
end
function M:Rig(def)
    local o={nodes={},materials={},materialByNode={},definition=def,glows={}}
    for id,d in ipairs(def.nodes) do
        local parent=d.parent==0 and self.root or o.nodes[d.parent];local n=parent:CreateChild('BossPart'..id);o.nodes[id]=n
        n.position=Vec(d.position);n.scale=Vector3(table.unpack(d.scale));local q=d.quaternion;n.rotation=Quaternion(q[4],q[1],-q[2],-q[3]);n.enabled=d.visible
        if d.model then local sm=n:CreateComponent('StaticModel');sm.model=assert(cache:GetResource('Model',Data.models[d.model].path));local m=self:Material(Data.materials[d.material]);sm.material=m;sm.castShadows=d.shadow;o.materials[#o.materials+1]=m;o.materialByNode[id]=m end
        if d.glow then o.glows[#o.glows+1]={node=n,data=d.glow} end
    end
    for id=#def.nodes,1,-1 do if not def.nodes[id].visible then Visibility.Set(o.nodes[id],false) end end
    o.root=o.nodes[1];self.objects[#self.objects+1]=o;return o
end
function M:Ring(o,at,r,k)
    Visibility.Set(o.root,true);o.root.position=Vec(V.Add(at,{0,.35,0}));Scale(o.root,r,1,r)
    local def=o.definition;Scale(o.nodes[def.grow],math.max(.01,math.min(1,k)))
    Opacity(o.materialByNode[def.fill],.12+.2*k+.08*math.sin(self.boss.time*24))
    if def.line then Opacity(o.materialByNode[def.line],.9) end
end
function M:Glows(o,right,up)
    if not o.root.enabled then return end
    for _,g in ipairs(o.glows) do local p=g.node.worldPosition;self.glow:Disc({-p.x,p.y,p.z},g.data.size*g.node.worldScale.x,RGB(g.data.color),1,right,up) end
end
function M:Update(dt)
    local b=self.boss;local r=b.rules;local c=r.config;local camera=b.session.camera:GetCamera();local p=camera.node.worldPosition
    local lean=({kneel={2.6,.17},dying={4.2,.26},dead={4.2,.26},ending={4.2,.26},ult={-c.ult.lift*math.min(1,r.t/2),-.18}})[r.state] or {0,0}
    self.lean=self.lean or {drop=0,pitch=0};self.lean.drop=self.lean.drop+(lean[1]-self.lean.drop)*math.min(1,dt*3);self.lean.pitch=self.lean.pitch+(lean[2]-self.lean.pitch)*math.min(1,dt*3)
    local driven=b.session.combatView.units[b.unit];if driven then driven.lean=math.abs(self.lean.drop)>.01 and self.lean or nil end
    local right=camera.node.worldRotation*Vector3.RIGHT;local up=camera.node.worldRotation*Vector3.UP
    right={-right.x,right.y,right.z};up={-up.x,up.y,up.z};self.glow:Begin({-p.x,p.y,p.z},b.time);self.ribbon:Begin({-p.x,p.y,p.z},b.time)
    Visibility.Set(self.warn.root,false);Visibility.Set(self.slam.root,false);Visibility.Set(self.sector.root,false)
    for _,o in ipairs(self.lanes) do Visibility.Set(o.root,false) end
    if r.state=='stomp' then self:Ring(self.warn,r.attackAt,c.stomp.r,r.t/c.stomp.warn)
    elseif r.state=='slamCrouch' or r.state=='slamAir' then self:Ring(self.slam,r.slamTo,r.slamKind=='hop' and c.hop.r or c.slam.r,(r.t+(r.state=='slamAir' and c.slam.crouch or 0))/(c.slam.crouch+r.slamT))
    elseif r.state=='sweep' then local k=math.min(1,r.t/c.sweep.warn);local o=self.sector;Visibility.Set(o.root,true);o.root.position=Vec(V.Add(r.attackAt,{0,.35,0}));o.root.rotation=Quaternion(-(r.sweepYaw-math.pi/2)*180/math.pi,Vector3.UP);Scale(o.root,c.sweep.r,1,c.sweep.r);Scale(o.nodes[Data.sector.grow],math.max(.01,k));Opacity(o.materialByNode[Data.sector.fill],r.t>c.sweep.warn-c.flash and math.floor(b.time*20)%2==1 and .05 or .14+.18*k)
    elseif r.state=='lanes' then local k=math.min(1,r.t/c.lanes.warn)
        for i,o in ipairs(self.lanes) do Visibility.Set(o.root,true);o.root.position=Vec(V.Add(r.laneFrom,{0,.6,0}));o.root.rotation=Quaternion(-(r.laneYaw+(i-1)*math.pi*2/c.lanes.n)*180/math.pi,Vector3.UP);Scale(o.root,c.lanes.w,1,c.lanes.len*Ease(math.min(1,k*2)));Opacity(o.materials[1],r.t>c.lanes.warn-c.flash and math.floor(b.time*20)%2==1 and .08 or .18+.22*k) end
    end
    self.shock.root.enabled=b.shock~=nil
    if b.shock then local k=math.min(1,(b.shock.age+dt)/.7);self.shock.root.position=Vec(V.Add(b.shock.pos,{0,.4,0}));Scale(self.shock.root,b.shock.r*(.2+.9*Ease(k)),1,b.shock.r*(.2+.9*Ease(k)));Opacity(self.shock.material,.8*(1-k)) end
    local showNodes=({fight=true,stomp=true,sweep=true,lanes=true,ult=true,recover=true,slamCrouch=true,slamAir=true,stuck=true,barrage=true,transition=true,standoff=true})[r.state] and r.hp>0
    b:Nodes();for i,n in ipairs(r.nodes) do local o=self.nodes[i];o.root.enabled=showNodes and not n.broken or false;o.root.position=Vec(n.pos);o.root.rotation=Quaternion(-b.time*1.8*180/math.pi,Vector3.UP)
        local pulse=1+.12*math.sin(b.time*7+i-1);Scale(o.root,pulse)
        local color=RGB(r:Braced() and 0x6a5a48 or n.hp<n.max*.4 and 0xff5030 or 0xffb02e)
        o.material:SetShaderParameter('uColor',Variant(Vector3(table.unpack(color))))
        if o.root.enabled then self.glow:Disc(n.pos,7,RGB(0xffa22a),r:Braced() and .15 or 1,right,up) end
    end
    local cockpit=b:Cockpit();self.shield.root.position=Vec(cockpit);local want=(showNodes or r.state=='rise') and (1-c.chip[r:Broken()+1])/(1-c.chip[1]) or 0
    if r.tailsOpen or r.state=='ult' then for i,tail in ipairs(b.tails) do
        local charge=r.state=='barrage' and not r.launched or r.state=='ult'
        local size=(r.state=='ult' and 9+6*math.min(1,r.t/c.ult.charge) or charge and 7 or 3.5)*(1+.25*math.sin(b.time*12+i))
        if r.hp>0 then self.glow:Disc(b:PartCenter(tail),size,RGB(0xff4a20),1,right,up) end
    end end
    self.shieldK=(self.shieldK or 0)+(want-(self.shieldK or 0))*math.min(1,dt*6);self.shield.root.enabled=self.shieldK>.02;self.shield.root.rotation=Quaternion(-b.time*.4*180/math.pi,Vector3.UP)
    Opacity(self.shield.material,.05+.13*self.shieldK*(.8+.2*math.sin(b.time*9))+(r.time-(r.hitAt or -9)<.12 and r.state~='kneel' and .25 or 0))
    self.dome.root.enabled=r.state=='ult';if self.dome.root.enabled then local center=b.world.layout.enginePit.points.floorCentre;self.dome.root.position=Vec({center[1],b:Ground(center[1],center[3])-30,center[3]});Scale(self.dome.root,560);local k=math.min(1,r.t/c.ult.charge);Opacity(self.dome.material,.03+.2*k*k+(r.t>c.ult.charge-1 and math.floor(b.time*16)%2==1 and .08 or 0)) end
    for i,ms in ipairs(b.missiles) do local o=self.missiles[i];if not o then o=self:Mesh(ms.bomb and Data.bomb or Data.missile,{shader='Unlit',color=RGB(ms.bomb and 0x3a3032 or 0xffe0c0),alpha=1});self.missiles[i]=o end
        if o.bomb~=ms.bomb then o.bomb=ms.bomb;o.model.model=assert(cache:GetResource('Model',Data.models[ms.bomb and Data.bomb or Data.missile].path));o.material:SetShaderParameter('uColor',Variant(Vector3(table.unpack(RGB(ms.bomb and 0x3a3032 or 0xffe0c0))))) end
        o.root.enabled=true;o.root.position=Vec(ms.prev);local delta=V.Sub(ms.to,ms.prev);o.root:LookAt(Vec(V.Add(ms.prev,delta)),Vector3.UP)
        local at=ms.prev;local pixels=graphics:GetHeight();local width=V.Length(V.Sub(at,{-p.x,p.y,p.z}))*2*math.tan(camera.fov*math.pi/360)/math.max(1,pixels)
        for j=1,#ms.hist-1 do self.ribbon:Segment(ms.hist[j],ms.hist[j+1],width,RGB(0xffb070),ms.bomb and .35 or .7,.3) end;self.glow:Disc(ms.prev,ms.bomb and 2.5 or 4,RGB(0xff6a30),1,right,up)
    end
    for i=#b.missiles+1,#self.missiles do self.missiles[i].root.enabled=false end
    for _,o in ipairs(self.planes) do Visibility.Set(o.root,false) end
    if b.raid then for i,plane in ipairs(b.raid.planes) do local o=self.planes[i];if not o then o=self:Rig(Data.bomber);self.planes[i]=o end;Visibility.Set(o.root,plane.pos~=nil)
        if plane.pos then o.root.position=Vec(plane.pos);o.root.rotation=Quaternion(-math.atan(b.raid.dir[1],b.raid.dir[3])*180/math.pi,Vector3.UP);self:Glows(o,right,up) end
    end end
    local pod=b.flow.pod;Visibility.Set(self.pod.root,pod~=nil and not b.flow.truck)
    if self.pod.root.enabled then
        local t=pod.t;local spawned=self.podFlight~=pod and t==0;self.podFlight=pod
        self.pod.root.position=Vec({pod.from[1]+math.sin(t*2.1)*4+t*3,pod.from[2]+t*9-t*t*.25,pod.from[3]+t*t*3.2})
        if spawned then self.pod.root.rotation=Quaternion.IDENTITY
        else
            -- Preserve Three.js XYZ Euler order through the logical X mirror.
            self.pod.root.rotation=Quaternion(math.deg(math.sin(t*5)*.4),Vector3.RIGHT)*Quaternion(-math.deg(math.pi+math.sin(t*1.7)*.5),Vector3.UP)*Quaternion(-math.deg(math.sin(t*3.3)*.5),Vector3.FORWARD)
        end
        for _,g in ipairs(self.pod.glows) do Scale(g.node,spawned and 1 or (3+math.random()*2.5)/g.data.size) end
        self:Glows(self.pod,right,up)
    else self.podFlight=nil end
    if b.flow.truck then local pos,yaw,speed=b:RecoveryPose()
        local convoy=self.convoy or {hp=1,pos=pos,yaw=yaw,v=speed};self.convoy=convoy;convoy.pos=pos;convoy.yaw=yaw;convoy.v=speed
        if not self.truck.truck then self.truck:Truck(convoy) end;self.truck:Update(dt,b.mission.rules,camera)
    end
    self.glow:Finish();self.ribbon:Finish()
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.glow:Dispose();self.ribbon:Dispose();self.truck:Dispose();self.root:Dispose()
    for _,o in ipairs(self.objects) do for _,m in ipairs(o.materials) do m:Dispose() end end
    self.objects={};self.missiles={};self.planes={};self.nodes={};self.lanes={}
    self.warn=nil;self.slam=nil;self.sector=nil;self.pod=nil;self.shield=nil;self.dome=nil;self.shock=nil
    self.glow=nil;self.ribbon=nil;self.truck=nil;self.root=nil;self.boss=nil;self.convoy=nil
end
return M

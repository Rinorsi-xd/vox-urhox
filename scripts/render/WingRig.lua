-- Source wingFx.js articulation. Geometry and hinges come from frozen GLBs.
local Coord=require 'core.Coord'
local V=require 'core.Math3'
local M={}
local seedNext=0
local function Spring(k,z,x) return {k=k or 110,z=z or .55,x=x or 0,v=0} end
local function Step(s,target,dt)
    local n=math.max(1,math.ceil(dt*120));local h=dt/n;local c=2*s.z*math.sqrt(s.k)
    for _=1,n do s.v=s.v+((target-s.x)*s.k-s.v*c)*h;s.x=s.x+s.v*h end;return s.x
end
local function Turn(n,axis,a) n.rotation=Quaternion(-a*180/math.pi,axis) end
local function Check(r,phase,i)
    local t=phase*8-i*.18-r.seed*.3;if t<0 or t>2.2 then return 0 end
    return t<.6 and math.sin(t/.6*math.pi)*.75 or t<1.4 and -math.sin((t-.6)/.8*math.pi)*.75 or math.sin((t-1.4)/.8*math.pi)*.2
end
function M.Build(node,segs,part,vis,attach)
    seedNext=seedNext+1
    local r={nodes={},flaps={},vanes={},seed=(seedNext*.61803398875)%1,time=0,glow=Spring(30,.9,1)};vis.rig.wing=r
    attach(node,segs.base)
    local function Add(p)
        local parent=p.parent and p.parent~=cjson.null and r.nodes[p.parent] or nil
        local origin=parent and parent.data.origin or {0,0,0};local n=(parent and parent.node or node):CreateChild(p.name)
        n.position=Coord.Vec(p.origin[1]-origin[1],p.origin[2]-origin[2],p.origin[3]-origin[3]);attach(n,p.model)
        local d={node=n,data=p,axis=Coord.Vec(table.unpack(p.hinge)):Normalized()};r.nodes[p.name]=d
        if p.name:match('^flap%d$') then d.i=#r.flaps;d.spring=Spring(150,.5);d.flutter=math.random()*10;r.flaps[#r.flaps+1]=d
        elseif p.name:match('^vane%d$') then d.i=#r.vanes;d.spring=Spring(120-d.i*18,.45);r.vanes[#r.vanes+1]=d
        elseif p.name=='sweep' then d.spring=Spring(26,.7);r.sweep=d
        elseif p.name=='ring' then d.angle=0;d.speed=0;r.ring=d end
    end
    for _,p in ipairs(segs.parts) do if not p.parent or p.parent==cjson.null then Add(p) end end
    for _,p in ipairs(segs.parts) do if p.parent and p.parent~=cjson.null then Add(p) end end
    if segs.info.kind=='wing' then
        local trail=node:CreateChild('WingtipTrail');local mesh=trail:CreateComponent('CustomGeometry');mesh.dynamic=true;mesh.castShadows=false;mesh.enabled=false
        local material=Material:new();assert(material:SetSurfaceShader('Shaders/BLGL/WingTrail.shader'));material.renderOrder=142;mesh.material=material
        r.trail={node=trail,mesh=mesh,material=material,points={},level=0,tip=Coord.Vec(table.unpack(segs.tip or {0,segs.info.span-.6,0}))}
    end
end
local function Trail(vis,r,st,dt,fast)
    local tr=r.trail;if not tr then return end
    local g=st and st.airTime>.5 and math.min(1,math.abs(st.controls[1] or 0)*1.5+math.abs(st.controls[3] or 0)*.6) or 0
    local want=st and st.airTime>.5 and fast*(.35+.65*g) or 0;tr.level=tr.level+(want-tr.level)*(1-math.exp(-dt*4))
    if tr.level<.01 and #tr.points==0 then tr.mesh.enabled=false;return end
    for _,p in ipairs(tr.points) do p.age=p.age+dt end
    if tr.level>.01 then table.insert(tr.points,1,{p=vis.node:LocalToWorld(tr.tip),w=(vis.node.worldRotation*Vector3(-1,0,0)):Normalized(),age=0,level=tr.level}) end
    while #tr.points>30 or #tr.points>0 and tr.points[#tr.points].age>.5 do table.remove(tr.points) end
    tr.mesh.enabled=#tr.points>1;if not tr.mesh.enabled then return end
    tr.mesh:BeginGeometry(0,TRIANGLE_LIST)
    local function Vertex(index,side)
        local p=tr.points[index];local life=math.max(0,1-p.age/.5);local half=(.05+.1*life)*p.level
        local a=life*life*p.level*.9;tr.mesh:DefineVertex(tr.node:WorldToLocal(p.p+p.w*(half*side)))
        tr.mesh:DefineColor(Color(.55*a/16,.85*a/16,1.3*a/16,1));tr.mesh:DefineNormal(Vector3.UP);tr.mesh:DefineTexCoord(Vector2.ZERO)
    end
    for i=1,#tr.points-1 do Vertex(i,1);Vertex(i+1,1);Vertex(i,-1);Vertex(i,-1);Vertex(i+1,1);Vertex(i+1,-1) end
    tr.mesh:Commit()
end
function M.Update(vis,state,time,dt)
    local r=vis.rig.wing;if not r then return end
    r.time=r.time+dt;local t=r.time;local st=state and state.st;local phase=st and st.phase or 'idle';local idle=not st or phase=='parked'
    local cyc=((t+r.seed*8)%8)/8;local lifting=state and state.lifting or 1
    local air,brake,throttle=st and st.airspeed or 0,st and st.brake or 0,st and st.throttle or 0
    local stall=st and st.stallSpeed or 15;local fast=st and V.Clamp((air-stall*1.3)/(stall*1.5),0,1) or 0
    local boost=phase=='boost' and V.Clamp(throttle,0,1)*fast or 0
    local liftSign=lifting~=0 and lifting or 1
    for _,f in ipairs(r.flaps) do
        local d
        if idle then d=Check(r,cyc,f.i)+math.sin(t*1.3+f.i+r.seed*6)*.03
        else d=(st.surfaces[state.partId..':'..f.data.name] or 0)-brake*.9*liftSign
            f.flutter=f.flutter+dt*(14+air*.25);d=d+(math.sin(f.flutter)*.6+math.sin(f.flutter*2.3+1.7)*.4)*(.012+.03*fast) end
        Turn(f.node,f.axis,Step(f.spring,V.Clamp(d,-1.2,1.2)*math.rad(26),dt))
    end
    if r.sweep then
        local k=idle and .3+(cyc<.45 and math.sin(cyc/.45*math.pi)*.45 or 0)+math.sin(t*.7)*.02
            or (({taxi=true,takeoff=true,climb=true,landing=true})[phase] or brake>.3) and .02 or .15+.6*fast+.25*boost
        Turn(r.sweep.node,r.sweep.axis,-Step(r.sweep.spring,k,dt)*math.rad(24))
    end
    local roll=st and st.surfaces[state.partId..':vanes'] or 0
    local base=idle and .12+math.sin(t*1.1)*.05 or phase=='landing' and .75 or ({taxi=true,takeoff=true,climb=true})[phase] and .45 or .18*(1-fast)-.1*boost
    base=base+brake*1.4+math.max(0,-roll*liftSign)*1.1
    for _,v in ipairs(r.vanes) do
        local f=base;if idle then local ph=cyc*8-3.2-v.i*.22;if ph>0 and ph<1.6 then f=f+math.sin(ph/1.6*math.pi)*.9 end
        else f=f+math.sin(t*(9+v.i*1.7))*.015*fast end
        local spread=v.data.spread~=0 and v.data.spread or -20
        Turn(v.node,v.axis,math.rad(spread)*Step(v.spring,V.Clamp(f,-.25,1.6),dt))
    end
    if r.ring then local want=idle and .5 or 1.2+air*.12+math.max(0,throttle)*3+boost*3
        r.ring.speed=r.ring.speed+(want-r.ring.speed)*(1-math.exp(-dt*2.5));r.ring.angle=r.ring.angle+r.ring.speed*dt;Turn(r.ring.node,r.ring.axis,r.ring.angle) end
    local glow=idle and .85+.2*math.sin(t*2.1+r.seed*6) or 1+.25*math.max(0,throttle)+.45*boost+.35*brake*(.5+.5*math.sin(t*18))
    local emission=2.8*Step(r.glow,glow,dt);for _,sm in ipairs(vis.emissionModels) do sm.instanceCustomData=Vector4(emission,0,0,0) end
    Trail(vis,r,st,dt,fast)
end
function M.Dispose(vis)
    local r=vis.rig.wing;if r and r.trail then r.trail.node:Dispose();r.trail.material:Dispose();r.trail=nil end
end
return M

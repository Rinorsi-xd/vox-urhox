-- Native-facing arithmetic golden check, run with Lua 5.4 and no engine window.
-- This tests controller equivalence against an immutable module, not Bullet.
local V={};V.__index=V
function Vector3(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
local function Vec(x,y,z) return Vector3(x,y,z) end
V.__add=function(a,b)return Vec(a.x+b.x,a.y+b.y,a.z+b.z)end
V.__sub=function(a,b)return Vec(a.x-b.x,a.y-b.y,a.z-b.z)end
V.__mul=function(a,b)if type(a)=='number' then return Vec(a*b.x,a*b.y,a*b.z) end;return Vec(a.x*b,a.y*b,a.z*b)end
function V:DotProduct(b)return self.x*b.x+self.y*b.y+self.z*b.z end
function V:CrossProduct(b)return Vec(self.y*b.z-self.z*b.y,self.z*b.x-self.x*b.z,self.x*b.y-self.y*b.x)end
local Q={};Q.__index=Q
function Quaternion(w,x,y,z)return setmetatable({w=w,x=x,y=y,z=z},Q)end
function Q:Inverse()local n=self.w*self.w+self.x*self.x+self.y*self.y+self.z*self.z;return Quaternion(self.w/n,-self.x/n,-self.y/n,-self.z/n)end
Q.__mul=function(a,b)
    if b.w then return Quaternion(a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w) end
    local qv=Vec(a.x,a.y,a.z);local uv=qv:CrossProduct(b);return b+uv*(2*a.w)+qv:CrossProduct(uv)*2
end
local VectorClass={ZERO=Vec(0,0,0),RIGHT=Vec(1,0,0),UP=Vec(0,1,0),FORWARD=Vec(0,0,1)}
Vector3=setmetatable(VectorClass,{__call=function(_,x,y,z)return Vec(x,y,z)end})
-- Vec must bypass the callable table to avoid recursion after publishing constants.
Vec=function(x,y,z)return setmetatable({x=x or 0,y=y or 0,z=z or 0},V)end
package.path='scripts/?.lua;'..package.path
package.loaded['core.Coord']={Vec=function(x,y,z)return Vec(-x,y,z)end}
package.loaded['drive.TerrainObstacles']={SUPPORT_MASK=0xffff}
local Math=require 'core.Math3'
local current=require 'physics.Body'
local before=assert(loadfile(NAV_BEFORE_ROOT..'/scripts/physics/Body.lua'))()
local Suspension=require 'drive.RaySuspension'
local oldSuspension=assert(loadfile(NAV_BEFORE_ROOT..'/scripts/drive/RaySuspension.lua'))()
local assertions=0
local function Equal(a,b,label)
    assertions=assertions+1
    assert(type(a)==type(b),label..' type')
    if type(a)=='table' then for k,v in pairs(a) do Equal(v,b[k],label..'.'..tostring(k)) end;for k in pairs(b) do assert(a[k]~=nil,label..' extra '..tostring(k))end
    else assert(a==b,label..' '..tostring(a)..' ~= '..tostring(b)) end
end
local function Copy(a)
    if type(a)~='table' then return a end
    local out={};for k,v in pairs(a)do out[k]=Copy(v)end
    return setmetatable(out,getmetatable(a))
end
local function Native(mass,q,seed)
    local state={mass=mass,position=Vec(seed*.2,1.3,-seed*.5),rotation=q,centerOfMass=Vec(.3,.8,-.2),linearVelocity=Vec(2,-.1,4),angularVelocity=Vec(.12,.3,-.2),kinematic=false}
    local counts,log={},{};local inertia={.08,.05,.11};local force,torque=Vec(),Vec();local methods={}
    local function Record(kind,value)log[#log+1]={kind=kind,value=Copy(value)}end
    local function Inv(value)local localValue=state.rotation:Inverse()*value;return state.rotation*Vec(localValue.x*inertia[1],localValue.y*inertia[2],localValue.z*inertia[3])end
    function methods:ApplyImpulse(v)Record('impulse',v);if state.mass>0 then state.linearVelocity=state.linearVelocity+v*(1/state.mass)end end
    function methods:ApplyTorqueImpulse(v)Record('torqueImpulse',v);if state.mass>0 then state.angularVelocity=state.angularVelocity+Inv(v)end end
    function methods:ApplyForce(v)Record('force',v);force=force+v end
    function methods:ApplyTorque(v)Record('torque',v);torque=torque+v end
    function methods:ResetForces()force=Vec()end
    function methods:ResetTorques()torque=Vec()end
    local object=setmetatable({node={}},{__index=function(_,key)
        if methods[key]then return methods[key]end
        counts[key]=(counts[key]or 0)+1;return Copy(state[key])
    end,__newindex=function(_,key,value)state[key]=Copy(value)end})
    local function Integrate()
        if mass>0 then
            state.linearVelocity=state.linearVelocity+force*(1/mass/60);state.angularVelocity=state.angularVelocity+Inv(torque)*(1/60)
            state.position=state.position+state.linearVelocity*(1/60)
            local angle=.0007;local r=Quaternion(math.cos(angle),0,math.sin(angle),0);state.rotation=r*state.rotation
        end
        force=Vec();torque=Vec()
    end
    return object,state,counts,log,Integrate
end
local function Wrap(mod,body) return mod.Wrap(body) end
local function Begin(b)if b.beginReadScope then b.beginReadScope()end end
local function End(b)if b.endReadScope then b.endReadScope()end end
local function Snapshot(body)
    return {p=body.translation(),q=body.rotation(),v=body.linvel(),w=body.angvel(),c=body.center(),lc=body.localCom(),m=body.mass()}
end
local function BodyCase(mod,scoped)
    local native,state,counts,log,integrate=Native(42,Quaternion(math.cos(.3),math.sin(.3),0,0),3)
    local body=Wrap(mod,native);local output={};for key in pairs(counts)do counts[key]=0 end
    for frame=1,30 do
        if scoped then Begin(body)end
        for wheel=1,12 do
            local point={x=wheel*.3,y=.2,z=wheel%3};local direction={x=.6,y=.8,z=0}
            output[#output+1]={Snapshot(body),body.velocityAtPoint(point),body.impulseDenominator(point,direction)}
            body.addForceAtPoint({x=2,y=3,z=-1},point);body.addTorque({x=.2,y=-.1,z=.3})
            if wheel%3==0 then body.applyImpulseAtPoint({x=.2,y=.3,z=-.1},point)end
            if wheel%4==0 then body.applyImpulse({x=.1,y=-.1,z=.2});body.applyTorqueImpulse({x=.1,y=.2,z=.1})end
            if wheel==5 then body.setLinvel({x=frame*.1,y=.2,z=3});body.setAngvel({x=.1,y=.2,z=-.3})end
            if wheel==8 then body.setTranslation({x=frame*.2,y=1.2,z=-3});body.setRotation({w=math.cos(.4),x=0,y=math.sin(.4),z=0})end
        end
        if scoped then End(body)end
        integrate();output[#output+1]=Snapshot(body)
    end
    return {output=output,log=log,state=state},counts
end
local oldBody,oldCounts=BodyCase(before,false);local newBody,newCounts=BodyCase(current,true)
Equal(oldBody,newBody,'body mixed mutation sequence')
local function SuspensionCase(mod,suspensionModule,wheelCount,tilt,moving,airborne)
    local q=Quaternion(math.cos(tilt/2),0,0,math.sin(tilt/2))
    local native,state,counts,log,integrate=Native(72,q,2)
    local groundNative,groundState,groundCounts,groundLog,groundIntegrate=Native(moving and 300 or 0,Quaternion(1,0,0,0),0)
    groundState.position=Vec();groundState.centerOfMass=Vec();groundState.linearVelocity=moving and Vec(.2,0,-.1)or Vec();groundState.angularVelocity=moving and Vec(0,.03,0)or Vec()
    local body,ground=Wrap(mod,native),Wrap(mod,groundNative)
    local vehicle={body=body,mass=72,wheels={}}
    for i=1,wheelCount do vehicle.wheels[i]={conn={i%2==0 and 1.2 or -1.2,0,-2+(i//2)*.6},down={0,-1,0},rest=.4,radius=.5,maxTravel=.3,compression=.2,relaxation=.4,stiffness=42,maxForce=800,contactAxle={-1,0,0},friction=2.2}end
    local rays=0
    vehicle.space={Raycast=function(_,origin,direction,length)
        rays=rays+1
        if airborne or rays%7==0 then return nil end
        return {point={origin[1]+direction[1]*.7,origin[2]+direction[2]*.7,origin[3]+direction[3]*.7},normal={0,1,0},dist=.7,body=ground}
    end}
    local suspension=suspensionModule.New(vehicle);local frames={}
    for key in pairs(counts)do counts[key]=0 end
    for frame=1,90 do
        Begin(body)
        body.resetForces();body.resetTorques();suspension:Sample()
        for i,s in ipairs(suspension.states)do s.engine=frame<30 and 15 or 0;s.brake=frame>=30 and 2 or 0;s.steer=math.sin(frame*.03)*(i%2==0 and .3 or -.3);s.side=frame>=60 and .4 or 1 end
        suspension:Apply(1/60);End(body);integrate();groundIntegrate()
        local states={};for i,s in ipairs(suspension.states)do states[i]={};for k,v in pairs(s)do if k~='groundBody' then states[i][k]=Copy(v)end end end
        frames[#frames+1]={states=states,body=Snapshot(body),ground=Snapshot(ground)}
    end
    return {frames=frames,log=log,groundLog=groundLog,rays=rays,state=state},counts
end
local cases={}
for _,wheels in ipairs({4,8,16})do for _,tilt in ipairs({0,.25})do for _,moving in ipairs({false,true})do for _,airborne in ipairs({false,true})do
    local old,oc=SuspensionCase(before,oldSuspension,wheels,tilt,moving,airborne)
    local new,nc=SuspensionCase(current,Suspension,wheels,tilt,moving,airborne)
    Equal(old,new,'suspension '..wheels..'/'..tilt..'/'..tostring(moving)..'/'..tostring(airborne))
    cases[#cases+1]={wheels=wheels,tilt=tilt,movingGround=moving,airborne=airborne,rays=new.rays,beforeReads=oc,afterReads=nc}
end end end end
local n,s=Native(0,Quaternion(1,0,0,0),0);local b=Wrap(current,n)
Begin(b);Equal(b.impulseDenominator({x=1,y=0,z=0},{x=0,y=1,z=0}),0,'static denominator');End(b)
Begin(b);b.setBodyType(true);Equal(b.bodyType(),true,'kinematic mutation');b.setNextKinematicTranslation({x=4,y=5,z=6});b.setNextKinematicRotation({w=1,x=0,y=0,z=0});End(b)
Equal(b.translation(),{x=4,y=5,z=6},'kinematic placement')
Begin(b);b.invalidate();assert(not b.isValid()and b.native==nil,'invalidated scope');assertions=assertions+1
local function ScopeReturn(body)
    local reads <close> = body.beginReadScope()
    return Snapshot(body)
end
local function ScopeError(body)
    local reads <close> = body.beginReadScope()
    Snapshot(body);error('expected controller failure')
end
local en,es=Native(35,Quaternion(1,0,0,0),4);local eb=Wrap(current,en)
Equal(ScopeReturn(eb),Snapshot(eb),'close normal return')
es.position=Vec(100,200,300);es.linearVelocity=Vec(3,2,1)
Equal(eb.translation(),{x=-100,y=200,z=300},'normal close observes external integration')
local ok,message=pcall(ScopeError,eb)
assert(not ok and message:find('expected controller failure',1,true),'expected error propagated');assertions=assertions+1
es.position=Vec(11,22,33);es.rotation=Quaternion(math.cos(.2),0,math.sin(.2),0);es.centerOfMass=Vec(.4,.5,.6)
es.linearVelocity=Vec(9,8,7);es.angularVelocity=Vec(.2,.3,.4);es.mass=61
local fresh=Wrap(before,en)
Equal(Snapshot(eb),Snapshot(fresh),'error close observes all native changes')
local function InvalidateScope(body)
    local reads <close> = body.beginReadScope()
    body.translation();body.invalidate();error('expected invalidated failure')
end
ok,message=pcall(InvalidateScope,eb);assert(not ok and not eb.isValid()and eb.native==nil,'close after invalidate has no throw');assertions=assertions+1
return {result='PASSED',assertions=assertions,bodyBeforeReads=oldCounts,bodyAfterReads=newCounts,suspensionCases=cases,scope='Offline Lua arithmetic and native-call golden; not actual Bullet or Web performance.'}

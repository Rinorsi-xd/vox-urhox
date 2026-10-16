-- Uses the Vector3/Quaternion native mocks initialized by body-cache regression.
local before=assert(loadfile(BODY_POINT_BEFORE_ROOT..'/scripts/physics/Body.lua'))()
local candidate=assert(loadfile('scripts/physics/Body.lua'))()
local assertions=0
local function Check(value,label) assertions=assertions+1;assert(value,label) end
local function Equal(a,b,label)
    for _,key in ipairs({'x','y','z'})do Check(a[key]==b[key],label..' '..key..': '..tostring(a[key])..' ~= '..tostring(b[key]))end
end
local function Native(mass,kinematic,spin,linear)
    local state={mass=mass,kinematic=kinematic,position=Vector3(11,-2,7),rotation=Quaternion(math.cos(.31),0,math.sin(.31),0),
        centerOfMass=Vector3(.7,-.2,1.1),angularVelocity=spin,linearVelocity=linear}
    local reads={};local writes={};local methods={}
    function methods:ApplyImpulse(v)state.linearVelocity=state.linearVelocity+v*(1/math.max(1,state.mass))end
    function methods:ApplyTorqueImpulse(v)state.angularVelocity=state.angularVelocity+v*.02 end
    local native=setmetatable({node={}},{__index=function(_,key)
        if methods[key]then return methods[key]end
        reads[key]=(reads[key]or 0)+1;return state[key]
    end,__newindex=function(_,key,value)writes[key]=(writes[key]or 0)+1;state[key]=value end})
    local function Reset()for key in pairs(reads)do reads[key]=nil end;for key in pairs(writes)do writes[key]=nil end end
    return native,state,reads,writes,Reset
end
local function Case(mod,mass,kinematic,spin,linear,scoped)
    local native,state,reads,writes,reset=Native(mass,kinematic,spin,linear)
    local body=mod.Wrap(native);reset()
    if scoped then body.beginReadScope()end
    local outputs={}
    for _,point in ipairs({{x=0,y=0,z=0},{x=4,y=-3,z=8},{x=-12,y=6,z=1}})do outputs[#outputs+1]=body.velocityAtPoint(point)end
    if scoped then body.endReadScope()end
    return outputs,reads,writes,state,body
end
local cases={}
for _,mass in ipairs({0,43})do for _,kinematic in ipairs({false,true})do for _,scoped in ipairs({false,true})do
    for _,spinCase in ipairs({{name='zero',v={0,0,0}},{name='negative-zero',v={-0.0,0,-0.0}},
        {name='spin-x',v={.2,0,0}},{name='spin-y',v={0,-.3,0}},{name='spin-z',v={0,0,.4}},
        {name='mixed',v={.2,-.3,.4}},{name='tiny',v={1e-200,-1e-210,1e-220}}})do
        local spin=Vector3(table.unpack(spinCase.v));local linear=Vector3(-3,.7,4)
        local old,oldReads,oldWrites=Case(before,mass,kinematic,spin,linear,scoped)
        local new,newReads,newWrites=Case(candidate,mass,kinematic,spin,linear,scoped)
        for i=1,#old do Equal(old[i],new[i],'point golden '..spinCase.name)end
        Check(next(oldWrites)==nil and next(newWrites)==nil,'queries never mutate native state')
        local zero=spinCase.name=='zero' or spinCase.name=='negative-zero'
        for _,key in ipairs({'position','rotation','centerOfMass'})do
            Check((newReads[key]or 0)==(zero and 0 or oldReads[key]),'pose bridge '..spinCase.name..' '..key)
            if zero then Check(oldReads[key]==(scoped and 1 or 3),'baseline really read pose '..key)end
        end
        for _,key in ipairs({'linearVelocity','angularVelocity'})do Check(newReads[key]==oldReads[key],'velocity reads unchanged '..key)end
        cases[#cases+1]={mass=mass,kinematic=kinematic,scoped=scoped,spin=spinCase.name,beforeReads=oldReads,afterReads=newReads}
    end
end end end
-- Keep tiny nonzero rotation observable; equality alone could hide underflow.
local n,s,reads,writes,reset=Native(0,false,Vector3(0,1e-12,0),Vector3())
local b=candidate.Wrap(n);reset();local tiny=b.velocityAtPoint({x=30,y=2,z=11})
Check(tiny.x~=0 or tiny.z~=0,'tiny nonzero angular response is retained')
Check(reads.position==1 and reads.rotation==1 and reads.centerOfMass==1,'tiny nonzero uses original center path')
-- The fast path must keep nonzero linear velocity, irrespective of mass/type.
local n2,s2,r2,w2,reset2=Native(0,true,Vector3(),Vector3(5,6,7));local b2=candidate.Wrap(n2);reset2()
Equal(b2.velocityAtPoint({x=-1,y=8,z=9}),{x=-5,y=6,z=7},'translating kinematic platform')
-- Exercise every mutation through the real wrapper while a read scope is open.
local function Mutations(mod)
    local native,state,counts,_,clear=Native(25,true,Vector3(),Vector3(1,2,3));local body=mod.Wrap(native);clear()
    local out={};body.beginReadScope()
    local point={x=7,y=4,z=-2}
    local function Sample()out[#out+1]=body.velocityAtPoint(point)end
    Sample();Sample();body.applyImpulse({x=3,y=2,z=-1});Sample()
    body.applyTorqueImpulse({x=2,y=-3,z=4});Sample()
    body.setAngvel({x=0,y=0,z=0});Sample()
    body.setLinvel({x=8,y=7,z=6});Sample()
    body.applyImpulseAtPoint({x=1,y=2,z=3},point);Sample()
    body.setTranslation({x=18,y=11,z=-9});body.setRotation({w=math.cos(.4),x=math.sin(.4),y=0,z=0});Sample()
    body.setNextKinematicTranslation({x=21,y=5,z=-7});body.setNextKinematicRotation({w=1,x=0,y=0,z=0});Sample()
    body.endReadScope()
    state.linearVelocity=Vector3(-8,2,4);state.angularVelocity=Vector3(0,.21,0);state.position=Vector3(30,-2,11);Sample()
    body.beginReadScope();Sample();body.invalidate();body.endReadScope()
    Check(not body.isValid()and body.native==nil,'invalidate closes cache')
    return out,counts
end
local oldMutation,oldMutationReads=Mutations(before);local newMutation,newMutationReads=Mutations(candidate)
for i=1,#oldMutation do Equal(oldMutation[i],newMutation[i],'scoped mutation '..i)end
-- Scope guards must also close when the early branch returns from a caller.
local n3,s3=Native(0,false,Vector3(),Vector3(2,3,4));local b3=candidate.Wrap(n3)
local function Guard(errorAfter)
    local guard <close> = b3.beginReadScope()
    local value=b3.velocityAtPoint({x=0,y=0,z=0})
    if errorAfter then error('expected branch unwind')end
    return value
end
Guard(false);s3.linearVelocity=Vector3(7,8,9);Equal(b3.velocityAtPoint({x=0,y=0,z=0}),{x=-7,y=8,z=9},'guard normal close')
local ok,err=pcall(Guard,true);Check(not ok and err:find('expected branch unwind',1,true),'guard error propagated')
s3.linearVelocity=Vector3(-1,-2,-3);Equal(b3.velocityAtPoint({x=0,y=0,z=0}),{x=1,y=-2,z=-3},'guard error close')
return {result='PASSED',assertions=assertions,cases=cases,mutationBeforeReads=oldMutationReads,mutationAfterReads=newMutationReads,
    scope='Actual Lua 5.4 Body modules with native property-count mocks; no actual Bullet, Web timing or GPU claim.'}

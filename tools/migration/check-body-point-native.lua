-- Real Bullet fixtures, isolated from the application and rendering pipeline.
local beforeRoot,output
for _,arg in ipairs(GetArguments()) do
    beforeRoot=arg:match('^%-body%-before=(.+)$') or beforeRoot
    output=arg:match('^%-body%-output=(.+)$') or output
end
assert(beforeRoot and output,'body probe paths are required')
local before=assert(loadfile(beforeRoot..'/scripts/physics/Body.lua'))()
local current=assert(loadfile('scripts/physics/Body.lua'))()
local report={schema=1,scope='Actual Windows native RigidBody/Box point velocities; no Web, full app, GPU or performance acceptance',
    beforeRoot=beforeRoot,assertions=0,failures={},cases={},mutations={},complete=false}
---@type Scene|nil
local activeScene=nil
local function Check(ok,label)
    report.assertions=report.assertions+1
    if not ok then report.failures[#report.failures+1]=label end
end
local function Vec(v)return {x=v.x,y=v.y,z=v.z}end
local function Near(a,b,label)
    for _,k in ipairs({'x','y','z'}) do
        local tolerance=1e-5*math.max(1e-30,math.abs(a[k]),math.abs(b[k]))
        Check(math.abs(a[k]-b[k])<=tolerance,label..' '..k..' '..tostring(a[k])..' / '..tostring(b[k]))
    end
end
local function Expected(native,point)
    local p=Vector3(-point.x,point.y,point.z)
    local center=native.position+native.rotation*native.centerOfMass
    local v=native.linearVelocity+native.angularVelocity:CrossProduct(p-center)
    return {x=-v.x,y=v.y,z=v.z}
end
local function Create(kind)
    local scene=Scene();activeScene=scene
    local world=scene:CreateComponent('PhysicsWorld')
    world.updateEnabled=false;world.interpolation=false;world.fps=60;world.maxSubSteps=1;world.gravity=Vector3.ZERO
    local node=scene:CreateChild('PointProbe')
    node.position=Vector3(11,4,7);node.rotation=Quaternion(17,31,-13)
    local native=node:CreateComponent('RigidBody');native.mass=kind=='dynamic' and 43 or 0
    native.kinematic=kind=='kinematic';native.useGravity=false
    native.linearDamping=0;native.angularDamping=0
    -- Local box is offset from node origin; rotated COM must enter omega x r.
    --       node o ---- (.7,-.2,1.1) [ 2 x 1.2 x 3 box ]
    -- Rays test this actual box; point queries include COM and remote points.
    local shape=node:CreateComponent('CollisionShape')
    shape:SetBox(Vector3(2,1.2,3),Vector3(.7,-.2,1.1))
    world:UpdateCollisions()
    local center=native.position+native.rotation*native.centerOfMass
    local hit=world:RaycastSingle(Ray(center+Vector3(0,8,0),Vector3.DOWN),20)
    Check(hit.body==native,kind..' real native box ray hit')
    local com=native.centerOfMass
    Check(math.abs(com.x)+math.abs(com.y)+math.abs(com.z)>.1,kind..' nonzero native COM')
    return scene,world,native
end
local function Dispose(scene)scene:Dispose();activeScene=nil end
local points={{x=0,y=0,z=0},{x=-12,y=6,z=1},{x=4,y=-3,z=8},{x=-11,y=4,z=7}}
local spins={{name='zero',v={0,0,0}},{name='negative-zero',v={-0.0,0,-0.0}},
    {name='tiny',v={1e-12,-2e-12,3e-12}},{name='x',v={.2,0,0}},
    {name='y',v={0,-.3,0}},{name='z',v={0,0,.4}},{name='mixed',v={.2,-.3,.4}}}
local function Case(mod,kind,spin,moving,scoped)
    local scene,world,native=Create(kind)
    native.linearVelocity=moving and Vector3(-3,.7,4) or Vector3.ZERO
    native.angularVelocity=Vector3(table.unpack(spin.v))
    local body=mod.Wrap(native)
    local record={com=Vec(native.centerOfMass),rotation={w=native.rotation.w,x=native.rotation.x,y=native.rotation.y,z=native.rotation.z},
        linear=Vec(native.linearVelocity),spin=Vec(native.angularVelocity),samples={}}
    if spin.name=='tiny' then Check(record.spin.x~=0 and record.spin.y~=0 and record.spin.z~=0,kind..' tiny native spin survives float binding')end
    if scoped then body.beginReadScope()end
    for i,p in ipairs(points)do
        local actual=body.velocityAtPoint(p);local expected=Expected(native,p)
        Near(actual,expected,kind..' native formula '..spin.name..' '..i)
        if spin.name=='tiny' and not moving then Check(actual.x~=0 or actual.y~=0 or actual.z~=0,kind..' tiny contribution observable '..i)end
        record.samples[#record.samples+1]={actual=actual,expected=expected}
    end
    if scoped then body.endReadScope()end
    body.invalidate();Dispose(scene)
    return record
end
local function Mutations(mod,kind,scoped)
    local scene,world,native=Create(kind);local body=mod.Wrap(native)
    body.setLinvel({x=1,y=2,z=3});body.setAngvel({x=0,y=0,z=0})
    local samples={};local point={x=7,y=4,z=-2}
    if scoped then body.beginReadScope()end
    local function Sample(name)
        local actual=body.velocityAtPoint(point);local expected=Expected(native,point)
        Near(actual,expected,kind..' '..name..' refreshed native formula')
        samples[#samples+1]={name=name,actual=actual,expected=expected,linear=Vec(native.linearVelocity),spin=Vec(native.angularVelocity)}
    end
    Sample('initial-zero');Sample('repeat-zero')
    local oldLinear=Vec(native.linearVelocity)
    body.applyImpulse({x=3,y=2,z=-1});Sample('linear-impulse')
    if kind=='dynamic' then Check(native.linearVelocity.x~=oldLinear.x,'dynamic impulse really changes native velocity')end
    body.applyTorqueImpulse({x=2,y=-3,z=4});Sample('torque-impulse')
    if kind=='dynamic' then Check(native.angularVelocity:Length()>0,'dynamic torque really changes native spin')end
    body.setAngvel({x=0,y=0,z=0});Sample('return-to-exact-zero')
    body.setAngvel({x=1e-12,y=-2e-12,z=3e-12});Sample('zero-to-tiny')
    body.setLinvel({x=8,y=7,z=6});Sample('set-linear')
    body.applyImpulseAtPoint({x=1,y=2,z=3},point);Sample('point-impulse')
    body.setTranslation({x=18,y=11,z=-9});body.setRotation({w=.9238795325,x=.3826834324,y=0,z=0});Sample('pose-with-spin')
    body.setNextKinematicTranslation({x=21,y=5,z=-7});body.setNextKinematicRotation({w=1,x=0,y=0,z=0});Sample('kinematic-pose')
    if scoped then body.endReadScope()end
    -- The controller scope ends before integration or external native changes.
    world:Update(1/60)
    native.linearVelocity=Vector3(-8,2,4);native.angularVelocity=Vector3(0,.21,0)
    native.position=Vector3(30,-2,11);Sample('after-step-external-state')
    local function Guard(fail)
        local guard <close> = body.beginReadScope()
        body.velocityAtPoint(point)
        if fail then error('expected probe unwind')end
    end
    Guard(false);native.linearVelocity=Vector3(9,8,7);Sample('normal-scope-close')
    local ok,err=pcall(Guard,true);Check(not ok and tostring(err):find('expected probe unwind',1,true)~=nil,'native scope unwind retains original error')
    native.angularVelocity=Vector3.ZERO;native.linearVelocity=Vector3(-1,-2,-3);Sample('error-scope-close')
    body.beginReadScope();body.velocityAtPoint(point);body.invalidate();body.endReadScope()
    Check(not body.isValid() and body.native==nil,'native invalidation closes scope')
    Dispose(scene);return samples
end
local function Run()
    for _,kind in ipairs({'static','kinematic','dynamic'})do
        for _,scoped in ipairs({false,true})do for _,moving in ipairs({false,true})do for _,spin in ipairs(spins)do
            local old=Case(before,kind,spin,moving,scoped)
            local new=Case(current,kind,spin,moving,scoped)
            for i=1,#old.samples do Near(old.samples[i].actual,new.samples[i].actual,'989c/current '..kind..' '..spin.name..' '..i)end
            report.cases[#report.cases+1]={kind=kind,scoped=scoped,moving=moving,spin=spin.name,before=old,current=new}
        end end end
        for _,scoped in ipairs({false,true})do
            local old=Mutations(before,kind,scoped);local new=Mutations(current,kind,scoped)
            for i=1,#old do Near(old[i].actual,new[i].actual,'989c/current mutation '..kind..' '..old[i].name)end
            report.mutations[#report.mutations+1]={kind=kind,scoped=scoped,before=old,current=new}
        end
    end
    report.complete=true
end
V.atFrame(2,function()
    local ok,err=xpcall(Run,debug.traceback)
    if activeScene then activeScene:Dispose();activeScene=nil end
    report.error=not ok and tostring(err) or nil
    report.result=ok and #report.failures==0 and 'PASSED' or 'FAILED'
    local f=assert(io.open(output,'wb'));f:write(cjson.encode(report));f:close()
    V.assert(ok,'native point probe completes: '..tostring(err))
    V.assert(#report.failures==0,'native point probe '..report.assertions..' checks, '..#report.failures..' failures')
    V.finish()
end)

-- Real native point queries, mutable points, writes, integration and paired timing.
local beforeRoot,output
for _,arg in ipairs(GetArguments()) do
    beforeRoot=arg:match('^%-body%-before=(.+)$') or beforeRoot
    output=arg:match('^%-body%-output=(.+)$') or output
end
assert(beforeRoot and output,'body probe paths are required')
local function Module(path,label)
    local f=assert(io.open(path,'rb'));local source=f:read('*a');f:close()
    return assert(load(source,'@bridge-fixture/'..label..'.lua'))()
end
local before=Module(beforeRoot..'/scripts/physics/Body.lua','Body')
local current=Module('scripts/physics/Body.lua','Body')
local Suspension=Module('scripts/drive/RaySuspension.lua','RaySuspension')
local beforeSuspension=Module(beforeRoot..'/scripts/drive/RaySuspension.lua','RaySuspension')
local beforeSpace=Module(beforeRoot..'/scripts/physics/Space.lua','Space')
local controlSpace=Module(beforeRoot..'/scripts/physics/Space.lua','Space')
local currentSpace=Module('scripts/physics/Space.lua','Space')
local report={schema=2,assertions=0,failures={},states={},rayTimings={},rayControls={},complete=false,
    loader='Actual source bytes via io.read + load with identical chunk labels; same-source A/A controls',
    scope='Windows native RigidBody and complete suspension CPU fixture; no full-game, Web, mobile or thermal acceptance'}
---@type Scene|nil
local activeScene=nil
local function Check(ok,label)
    report.assertions=report.assertions+1
    if not ok then report.failures[#report.failures+1]=label end
end
local function Equal(a,b,label)
    if type(a)=='table' then
        for k,v in pairs(a)do Equal(v,b[k],label..'.'..tostring(k))end
    else Check(a==b,label..' '..tostring(a)..' / '..tostring(b))end
end
local function Vector(v)return {x=v.x,y=v.y,z=v.z}end
local function Create(mod)
    local scene=Scene();activeScene=scene
    local world=scene:CreateComponent('PhysicsWorld')
    world.updateEnabled=false;world.interpolation=false;world.fps=60;world.maxSubSteps=1;world.gravity=Vector3.ZERO
    local node=scene:CreateChild('ArmProbe');node.position=Vector3(11,4,7);node.rotation=Quaternion(17,31,-13)
    local native=node:CreateComponent('RigidBody');native.mass=43;native.useGravity=false
    native.linearDamping=0;native.angularDamping=0
    -- node o ---- local (.7,-.2,1.1) [2 x 1.2 x 3 box]; no collision pair.
    -- Offset COM and rotated inertia exercise all lever-arm components.
    node:CreateComponent('CollisionShape'):SetBox(Vector3(2,1.2,3),Vector3(.7,-.2,1.1))
    world:UpdateCollisions()
    local com=native.centerOfMass
    Check(math.abs(com.x)+math.abs(com.y)+math.abs(com.z)>.1,'actual native offset COM')
    local b=mod.Wrap(native);b.setLinvel({x=2,y=-.1,z=4});b.setAngvel({x=.12,y=.3,z=-.2})
    return scene,world,native,b
end
local function Snapshot(n)
    local q=n.rotation
    return {p=Vector(n.position),q={w=q.w,x=q.x,y=q.y,z=q.z},v=Vector(n.linearVelocity),w=Vector(n.angularVelocity)}
end
local function Dispose(scene,b)b.invalidate();scene:Dispose();activeScene=nil end
local directions={{x=.6,y=.8,z=0},{x=0,y=0,z=1}}
local function Query(b,p)
    return {velocity=b.velocityAtPoint(p),side=b.impulseDenominator(p,directions[1]),forward=b.impulseDenominator(p,directions[2])}
end
local function Mutations(mod,scoped)
    local scene,world,n,b=Create(mod);local results={};local p={x=7,y=4,z=-2}
    if scoped then b.beginReadScope()end
    local function Sample()results[#results+1]=Query(b,p)end
    Sample();Sample();p.x=p.x+.125;Sample();p.y=p.y-.25;Sample();p.z=p.z+.5;Sample()
    b.addForceAtPoint({x=2,y=3,z=-1},p);Sample()
    b.applyImpulseAtPoint({x=.2,y=.3,z=-.1},p);Sample()
    b.applyImpulse({x=.1,y=-.1,z=.2});b.applyTorqueImpulse({x=.1,y=.2,z=.1});Sample()
    b.setTranslation({x=18,y=11,z=-9});Sample()
    b.setRotation({w=.9238795325,x=.3826834324,y=0,z=0});Sample()
    b.setBodyType(true);b.setNextKinematicTranslation({x=21,y=5,z=-7});Sample()
    b.setNextKinematicRotation({w=1,x=0,y=0,z=0});Sample();b.setBodyType(false)
    if scoped then b.endReadScope()end
    world:Update(1/60);Sample()
    n.position=Vector3(30,-2,11);n.rotation=Quaternion(21,-12,33);Sample()
    local function Guard(fail)
        local guard <close> = b.beginReadScope()
        Sample();if fail then error('expected arm unwind')end
    end
    Guard(false);n.position=Vector3(31,-2,11);Sample()
    local ok,err=pcall(Guard,true);Check(not ok and tostring(err):find('expected arm unwind',1,true)~=nil,'scope error preserved')
    n.position=Vector3(32,-2,11);Sample()
    results[#results+1]=Snapshot(n);Dispose(scene,b);return results
end
local function Vehicle(mod,wheels)
    local scene,world,n,b=Create(mod)
    local v={body=b,mass=43,wheels={}}
    for i=1,wheels do
        v.wheels[i]={conn={i%2==0 and 1.2 or -1.2,0,-2+(i//2)*.6},down={0,-1,0},rest=.4,radius=.5,maxTravel=.3,compression=.2,relaxation=.4,stiffness=42,maxForce=800,contactAxle={-1,0,0},friction=2.2}
    end
    -- Deterministic support keeps actual Bullet controller math isolated from
    -- collision broadphase ordering. Every configured wheel casts every step.
    local rays=0
    v.space={Raycast=function(_,o,d)
        rays=rays+1
        return {point={o[1]+d[1]*.7,o[2]+d[2]*.7,o[3]+d[3]*.7},normal={0,1,0},dist=.7}
    end}
    local suspension=mod==before and beforeSuspension or Suspension
    return scene,world,n,b,suspension.New(v),function()return rays end
end
local function SuspensionRun(mod,wheels,frames,record)
    local scene,world,n,b,s,rays=Vehicle(mod,wheels);local states={}
    collectgarbage('collect');local start=os.clock()
    for frame=1,frames do
        do
            local guard <close> = b.beginReadScope()
            b.resetForces();s:Sample()
            for i,state in ipairs(s.states)do
                state.engine=frame%90<30 and 15 or 0;state.brake=frame%90>=30 and 2 or 0
                state.steer=math.sin(frame*.03)*(i%2==0 and .3 or -.3);state.side=frame%90>=60 and .4 or 1
            end
            s:Apply(1/60)
        end
        world:Update(1/60)
        if record then
            local wheelsOut={}
            for i,state in ipairs(s.states)do wheelsOut[i]={force=state.force,length=state.length,forward=state.forwardImpulse,side=state.sideImpulse,spin=state.spin,skid=state.skid}end
            states[#states+1]={body=Snapshot(n),wheels=wheelsOut}
        end
    end
    local ms=(os.clock()-start)*1000
    local out={states=states,final=Snapshot(n),rays=rays(),cpuMs=ms}
    Dispose(scene,b);return out
end
local function Rays(mod,iterations)
    local scene=Scene();activeScene=scene
    local space=mod.New(scene)
    local function Box(name,y,trigger)
        local node=scene:CreateChild(name);node.position=Vector3(0,y,0)
        local body=node:CreateComponent('RigidBody');body.mass=0;body.trigger=trigger
        node:CreateComponent('CollisionShape'):SetBox(Vector3(4,.5,4))
        return body
    end
    -- Downward ray: excluded box -> trigger box -> accepted static floor.
    local ground=Box('Floor',0,false)
    local excluded=space:Register(Box('Excluded',2,false),{type='excluded'})
    Box('Trigger',1,true)
    local floor=space:Register(ground,{type='ground'})
    space.world:UpdateCollisions()
    local origin,direction={0,4,0},{0,-1,0}
    local first=space:Raycast(origin,direction,10,excluded,nil,true,0xffff)
    Check(first~=nil and first.body==floor and first.collider==ground.node:GetID(),'actual ray rejects excluded and trigger')
    local sum=0;local last
    collectgarbage('collect');local start=os.clock()
    for i=1,iterations do
        last=space:Raycast(origin,direction,10,excluded,nil,true,0xffff)
        sum=sum+last.dist+last.point[2]+last.normal[2]
    end
    local ms=(os.clock()-start)*1000
    local result={cpuMs=ms,sum=sum,point=last.point,normal=last.normal,dist=last.dist}
    space:Dispose();scene:Dispose();activeScene=nil;return result
end
local function Run()
    for _,scoped in ipairs({false,true})do
        local a,b=Mutations(before,scoped),Mutations(current,scoped)
        Equal(a,b,'d011/current mutations '..tostring(scoped))
    end
    for _,wheels in ipairs({4,8,16})do
        local a,b=SuspensionRun(before,wheels,180,true),SuspensionRun(current,wheels,180,true)
        Equal(a.states,b.states,'suspension '..wheels);Equal(a.final,b.final,'final '..wheels)
        Equal(a.rays,b.rays,'rays '..wheels)
        report.states[#report.states+1]={wheels=wheels,frames=180,rays=a.rays,before=a.final,current=b.final}
    end
    Rays(beforeSpace,1000);Rays(currentSpace,1000)
    for pass=1,5 do
        local row={pass=pass,iterations=20000}
        if pass%2==0 then row.second=Rays(controlSpace,20000);row.first=Rays(beforeSpace,20000)
        else row.first=Rays(beforeSpace,20000);row.second=Rays(controlSpace,20000)end
        Equal(row.first.sum,row.second.sum,'A/A ray checksum '..pass)
        row.ratio=row.second.cpuMs/row.first.cpuMs;report.rayControls[#report.rayControls+1]=row
    end
    for pass=1,9 do
        local row={pass=pass,iterations=20000,order=pass%2==0 and 'current/before' or 'before/current'}
        if pass%2==0 then row.current=Rays(currentSpace,20000);row.before=Rays(beforeSpace,20000)
        else row.before=Rays(beforeSpace,20000);row.current=Rays(currentSpace,20000)end
        Equal(row.before.sum,row.current.sum,'ray checksum '..pass)
        Equal(row.before.point,row.current.point,'ray point '..pass)
        Equal(row.before.normal,row.current.normal,'ray normal '..pass)
        row.ratio=row.current.cpuMs/row.before.cpuMs;report.rayTimings[#report.rayTimings+1]=row
    end
    local function Median(rows)
        local values={};for _,row in ipairs(rows)do values[#values+1]=row.ratio end
        table.sort(values);return values[(#values+1)//2]
    end
    report.controlMedianRatio=Median(report.rayControls);report.rayMedianRatio=Median(report.rayTimings)
    local wins=0;for _,row in ipairs(report.rayTimings)do if row.ratio<1 then wins=wins+1 end end
    report.rayWins=wins
    report.timingAccepted=math.abs(report.controlMedianRatio-1)<.05 and report.rayMedianRatio<.95 and wins==9
    report.complete=true
end
V.atFrame(2,function()
    local ok,err=xpcall(Run,debug.traceback)
    if activeScene then activeScene:Dispose();activeScene=nil end
    report.error=not ok and tostring(err) or nil
    report.result=ok and #report.failures==0 and 'PASSED' or 'FAILED'
    local f=assert(io.open(output,'wb'));f:write(cjson.encode(report));f:close()
    V.assert(ok,'native arm probe completes: '..tostring(err))
    V.assert(#report.failures==0,'native arm probe '..report.assertions..' exact checks, '..#report.failures..' failures')
    V.finish()
end)

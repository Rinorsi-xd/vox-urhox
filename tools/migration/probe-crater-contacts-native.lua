-- Headless QA only: shipping map/vehicle, real NodeCollision manifolds.
-- A keeps current collision. B disables only existing old spire boxes, not a proposed production fix.
local World=require 'drive.CraterWorld'
local Vehicle=require 'drive.Vehicle'
local Blueprint=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Spec=require 'drive.VehicleSpec'
local output=''
local meshes=false
local quick=false
local enginePit=false
for _,arg in ipairs(GetArguments()) do
    output=arg:match('^%-probe%-output=(.+)$') or output
    if arg=='-probe-meshes=1' then meshes=true end
    if arg=='-probe-quick=1' then quick=true end
    if arg=='-probe-engine-pit=1' then enginePit=true end
end
local scene=nil ---@type Scene?
local world=nil ---@type table?
local current=nil ---@type table?
local currentStep=0
local contacts={}
local function Vec(v) return {-v.x,v.y,v.z} end
local function Plain(v) return {v.x,v.y,v.z} end
local function Q(q) return {q.x,q.y,q.z,q.w} end
local function BodyInfo(native)
    local node=native.node;local shapes={}
    for _,s in ipairs(node:GetComponents('CollisionShape')) do
        local box=s.worldBoundingBox
        shapes[#shapes+1]={kind=s.shapeType,size=Plain(s.size),offset=Plain(s.position),rotation=Q(s.rotation),margin=s.margin,
            engineBounds={min=Plain(box.min),max=Plain(box.max)}}
    end
    local index=tonumber(node.name:match('^Hull(%d+)$'))
    local block=index and world.layout.blocks[index]
    local definition=block and {index=index,kind=block.kind,module=block.module,src=block.src,pos=block.pos,size=block.size,
        rot=block.rot,noPhysics=block.noPhysics,hasVertices=block.vertices~=nil,hasTriangles=block.triangles~=nil}
    return {id=node:GetID(),name=node.name,sourcePosition=Vec(node.worldPosition),layer=native.collisionLayer,mask=native.collisionMask,
        trigger=native.trigger,mass=native.mass,shapes=shapes,definition=definition}
end
local function WheelStates(v)
    local out={}
    for i,s in ipairs(v.suspension.states) do
        local native=s.groundBody and s.groundBody.native
        out[i]={grounded=s.grounded,length=s.length,force=s.force,point=s.point,normal=s.normal,
            engine=s.engine,brake=s.brake,groundNode=native and native.node.name}
    end
    return out
end
local function Pose(v)
    local p=v.body.translation();local velocity=v.body.linvel();local q=v.body.rotation()
    return {position={p.x,p.y,p.z},velocity={velocity.x,velocity.y,velocity.z},rotation=q,wheels=WheelStates(v)}
end
local function RunPath(route,mode,spec)
    math.randomseed(1017)
    local disabled={}
    if mode=='disable-old-spire-boxes' then
        for _,index in ipairs({190,191,192}) do
            local node=world.root:GetChild('Hull'..index)
            if node then local b=node:GetComponent('RigidBody');disabled[#disabled+1]={body=b,enabled=b.enabled};b.enabled=false end
        end
    end
    local vehicle=Vehicle.New(world.space,spec)
    vehicle:Place({route.x,world:GroundAt(route.x,route.z)+.1,route.z},route.yaw)
    vehicle.native.collisionEventMode=COLLISION_ALWAYS
    local row={name=route.name,mode=mode,route=route,snapshots={},contacts={},nodes={},collidingBodies={},contactCount=0,droppedContacts=0}
    current=row;local pending={}
    SubscribeToEvent(vehicle.node,'NodeCollision',function(_,data)
        if data:GetBool('Trigger') then return end
        local other=data['OtherBody']:GetPtr('RigidBody');local otherNode=data['OtherNode']:GetPtr('Node')
        assert(other and otherNode,'NodeCollision missing actual opposing body')
        local id=otherNode:GetID()
        if not row.nodes[tostring(id)] then row.nodes[tostring(id)]=BodyInfo(other) end
        local buffer=data:GetBuffer('Contacts')
        assert(buffer.size%32==0,'Invalid contact buffer length '..tostring(buffer.size))
        while not buffer.eof do
            local point=buffer:ReadVector3();local normal=buffer:ReadVector3();local distance=buffer:ReadFloat();local impulse=buffer:ReadFloat()
            row.contactCount=row.contactCount+1
            if #pending<32 then pending[#pending+1]={node=id,name=otherNode.name,point=Vec(point),normal=Vec(normal),distance=distance,
                penetration=math.max(0,-distance),impulse=impulse}
            else row.droppedContacts=row.droppedContacts+1 end
        end
    end)
    row.vehicle=BodyInfo(vehicle.native)
    for step=1,360 do
        currentStep=step;pending={}
        local command={throttle=step>90 and 1 or 0,steer=0,handbrake=false,boost=false,jump=false,climb=0,strafe=0}
        local before=Pose(vehicle)
        vehicle:Step(command,1/60);world.space:Step(1/60)
        local after=Pose(vehicle)
        if step==90 then row.start=after end
        if step%10==0 or #pending>0 and step>90 then
            row.snapshots[#row.snapshots+1]={step=step,phase=step<=90 and 'settle' or 'drive',before=before,after=after,contacts=pending}
        end
        if step%30==0 then
            local bodies=world.space.world:GetCollidingBodies(vehicle.native);local names={}
            for _,body in ipairs(bodies) do names[#names+1]={id=body.node:GetID(),name=body.node.name} end
            row.collidingBodies[#row.collidingBodies+1]={step=step,bodies=names}
        end
        if route.stopProgress and row.start then
            local dx=after.position[1]-row.start.position[1];local dz=after.position[3]-row.start.position[3]
            if dx*math.sin(route.yaw)+dz*math.cos(route.yaw)>=route.stopProgress then
                row.stopStep=step;row.snapshots[#row.snapshots+1]={step=step,phase='threshold',before=before,after=after,contacts=pending};break
            end
        end
    end
    row.finish=Pose(vehicle)
    local dx=row.finish.position[1]-row.start.position[1];local dz=row.finish.position[3]-row.start.position[3]
    row.forwardProgress=dx*math.sin(route.yaw)+dz*math.cos(route.yaw)
    UnsubscribeFromEvent(vehicle.node,'NodeCollision');vehicle:Dispose();current=nil
    for _,entry in ipairs(disabled) do entry.body.enabled=entry.enabled end
    return row
end
local function Run()
    local meshBuildMs=nil
    local meshModuleOk,meshModule=pcall(require,'drive.CraterMeshCollision')
    if meshModuleOk then
        local original=meshModule.Build
        meshModule.Build=function(...)
            local start=Time:GetSystemTime();original(...);meshBuildMs=Time:GetSystemTime()-start
        end
    end
    scene=Scene();scene:CreateComponent('Octree');local buildStart=Time:GetSystemTime();world=World.New(scene)
    local buildMs=Time:GetSystemTime()-buildStart
    local bp=Prefab.Create(Blueprint.New(),'raceCar');local spec=Spec.Build(bp);assert(spec.ok)
    local result={status='PASS',runtime='0.9.0-beta.40_20261015.121839.6dc5c357cced',sourceSpace='RH metres; engine X mirrored',
        vehicle={name=bp.name,parts=bp:Size(),mass=spec.motion.mass,bounds=spec.bounds,wheels=#spec.wheels},
        boundary='Real shipping CraterWorld/Vehicle fixed steps and native Bullet NodeCollision. No render, audio, AI, FPS or phone claim. B disables only currently existing Hull190-192 for causal diagnosis; preserves Hull892 and is not asserted to match H5 mesh collision.',
        sourceFlags={},paths={}}
    local surfaceNames={}
    for _,node in ipairs(world.root:GetChildren()) do if node.name:match('^DrivingSurface_') then surfaceNames[#surfaceNames+1]=node.name end end
    result.fullProductionBuild={wallMs=buildMs,meshBuildMs=meshBuildMs,meshCount=world.drivingMeshCollisionCount,
        triangleCount=world.drivingMeshTriangleCount,surfaceNames=surfaceNames,rootChildren=#world.root:GetChildren()}
    for _,index in ipairs({181,182,183,190,191,192,892}) do
        local b=assert(world.layout.blocks[index]);local node=world.root:GetChild('Hull'..index)
        result.sourceFlags[#result.sourceFlags+1]={index=index,noPhysics=b.noPhysics==true,nodeExists=node~=nil,kind=b.kind,src=b.src}
    end
    if quick then
        result.boundary='Actual full production World.New constructor and real Bullet contacts. No render, audio, AI, FPS or mobile claim. Same fixed-step vehicle paths compared against an isolated earlier collision snapshot.'
        for _,route in ipairs({
            {name='mesa-z-29-short',x=29,z=-177,yaw=0,stopProgress=10},
            {name='mesa-z-29-tangent',x=29,z=-177,yaw=.436,stopProgress=10},
            {name='mesa-foot-x--170.5',x=3,z=-170.5,yaw=math.pi/2,stopProgress=13},
            {name='mesa-foot-x--171',x=3,z=-171,yaw=math.pi/2,stopProgress=13},
        }) do
            local row=RunPath(route,'full-constructor',spec);result.paths[#result.paths+1]=row
            print('CRATER_CONTACT_PATH '..cjson.encode({name=row.name,progress=row.forwardProgress,contacts=row.contactCount}))
        end
        world:Dispose();world=nil;scene:Dispose();scene=nil
        if enginePit then
            local Pit=require 'drive.EnginePitWorld';scene=Scene();scene:CreateComponent('Octree')
            -- Physics-only fixture supplies the two visual deck node handles.
            scene:CreateChild(utf8.char(0x53ef,0x584c,0x7532,0x677f));scene:CreateChild(utf8.char(0x584c,0x6389,0x7684,0x7532,0x677f))
            local pitStart=Time:GetSystemTime();world=Pit.New(scene)
            local pitSurfaces={}
            for _,node in ipairs(world.root:GetChildren()) do if node.name:match('^DrivingSurface_') then pitSurfaces[#pitSurfaces+1]=node.name end end
            result.enginePit={wallMs=Time:GetSystemTime()-pitStart,namespace=world.assetNamespace,
                meshCount=world.drivingMeshCollisionCount,surfaceNames=pitSurfaces,rootChildren=#world.root:GetChildren(),visualDeckNodeFixture=true}
            assert(#pitSurfaces==0 and not world.drivingMeshCollisionCount,'Crater collision leaked into EnginePit')
            world:Dispose();world=nil;scene:Dispose();scene=nil
        end
        return result
    end
    local routes={}
    for _,dx in ipairs({-5,-3.5,-2,0,2,3.5,5}) do
        routes[#routes+1]={name='spire-z-'..dx,x=-52+dx,z=-202,yaw=0}
    end
    for _,dz in ipairs({-4,-2.5,0,2.5,4}) do
        routes[#routes+1]={name='spire-x-'..dz,x=-64,z=-190+dz,yaw=math.pi/2}
    end
    for _,route in ipairs(routes) do
        for _,mode in ipairs({'current','disable-old-spire-boxes'}) do
            local row=RunPath(route,mode,spec);result.paths[#result.paths+1]=row
            print('CRATER_CONTACT_PATH '..cjson.encode({name=row.name,mode=mode,progress=row.forwardProgress,contacts=row.contactCount}))
        end
    end
    for _,x in ipairs({8,11.2,14,17,20,23,26,29,32}) do
        local row=RunPath({name='mesa-z-'..x,x=x,z=-177,yaw=0},'current',spec)
        result.paths[#result.paths+1]=row
        print('CRATER_CONTACT_PATH '..cjson.encode({name=row.name,mode=row.mode,progress=row.forwardProgress,contacts=row.contactCount}))
    end
    if meshes then
        local module=require 'drive.CraterMeshCollision';local data=module.Read()
        local count=0
        for _,index in ipairs(data.skipBlocks) do
            local node=world.root:GetChild('Hull'..index)
            if node then node:GetComponent('RigidBody').enabled=false;count=count+1 end
        end
        module.Build(world,nil,data)
        result.meshReplacement={disabledOldBodies=count,skipIndices=#data.skipBlocks,meshCount=#data.meshes}
        local meshRoutes={
            {name='spire-z--5',x=-57,z=-202,yaw=0},
            {name='spire-z--3.5',x=-55.5,z=-202,yaw=0},
            {name='spire-z-0',x=-52,z=-202,yaw=0},
            {name='mesa-z-8',x=8,z=-177,yaw=0},
            {name='mesa-z-11.2',x=11.2,z=-177,yaw=0},
            {name='mesa-z-14',x=14,z=-177,yaw=0},
            {name='mesa-z-17',x=17,z=-177,yaw=0},
            {name='mesa-z-20',x=20,z=-177,yaw=0},
            {name='mesa-z-23',x=23,z=-177,yaw=0},
            {name='mesa-z-26',x=26,z=-177,yaw=0},
            {name='mesa-z-29',x=29,z=-177,yaw=0},
            {name='mesa-z-32',x=32,z=-177,yaw=0},
        }
        for _,route in ipairs(meshRoutes) do
            local row=RunPath(route,'h5-visual-triangle-meshes',spec);result.paths[#result.paths+1]=row
            print('CRATER_CONTACT_PATH '..cjson.encode({name=row.name,mode=row.mode,progress=row.forwardProgress,contacts=row.contactCount}))
        end
    end
    local total=0;for _,row in ipairs(result.paths) do total=total+row.contactCount end
    assert(total>0,'No real contacts captured; API not validated')
    result.totalContacts=total;world:Dispose();world=nil;scene:Dispose();scene=nil
    return result
end
function Start()
    local ok,result=xpcall(Run,debug.traceback)
    if not ok then result={status='FAIL',error=tostring(result),active=current and {name=current.name,mode=current.mode,step=currentStep}} end
    local file=assert(io.open(output,'wb'));file:write(cjson.encode(result));file:close()
    print('CRATER_CONTACT_RESULT '..result.status);engine:Exit()
end

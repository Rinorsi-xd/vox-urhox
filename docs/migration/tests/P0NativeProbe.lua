-- Controlled native entry, derived from the project's 3D scene scaffold.
-- Copy temporarily into scripts/diagnostics for Maker local validation.
local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Spec=require 'drive.VehicleSpec'
local Vehicle=require 'drive.Vehicle'
local View=require 'render.DriveView'
local Space=require 'physics.Space'
local Surface=require 'render.JoinedSurface'
local ResourceGate=require 'app.ResourceGate'
local Dependencies=require 'parts.Dependencies'
local scene,space,drive,bp,vehicle
local gate,cameraNode,removed
local checks=0
local function Check(ok,label)
    checks=checks+1
    if V then V.assert(ok,label) end
    assert(ok,label);print('[P0Native] PASS '..label)
end
local function Geometry()
    local result={}
    for slot,mesh in pairs(drive.view.joined.meshes) do result[slot]={mesh=mesh,geometry=mesh.geometry,surface=mesh.surface} end
    return result
end
local function BuildVehicle() return Vehicle.New(space,Spec.Build(bp)) end
function Start()
    scene=Scene();scene:CreateComponent('Octree')
    local zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(-200,200);zone.ambientColor=Color(.65,.65,.65)
    local light=scene:CreateChild('Sun');light.direction=Vector3(.3,-1,.5);light:CreateComponent('Light').lightType=LIGHT_DIRECTIONAL
    space=Space.New(scene)
    cameraNode=scene:CreateChild('Camera');cameraNode.position=Vector3(14,10,-18);cameraNode:LookAt(Vector3.ZERO)
    local camera=cameraNode:CreateComponent('Camera');camera.farClip=200
    renderer:SetViewport(0,Viewport:new(scene,camera))
    SubscribeToEvent('Update',function(_,data) ResourceGate.UpdatePending(data:GetFloat('TimeStep')) end)
    bp=Prefab.Create(BP.New(),'vanguard');gate=ResourceGate.New()
    gate:Start(Dependencies.For(bp:List()),function(ok,message)
        if not ok then P0Failure=message;return end
        vehicle=BuildVehicle();vehicle:Place({0,0,0},0);drive=View.New(scene,bp,vehicle)
        local target=drive.view:GetWorldBounds().center
        cameraNode.position=target+Vector3(14,10,-18);cameraNode:LookAt(target)
        P0Ready=true;print('[P0Native] READY parts='..bp:Size())
    end)
end
function P0ValidateDamage()
    local before=Geometry();local rebuilds=drive.view.joined.rebuilds
    drive:Bind(bp,vehicle)
    Check(drive.view.joined.rebuilds==rebuilds,'unchanged native bind skips rebuilding')
    for slot,old in pairs(before) do local mesh=drive.view.joined.meshes[slot]
        Check(mesh==old.mesh and mesh.geometry==old.geometry and mesh.surface==old.surface,'retains native material mesh '..slot)
    end
    local score=-math.huge
    for _,p in ipairs(bp:List()) do if Surface.IsJoined(p) then
        local s=p.pos[2]*100-p.pos[1]-p.pos[3]
        if s>score then score=s;removed=p end
    end end
    assert(removed,'fixture needs joined armor')
    bp:Remove(removed.id);drive.view:SyncBlueprint(bp);vehicle:Dispose();vehicle=BuildVehicle();vehicle:Place({0,0,0},0);drive:Bind(bp,vehicle)
    Check(drive.view.visuals[removed.id]==nil,'damage removes actual visual')
    Check(drive.view.joined.surfaceCache.parts[removed.id]==nil,'damage releases cached part')
    Check(drive.view.joined.surfaceCache.rebuiltParts<=6,'damage regenerates adjacent surfaces only')
    for slot,old in pairs(before) do local mesh=drive.view.joined.meshes[slot]
        if mesh then Check(mesh==old.mesh and mesh.geometry==old.geometry,'damage retains native mesh '..slot) end
    end
    print('[P0Native] damaged part='..removed.id..' rebuilt='..drive.view.joined.surfaceCache.rebuiltParts)
end
function P0ValidateRepair()
    bp:Add(removed);drive.view:SyncBlueprint(bp);vehicle:Dispose();vehicle=BuildVehicle();vehicle:Place({0,0,0},0);drive:Bind(bp,vehicle)
    Check(drive.view.visuals[removed.id]~=nil,'repair restores actual visual')
    Check(drive.view.joined.surfaceCache.parts[removed.id]~=nil,'repair restores exact surface')
    drive.view:SetXray(true);drive.view:SetXray(false)
    -- Put a floor away from the vehicle so no chassis can obscure these rays.
    local floor=scene:CreateChild('CacheFloor');floor.position=Vector3(-40,-.5,0)
    floor:CreateComponent('CollisionShape'):SetBox(Vector3(10,1,10))
    local native=floor:CreateComponent('RigidBody');native.collisionLayer=1
    local body=space:Register(native,{type='ground'});space.world:UpdateCollisions()
    local function Cast() return space:Raycast({40,3,0},{0,-1,0},10,nil,nil,true) end
    local hit=assert(Cast());Check(math.abs(hit.dist-3)<1e-4,'real Bullet static ray hits floor')
    local n=space.staticQueryHits;Check(Cast()~=nil and space.staticQueryHits==n+1,'real static result reused')
    hit.point[2]=90;Check(math.abs(Cast().point[2])<1e-4,'callers cannot mutate cached hit')
    body.setTranslation({x=40,y=-2.5,z=0});space.world:UpdateCollisions()
    Check(math.abs(assert(Cast()).dist-5)<1e-4,'static movement invalidates hit')
    body.setEnabled(false);space.world:UpdateCollisions();Check(Cast()==nil,'static disable invalidates hit')
    body.setEnabled(true);space.world:UpdateCollisions();Check(Cast()~=nil,'static enable invalidates miss')
    body.setBodyType(true);space.world:UpdateCollisions();Check(Cast()==nil,'kinematic conversion invalidates static hit')
    body.setBodyType(false);space.world:UpdateCollisions();Check(Cast()~=nil,'static conversion invalidates miss')
    space:Unregister(native);floor:Dispose();Check(Cast()==nil,'static removal invalidates cached native object')
    print('[P0Native] RESULT assertions='..checks..' cacheHits='..space.staticQueryHits..' cacheMisses='..space.staticQueryMisses)
    return checks
end

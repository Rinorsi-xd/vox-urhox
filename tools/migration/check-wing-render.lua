local Coord=require 'core.Coord';local Rot=require 'core.Rotations';local BP=require 'construction.Blueprint'
local scene,view,space,vehicle,drive=nil,nil,nil,nil,nil
local partNumber=0
local function Part(type,x,y,z,r)
    partNumber=partNumber+1;return {id=partNumber,type=type,pos={x,y,z},rot=r,color=0x48c8ef,_cells=BP.PartCells(type,{x,y,z},r)}
end
local function Setup(type)
    require('urhox-libs/UI').GetRoot():SetVisible(false)
    if drive then drive:Dispose();vehicle:Dispose();scene:Dispose() end
    scene=Scene();scene:CreateComponent('Octree');space=require('physics.Space').New(scene)
    local floor=scene:CreateChild('Floor');floor:CreateComponent('CollisionShape'):SetStaticPlane();space:Register(floor:CreateComponent('RigidBody'),{type='ground'})
    local floorModel=floor:CreateComponent('StaticModel');floorModel.model=cache:GetResource('Model','Models/Plane.mdl');floor:SetScale(150)
    local floorMaterial=Material:new();floorMaterial:SetTechnique(0,cache:GetResource('Technique','Techniques/PBR/PBRNoTexture.xml'));floorMaterial:SetShaderParameter('MatDiffColor',Variant(Color(.18,.22,.24)));floorModel.material=floorMaterial
    local zone=scene:CreateChild('Zone'):CreateComponent('Zone');zone.boundingBox=BoundingBox(Vector3(-1000,-1000,-1000),Vector3(1000,1000,1000));zone.ambientColor=Color(.5,.5,.5)
    local sun=scene:CreateChild('Sun'):CreateComponent('Light');sun.lightType=LIGHT_DIRECTIONAL;sun.node.direction=Vector3(.4,-1,.3)
    local left,right
    for r=0,23 do local n=Rot.ApplyRot(r,{1,0,0});local span=Rot.ApplyRot(r,{0,1,0});if n[2]>.99 and span[1]>.99 then right=r elseif n[2]>.99 and span[1]<-.99 then left=r end end
    local parts={Part('core',0,0,0,0),Part(type,-2,0,0,left),Part(type,2,0,0,right)}
    local spec=require('drive.VehicleSpec').BuildParts(parts,0);vehicle=require('drive.Vehicle').New(space,spec);vehicle:Place({0,10,0},0)
    drive=require('render.DriveView').New(scene,{List=function() return parts end},vehicle);view=drive.view
    local camera=scene:CreateChild('Camera');camera.position=Vector3(15,16,-23);camera:LookAt(Vector3(0,10,0));local cam=camera:CreateComponent('Camera');cam.fov=45;cam.farClip=500;renderer:SetViewport(0,Viewport:new(scene,cam))
    V.assert(#spec.wings==2 and #drive.wings==2,type..' source wing specs bind native segmented display')
    local vis=view.visuals[parts[2].id];local rig=vis.rig.wing
    V.assert(rig and next(rig.nodes) and #vis.emissionModels>0,type..' native source joints and dynamic glow exist')
    for i=1,90 do vehicle:Step({throttle=1,climb=.5,steer=.4},1/60);space:Step(1/60);drive:SavePose();drive:Update(1,1/60) end
    V.assert(vehicle.wingState~=nil and vehicle.telemetry.airspeed~=nil,type..' actual rigid body receives wing telemetry')
    local surfaces={};for name in pairs(rig.nodes) do surfaces[parts[2].id..':'..name]=.8 end;surfaces[parts[2].id..':vanes']=.8
    local state={st={phase='boost',surfaces=surfaces,airspeed=42,stallSpeed=15,brake=.3,throttle=1,airTime=2,controls={.7,0,.7}},partId=parts[2].id,lifting=1}
    for i=1,60 do require('render.WingRig').Update(vis,state,i/60,1/60) end
    local moved=false;for _,n in pairs(rig.nodes) do if math.abs(n.node.rotation.w-1)>.00001 then moved=true end end
    V.assert(moved,type..' actual source flap, sweep, vane or ring moves')
    V.assert(rig.trail and rig.trail.material,type..' native bounded source wingtip trail exists')
    vehicle:Place({0,10,0},0);drive:ResetPose();drive:Update(1,1/60)
end
for i,type in ipairs({'wing2','wing3','wing4','wing5'}) do V.atFrame(45+i*5,function() Setup(type) end) end
V.atFrame(68,function()
    local UI=require 'urhox-libs/UI';UI.SetRoot(UI.Panel{width='100%',height='100%',pointerEvents='none'})
    if VOX_HANGAR then local app=VOX_HANGAR.app;app.Update=function() end;app.loadingFlow.page:Close();app.loadingFlow.active=false end
end)
V.atFrame(70,function() local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/wing-render.png');image:Dispose();V.finish() end)

local Math=require('core.Math3');local Coord=require('core.Coord');local IK=require('parts.MechIK')
local Rot=require('core.Rotations');local BP=require('construction.Blueprint');local Spec=require('drive.VehicleSpec')
local Space=require('physics.Space');local Vehicle=require('drive.Vehicle');local View=require('render.VehicleView');local Mech=require('render.MechView')
local CELL=require('Config').CELL
local scene,space,vehicle,view,mech,equipment;local report={};local maxToe,maxSensor,samples=0,0,0
local function Sync()
    local p,q=vehicle.body.translation(),vehicle.body.rotation();view.root.position=Coord.Vec(p.x,p.y,p.z);view.root.rotation=Quaternion(q.w,q.x,-q.y,-q.z)
end
local function Measure()
    Sync();mech:Update(1,1/60)
    for _,item in ipairs(mech.items) do local s=vehicle.mechStates[item.id]
        if s.grounded then local toe=item.vis.rig.mech.toecap.worldPosition;local target=Coord.Vec(s.foot[1],s.foot[2]+(s.soleLift or 0),s.foot[3]);maxToe=math.max(maxToe,(toe-target).length);samples=samples+1 end
    end
    -- Sensor state was computed before Bullet integration. Recalculate against
    -- the post-integration body so both sides describe this same rendered pose.
    for _,s in pairs(vehicle.mechStates) do if s.foot then
        local q,p=vehicle.body.rotation(),Math.Array(vehicle.body.translation());s.target=vehicle.mechControl:Local(s,s.foot,q,p)
        s.lift=s.soleLift~=0 and Math.Sub(vehicle.mechControl:Local(s,Math.Add(s.foot,{0,s.soleLift,0}),q,p),s.target) or nil
    end end
    vehicle.mechHitboxes:Update()
    for _,box in ipairs(vehicle.mechHitboxes.items) do local vis=view.visuals[box.partId]
        local rendered=vis.rig.mech[box.name]:LocalToWorld(Coord.Vec(table.unpack(box.segmentCenter)))
        local hit=view.root:LocalToWorld(Coord.Vec(table.unpack(Math.Scale(box.center,1/CELL))))
        maxSensor=math.max(maxSensor,(rendered-hit).length)
    end
end
local function Prepare(type)
    if vehicle then if equipment then equipment:Dispose() end;vehicle:Dispose();view:Dispose();scene:Dispose() end
    scene=Scene();scene:CreateComponent('Octree');space=Space.New(scene)
    local floor=scene:CreateChild('Floor');floor:CreateComponent('CollisionShape'):SetStaticPlane();space:Register(floor:CreateComponent('RigidBody'),{type='ground'})
    local model=floor:CreateComponent('StaticModel');model.model=cache:GetResource('Model','Models/Plane.mdl');floor:SetScale(150)
    local zone=scene:CreateChild('Zone'):CreateComponent('Zone');zone.boundingBox=BoundingBox(Vector3(-1000,-1000,-1000),Vector3(1000,1000,1000));zone.ambientColor=Color(.5,.5,.5)
    local light=scene:CreateChild('Sun'):CreateComponent('Light');light.lightType=LIGHT_DIRECTIONAL;light.node.direction=Vector3(.4,-1,.3)
    local parts,rotation={},0;for r=0,23 do if Rot.ApplyRot(r,{0,1,0})[2]<-.99 and Rot.ApplyRot(r,{0,0,1})[3]>.99 then rotation=r;break end end
    local function Add(t,x,y,z,r) parts[#parts+1]={id=#parts+1,type=t,pos={x,y,z},rot=r or 0,color=0x5bbfcf,_cells=BP.PartCells(t,{x,y,z},r or 0)} end
    for x=-4,4 do for z=-2,2 do Add(x==0 and z==0 and 'core' or 'cube',x,1,z) end end
    Add(type,-4,0,0,rotation);Add(type,4,0,0,rotation)
    vehicle=Vehicle.New(space,Spec.BuildParts(parts,0));vehicle:Place({0,0,0},0)
    view=View.New(scene);view:Rebuild({List=function() return parts end});mech=Mech.New(view,vehicle)
    local camera=scene:CreateChild('Camera');camera.position=Vector3(17,12,-22);camera:LookAt(Vector3(0,4,0));local cam=camera:CreateComponent('Camera');cam.fov=50;cam.farClip=500
    renderer:SetViewport(0,Viewport:new(scene,cam));maxToe,maxSensor,samples=0,0,0
end
for index,type in ipairs({'mech3','mech4','mech5'}) do
    V.atFrame(45+index*10,function()
        Prepare(type)
        for i=1,240 do vehicle:Step({},1/60);space:Step(1/60) end
        for i=1,90 do vehicle:Step({throttle=.5},1/60);space:Step(1/60);Measure() end
        V.assert(#mech.items==2,type..' actual native segmented rig is bound')
        V.assert(samples>70 and maxToe<.025,type..' actual rendered planted toe matches support plus sole lift')
        V.assert(maxSensor<.001,type..' actual rendered segment centers match animated hit sensors')
        local state=vehicle.mechStates[mech.items[1].id]
        local grounded,previous,foot=state.grounded,state.previous,state.foot
        state.grounded=false;state.previous=Math.Sub(foot,{.4,.2,.6})
        mech:Update(.5,1/60)
        local toe=mech.items[1].vis.rig.mech.toecap.worldPosition
        local expected=Coord.Vec(table.unpack(Math.Add(Math.Mix(state.previous,foot,.5),{0,state.soleLift or 0,0})))
        V.assert((toe-expected).length<.025,type..' airborne segmented rig interpolates a real previous foot pose')
        state.grounded=grounded;state.previous=previous;mech:Update(1,1/60)
        report[type]={samples=samples,maxToe=maxToe,maxSensor=maxSensor}
        local p=vehicle.body.translation();local camera=scene:GetChild('Camera');local target=Coord.Vec(p.x,p.y+3,p.z)
        camera.position=target+Vector3(17,9,-22);camera:LookAt(target)
    end)
end
V.atFrame(85,function()
    if VOX_HANGAR and VOX_HANGAR.app then
        local app=VOX_HANGAR.app;app.loadingFlow:Close();app.Update=function() end
    end
    require('urhox-libs/UI').SetRoot(nil)
    renderer:SetViewport(0,Viewport:new(scene,scene:GetChild('Camera'):GetComponent('Camera')))
    equipment=require('render.EquipmentEffects').New(scene);equipment:Bind(view,vehicle)
    for _,s in pairs(vehicle.mechStates) do s.qaJet=s.jet;s.qaPulse=s.pulse;s.jet=1;s.pulse=.8 end
    mech:Update(1,1/60);equipment:Update(1/60,{camera=scene:GetChild('Camera'),time=1,fov=50})
    local proxies,shieldSlots,emissionSlots=0,0,0
    for _,item in pairs(equipment.items) do for _,proxy in pairs(item.proxies) do if proxy.model.enabled then proxies=proxies+1 end end end
    for _,item in ipairs(mech.items) do shieldSlots=shieldSlots+#item.vis.shieldModels;emissionSlots=emissionSlots+#item.vis.emissionModels end
    V.assert(proxies>0,'actual T5 knee nozzle proxies created from forced jet output')
    V.assert(shieldSlots>0 and emissionSlots==0,'mech shield pulse slots avoid generic dynamic emission overwrites')
    report.effects={proxies=proxies,shieldModels=shieldSlots,dynamicEmissionModels=emissionSlots}
end)
V.atFrame(95,function()
    for _,s in pairs(vehicle.mechStates) do s.jet=s.qaJet;s.pulse=s.qaPulse;s.qaJet=nil;s.qaPulse=nil end
    mech:Update(1,1/60);equipment:Update(1/60,{camera=scene:GetChild('Camera'),time=1.1,fov=50})
    local f=assert(io.open('docs/migration/evidence/mech-render-measurements.json','w'));f:write(cjson.encode(report));f:close()
    V.finish()
end)

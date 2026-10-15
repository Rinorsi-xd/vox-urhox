local Collision=require 'audio.CollisionAudio'
local Space=require 'physics.Space'
local scene=Scene();local space=Space.New(scene)
local function Box(name,pos,size,mass,offset)
    local node=scene:CreateChild(name);node.position=pos
    local native=node:CreateComponent('RigidBody');native.friction=0;native.restitution=0
    node:CreateComponent('CollisionShape'):SetBox(size,offset or Vector3.ZERO);native.mass=mass
    return {vehicle={node=node,body=space:Register(native,{type='fixture'})}}
end
local function Remove(unit)
    local vehicle=unit.vehicle
    space:Unregister(vehicle.body.native);vehicle.node:Dispose();unit.vehicle=nil
end
V.atFrame(2,function()
    local file=File:new('.tmp/source-collision-audio.json',FILE_READ)
    local source=cjson.decode(file:ReadString());file:Dispose()
    for i,case in ipairs(source.cases) do
        local detector=Collision.New();local unit=Box('Rules',Vector3(0,20,0),Vector3.ONE,1)
        detector:BeforeStep({unit});detector.entries[unit].side=math.abs(case.normal)<.6
        if case.age then detector.last[unit]=10-case.age end
        unit.vehicle.body.setLinvel({x=case.delta,y=0,z=0})
        local retired=unit.vehicle
        if case.dead then unit.vehicle=nil elseif case.rebuild then unit.vehicle={body={}} end
        local events={};detector:AfterStep(10,events)
        V.assert(#events==case.count,'frozen original collision rule '..i)
        if #events>0 then V.assert(math.abs(events[1].strength-case.strength)<1e-6,'original collision strength '..i) end
        unit.vehicle=retired;detector:Dispose();Remove(unit)
    end
    Box('Wall',Vector3(0,2,4),Vector3(10,8,1),0)
    local unit=Box('Impact',Vector3(0,2,0),Vector3.ONE,10,Vector3(1,0,0))
    local detector=Collision.New();unit.vehicle.body.setLinvel({x=0,y=0,z=20})
    local events={}
    for i=1,25 do detector:BeforeStep({unit});space:Step(1/60);detector:AfterStep(i/60,events) end
    V.assert(#events>0 and events[1].type=='vehicleCollision' and events[1].strength>0,'actual Bullet wall contact and velocity jump produce original cue')
    V.assert(#events==1,'persistent actual wall contact does not retrigger without another substantial delta')
    local center=unit.vehicle.body.center();local origin=unit.vehicle.body.translation()
    V.assert(math.abs(events[1].pos[1]-center.x)<.01 and math.abs(center.x-origin.x)>.5,'impact audio uses actual world COM like source unit.pos, including an offset compound body')
    local feedback=require('audio.CombatFeedbackAudio').New(scene);feedback.focus=function() return true end
    feedback:SetActive(true);feedback:Consume(events)
    V.assert(feedback.counts.vehicle_collision==1,'actual wall cue reaches original bounded feedback SoundSource')
    local view=require('render.CombatView').New(scene)
    local pending={viewEvents=events,debris={events={}}}
    V.assert(events[1].unit==unit,'collision carries the actual unit required by shared event consumers')
    view:Consume(pending);view:Dispose()
    V.assert(#pending.viewEvents==0,'actual combat renderer consumes collision event without creating a vehicle or retaining the batch')
    detector:Dispose();detector:Dispose();feedback:Dispose();Remove(unit)
    Box('Floor',Vector3(20,-.5,0),Vector3(10,1,10),0)
    local falling=Box('Landing',Vector3(20,2,0),Vector3.ONE,10)
    local floor=Collision.New();falling.vehicle.body.setLinvel({x=0,y=-12,z=0});local landing={}
    for i=1,35 do floor:BeforeStep({falling});space:Step(1/60);floor:AfterStep(i/60,landing) end
    V.assert(#landing==0,'actual vertical landing does not produce side-collision audio')
    local braking=Box('AirBrake',Vector3(40,20,0),Vector3.ONE,10);local brake=Collision.New()
    braking.vehicle.body.setLinvel({x=10,y=0,z=0});brake:BeforeStep({braking})
    braking.vehicle.body.setLinvel({x=0,y=0,z=0});local silent={};brake:AfterStep(1,silent)
    V.assert(#silent==0,'horizontal deceleration without actual side contact stays silent')
    Remove(braking);brake:BeforeStep({braking});brake:Dispose()
    V.assert(next(brake.entries)==nil,'destroyed-body subscriptions and repeated disposal release retained owners')
    floor:Dispose();Remove(falling);space:Dispose();scene:Dispose();V.finish()
end)

local scene=Scene()
local world=scene:CreateComponent('PhysicsWorld')
world.updateEnabled=false;world.gravity=Vector3.ZERO
V.atFrame(5,function()
    -- Sweep a .5 m box from z=0 to z=10, stopping at the front of a 1 m wall.
    -- Own overlapping chassis must be excluded; a second sweep starts in a wall.
    local wall=scene:CreateChild('Wall');wall.position=Vector3(0,0,5)
    wall:CreateComponent('CollisionShape'):SetBox(Vector3.ONE)
    local body=wall:CreateComponent('RigidBody');body.collisionLayer=1
    local own=scene:CreateChild('Own');own:CreateComponent('CollisionShape'):SetBox(Vector3(3,3,3))
    local chassis=own:CreateComponent('RigidBody');chassis.mass=100;chassis.collisionLayer=2
    local probe=scene:CreateChild('Query');local shape=probe:CreateComponent('CollisionShape')
    shape:SetBox(Vector3(.5,.5,.5));shape.margin=.001
    world:Update(1/60)
    local hit=world:ConvexCast(shape,Vector3.ZERO,Quaternion.IDENTITY,Vector3(0,0,10),Quaternion.IDENTITY,1)
    print('DRILL_CAST',hit.body==body,hit.distance,hit.hitFraction,hit.position,hit.normal)
    V.assert(hit.body==body and math.abs(hit.hitFraction-.425)<.01,'native convex cast accepts a shape without a body')
    V.assert(math.abs(hit.distance-4.25)<.1,'native sweep distance is travel distance')
    local layer=chassis.collisionLayer;chassis.collisionLayer=0
    local filtered=world:ConvexCast(shape,Vector3.ZERO,Quaternion.IDENTITY,Vector3(0,0,10),Quaternion.IDENTITY)
    chassis.collisionLayer=layer
    V.assert(filtered.body==body and chassis.collisionLayer==2,'temporary exclusion restores chassis collision layer')
    local overlap=world:ConvexCast(shape,Vector3(0,0,4.4),Quaternion.IDENTITY,Vector3(0,0,5),Quaternion.IDENTITY,1)
    print('DRILL_OVERLAP',overlap.body==body,overlap.distance,overlap.hitFraction)
    V.assert(overlap.body==body and overlap.hitFraction==0,'initial overlap reports immediate contact')
    chassis.kinematic=true;own.position=Vector3(4,2,1);chassis.position=own.position
    world:Update(1/60)
    V.assert((chassis.position-own.position).length<.001,'kinematic pose survives physics step')
    chassis.kinematic=false
    V.assert(not chassis.kinematic and chassis.mass==100,'dynamic restoration preserves mass')
    scene:Dispose();V.finish()
end)

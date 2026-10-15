local scene=nil ---@type Scene|nil
V.atFrame(3,function()
    scene=Scene();local world=scene:CreateComponent('PhysicsWorld');world.updateEnabled=false
    local solid=scene:CreateChild('SolidBox');solid.position=Vector3(0,1,0)
    solid:CreateComponent('CollisionShape'):SetBox(Vector3(2,2,2))
    local obstacle=solid:CreateComponent('RigidBody');obstacle.collisionLayer=1
    local moving=scene:CreateChild('DynamicBox');moving.position=Vector3(7,1,0)
    moving:CreateComponent('CollisionShape'):SetBox(Vector3(2,2,2))
    local dynamic=moving:CreateComponent('RigidBody');dynamic.mass=10;dynamic.useGravity=false;dynamic.collisionLayer=2
    local query=scene:CreateChild('ResetQuery');query.position=Vector3(0,1,0)
    query:CreateComponent('CollisionShape'):SetBox(Vector3(2,2,2))
    local body=query:CreateComponent('RigidBody');body.trigger=true;body.collisionLayer=0;body.collisionMask=0xffff;body.collisionEventMode=COLLISION_NEVER
    local function List(label)
        local found={};for _,b in ipairs(world:GetRigidBodies(body)) do found[#found+1]=b.node.name end
        print('[ResetOverlapProbe] '..label..' '..cjson.encode(found));return found
    end
    V.assert(#List('static layer0')==1,'GetRigidBodies(body) detects static geometry with query layer0')
    body.enabled=false;V.assert(#List('disabled')==1,'Disabled query remains a shape-only contact test')
    body.position=Vector3(20,1,0);V.assert(#List('disabled moved')==0,'Disabled query moved transform updates overlap')
    body.position=Vector3(7,1,0);V.assert(#List('disabled dynamic')==1,'Disabled query detects actual dynamic body')
    world:Update(1/60)
    V.assert(dynamic.linearVelocity:Length()<1e-7 and (dynamic.position-Vector3(7,1,0)):Length()<1e-6,'Shape query produces no physical displacement or impulse')
    scene:Dispose();scene=nil;V.finish()
end)

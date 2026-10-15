local BP=require 'construction.Blueprint'
local Defs=require('parts.Defs').PARTS
local Prefab=require 'construction.Prefab'
local Space=require 'physics.Space'
local Vehicle=require 'drive.Vehicle'
local Unit=require 'combat.CarUnit'
local cases={'wing','mech'}
local index=0
local exercise=nil ---@type thread|nil
local scene=nil ---@type Scene|nil
local function Blueprint(kind)
    if kind=='wing' then return Prefab.Create(BP.New(),'feather') end
    local bp=BP.New()
    for x=-4,4 do for z=-2,2 do bp:Add({type=x==0 and z==0 and 'core' or 'cube',pos={x,3,z},rot=0,color=0x38aaff}) end end
    local rot
    for i=0,23 do local up=require('core.Rotations').ApplyRot(i,{0,1,0});local f=require('core.Rotations').ApplyRot(i,{0,0,1})
        if up[2]<-.99 and f[3]>.99 then rot=i;break end
    end
    for _,x in ipairs({-4,4}) do bp:Add({type='mech3',pos={x,2,0},rot=assert(rot),color=0x38aaff}) end
    bp:Add({type='laser1',pos={0,4,0},rot=0,color=0x38aaff})
    return bp
end
local function Run(kind)
    scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene)
    local floor=scene:CreateChild('Floor');floor:CreateComponent('CollisionShape'):SetStaticPlane()
    space:Register(floor:CreateComponent('RigidBody'),{type='ground'})
    local env={time=0,viewEvents={},fx={},debris=require('combat.Debris').New(space),RecordDamage=function()end,RecordKill=function()end}
    function env:NewVehicle(spec,unit)
        local v=Vehicle.New(space,spec);space.bodies[v.node:GetID()].owner={type='car',ref=unit};return v
    end
    local unit=Unit.New(env,Blueprint(kind):ToTable(),{name='rebuild-'..kind,spawn={pos={0,20,0},yaw=.3},combat=true,autoRespawn=false})
    local old=unit.vehicle;old.body.setLinvel({x=2,y=1,z=18});old.body.setAngvel({x=.1,y=.2,z=.05})
    for i=1,60 do old:Step({throttle=1,steer=.3},1/60);space:Step(1/60);if i%5==0 then coroutine.yield() end end
    local keep={}
    for _,p in ipairs(unit.bp:List()) do
        local def=Defs[p.type]
        if def.cat=='weapon' or def.cat=='movement' and not p.type:match(kind=='wing' and '^wing' or '^mech') then keep[#keep+1]=p.id end
    end
    V.assert(#keep>0,kind..' actual source vehicle starts with removable weapons or actuators')
    for _,id in ipairs(keep) do unit:Destroy(id) end
    local before=old:GetState();local mass=old.mass;local weapons=unit.weapons
    unit:Flush()
    V.assert(unit.alive and unit.vehicle~=old and old.disposed,kind..' losing all weapons retains real remaining movement and retires old body')
    if not unit.alive then scene:Dispose();scene=nil;return end
    local current=unit.vehicle:GetState()
    V.assert(unit.vehicle.mass<mass and unit.weapons==weapons,kind..' actual rebuild reduces mass without resetting weapon-system ownership')
    for _,key in ipairs({'p','q','lv','av'}) do
        local same=true;for k,value in pairs(before[key]) do if math.abs(current[key][k]-value)>1e-5 then same=false end end
        V.assert(same,kind..' actual rebuild preserves '..key)
    end
    if kind=='wing' then
        V.assert(#unit.spec.wings>0 and unit.vehicle.wingState~=nil and current.wing.phase==before.wing.phase,kind..' surviving flight controller retains its phase')
    else
        V.assert(#unit.spec.mechLegs==2 and unit.vehicle.mechControl~=nil and current.mech.phase==before.mech.phase,kind..' surviving mechanical feet retain controller phase')
    end
    for i=1,60 do unit.vehicle:Step({throttle=1},1/60);space:Step(1/60);if i%5==0 then coroutine.yield() end end
    local p=unit.vehicle.body.translation()
    V.assert(p.x==p.x and p.y==p.y and p.z==p.z,kind..' damaged native body continues finite physical simulation')
    unit:Dispose();env.debris:Clear();scene:Dispose();scene=nil
end
for frame=47,180 do V.atFrame(frame,function()
    if not exercise or coroutine.status(exercise)=='dead' then
        index=index+1;if index>#cases then return end
        exercise=coroutine.create(function()Run(cases[index])end)
    end
    if coroutine.status(exercise)~='dead' then local ok,err=coroutine.resume(exercise);assert(ok,err) end
end)end
V.atFrame(185,function()V.assert(index>#cases,'both actual damaged movement families completed');V.finish()end)

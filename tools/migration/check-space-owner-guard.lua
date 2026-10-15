-- Real Lua modules, native-free world/body doubles. No claim about Bullet timing.
package.path='scripts/?.lua;'..package.path
Vector3=function(x,y,z) return {x=x,y=y,z=z} end
package.loaded['core.Coord']={Vec=Vector3}
package.loaded['physics.Body']={Wrap=function(native)
    local valid=true
    return {native=native,isValid=function() return valid end,invalidate=function() valid=false end}
end}
local current=require 'physics.Space'
local baseline=assert(loadfile(SPACE_BASELINE_ROOT..'/scripts/physics/Space.lua'))()
local rawPairs=pairs
local checks=0
local function Check(ok,label) checks=checks+1;assert(ok,label) end
local function Equal(a,b,label)
    Check(type(a)==type(b),label..' type')
    if type(a)=='table' then
        for k,v in rawPairs(a) do Equal(v,b[k],label..'.'..tostring(k)) end
        for k in rawPairs(b) do Check(a[k]~=nil,label..' extra '..tostring(k)) end
    else Check(a==b,label..' value') end
end
local function Fixture(module)
    local f={log={},natives={},owners={},scans=0,visits=0,updates=0,updateHook=false}
    local world={Update=function(_,dt)
        f.updates=f.updates+1;f.log[#f.log+1]='update:'..dt
        if f.updateHook then f.updateHook();f.updateHook=false end
    end}
    f.space=module.New({GetComponent=function() return world end})
    function f:Register(id,kind,hasRef)
        local native={node={GetID=function() return id end}}
        local owner=kind and {type=kind} or nil
        if owner and hasRef~=false then owner.ref={PostStep=function() f.log[#f.log+1]='post:'..id end} end
        f.natives[id]=native;f.owners[id]=owner
        return self.space:Register(native,owner)
    end
    function f:SetOwner(id,kind,hasRef)
        local owner=kind and {type=kind} or nil
        if owner and hasRef~=false then owner.ref={PostStep=function() f.log[#f.log+1]='post:'..id end} end
        if module.SetOwner then self.space:SetOwner(self.natives[id],owner)
        else self.space.bodies[id].owner=owner end
        self.owners[id]=owner
    end
    return f
end
local before,after=Fixture(baseline),Fixture(current)
local function Both(fn) fn(before);fn(after) end
local function Compare(label)
    Equal(before.log,after.log,label..' calls/order')
    Equal(before.updates,after.updates,label..' native updates')
    local vehicles=0
    for id,entry in rawPairs(after.space.bodies) do
        local old=before.space.bodies[id]
        Check(old~=nil,label..' same id')
        Check((entry.owner and entry.owner.type)==(old.owner and old.owner.type),label..' owner')
        Check(entry.body.isValid()==old.body.isValid(),label..' validity')
        if entry.owner and entry.owner.type=='vehicle' then vehicles=vehicles+1 end
    end
    Check(after.space.vehicleOwners==vehicles,label..' owner count')
end
pairs=function(t)
    local f=t==before.space.bodies and before or t==after.space.bodies and after
    if not f then return rawPairs(t) end
    f.scans=f.scans+1
    local iterator,state,key=rawPairs(t)
    return function(s,k)
        local nextKey,value=iterator(s,k)
        if nextKey~=nil then f.visits=f.visits+1 end
        return nextKey,value
    end,state,key
end

Both(function(f) for i=1,1500 do f:Register(i*7,'ground') end end)
Both(function(f) for i=1,6 do f:Register(20000+i,'vehicle') end end)
Compare('registered')
Both(function(f) f.space:Step(1/60) end);Compare('vehicle step')
Check(before.visits==after.visits,'vehicle path retains full pairs traversal')
Both(function(f) for i=1,6 do f:SetOwner(20000+i,'car') end end)
Compare('combat ownership')
local oldVisits,newVisits=before.visits,after.visits
Both(function(f) for _=1,600 do f.space:Step(1/60) end end)
Compare('600 combat steps')
Check(before.visits-oldVisits==1506*600,'baseline scans every registered body')
Check(after.visits==newVisits,'zero vehicle owners skips all body scans')
local removedVisits=before.visits-oldVisits

Both(function(f) f:SetOwner(20001,'vehicle');f:SetOwner(20001,'vehicle');f.space:Step(.02) end)
Compare('car to vehicle and same owner kind')
Both(function(f) f:SetOwner(20001,'car');f:SetOwner(20002,'vehicle',false);f.space:Step(.03) end)
Compare('vehicle without ref')
Both(function(f) f:SetOwner(20002,nil);f.space:Step(.04) end);Compare('nil owner')
Both(function(f) f:SetOwner(20003,'vehicle');f:Register(20003,'car');f.space:Step(.05) end)
Compare('reregister vehicle as car')
Both(function(f) f:Register(20004,'vehicle');f:Register(20004,'vehicle');f.space:Step(.06) end)
Compare('reregister vehicle as vehicle')
Both(function(f) f:Register(20005,'ground');f:Register(20005,'vehicle');f.space:Step(.07) end)
Compare('reregister ground as vehicle')
Both(function(f)
    local native=f.natives[20004];f.space:Unregister(native);f.space:Unregister(native)
    f.space:Unregister(f.natives[20005]);f.space:Step(.08)
end)
Compare('duplicate unregister')
Both(function(f)
    f.updateHook=function() f:SetOwner(20001,'vehicle') end
    f.space:Step(.09)
end)
Compare('owner added by world update')
Both(function(f)
    f.updateHook=function() f:SetOwner(20001,'car') end
    f.space:Step(.1)
end)
Compare('owner removed by world update')
local count=after.space.vehicleOwners
local ok=pcall(function() after.space:SetOwner({node={GetID=function() return -1 end}},{type='vehicle'}) end)
Check(not ok and after.space.vehicleOwners==count,'unknown owner fails without count mutation')

-- Exercise the actual world integration method, rather than matching its text.
package.loaded['scene.TrackAssets']={}
package.loaded['combat.CarUnit']={}
package.loaded['combat.Debris']={}
package.loaded['combat.VehicleRay']={}
package.loaded['drive.Vehicle']={New=function(space)
    local native={node={GetID=function() return 30001 end}}
    local vehicle={native=native,node=native.node}
    vehicle.body=space:Register(native,{type='vehicle',ref=vehicle})
    return vehicle
end}
local track=require 'drive.TrackWorld'
local unit={name='integration'}
local vehicle=track.NewVehicle({space=after.space},{},unit)
Check(after.space.bodies[30001].owner.type=='car','actual NewVehicle sets car')
Check(after.space.bodies[30001].owner.ref==unit,'actual NewVehicle retains unit identity')
Check(after.space.bodies[30001].body==vehicle.body,'actual NewVehicle retains body binding')
Check(after.space.vehicleOwners==0,'actual NewVehicle removes transient vehicle owner')
after.space:Unregister(vehicle.native)

Both(function(f) f:Register(40001,'vehicle');f:Register(40002,'vehicle',false);f:Register(40003,nil) end)
Compare('dispose setup')
local retained={}
for _,entry in rawPairs(after.space.bodies) do retained[#retained+1]=entry.body end
Both(function(f) f.space:Dispose();f.space:Dispose() end)
Check(after.space.vehicleOwners==0,'dispose resets count')
Check(next(after.space.bodies)==nil and after.space.world==nil and after.space.scene==nil,'dispose removes owners and world')
for _,body in ipairs(retained) do Check(not body.isValid(),'dispose invalidates retained wrapper') end
pairs=rawPairs
return {result='PASS',assertions=checks,baselineEmptyScanVisits=removedVisits,candidateEmptyScanVisits=0,
    fixedUpdates=600,staticBodies=1500,combatCars=6,nativePhysicsTested=false,
    limitations='Native-free actual Lua equivalence; no Bullet, Web frame-time or target-device acceptance.'}

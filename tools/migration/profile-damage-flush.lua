-- Attribution only: actual production Lua with native factories excluded.
-- These timings cannot sign native/Web/device frame-time acceptance.
local BP=require 'construction.Blueprint'
local Unit=require 'combat.CarUnit'
local Spec=require 'drive.VehicleSpec'
local Prefab=require 'construction.Prefab'
local samples={}
local active
local stack={}
local function Observe(module,key,label)
    local original=assert(module[key],label)
    module[key]=function(...)
        if not active then return original(...) end
        local frame={at=os.clock(),child=0};stack[#stack+1]=frame
        local result=table.pack(original(...));local elapsed=os.clock()-frame.at
        stack[#stack]=nil
        local parent=stack[#stack];if parent then parent.child=parent.child+elapsed end
        local row=active[label] or {calls=0,inclusiveMs=0,exclusiveMs=0}
        row.calls=row.calls+1;row.inclusiveMs=row.inclusiveMs+elapsed*1000
        row.exclusiveMs=row.exclusiveMs+(elapsed-frame.child)*1000;active[label]=row
        return table.unpack(result,1,result.n)
    end
end
for _,key in ipairs({'Graph','Connectivity','List','Size'}) do Observe(BP,key,'Blueprint.'..key) end
for _,key in ipairs({'Build','BuildParts','MergeBoxes'}) do Observe(Spec,key,'VehicleSpec.'..key) end
Observe(require('construction.Rotors'),'Spec','Rotors.Spec')
Observe(require('construction.TurretRange'),'For','TurretRange.For')
for _,key in ipairs({'Budget','LostCombatAbility','Build'}) do Observe(Unit,key,'CarUnit.'..key) end
local function Environment()
    local env={time=0,fx={},viewEvents={},debris={Spawn=function() end}}
    function env:RecordDamage() end
    function env:RecordKill() end
    function env:NewVehicle(spec)
        local state={p={x=1,y=30,z=2},q={x=0,y=0,z=0,w=1},lv={x=2,y=1,z=3},av={x=.1,y=.2,z=.05}}
        local vehicle={spec=spec,rotors={},body={}}
        function vehicle:Place() end
        function vehicle:GetState() return state end
        function vehicle:SetState(value) state=value end
        function vehicle:Dispose() end
        vehicle.body.translation=function() return state.p end
        vehicle.body.rotation=function() return state.q end
        vehicle.body.center=function() return state.p end
        vehicle.body.velocityAtPoint=function() return {x=2,y=1,z=3} end
        return vehicle
    end
    return env
end
for _,name in ipairs({'raceCar','megaMech'}) do
    local bp=Prefab.Create(BP.New(),name);local env=Environment()
    local unit=Unit.New(env,bp:ToTable(),{name=name,spawn={pos={0,30,0},yaw=.3},combat=false,autoRespawn=false,externalControl=true})
    for step=1,3 do
        local parts=unit.bp:List();local id
        for i=#parts,1,-1 do if parts[i].type~='core' then id=parts[i].id;break end end
        local part=assert(unit.bp.parts[id]);local count=unit.bp:Size()
        unit:Damage(id,1e9,{0,30,0});active={};local start=os.clock();unit:Flush();local elapsed=(os.clock()-start)*1000
        samples[#samples+1]={name=name,step=step,parts=count,removedType=part.type,totalMs=elapsed,segments=active}
        active=nil
        assert(unit.alive,'profiling fixture must stay alive')
    end
    unit:Dispose()
end
return samples

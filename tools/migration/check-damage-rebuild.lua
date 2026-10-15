local BP=require 'construction.Blueprint'
local Spec=require 'drive.VehicleSpec'
local Turret=require 'construction.TurretRange'
local Unit=require 'combat.CarUnit'
local Prefab=require 'construction.Prefab'
local checks={}
local function Check(value,name) assert(value,name);checks[#checks+1]=name end
local function Equal(a,b,path)
    path=path or 'value'
    if type(a)~=type(b) then return false,path..' type' end
    if type(a)=='number' then return a==b or math.abs(a-b)<1e-8*math.max(1,math.abs(b)),path end
    if type(a)~='table' then return a==b,path end
    for k,v in pairs(a) do local ok,why=Equal(v,b[k],path..'.'..tostring(k));if not ok then return false,why end end
    for k in pairs(b) do if a[k]==nil then return false,path..' missing '..tostring(k) end end
    return true,path
end
local function Same(a,b,name) local ok,why=Equal(a,b);Check(ok,name..': '..why) end
local before={}
local function Before(name)
    local key=name:gsub('%.','/')
    if not damage_before[key] then return require(name) end
    if not before[key] then
        local env=setmetatable({require=Before},{__index=_G})
        before[key]=assert(load(damage_before[key],'before/'..key,'t',env))()
    end
    return before[key]
end
local oldBP,oldSpec,oldTurret,oldUnit=Before('construction.Blueprint'),Before('drive.VehicleSpec'),Before('construction.TurretRange'),Before('combat.CarUnit')
local function GraphCheck(bp,label)
    Same(bp:Graph(),oldBP.Graph(bp),label..' graph equals full fresh socket query')
    local graph=bp:Graph()
    Same(bp:Connectivity(graph),bp:Connectivity(oldBP.Graph(bp)),label..' connectivity equals fresh')
    local core=bp:CoreParts()[1]
    if core then graph[core.id]={[-999]=true};Same(bp:Graph(),oldBP.Graph(bp),label..' mutable caller graph never corrupts cache') end
end
for _,name in ipairs({'raceCar','megaMech','scorpion','hawk','feather','vanguard','tianyuan','fuyuan','fox','trooper'}) do
    local bp=Prefab.Create(BP.New(),name);GraphCheck(bp,name..' pristine')
    local list=bp:List()
    local neighborsCalls=0;local fresh=bp.Neighbors
    bp.Neighbors=function(self,...) neighborsCalls=neighborsCalls+1;return fresh(self,...) end
    bp:Graph();Check(neighborsCalls==0,name..' unchanged graph computes no sockets')
    for step=1,math.min(16,#list) do
        local id=list[step].id;local removed=bp:Remove(id);local previousCalls=neighborsCalls
        bp:Graph();Check(neighborsCalls==previousCalls,name..' deletion updates existing edges without rescanning sockets '..step)
        GraphCheck(bp,name..' remove '..step)
        bp:Add(removed);GraphCheck(bp,name..' restore '..step)
    end
    bp:Clear();GraphCheck(bp,name..' clear')
    bp:Add({type='core',pos={0,0,0}});GraphCheck(bp,name..' new core after clear')
end
for i,c in ipairs(fixture.turrets) do
    local bp=BP.New();for _,p in ipairs(c.parts) do bp:Add(p) end
    local owner={};for id,value in pairs(c.owner) do owner[tonumber(id)]=value end
    local function Verify(label)
        local actual=Turret.For(bp,owner);local expected={}
        for _,p in ipairs(bp:List()) do if require('parts.Defs').PARTS[p.type].weapon then expected[p.id]=oldTurret.Compute(bp:List(),p,owner) end end
        Same(actual,expected,'turret '..i..' '..label)
        return actual
    end
    local pristine=Verify('pristine');Verify('repeat')
    local remote=bp:Add({type='cube',pos={600,0,600}});local withRemote=Verify('remote insert')
    for id,range in pairs(pristine) do Check(withRemote[id]==range,'remote occupancy reuses exact turret range object '..i..'/'..id) end
    bp:Remove(remote.id);Verify('remote removal')
    for _,p in ipairs(bp:List()) do if p.id~=1 then
        bp:Remove(p.id);Verify('remove '..p.id)
        bp:Add(p);Verify('restore '..p.id)
        owner[p.id]=765;Verify('owner change '..p.id)
        owner[p.id]=nil;Verify('owner restore '..p.id)
        break
    end end
end
local function Environment()
    local env={time=0,viewEvents={},units={},fx={},created=0,disposed=0,debrisLog={},damageLog={},killLog={}}
    local seed=31337
    env.random=function() seed=(seed*48271)%2147483647;return seed/2147483647 end
    function env:NewVehicle(spec)
        self.created=self.created+1
        local state={p={x=1,y=3,z=2},q={x=0,y=0,z=0,w=1},lv={x=4,y=0,z=2},av={x=0,y=.2,z=0}}
        local vehicle={spec=spec,rotors={},com={0,0,0}}
        vehicle.body={translation=function() return state.p end,rotation=function() return state.q end,center=function() return state.p end,
            velocityAtPoint=function(p) return {x=4+p.z*.2,y=0,z=2-p.x*.2} end}
        function vehicle:Place() end
        function vehicle:GetState() return state end
        function vehicle:SetState(s) state=s end
        function vehicle:Dispose() env.disposed=env.disposed+1 end
        return vehicle
    end
    env.debris={Spawn=function(_,parts,pose,velocity,kick)
        local ids={};for _,p in ipairs(parts) do ids[#ids+1]=p.id end
        env.debrisLog[#env.debrisLog+1]={ids=ids,pose=pose,velocity=velocity({1,2,3}),kick=kick}
    end}
    function env:RecordDamage(_,amount,point,opts) self.damageLog[#self.damageLog+1]={amount=amount,point=point,opts=opts} end
    function env:RecordKill(unit,pos) self.killLog[#self.killLog+1]={name=unit.name,pos=pos} end
    return env
end
local function Snapshot(unit,env)
    local events={};for _,e in ipairs(env.viewEvents) do local copy={};for key,value in pairs(e) do if key~='unit' then copy[key]=value end end;events[#events+1]=copy end
    return {blueprint=unit.bp:ToTable(),hp=unit.hp,shields=unit.shields,alive=unit.alive,kill=unit.kill,dirty=unit.dirty,
        lostCells=unit.lostCells,lostMajor=unit.lostMajor,budget=unit:Budget(),life=unit:Life(),spec=unit.spec,
        bodyHp=unit.bodyHp,bodyHpMax=unit.bodyHpMax,struct=unit.struct,structMax=unit.structMax,hitAt=unit.hitAt,
        weapons=unit.weapons and {groups=unit.weapons.groups,energy=unit.weapons.energy,current=unit.weapons.current,time=unit.weapons.time} or false,
        events=events,debris=env.debrisLog,damage=env.damageLog,kills=env.killLog,created=env.created,disposed=env.disposed,
        state=unit.vehicle and unit.vehicle:GetState() or false}
end
damage_benchmarks={}
for _,name in ipairs({'raceCar','megaMech','scorpion','hawk','feather','vanguard','tianyuan','fuyuan','fox','trooper'}) do
    local source=Prefab.Create(BP.New(),name):ToTable()
    local oldEnv,newEnv=Environment(),Environment()
    local cfg={name=name,spawn={pos={0,0,0},yaw=0},externalControl=true}
    local a,b=oldUnit.New(oldEnv,source,cfg),Unit.New(newEnv,source,cfg)
    Same(Snapshot(b,newEnv),Snapshot(a,oldEnv),'pristine unit '..name)
    local ids={};for _,p in ipairs(b.bp:List()) do if p.type~='core' then ids[#ids+1]=p.id end end
    local elapsedBefore,elapsedAfter=0,0
    for step=1,math.min(12,#ids) do
        local id=ids[#ids-step+1]
        oldEnv.time=step*.25;newEnv.time=oldEnv.time
        if a.alive and a.bp.parts[id] then
            a:Damage(id,1e9,{2,3,4});b:Damage(id,1e9,{2,3,4})
            local t=os.clock();a:Flush();elapsedBefore=elapsedBefore+os.clock()-t
            t=os.clock();b:Flush();elapsedAfter=elapsedAfter+os.clock()-t
            Same(Snapshot(b,newEnv),Snapshot(a,oldEnv),'same-step damage/flush '..name..'/'..step)
            Check(oldEnv.random()==newEnv.random(),'damage rebuild retains RNG stream '..name..'/'..step)
        end
    end
    if a.alive then
        local ac=a.bp:CoreParts()[1];local bc=b.bp:CoreParts()[1]
        a:Damage(ac.id,1e9,{0,0,0});b:Damage(bc.id,1e9,{0,0,0});a:Flush();b:Flush()
        Same(Snapshot(b,newEnv),Snapshot(a,oldEnv),'core kill preserves component debris, events and state '..name)
        Check(oldEnv.random()==newEnv.random(),'core kill preserves RNG '..name)
    end
    damage_benchmarks[#damage_benchmarks+1]={name=name,parts=#source.parts,isolatedFlushBeforeMs=elapsedBefore*1000,isolatedFlushAfterMs=elapsedAfter*1000,
        nativeVehicleAndDebris='stubbed; no actual engine or Web frame-time claim'}
end
for _,name in ipairs({'raceCar','scorpion'}) do
    local source=Prefab.Create(BP.New(),name):ToTable();local oldEnv,newEnv=Environment(),Environment()
    local cfg={name=name,spawn={pos={0,0,0},yaw=0},externalControl=true,combat=true}
    local a,b=oldUnit.New(oldEnv,source,cfg),Unit.New(newEnv,source,cfg)
    a.weapons.energy=79;b.weapons.energy=79;a.weapons.time=3;b.weapons.time=3
    local id=nil ---@type number|nil
    for _,p in ipairs(b.bp:List()) do if p.type~='core' and require('parts.Defs').PARTS[p.type].cat=='weapon' then id=p.id;break end end
    assert(id,'combat fixture has a weapon')
    a:Destroy(id);b:Destroy(id);a:Flush();b:Flush()
    Same(Snapshot(b,newEnv),Snapshot(a,oldEnv),'combat refit retains HP, shield, energy, cooldown and weapon state '..name)
    Check(a.alive and b.alive,'combat restore fixture remains alive '..name)
    oldEnv.time=1;newEnv.time=1
    Same(b:RestoreMissing(1),a:RestoreMissing(1),'repair selection/order preserved '..name)
    a:Flush();b:Flush()
    Same(Snapshot(b,newEnv),Snapshot(a,oldEnv),'restored combat vehicle same-step rebuild '..name)
end
return checks

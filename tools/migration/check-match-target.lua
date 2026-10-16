package.path='scripts/?.lua;'..package.path
package.loaded['core.Coord']={}
package.loaded['combat.ArenaData']={escort=golden.escort}
local Nav=require 'combat.EnemyDriverNav'
local Target=require 'combat.MatchTarget'
local Objectives=require 'combat.BattleObjectives'
local checks,failures={},{}
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<=1e-8 end
    if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not Same(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end
    return true
end
local function Check(value,name,actual,expected)
    checks[#checks+1]=name
    if not value then failures[#failures+1]={name=name,actual=actual,expected=expected} end
end
local function Copy(value) if type(value)~='table' then return value end;local out={};for key,item in pairs(value) do out[key]=Copy(item) end;return out end
local function Unit(row)
    local u=Copy(row);u.pos=Copy(row.pos or {0,0,0});u.alive=row.alive~=false;u.health=row.health or 1;u.team=row.team or 'red';u.vehicle={body={id=u.id}}
    u.spec={bounds={radius=3}};u.Position=function(self) return self.pos end;u.Health=function(self) return self.health end;return u
end
for _,case in ipairs(golden.pickCases) do
    local units={Unit({id='self',team='blue',pos={0,8,0}})};for _,row in ipairs(case.rows) do units[#units+1]=Unit(row) end
    local calls={};local world={time=0}
    function world:CastRay(from,dir,length,exclude)
        local dest={};for i=1,3 do dest[i]=from[i]+dir[i]*length end
        local target
        for _,u in ipairs(units) do if math.sqrt((u.pos[1]-dest[1])^2+(u.pos[2]+1-dest[2])^2+(u.pos[3]-dest[3])^2)<1e-6 then target=u;break end end
        assert(target,'Missing Lua ray endpoint')
        calls[#calls+1]={from=Copy(from),to=dest,length=length,exclude=exclude.id,target=target.id}
        if not target.hit or target.hit.kind=='none' then return nil end
        return {dist=target.hit.margin and length+target.hit.margin or target.hit.dist,owner={ref=target.hit.kind=='target' and target or units[1]}}
    end
    local entries={};for _,u in ipairs(units) do entries[#entries+1]={unit=u} end
    local battle={world=world,entries=entries,rules={shield={blue=true,red=true}}}
    battle.objectives=setmetatable({battle=battle,id=case.mode,bases={blue={zone={pos={0,0,0},rx=10,rz=10,h=20}},red={zone={pos={100,0,0},rx=10,rz=10,h=20}}}},Objectives)
    local entry=entries[1]
    for i,step in ipairs(case.steps) do
        world.time=step.time
        for _,patch in ipairs(step.patches or {}) do for _,u in ipairs(units) do if u.id==patch.id then for key,value in pairs(patch) do u[key]=Copy(value) end end end end
        if step.shield then battle.rules.shield=Copy(step.shield) end
        local before=entry.pick;local offset=#calls;local pick=Target.Pick(battle,entry)
        local newCalls={};for k=offset+1,#calls do newCalls[#newCalls+1]=calls[k] end
        local actual={unit=pick.unit and pick.unit.id or false,seen=pick.seen,['until']=pick.untilAt,sameCache=before==pick,calls=newCalls}
        Check(Same(actual,case.expected[i]),case.name..' step '..i,actual,case.expected[i])
    end
end
local points={{id='A',pos={-100,4,20},radius=22},{id='B',pos={100,5,-20},radius=22},{id='C',pos={0,6,0},radius=22}}
local function NewObjectives(case,entries,states)
    local battle={entries=entries,world={time=case.now or 3,layout={nav={nodes={iC1={0,6,0}}}}},rules={t=case.t or 0,sudden=case.sudden or false,s=90,attack=case.attack or 'blue',shield={blue=true,red=not case.shieldDown},score={blue=case.score or 0,red=case.score or 0},points=states or {{id='A',count={blue=0,red=0}},{id='B',count={blue=0,red=0}},{id='C',count={blue=0,red=0}}}}}
    local obj=setmetatable({battle=battle,world=battle.world,id=case.mode or 'conquest',points=Copy(points),bases={blue={aim={-400,30,0}},red={aim={400,30,0}}},assignAt={},goals={},path={{0,3,0},{0,3,300}},cum={0,300},length=300},Objectives)
    battle.objectives=obj;return obj
end
for _,case in ipairs(golden.goals) do
    local me=Unit({id='self',team=case.team,pos=case.pos or {0,8,0}})
    local foe=case.distance~=nil and Unit({id='foe',team=case.team=='blue' and 'red' or 'blue',pos={case.distance,8,0}}) or nil
    local entry={unit=me,member={role=case.role},driver={}}
    local obj=NewObjectives(case,{entry})
    local target,charge=obj:Goal(entry,{unit=foe,seen=case.seen or false})
    local actual
    if target.id then actual={unit=target.id,passive=false,charge=charge or false}
    else actual={pos=target.pos or target:Position(),radius=target.radius,passive=target.passive or false,shoot=target.shoot or false,charge=charge or false} end
    Check(Same(actual,case.expected),case.name,actual,case.expected)
end
for _,case in ipairs(golden.assignments) do
    local entries={};for _,row in ipairs(case.rows) do entries[#entries+1]={unit=Unit(row),member={role=row.role},driver=row.driver~=false and {} or nil} end
    local obj=NewObjectives(case,entries,Copy(case.states));obj.world.time=0
    obj:Goal(entries[1],{seen=false})
    local actual={}
    for _,entry in ipairs(entries) do
        local j=obj.goals[entry];local job=false
        if j then job=j.reactor and {reactor=true} or {point=type(j.point)=='number' and obj.points[j.point].id or j.point} end
        actual[#actual+1]={id=entry.unit.id,job=job}
    end
    Check(Same(actual,case.expected),case.name,actual,case.expected)
    Check(obj.assignAt.blue==case['until'],case.name..' cache-until',obj.assignAt.blue,case['until'])
end
for _,case in ipairs(golden.assignmentCache) do
    local entries={};for _,row in ipairs(case.rows) do entries[#entries+1]={unit=Unit(row),member={role=row.role},driver={}} end
    local obj=NewObjectives({mode='conquest'},entries)
    for index,step in ipairs(case.steps) do
        obj.world.time=step.time;obj.battle.rules.score[case.team]=step.score
        obj.battle.rules.shield[case.team=='blue' and 'red' or 'blue']=step.shield
        local target,charge=obj:Goal(entries[1],{seen=false});local jobs={}
        for _,entry in ipairs(entries) do
            local j=obj.goals[entry];local job=j and (j.reactor and {reactor=true} or {point=obj.points[j.point].id}) or false
            jobs[#jobs+1]={id=entry.unit.id,job=job}
        end
        local actual={goal={pos=target:Position(),radius=target.radius,shoot=target.shoot or false,passive=target.passive or false,charge=charge or false},jobs=jobs,['until']=obj.assignAt[case.team]}
        Check(Same(actual,case.expected[index]),case.name..' step '..index,actual,case.expected[index])
    end
end
return {checks=checks,failures=failures}

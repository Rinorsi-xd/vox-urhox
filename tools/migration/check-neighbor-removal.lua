local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Unit=require 'combat.CarUnit'
local oldBP=assert(load(neighbor_reference,'f56e/Blueprint'))()
local env=setmetatable({require=function(name)
    if name=='construction.Blueprint' then return oldBP end
    return require(name)
end},{__index=_G})
local oldUnit=assert(load(carunit_source,'f56e/CarUnit','t',env))()
local checks=0
local function Check(ok,label) assert(ok,label);checks=checks+1 end
local function Equal(a,b,path)
    path=path or 'value'
    if type(a)~=type(b) then return false,path..' type' end
    if type(a)=='number' then return a==b or math.abs(a-b)<1e-8*math.max(1,math.abs(b)),path end
    if type(a)~='table' then return a==b,path end
    for k,v in pairs(a) do local ok,why=Equal(v,b[k],path..'.'..tostring(k));if not ok then return false,why end end
    for k in pairs(b) do if a[k]==nil then return false,path..' missing '..tostring(k) end end
    return true,path
end
local function Same(a,b,label) local ok,why=Equal(a,b);Check(ok,label..': '..why) end
local function Inverse(bp,label)
    for source,row in pairs(bp._neighbors) do
        Check(bp.parts[source]~=nil,label..' cached owner exists')
        for target in pairs(row) do
            Check(bp.parts[target]~=nil,label..' cached target exists')
            Check(bp._neighborOwners[target] and bp._neighborOwners[target][source],label..' reverse registration')
        end
    end
    for target,owners in pairs(bp._neighborOwners) do
        Check(next(owners)~=nil,label..' empty owners pruned')
        for source in pairs(owners) do
            Check(bp._neighbors[source] and bp._neighbors[source][target],label..' stale reverse owner')
        end
    end
end
local function Graph(bp,label)
    Inverse(bp,label..' before graph')
    local actual=bp:Graph();local expected={}
    for id,part in pairs(bp.parts) do expected[id]=bp:Neighbors(part) end
    Same(actual,expected,label..' fresh socket equivalence')
    Inverse(bp,label..' after graph')
    local id=next(actual)
    if id then actual[id]={[-999]=true};Same(bp:Graph(),expected,label..' caller snapshot isolation') end
end
for _,name in ipairs({'raceCar','megaMech','scorpion','hawk','feather','vanguard','tianyuan','fuyuan','fox','trooper'}) do
    local bp=Prefab.Create(BP.New(),name);Graph(bp,name..' pristine')
    local list=bp:List()
    for i=1,math.min(16,#list) do
        local removed=bp:Remove(list[i].id);Inverse(bp,name..' removal '..i)
        local fresh=bp.Neighbors;bp.Neighbors=function() error('deletion must retain valid cached rows') end
        bp:Graph();bp.Neighbors=fresh;Graph(bp,name..' deletion '..i)
        bp:Add(removed);Graph(bp,name..' readd '..i)
    end
    bp:Clear();Graph(bp,name..' clear')
    bp:Add({type='core',pos={0,0,0}});Graph(bp,name..' reuse after clear')
end
-- Exercise a partial and deliberately asymmetric cache: cleanup must not rely
-- on a corresponding outgoing socket, nor require every row to be cached.
do
    local bp=BP.New();local a=bp:Add({type='core',pos={0,0,0}})
    local b=bp:Add({type='cube',pos={1,0,0}});local c=bp:Add({type='cube',pos={2,0,0}})
    bp._neighbors={[a.id]={[b.id]=true},[b.id]={}}
    bp._neighborOwners={[b.id]={[a.id]=true}}
    bp:Remove(b.id);Inverse(bp,'asymmetric partial cache')
    Check(bp._neighbors[a.id][b.id]==nil,'incoming edge removed without symmetric outgoing row')
    bp:Add(b);Graph(bp,'partial cache restored')
    bp:Remove(c.id);Graph(bp,'partial cache final removal')
end
local function Environment()
    local e={time=0,viewEvents={},units={},fx={},created=0,disposed=0,debrisLog={},damageLog={},killLog={}}
    local seed=31337
    e.random=function() seed=(seed*48271)%2147483647;return seed/2147483647 end
    function e:NewVehicle(spec)
        self.created=self.created+1
        local state={p={x=1,y=3,z=2},q={x=0,y=0,z=0,w=1},lv={x=4,y=0,z=2},av={x=0,y=.2,z=0}}
        local v={spec=spec,rotors={},com={0,0,0}}
        v.body={translation=function() return state.p end,rotation=function() return state.q end,center=function() return state.p end,
            velocityAtPoint=function(p) return {x=4+p.z*.2,y=0,z=2-p.x*.2} end}
        function v:Place() end
        function v:GetState() return state end
        function v:SetState(s) state=s end
        function v:Dispose() e.disposed=e.disposed+1 end
        return v
    end
    e.debris={Spawn=function(_,parts,pose,velocity,kick)
        local ids={};for _,p in ipairs(parts) do ids[#ids+1]=p.id end
        e.debrisLog[#e.debrisLog+1]={ids=ids,pose=pose,velocity=velocity({1,2,3}),kick=kick}
    end}
    function e:RecordDamage(_,amount,point,opts) self.damageLog[#self.damageLog+1]={amount=amount,point=point,opts=opts} end
    function e:RecordKill(unit,pos) self.killLog[#self.killLog+1]={name=unit.name,pos=pos} end
    return e
end
local function Snapshot(unit,e)
    local events={};for _,event in ipairs(e.viewEvents) do
        local copy={};for key,value in pairs(event) do if key~='unit' then copy[key]=value end end;events[#events+1]=copy
    end
    return {blueprint=unit.bp:ToTable(),hp=unit.hp,shields=unit.shields,alive=unit.alive,kill=unit.kill,dirty=unit.dirty,
        lostCells=unit.lostCells,lostMajor=unit.lostMajor,budget=unit:Budget(),life=unit:Life(),spec=unit.spec,
        bodyHp=unit.bodyHp,bodyHpMax=unit.bodyHpMax,struct=unit.struct,structMax=unit.structMax,hitAt=unit.hitAt,
        events=events,debris=e.debrisLog,damage=e.damageLog,kills=e.killLog,created=e.created,disposed=e.disposed,
        state=unit.vehicle and unit.vehicle:GetState() or false}
end
local function ObserveRemovals(bp)
    local metric={calls=0,fullCacheRows=0,incomingEdges=0}
    local remove=bp.Remove
    bp.Remove=function(self,id)
        metric.calls=metric.calls+1
        local incoming=self._neighborOwners and self._neighborOwners[id]
        local pairsBefore=pairs
        _G.pairs=function(t)
            local iter,state,key=pairsBefore(t)
            if t~=self._neighbors and t~=incoming then return iter,state,key end
            return function(s,k)
                local nextKey,value=iter(s,k)
                if nextKey~=nil then
                    if t==self._neighbors then metric.fullCacheRows=metric.fullCacheRows+1
                    else metric.incomingEdges=metric.incomingEdges+1 end
                end
                return nextKey,value
            end,state,key
        end
        local result=table.pack(pcall(remove,self,id));_G.pairs=pairsBefore
        assert(result[1],result[2]);return table.unpack(result,2,result.n)
    end
    return metric
end
local samples={}
for _,fixture in ipairs({{name='vanguard',id=159,removed=63,rows=20034},{name='scorpion',id=1540,removed=7,rows=10871}}) do
    local source=Prefab.Create(BP.New(),fixture.name):ToTable()
    local aEnv,bEnv=Environment(),Environment()
    local cfg={name=fixture.name,spawn={pos={0,0,0},yaw=0},externalControl=true,autoRespawn=false}
    local a,b=oldUnit.New(aEnv,source,cfg),Unit.New(bEnv,source,cfg)
    Same(Snapshot(b,bEnv),Snapshot(a,aEnv),fixture.name..' pristine unit')
    local oldCount,newCount=ObserveRemovals(a.bp),ObserveRemovals(b.bp)
    a:Damage(fixture.id,1e9,{2,3,4});b:Damage(fixture.id,1e9,{2,3,4});a:Flush();b:Flush()
    Same(Snapshot(b,bEnv),Snapshot(a,aEnv),fixture.name..' bridge damage/disconnect semantics')
    Check(aEnv.random()==bEnv.random(),fixture.name..' same RNG stream')
    Graph(b.bp,fixture.name..' post disconnect')
    Check(oldCount.calls==fixture.removed,fixture.name..' actual disconnect count')
    Check(oldCount.fullCacheRows==fixture.rows,fixture.name..' frozen full scan regression control')
    Check(newCount.calls==oldCount.calls,fixture.name..' same removal call count')
    Check(newCount.fullCacheRows==0,fixture.name..' no whole-cache traversal per removal')
    samples[#samples+1]={name=fixture.name,target=fixture.id,remaining=b.bp:Size(),alive=b.alive,before=oldCount,after=newCount}
    a:Dispose();b:Dispose()
end
return {checks=checks,samples=samples}

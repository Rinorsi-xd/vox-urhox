package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local A=require 'combat.EnemyDriverMath'
local current=require 'combat.EnemyDriverNav'
local before=assert(loadfile(NAV_BEFORE_MODULE))()
local count,negative=0,0
local function Check(ok,message) assert(ok,message);count=count+1 end
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b or type(a)=='number' and a~=a and b~=b end
    for k,v in pairs(a)do if not Equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
local originalSpatial,originalDistance=A.Spatial,A.Distance
local function Measure(callback)
    local spatial,distance=0,0
    A.Spatial=function(...)spatial=spatial+1;return originalSpatial(...)end
    A.Distance=function(...)distance=distance+1;return originalDistance(...)end
    local result=table.pack(pcall(callback))
    A.Spatial=originalSpatial;A.Distance=originalDistance
    assert(result[1],result[2])
    return result[2],spatial,distance
end
local function QueryNearest(module,nav,p,width,accept)
    local visited={}
    local id,spatial,distance=Measure(function()
        return module.Nearest(nav,p,width,function(point,key)
            visited[#visited+1]=key
            return #visited>=accept
        end)
    end)
    return {id=id,visited=visited},spatial,distance
end
local function QueryPath(module,nav,from,to,width,kind)
    local calls={};local random=A.Seeded(31817)
    local jitter=nil ---@type function|nil
    if kind~=0 then jitter=function(a,b)
        calls[#calls+1]={a,b}
        -- Stateful jitter proves callback count/order and its RNG consumption.
        return kind==2 and 1+random()*.8 or 1+(#a+#b)%7*.1
    end end
    local path,spatial,distance=Measure(function()return module.Path(nav,from,to,width,jitter)end)
    return {path=path,calls=calls,nextRandom=random()},spatial,distance
end
local rows={}
for _,row in ipairs(NAV_CASES)do
    local nav=row.nav;local ids={};for id in pairs(nav.nodes)do ids[#ids+1]=id end;table.sort(ids)
    local work={name=row.name,nodes=#ids,edges=#nav.edges,nearestQueries=0,pathQueries=0,
        beforeSpatial=0,afterSpatial=0,beforeHeuristic=0,afterHeuristic=0}
    for _,width in ipairs({1,3,6,12,20,30.5,40})do
        current.Graph(nav,width);before.Graph(nav,width)
        for i,id in ipairs(ids)do
            local p=nav.nodes[id];local query={p[1]+.137,p[2]-.231,p[3]+.419}
            local old,os=QueryNearest(before,nav,query,width,1+i%7)
            local new,ns=QueryNearest(current,nav,query,width,1+i%7)
            Check(Equal(old,new),row.name..' nearest callback/order '..width..'/'..id)
            work.nearestQueries=work.nearestQueries+1;work.beforeSpatial=work.beforeSpatial+os;work.afterSpatial=work.afterSpatial+ns
            local target=ids[1+(i*47+13)%#ids]
            for kind=0,2 do
                local from=kind==0 and id or query
                local to=kind==1 and target or nav.nodes[target]
                local op,ops,oph=QueryPath(before,nav,from,to,width,kind)
                local np,nps,nph=QueryPath(current,nav,from,to,width,kind)
                Check(Equal(op,np),row.name..' full path/jitter/RNG '..width..'/'..id..'/'..kind)
                work.pathQueries=work.pathQueries+1
                work.beforeSpatial=work.beforeSpatial+ops;work.afterSpatial=work.afterSpatial+nps
                work.beforeHeuristic=work.beforeHeuristic+oph;work.afterHeuristic=work.afterHeuristic+nph
            end
        end
    end
    Check(work.afterSpatial<work.beforeSpatial,row.name..' actual distance work reduced')
    Check(work.afterHeuristic<=work.beforeHeuristic,row.name..' heuristic work never increases')
    rows[#rows+1]=work
end
local special={nodes={a={0,0,0},b={2,0,0},c={0,0,2},d={2,0,2},island={90,0,90}},
    edges={{'a','b',20},{'a','c',20},{'b','d',20},{'c','d',20},{'a','b',35},{'island','island',50}}}
for _,nav in ipairs({special,{nodes={},edges={}}})do
    for _,p in ipairs({{1,0,1},{0/0,0,0},{math.huge,0,0},{-math.huge,0,0}})do
        for _,width in ipairs({1,40})do
            Check(Equal(QueryNearest(before,nav,p,width,99),QueryNearest(current,nav,p,width,99)),'ties/NaN/infinity/empty callback order')
        end
    end
end
Check(before.Nearest(nil,{0,0,0},1)==current.Nearest(nil,{0,0,0},1),'nil layout nearest')
Check(Equal(before.Path(nil,{0,0,0},{1,0,1},1),current.Path(nil,{0,0,0},{1,0,1},1)),'nil layout path')
for _,from in ipairs({'a','island','absent',{0/0,0,0},{math.huge,0,0}})do
    for _,to in ipairs({'d','island','absent',{0/0,0,0},{math.huge,0,0}})do
        Check(Equal(QueryPath(before,special,from,to,1,2),QueryPath(current,special,from,to,1,2)),'ties/disconnected/invalid/NaN path and stateful jitter')
    end
end
local p={0,0,0}
for i=1,10 do p[1]=i*.4;p[3]=2-i*.2
    Check(Equal(QueryNearest(before,special,p,1,1),QueryNearest(current,special,p,1,1)),'distances do not persist across query mutation')
end
special.nodes={a={0,0,0},b={-2,0,0},c={0,0,-2},d={-2,0,-2},island={-90,0,-90}}
Check(Equal(QueryPath(before,special,'a','d',1,2),QueryPath(current,special,'a','d',1,2)),'replacement nodes invalidate graph')
special.edges={{'a','island',50}}
Check(Equal(QueryPath(before,special,'a','island',1,2),QueryPath(current,special,'a','island',1,2)),'replacement edges invalidate graph')
-- Demonstrate that the comparator catches real behavioral regressions.
do
    local nav={nodes={a={0,0,0},b={1,0,0},c={2,0,0}},edges={{'a','b',10},{'b','c',10}}}
    local expected=current.Path(nav,'a','c',1)
    Check(not Equal(expected,{'a','c'}),'negative path truncation detected');negative=negative+1
    local old=QueryPath(before,nav,'a','c',1,2)
    local changed=QueryPath(current,nav,'a','c',1,1)
    Check(not Equal(old,changed),'negative jitter/RNG replacement detected');negative=negative+1
    local visits=QueryNearest(current,nav,{1,0,0},1,3)
    Check(not Equal(visits,{id=visits.id,visited={visits.visited[3],visits.visited[2],visits.visited[1]}}),'negative available order reversal detected');negative=negative+1
end
return {result='PASSED',assertions=count,negativeControls=negative,rows=rows}

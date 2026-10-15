-- Actual layout inputs and exact returned edge identity, including duplicate order.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local N=require 'combat.EnemyDriverNav'
local old=assert(loadfile(NAV_BEFORE_MODULE))()
local count=0
local function Check(ok,message)assert(ok,message);count=count+1 end
local function Compare(nav,a,b)
    local actual,expected=N.EdgeBetween(nav,a,b),old.EdgeBetween(nav,a,b)
    Check(rawequal(actual,expected),'first edge identity '..tostring(a)..'/'..tostring(b))
end
local rows={}
for _,map in ipairs(NAV_CASES) do
    local nav=map.nav;local ids={};for id in pairs(nav.nodes)do ids[#ids+1]=id end;table.sort(ids)
    local coldAt=os.clock();N.EdgeBetween(nav,ids[1],ids[1]);local coldMs=(os.clock()-coldAt)*1000
    for _,a in ipairs(ids)do for _,b in ipairs(ids)do Compare(nav,a,b) end end
    Compare(nav,nil,nil);Compare(nav,ids[1],nil);Compare(nav,nil,ids[1]);Compare(nav,'__absent__',ids[1])
    local queries={};for _,edge in ipairs(nav.edges)do queries[#queries+1]={edge[1],edge[2]};queries[#queries+1]={edge[2],edge[1]}end
    local loops=20;local beforeAt=os.clock()
    for _=1,loops do for _,q in ipairs(queries)do old.EdgeBetween(nav,q[1],q[2])end end
    local beforeMs=(os.clock()-beforeAt)*1000;local afterAt=os.clock()
    for _=1,loops do for _,q in ipairs(queries)do N.EdgeBetween(nav,q[1],q[2])end end
    local afterMs=(os.clock()-afterAt)*1000
    rows[#rows+1]={name=map.name,nodes=#ids,edges=#nav.edges,pairs=#ids*#ids,coldMs=coldMs,
        benchmarkQueries=loops*#queries,beforeCpuMs=beforeMs,afterCpuMs=afterMs}
end
Compare(nil,'a','b');Compare({nodes={},edges={}},'a','b')
local first={'a','b',10};local reverse={'b','a',80};local self={'a','a',7}
local nav={nodes={a={0,0,0},b={1,0,0}},edges={first,reverse,self,{'a','b',100}}}
for _,a in ipairs({'a','b','absent'})do for _,b in ipairs({'a','b','absent'})do Compare(nav,a,b)end end
Check(rawequal(N.EdgeBetween(nav,'a','b'),first),'duplicate preserves first source edge')
Check(rawequal(N.EdgeBetween(nav,'b','a'),first),'reverse preserves same first source edge')
Check(rawequal(N.EdgeBetween(nav,'a','a'),self),'self edge identity')
Check(select('#',N.EdgeBetween(nav,'a','absent'))==select('#',old.EdgeBetween(nav,'a','absent')),'missing edge preserves zero return values')
nav.edges={reverse,first};Compare(nav,'a','b');Compare(nav,'a','a')
Check(rawequal(N.EdgeBetween(nav,'a','b'),reverse),'replacement invalidates duplicate order')
nav.nodes={a={4,0,0},b={5,0,0}};Compare(nav,'b','a')
local watch=setmetatable({},{__mode='v'})
do
    local edge={'x','y',9};local temporary={nodes={x={0,0,0},y={1,0,0}},edges={edge}}
    watch.nav=temporary;watch.nodes=temporary.nodes;watch.edges=temporary.edges;watch.edge=edge
    N.EdgeBetween(temporary,'x','y')
end
collectgarbage('collect');collectgarbage('collect')
Check(watch.nav==nil and watch.nodes==nil and watch.edges==nil and watch.edge==nil,'retired layout and index edges released')
return {result='PASSED',assertions=count,rows=rows,weakRelease=true,tableReplacement=true,duplicateOrder=true}

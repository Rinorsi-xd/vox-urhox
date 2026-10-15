-- Standalone Lua 5.4 check. The runner supplies NAV_CASES from actual JSON maps
-- and NAV_BEFORE_MODULE from the immutable pre-change build.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local N=require 'combat.EnemyDriverNav'
local old=assert(loadfile(assert(NAV_BEFORE_MODULE)))()
local count=0
local function Check(value,message) assert(value,message);count=count+1 end
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Flat(nav,id)
    local flat=false
    for _,e in ipairs(nav.edges) do
        if(e[1]==id or e[2]==id) and math.abs(nav.nodes[e[1]][2]-nav.nodes[e[2]][2])<.2 then flat=true end
    end
    return flat
end
local rows={}
for _,row in ipairs(assert(NAV_CASES)) do
    local nav=row.nav
    local ids={};for id in pairs(nav.nodes) do ids[#ids+1]=id;Check(N.HasFlatEdge(nav,id)==Flat(nav,id),row.name..' flat '..id) end
    table.sort(ids)
    Check(not N.HasFlatEdge(nav,'__absent__'),row.name..' missing flat')
    local paths=0
    for _,width in ipairs({1,3,6,12,20,30.5,40}) do
        local graph=N.Graph(nav,width)
        Check(Equal(graph,old.Graph(nav,width)),row.name..' graph '..width)
        Check(rawequal(graph,N.Graph(nav,width)),row.name..' graph reused '..width)
        local function jitter(a,b)
            local sum=0;for i=1,#a do sum=sum+a:byte(i) end;for i=1,#b do sum=sum+b:byte(i) end
            return 1+(sum%17)/20
        end
        for i=1,math.min(12,#ids) do
            local from,to=ids[1+(i*17)%#ids],ids[1+(i*47+5)%#ids]
            Check(Equal(N.Path(nav,from,to,width),old.Path(nav,from,to,width)),row.name..' path '..width..'/'..i)
            Check(Equal(N.Path(nav,nav.nodes[from],nav.nodes[to],width,jitter),old.Path(nav,nav.nodes[from],nav.nodes[to],width,jitter)),row.name..' jitter path '..width..'/'..i)
            Check(N.Nearest(nav,nav.nodes[from],width)==old.Nearest(nav,nav.nodes[from],width),row.name..' nearest '..width..'/'..i)
            paths=paths+2
        end
    end
    rows[#rows+1]={name=row.name,nodes=#ids,edges=#nav.edges,paths=paths}
end
local nav={nodes={a={0,0,0},b={2,0,0}},edges={{'a','b',8}}}
local g=N.Graph(nav,3);Check(N.HasFlatEdge(nav,'a'),'replacement before flat')
nav.edges={{'a','b',2}};Check(not rawequal(g,N.Graph(nav,3)) and #N.Graph(nav,3).ids==0,'edges replacement invalidates')
nav.nodes={a={0,0,0},b={2,1,0}};Check(not N.HasFlatEdge(nav,'a'),'nodes replacement invalidates flat')
local watch=setmetatable({},{__mode='v'})
do
    local temporary={nodes={a={0,0,0},b={1,0,0}},edges={{'a','b',8}}}
    watch.nav=temporary;watch.nodes=temporary.nodes;watch.edges=temporary.edges
    local graph=N.Graph(temporary,3);watch.graph=graph;N.HasFlatEdge(temporary,'a')
end
collectgarbage('collect');collectgarbage('collect')
Check(watch.nav==nil and watch.nodes==nil and watch.edges==nil and watch.graph==nil,'weak cache releases retired nav and data')
return {result='PASSED',assertions=count,maps=rows,weakRelease=true,tableReplacement=true}

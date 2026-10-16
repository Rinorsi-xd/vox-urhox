local A=require 'combat.EnemyDriverMath'
local M={}
-- Layout navigation is immutable for a world's lifetime. Weak keys let retired
-- worlds release their graph; replacing either source table invalidates it.
local layouts=setmetatable({},{__mode='k'})
local function Layout(nav)
    local entry=layouts[nav]
    if not entry or entry.nodes~=nav.nodes or entry.edges~=nav.edges then
        entry={nodes=nav.nodes,edges=nav.edges,graphs={}};layouts[nav]=entry
    end
    return entry
end
function M.Graph(nav,width)
    local entry=nav and Layout(nav)
    if entry and entry.graphs[width] then return entry.graphs[width] end
    local g={nodes=nav and nav.nodes or {},adj={},ids={}}
    for _,e in ipairs(nav and nav.edges or {}) do
        local a,b,w=e[1],e[2],e[3]
        if w>=width+1 and g.nodes[a] and g.nodes[b] then
            for _,id in ipairs({a,b}) do if not g.adj[id] then g.adj[id]={};g.ids[#g.ids+1]=id end end
            local cost=A.Spatial(g.nodes[a],g.nodes[b]);table.insert(g.adj[a],{b,cost});table.insert(g.adj[b],{a,cost})
        end
    end
    if entry then entry.graphs[width]=g end
    return g
end
function M.HasFlatEdge(nav,id)
    if not nav then return false end
    local entry=Layout(nav)
    if not entry.flat then
        local flat={}
        for _,e in ipairs(nav.edges or {}) do
            if math.abs(nav.nodes[e[1]][2]-nav.nodes[e[2]][2])<.2 then flat[e[1]]=true;flat[e[2]]=true end
        end
        entry.flat=flat
    end
    return entry.flat[id]==true
end
function M.Nearest(nav,p,width,available)
    local g=M.Graph(nav,width);local ids={table.unpack(g.ids)};local rank,distances={},{}
    for i,id in ipairs(g.ids) do rank[id]=i;distances[id]=A.Spatial(g.nodes[id],p) end
    table.sort(ids,function(a,b) local x,y=distances[a],distances[b];return x<y or x==y and rank[a]<rank[b] end)
    for _,id in ipairs(ids) do if not available or available(g.nodes[id],id) then return id end end
end
function M.Path(nav,from,to,width,jitter)
    local g=M.Graph(nav,width);if #g.ids==0 then return {} end
    local function nearest(p)
        local best=g.ids[1];local distance=A.Spatial(g.nodes[best],p)
        for i=2,#g.ids do local id=g.ids[i];local nextDistance=A.Spatial(g.nodes[id],p)
            if nextDistance<distance then best=id;distance=nextDistance end
        end;return best
    end
    local start=type(from)=='string' and from or nearest(from);local goal=type(to)=='string' and to or nearest(to)
    if not g.adj[start] or not g.adj[goal] then return {} end
    local open={start};local pending={[start]=true};local costs={[start]=0};local previous={};local heuristics={}
    while #open>0 do
        local cur,idx,score=nil,0,math.huge
        for i,id in ipairs(open) do
            -- Positions are immutable; only the accumulated cost changes while
            -- a node remains open. Keep the original scan/tie and jitter order.
            local h=heuristics[id];if h==nil then h=A.Distance(g.nodes[id],g.nodes[goal]);heuristics[id]=h end
            local s=costs[id]+h;if s<score then cur,idx,score=id,i,s end
        end
        if cur==goal then local out={cur};while previous[out[1]] do table.insert(out,1,previous[out[1]]) end;return out end
        table.remove(open,idx);pending[cur]=nil
        for _,edge in ipairs(g.adj[cur]) do local id=edge[1];local alt=costs[cur]+edge[2]*(jitter and jitter(cur,id) or 1)
            if alt<(costs[id] or math.huge) then costs[id]=alt;previous[id]=cur;if not pending[id] then open[#open+1]=id;pending[id]=true end end
        end
    end
    return {}
end
function M.Visible(world,from,to,exclude,target)
    if not world or not world.CastRay then return true end;local d=A.Spatial(from,to);if d<.01 then return true end
    local h=world:CastRay(from,{(to[1]-from[1])/d,(to[2]-from[2])/d,(to[3]-from[3])/d},d,exclude)
    return not h or h.dist>=d-.6 or target and h.owner and h.owner.ref==target or false
end
function M.StaticRay(world,from,dir,length,exclude)
    if world and world.space then return world.space:Raycast(from,dir,length,exclude,nil,true) end
    return world and world.CastRay and world:CastRay(from,dir,length,exclude) or nil
end
function M.Height(world,x,z,above,exclude) local h=M.StaticRay(world,{x,above,z},{0,-1,0},12,exclude);return h and h.point[2] or nil end
function M.Direct(world,from,to,v,width)
    if not world or not world.CastRay then return true end
    local length=A.Distance(from,to);if length>65 then return false end
    local start=M.Height(world,from[1],from[3],from[2]+v.spec.bounds.min[2]+3,v.body);if not start then return false end
    local count=math.max(1,math.ceil(length/5));local step=length/count;local dx,dz=(to[1]-from[1])/math.max(1,length),(to[3]-from[3])/math.max(1,length);local previous=start
    -- Centre and both footprint edges must retain ground; the low ray catches thin parapets.
    for i=1,count do local x,z=from[1]+(to[1]-from[1])*i/count,from[3]+(to[3]-from[3])*i/count
        local y=M.Height(world,x,z,previous+3,v.body);if not y or math.abs(y-previous)>step*.3+.25 then return false end
        for _,s in ipairs({-1,1}) do local side=M.Height(world,x+dz*width*.45*s,z-dx*width*.45*s,y+3,v.body);if not side or math.abs(side-y)>math.max(.5,width*.18) then return false end end
        previous=y
    end
    if world.space then local delta={to[1]-from[1],previous-start,to[3]-from[3]};local len=math.sqrt(delta[1]^2+delta[2]^2+delta[3]^2)
        if len>.1 and M.StaticRay(world,{from[1],start+.5,from[3]},{delta[1]/len,delta[2]/len,delta[3]/len},len-.05,v.body) then return false end
    end
    return true
end
function M.Inside(zone,p,pad) pad=pad or 0;return ((p[1]-zone.pos[1])/(zone.rx+pad))^2+((p[3]-zone.pos[3])/(zone.rz+pad))^2<=1 end
function M.Edge(zone,from,pad,fallback)
    local dx,dz=from[1]-zone.pos[1],from[3]-zone.pos[3];if math.sqrt(dx*dx+dz*dz)<1 and fallback then dx,dz=fallback[1]-zone.pos[1],fallback[3]-zone.pos[3] end
    local k=1/math.max(1e-6,math.sqrt((dx/(zone.rx+pad))^2+(dz/(zone.rz+pad))^2));return {zone.pos[1]+dx*k,from[2],zone.pos[3]+dz*k}
end
function M.EdgeBetween(nav,a,b)
    if not nav then return end
    local entry=Layout(nav)
    if not entry.between then
        local between={}
        for _,e in ipairs(nav.edges or {}) do
            local x,y=e[1],e[2]
            between[x]=between[x] or {};between[y]=between[y] or {}
            -- Undirected duplicates retain the first source edge in either direction.
            if not between[x][y] then between[x][y]=e;between[y][x]=e end
        end
        entry.between=between
    end
    local row=entry.between[a];if row and row[b] then return row[b] end
end
function M.Narrow(nav,p,width)
    for _,e in ipairs(nav and nav.edges or {}) do local a,b=nav.nodes[e[1]],nav.nodes[e[2]]
        if e[3]<20 and a and b then local ex,ez=b[1]-a[1],b[3]-a[3];local l2=ex*ex+ez*ez;if l2==0 then l2=1 end
            local t=A.Clamp(((p[1]-a[1])*ex+(p[3]-a[3])*ez)/l2,0,1)
            if math.sqrt((p[1]-a[1]-ex*t)^2+(p[3]-a[3]-ez*t)^2)<e[3]*.5+width*.5 then return true end
        end
    end;return false
end
return M

-- Frozen shared/build/rotor.js. All poses use source coordinates; metres only
-- at the drive boundary. Joined groups may slide past unrelated block groups.
local Defs=require('parts.Defs').PARTS
local Rot=require 'core.Rotations'
local V=require 'core.Math3'
local M={RANGE_STEP=math.pi/36,SPEED={aim=2.4,spin=math.pi,step=4.2}}
M.MODES={{type='rotor',mode='aim',name='跟随视角',hint='像炮塔一样跟着准星转'},
    {type='rotorSpin',mode='spin',name='一直转',hint='试车时一直匀速转'},
    {type='rotorStep',mode='step',name='步进',hint='试车按 F 转 90°'}}
M.IDENT={q={x=0,y=0,z=0,w=1},t={0,0,0}}
function M.Keys(set) local out={};for id in pairs(set) do out[#out+1]=id end;table.sort(out);return out end
function M.Is(type) return Defs[type] and Defs[type].rotor~=nil end
function M.Frame(p)
    local axis=Rot.ApplyRot(p.rot,{0,1,0});local sign=p.pos[1]<0 and -1 or 1
    return {pivot={p.pos[1],p.pos[2]+.5,p.pos[3]},axis=axis,ref=Rot.ApplyRot(p.rot,{0,0,1}),sign=sign,spin=V.Scale(axis,sign)}
end
function M.AimRef(p)
    local axis=M.Frame(p).axis
    for _,v in ipairs({{0,0,1},{0,1,0}}) do local flat=V.Reject(v,axis);if V.Length(flat)>.5 then return V.Normalize(flat) end end
end
function M.AimOffset(p)
    local ref=M.AimRef(p)
    return math.atan(V.Dot(ref,Rot.ApplyRot(p.rot,{1,0,0})),V.Dot(ref,Rot.ApplyRot(p.rot,{0,0,1})))
end
function M.AxisQuat(axis,a) local s=math.sin(a/2);return {x=axis[1]*s,y=axis[2]*s,z=axis[3]*s,w=math.cos(a/2)} end
function M.Apply(pose,p) return V.Add(V.Rotate(pose.q,p),pose.t) end
function M.Inverse(pose,p) return V.Unrotate(pose.q,V.Sub(p,pose.t)) end
function M.Pose(parent,pivot,axis,a)
    local q=M.AxisQuat(axis,a);local t=V.Sub(pivot,V.Rotate(q,pivot))
    return {q=V.QMul(parent.q,q),t=V.Add(V.Rotate(parent.q,t),parent.t)}
end
function M.Loads(bp,adj)
    adj=adj or bp:Graph();local out={};local cores={};for _,p in ipairs(bp:CoreParts()) do cores[p.id]=true end
    for _,r in ipairs(bp:List()) do if M.Is(r.type) then
        local f=M.Frame(r);local top={}
        for _,c in ipairs(r._cells) do top[bp.Key(c[1]+f.axis[1],c[2]+f.axis[2],c[3]+f.axis[3])]=true end
        local seeds,seedSet,base={},{},{}
        for _,id in ipairs(M.Keys(adj[r.id])) do
            local on=false;for _,c in ipairs(bp.parts[id]._cells) do if top[bp.Key(table.unpack(c))] then on=true;break end end
            if on then seeds[#seeds+1]=id;seedSet[id]=true else base[id]=true end
        end
        local function Above(id)
            for _,c in ipairs(bp.parts[id]._cells) do if V.Dot(V.Sub({c[1],c[2]+.5,c[3]},f.pivot),f.axis)>.5 then return true end end
            return false
        end
        local function Linked(a,b)
            local p,q=bp.parts[a],bp.parts[b]
            return not Defs[p.type].shape or not Defs[q.type].shape or (p.g or 0)==(q.g or 0)
        end
        local load,from,queue={},{},{table.unpack(seeds)};for _,id in ipairs(seeds) do load[id]=true end
        local ending=nil ---@type number|nil
        local i=1
        while i<=#queue do local cur=queue[i];i=i+1
            if not ending and (base[cur] or cores[cur]) then ending=cur end
            for _,n in ipairs(M.Keys(adj[cur])) do if n~=r.id and not load[n] and Linked(cur,n) then
                load[n]=true;from[n]=cur;queue[#queue+1]=n
            end end
        end
        local back={}
        if ending then
            local path={};local id=ending;while id do table.insert(path,1,id);id=from[id] end
            local cut=nil ---@type number|nil
            for j,p in ipairs(path) do if not Above(p) then cut=j;break end end
            local first=cut and math.max(1,cut-1) or math.max(1,#path-2)
            local last=cut and math.min(#path,cut+1) or #path
            for j=first,last do back[path[j]]=true end
        end
        local reachedBase=false;for id in pairs(base) do reachedBase=reachedBase or load[id]==true end
        if reachedBase then
            load={};queue={};for _,id in ipairs(seeds) do if not cores[id] then queue[#queue+1]=id;load[id]=true end end
            i=1;while i<=#queue do local cur=queue[i];i=i+1
                for _,n in ipairs(M.Keys(adj[cur])) do if n~=r.id and not load[n] and not base[n] and not cores[n] and Above(n) and Linked(cur,n) then
                    load[n]=true;queue[#queue+1]=n
                end end
            end
        end
        local legs,coreOn={},false
        for id in pairs(load) do local d=Defs[bp.parts[id].type]
            if d.leg or d.mech then legs[id]=true end
            if not reachedBase and cores[id] then coreOn=true;back[id]=true end
        end
        local info={load=load,count=#M.Keys(load),blockers={},stuck=false}
        if coreOn then info.problem='核心在转盘上，转不了';info.blockers=M.Keys(back)
        elseif next(legs) then info.problem='节足装在转盘上转不了（以后再做）';info.blockers=M.Keys(legs)
        elseif next(back) then info.problem='转盘上的东西还连着车身，试车时转一下就会弹回来';info.blockers=M.Keys(back);info.stuck=true end
        out[r.id]=info
    end end
    return out
end
function M.Tree(loads)
    local live,owner,parent,own={}, {}, {}, {}
    for _,id in ipairs(M.Keys(loads)) do local r=loads[id];if not r.problem or r.stuck then
        live[#live+1]=id;own[id]={}
        for _,p in ipairs(M.Keys(r.load)) do if not owner[p] or loads[owner[p]].count>r.count then owner[p]=id end end
    end end
    for _,id in ipairs(live) do parent[id]=owner[id] end
    -- Malformed overlapping/cyclic loads must not recurse indefinitely.
    local depth,visiting={},{}
    local function Depth(id)
        if depth[id] then return depth[id] end
        if visiting[id] then parent[id]=nil;return 0 end
        visiting[id]=true;local d=parent[id] and 1+Depth(parent[id]) or 0;visiting[id]=nil;depth[id]=d;return d
    end
    for _,id in ipairs(live) do Depth(id) end
    table.sort(live,function(a,b) return depth[a]==depth[b] and a<b or depth[a]<depth[b] end)
    for _,p in ipairs(M.Keys(owner)) do local id=owner[p];if p~=id then own[id][#own[id]+1]=p else owner[p]=nil end end
    return {owner=owner,parent=parent,order=live,own=own}
end
-- Contact sweep: cell centre plus eight corners inset to 0.3 cell.
--   [base] -- pivot/+Y -- [load]  -> rotate samples -> occupied cell lookup
-- Touching faces are allowed; core/legs and structural loops are diagnosed first.
function M.Range(bp,r,load)
    local f=M.Frame(r);local samples={};local offsets={{0,0,0}}
    for _,x in ipairs({-.3,.3}) do for _,y in ipairs({-.3,.3}) do for _,z in ipairs({-.3,.3}) do offsets[#offsets+1]={x,y,z} end end end
    for _,id in ipairs(M.Keys(load)) do for _,c in ipairs(bp.parts[id]._cells) do for _,o in ipairs(offsets) do
        samples[#samples+1]={c[1]+o[1],c[2]+.5+o[2],c[3]+o[3]}
    end end end
    local function Reach(dir)
        for i=1,71 do
            local q=M.AxisQuat(f.spin,dir*i*M.RANGE_STEP);local hit={}
            for _,s in ipairs(samples) do local p=V.Add(V.Rotate(q,V.Sub(s,f.pivot)),f.pivot)
                for _,id in ipairs(bp.cellIds[bp.Key(math.floor(p[1]+.5),math.floor(p[2]),math.floor(p[3]+.5))] or {}) do
                    if id~=r.id and not load[id] then hit[id]=true end
                end
            end
            if next(hit) then return dir*(i-1)*M.RANGE_STEP,M.Keys(hit) end
        end
        return nil,{}
    end
    local hi,hb=Reach(1)
    if not hi then return {free=true,lo=-math.huge,hi=math.huge,blockers={},hiBlockers={},loBlockers={}} end
    local lo,lb=Reach(-1);local both={};for _,id in ipairs(hb) do both[id]=true end;for _,id in ipairs(lb) do both[id]=true end
    return {free=false,lo=lo or -math.pi*2,hi=hi,blockers=M.Keys(both),hiBlockers=hb,loBlockers=lb}
end
function M.RangeText(r)
    if r.hi-r.lo<2*M.RANGE_STEP then return '两个方向一转就碰到，试车时转一下就弹回来' end
    local function Side(a) return math.abs(a)<M.RANGE_STEP/2 and '一点都转不了' or '最多 '..math.abs(math.floor(a*180/math.pi+.5))..'°' end
    return '按 F 的方向'..Side(r.hi)..'，反方向'..Side(r.lo)
end
function M.Inspect(bp,adj)
    local loads=M.Loads(bp,adj)
    for id,r in pairs(loads) do if not r.problem and r.count>0 then r.range=M.Range(bp,bp.parts[id],r.load) end end
    return loads
end
function M.Spec(bp,adj,reached)
    local loads=M.Loads(bp,adj);local tree=M.Tree(loads);local list,owner,index={},{},{}
    for _,id in ipairs(tree.order) do if reached[id] then local p=bp.parts[id];local f=M.Frame(p);local l=loads[id]
        local range=l.stuck and {free=false,lo=0,hi=0} or M.Range(bp,p,l.load)
        local r={index=#list+1,partId=id,parent=index[tree.parent[id]],mode=Defs[p.type].rotor,pivot=V.Scale(f.pivot,require('Config').CELL),
            axis=f.spin,sign=f.sign,ref=M.AimRef(p),load=M.Keys(l.load),own=tree.own[id],range=range}
        list[#list+1]=r;index[id]=r.index;for _,partId in ipairs(r.own) do owner[partId]=r.index end
    end end
    return list,owner
end
return M

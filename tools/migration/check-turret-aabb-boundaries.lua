local Current=require 'construction.TurretRange'
local Previous=assert(loadfile(turret_reference))()
local Rot=require 'core.Rotations'
local Assets=require 'parts.PartAssets'
local function Up(fn,key)
    for i=1,40 do local name,value=debug.getupvalue(fn,i);if not name then break end;if name==key then return value,i end end
    error('missing upvalue '..key)
end
local Prepare=Up(Current.Compute,'Prepare')
local Evaluate=Up(Current.Compute,'Evaluate')
local PreviousEvaluate=Up(Previous.Compute,'Evaluate')
local Misses,index=Up(Evaluate,'MissesBounds')
local cache=Up(Current.For,'cached')
local checks,stats={}, {pruned=0,broadChecks=0,sampleHashesChecked=0,fallbackContexts=0,rotations=0,computes=0,edits=0,aliasCases=0}
local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
local function Equal(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if not Equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
local function Hash(x,y,z)return ((x+1024)*2048+(y+1024))*2048+(z+1024)end
local function Round(x)return math.floor(x+.5)end
-- Validate every actual positive broad-phase result against all original samples.
debug.setupvalue(Evaluate,index,function(context,m,cp,sp,cy,sy)
    stats.broadChecks=stats.broadChecks+1
    local miss=Misses(context,m,cp,sp,cy,sy)
    if miss then
        stats.pruned=stats.pruned+1
        local pv=context.pv
        for _,s in ipairs(context.samples)do
            stats.sampleHashesChecked=stats.sampleHashesChecked+1
            local y1,z1=s[2]*cp+s[3]*sp,-s[2]*sp+s[3]*cp
            local x,y,z=s[1]*cy+z1*sy,y1,-s[1]*sy+z1*cy
            local hash=Hash(Round(m[1]*x+m[2]*y+m[3]*z+pv[1]),math.floor(m[4]*x+m[5]*y+m[6]*z+pv[2]),Round(m[7]*x+m[8]*y+m[9]*z+pv[3]))
            assert(not context.occ[hash],'broad phase suppressed an original sampled hit')
        end
    end
    return miss
end)
local function Part(type,pos,rot)return {id=1,type=type,pos=pos,rot=rot,_cells={}}end
local function Wall(id,c)return {id=id,type='cube',pos={c[1],c[2],c[3]},rot=0,_cells={{c[1],c[2],c[3]}}}end
local function SamplePoint(part)
    local t=Assets.Get(part.type,0).weapon
    local muzzle=(t.muzzles or {t.muzzle})[1]
    local d={};local length2=0;for k=1,3 do d[k]=muzzle[k]-t.pivot[k];length2=length2+d[k]*d[k]end
    local n=math.max(2,math.ceil(math.sqrt(length2)/.3));local scale=math.ceil(n*.6)/n
    local s={};for k=1,3 do s[k]=d[k]*scale end
    local point=Rot.ApplyRot(part.rot,s);local pivot=Rot.ApplyRot(part.rot,t.pivot)
    for k=1,3 do point[k]=point[k]+pivot[k]+part.pos[k]+(k==2 and .5 or 0)end
    return point
end
local function Compare(parts,part,owner,label)
    local n=0;local a=Current.Compute(parts,part,owner,function()n=n+1 end)
    local previousN=0;local b=Previous.Compute(parts,part,owner,function()previousN=previousN+1 end)
    Check(Equal(a,b),label..' exact range/order')
    Check(n==previousN,label..' checkpoint boundary count')
    stats.computes=stats.computes+1
    return a
end
for rot=0,23 do
    stats.rotations=stats.rotations+1
    for _,type in ipairs({'mg3','sniper5','missile3'})do
        local base=Part(type,{0,0,0},rot)
        local point=SamplePoint(base)
        local center={Round(point[1]),math.floor(point[2]),Round(point[3])}
        local parts={base}
        for x=-1,1 do for y=-1,1 do for z=-1,1 do parts[#parts+1]=Wall(#parts+1,{center[1]+x,center[2]+y,center[3]+z})end end end
        Compare(parts,base,nil,type..' rot'..rot..' dense')
        if type=='mg3' then for axis=1,3 do for _,sign in ipairs({-1,1})do for _,eps in ipairs({-1e-10,0,1e-10})do
            local target=sign*(axis==2 and 1 or .5)+eps
            local shifted={0,0,0};shifted[axis]=target-point[axis]
            local p=Part(type,shifted,rot);local s=SamplePoint(p)
            local c={Round(s[1]),math.floor(s[2]),Round(s[3])}
            Compare({p,Wall(2,c)},p,nil,type..' rot'..rot..' axis'..axis..' boundary'..target)
        end end end end
    end
    for _,pos in ipairs({{1020,0,0},{1023,0,0},{-1024,0,0},{0,1023,0},{0,-1024,0},{0,0,1023},{0,0,-1024},{0,0,1024},{2048,0,0}})do
        local p=Part('mg3',pos,rot);local s=SamplePoint(p);local c={Round(s[1]),math.floor(s[2]),Round(s[3])}
        local parts={p,Wall(2,c)};local context=Prepare(parts,p)
        if not context.bounds then stats.fallbackContexts=stats.fallbackContexts+1 end
        Compare(parts,p,nil,'domain rot'..rot..' '..table.concat(pos,','))
    end
    -- Explicit alias: z+2048 and y-1 encode the same Hash. Transformed samples
    -- outside the safe domain must follow the legacy sampled-hash path.
    local m=Rot.ROTATIONS[rot].m;local sample={0,0,2048}
    local raw=Rot.ApplyRot(rot,sample)
    local alias={raw[1],raw[2]-1,raw[3]+2048}
    Check(Hash(table.unpack(raw))==Hash(table.unpack(alias)),'hash alias rot'..rot)
    local samples={{0,0,2048}};samples.bounds={lo={0,0,2048},hi={0,0,2048},center={0,0,2048},half={0,0,0}}
    local safeOcc=alias[1]>=-1024 and alias[1]<=1023 and alias[2]>=-1024 and alias[2]<=1023 and alias[3]>=-1024 and alias[3]<=1023
    local function Context()return {def={aim={pitch={0,0}}},samples=samples,pv={0,0,0},rot=rot,occ={[Hash(table.unpack(alias))]=2},bounds=safeOcc and {lo=alias,hi=alias} or nil}end
    local context=Context()
    Check(not Misses(context,m,1,0,1,0),'alias fallback rot'..rot)
    Check(Equal(Evaluate(context),PreviousEvaluate(Context())),'alias sampled output rot'..rot)
    stats.aliasCases=stats.aliasCases+1
end
-- Keep one blueprint identity across edits, forcing actual cached-ray reuse.
for rot=0,23 do
    local p=Part('sniper5',{0,0,0},rot);local point=SamplePoint(p)
    local c={Round(point[1]),math.floor(point[2]),Round(point[3])}
    local parts={p,Wall(2,{0,-3,0})};local bp={List=function()return parts end}
    local owner={[1]=1,[2]=1,[3]=1}
    local function Edit(label)
        local a=Current.For(bp,owner);local b=Previous.For(bp,owner)
        Check(Equal(a,b),'edit rot'..rot..' '..label);stats.edits=stats.edits+1
        return a
    end
    local before=stats.pruned;local initial=Edit('initial off-ray occupancy');local initialPruned=stats.pruned-before
    Edit('unchanged warm')
    parts[#parts+1]=Wall(3,c);local blocked=Edit('add intersecting wall')
    if rot==0 then Check(not Equal(initial,blocked),'new wall changes previously pruned initial range')end
    local prior=cache[bp].entries[1].context.rays
    local moved={c[1]+2,c[2]+1,c[3]-1};parts[3]=Wall(3,moved);Edit('move wall')
    Check(cache[bp].entries[1].context.rays==prior,'reuse ray identity rot'..rot)
    owner[3]=2;Edit('exclude changed owner')
    owner[1]=2;Edit('change weapon owner')
    owner[1]=1;owner[3]=1;Edit('restore shared owner')
    parts[3]=nil;Edit('delete wall')
    parts[3]=Wall(3,c);Edit('restore wall')
    parts[3]=nil;parts[2]=nil;Edit('remove every obstacle')
    parts[2]=Wall(2,c);Edit('add after empty')
    if rot==0 then Check(initialPruned>0,'initial off-ray state exercises uncached broad miss')end
end
Check(stats.pruned>0,'broad miss branch exercised')
Check(stats.fallbackContexts>0,'out-of-domain occupancy fallback exercised')
return checks,stats

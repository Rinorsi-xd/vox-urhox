local Current=require 'construction.TurretRange'
local Previous=assert(loadfile(turret_reference))()
local BP=require 'construction.Blueprint'
local Rotors=require 'construction.Rotors'
local Rot=require 'core.Rotations'
local Assets=require 'parts.PartAssets'
local Defs=require('parts.Defs').PARTS
local checks={}
local function Up(fn,key)
    for i=1,40 do local name,value=debug.getupvalue(fn,i);if not name then break end;if name==key then return value end end
    error('missing upvalue '..key)
end
local Prepare,OldPrepare=Up(Current.Compute,'Prepare'),Up(Previous.Compute,'Prepare')
local currentCache,oldCache=Up(Current.For,'cached'),Up(Previous.For,'cached')
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return string.pack('>d',a)==string.pack('>d',b) end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
local weaponTypes={};for kind,d in pairs(Defs) do if d.weapon and not d.drill then weaponTypes[#weaponTypes+1]=kind end end;table.sort(weaponTypes)
-- Exercise the actual private Prepare with all authored weapon sample sets.
for _,kind in ipairs(weaponTypes) do for rotation=0,23 do
    local rig=Assets.Get(kind,rotation).weapon
    if rig then
        local pivot=Rot.ApplyRot(rotation,rig.pivot)
        local weapon={id=1,type=kind,rot=rotation,pos={-pivot[1],-pivot[2]-.5,-pivot[3]},_cells={}}
        local empty=Prepare({weapon},weapon)
        if empty then for axis=1,3 do for _,epsilon in ipairs({-1e-10,0,1e-10}) do
            local center={0,0,0};center[axis]=empty.reach+epsilon
            local cell={center[1],center[2]-.5,center[3]}
            local wall={id=2,type='cube',rot=0,pos=cell,_cells={cell}}
            Check(Equal(Prepare({weapon,wall},weapon),OldPrepare({weapon,wall},weapon)),kind..' rot '..rotation..' threshold axis '..axis..' '..epsilon)
        end end end
    end
end end
if scalar_test_mode=='thresholdOnly' then return checks end
local function Owners(bp)
    local adj=bp:Graph();local conn=bp:Connectivity(adj);local _,owner=Rotors.Spec(bp,adj,conn.reached);return owner
end
local function Compare(bp,owner,label)
    local n,m=0,0
    local a=Current.For(bp,owner,function() n=n+1 end)
    local b=Previous.For(bp,owner,function() m=m+1 end)
    Check(Equal(a,b),label..' exact double/range/order')
    Check(n==m,label..' checkpoints')
    Check(Equal(currentCache[bp],oldCache[bp]),label..' occupancy/rays/cache signatures')
end
for i,row in ipairs(scalar_roster) do
    local bp=BP.New():Load(row.source);local owner=Owners(bp)
    Compare(bp,owner,'K '..i..' cold');Compare(bp,owner,'K '..i..' hot')
    local removed={}
    for step=1,3 do
        local parts=bp:List();local target
        for j=#parts,1,-1 do if parts[j].type=='cube' then target=parts[j];break end end
        Check(target~=nil,'K '..i..' removable cube '..step)
        removed[#removed+1]=bp:Remove(target.id);owner=Owners(bp)
        Compare(bp,owner,'K '..i..' damage '..step);Compare(bp,owner,'K '..i..' damage hot '..step)
    end
    for j=#removed,1,-1 do bp:Add(removed[j]);owner=Owners(bp);Compare(bp,owner,'K '..i..' repair '..j) end
    local weapon,wall
    for _,p in ipairs(bp:List()) do if Defs[p.type].weapon and not Defs[p.type].drill then weapon=weapon or p elseif p.type=='cube' then wall=wall or p end end
    if weapon and wall then
        owner=owner or {};owner[wall.id]=913;Compare(bp,owner,'K '..i..' wall different owner')
        owner[weapon.id]=913;Compare(bp,owner,'K '..i..' weapon owner switch')
        owner=Owners(bp);Compare(bp,owner,'K '..i..' owners restored')
        local added=bp:Add({type=wall.type,pos=wall.pos,rot=wall.rot,color=wall.color})
        owner[added.id]=owner[wall.id];Compare(bp,owner,'K '..i..' overlap')
        local saved=bp:Remove(wall.id);Compare(bp,owner,'K '..i..' overlap reveal')
        bp:Add(saved);bp:Remove(added.id);Compare(bp,owner,'K '..i..' overlap restored')
        local remote=bp:Add({type='cube',pos={900,900,900},rot=0});Compare(bp,owner,'K '..i..' far add')
        bp:Remove(remote.id);Compare(bp,owner,'K '..i..' far remove')
    end
end
-- Real pure Spec/cache paths show whether each blueprint identity was warmed.
local Spec=require 'drive.VehicleSpec'
local Cache=require 'drive.SpawnSpecCache'
for i,row in ipairs(scalar_roster) do
    local cache=Cache.New();Check(cache:Prepare(row.source),'K '..i..' cache prepare')
    local bp=BP.New():Load(row.source);Check(not currentCache[bp],'K '..i..' fresh bp has no clearance cache')
    Check(cache:Get(row.source)~=nil,'K '..i..' real spawn spec cache hit')
    Check(not currentCache[bp],'K '..i..' Get does not warm fresh bp')
    Compare(bp,Owners(bp),'K '..i..' first clearance after cached spec')
    local warm=BP.New():Load(row.source);Check(Spec.Build(warm).ok,'K '..i..' direct spec valid')
    Check(currentCache[warm]~=nil,'K '..i..' direct Spec.Build warms its own bp')
    Previous.For(warm,Owners(warm))
    Compare(warm,Owners(warm),'K '..i..' direct spec warm clearance');cache:Dispose()
end
return checks

local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Turret=require 'construction.TurretRange'
local previous=assert(loadfile(turret_reference))()
local checks,benchmarks={},{}
local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Compare(bp,owner,label)
    Check(Equal(Turret.For(bp,owner),previous.For(bp,owner)),label)
end
for _,name in ipairs({'raceCar','megaMech'}) do
    local bp=Prefab.Create(BP.New(),name);Compare(bp,nil,name..' cold')
    local blockType
    for _,p in ipairs(bp:List()) do
        local d=require('parts.Defs').PARTS[p.type]
        if d.shape and not d.weapon then blockType=p.type;break end
    end
    assert(blockType,'source prefab has a structural part')
    local row={name=name,previousMs=0,currentMs=0,previousCheckpoints=0,currentCheckpoints=0,repetitions=6}
    for i=1,row.repetitions do
        local remote=bp:Add{type=blockType,pos={500+i*10,0,500}}
        Compare(bp,nil,name..' addition '..i)
        bp:Remove(remote.id)
        local start=os.clock()
        local a=previous.For(bp,nil,function() row.previousCheckpoints=row.previousCheckpoints+1 end)
        row.previousMs=row.previousMs+(os.clock()-start)*1000
        start=os.clock()
        local b=Turret.For(bp,nil,function() row.currentCheckpoints=row.currentCheckpoints+1 end)
        row.currentMs=row.currentMs+(os.clock()-start)*1000
        Check(Equal(a,b),name..' distant deletion '..i)
    end
    Check(row.currentCheckpoints<row.previousCheckpoints,name..' distant deletion skips full context scans')
    local ids={};for _,p in ipairs(bp:List()) do ids[#ids+1]=p.id end
    local saved={}
    for i=1,math.min(12,#ids) do
        local index=math.floor((i-1)*#ids/12)+1
        local p=bp:Remove(ids[index]);saved[#saved+1]=p
        Compare(bp,nil,name..' varied deletion '..i)
    end
    for i=#saved,1,-1 do bp:Add(saved[i]);Compare(bp,nil,name..' restore '..i) end
    local owner={}
    for i,id in ipairs(ids) do if i%2==0 then owner[id]=1 end end
    Compare(bp,owner,name..' ownership changes')
    local p=bp:Remove(ids[1]);Compare(bp,owner,name..' delete with ownership')
    bp:Add(p);Compare(bp,owner,name..' restore with ownership')
    owner[ids[2]]=2;Compare(bp,owner,name..' surviving owner changes')
    bp:Clear();Compare(bp,owner,name..' clear releases old entries')
    benchmarks[#benchmarks+1]=row
end
-- Overlapping cells must reveal the remaining occupant after the front one is
-- removed. Filtering the old occupancy map would lose that blocker.
local bp=BP.New()
local weaponType,blockType
for _,d in ipairs(require('parts.Defs').DATA.parts) do
    if d.weapon and not d.drill and not weaponType then weaponType=d.id end
    if d.shape and not blockType then blockType=d.id end
end
assert(weaponType and blockType)
bp:Add{type=weaponType,pos={0,0,0}}
local a=bp:Add{type=blockType,pos={0,1,1}}
local b=bp:Add{type=blockType,pos={0,1,1}}
Compare(bp,nil,'overlap initial')
bp:Remove(b.id);Compare(bp,nil,'overlap exposes prior occupant')
bp:Remove(a.id);Compare(bp,nil,'overlap final blocker removed')
return checks,benchmarks

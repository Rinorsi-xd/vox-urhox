local BP=require 'construction.Blueprint'
local Rotors=require 'construction.Rotors'
local current=require 'construction.TurretRange'
local reference=assert(loadfile(turret_reference))()
local prefabs=require('combat.ArenaData').prefabs
local checks=0
local function Equal(a,b,path)
    assert(type(a)==type(b),path..' type')
    if type(a)~='table' then
        assert(a==b,path..' value')
        if type(a)=='number' then assert(string.pack('>d',a)==string.pack('>d',b),path..' bits') end
        checks=checks+1;return
    end
    for key,value in pairs(a) do Equal(value,b[key],path..'/'..tostring(key)) end
    for key in pairs(b) do assert(a[key]~=nil,path..' extra key '..tostring(key)) end
end
local keys={};for key in pairs(prefabs) do keys[#keys+1]=key end;table.sort(keys)
local rows={}
for _,key in ipairs(keys) do
    local row={key=key,parts=#prefabs[key].parts,previousMs={},currentMs={}}
    for repeatIndex=1,3 do
        local bp=BP.New():Load(prefabs[key]);local graph=bp:Graph()
        local _,owner=Rotors.Spec(bp,graph)
        local results={}
        -- Alternate execution order to reduce cache/thermal ordering bias.
        for _,name in ipairs(repeatIndex%2==1 and {'previous','current'} or {'current','previous'}) do
            collectgarbage('collect')
            local start=os.clock()
            results[name]=(name=='previous' and reference or current).For(bp,owner)
            row[name..'Ms'][repeatIndex]=(os.clock()-start)*1000
        end
        Equal(results.previous,results.current,key..'/cold/'..repeatIndex)
        Equal(reference.For(bp,owner),current.For(bp,owner),key..'/warm/'..repeatIndex)
    end
    rows[#rows+1]=row
end
return rows,checks

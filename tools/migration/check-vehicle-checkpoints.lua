local BP=require 'construction.Blueprint'
local Spec=require 'drive.VehicleSpec'
local Rotors=require 'construction.Rotors'
local Turret=require 'construction.TurretRange'
local checks={}
checkpoint_source_differences={}
local function Check(value,name) assert(value,name);checks[#checks+1]=name end
local function Normalize(value)
    if value==cjson.null then return nil end
    if type(value)=='number' then
        if value==math.huge or value==-math.huge or value~=value then return nil end
        return value
    end
    if type(value)=='table' then local out={};for k,v in pairs(value) do out[k]=Normalize(v) end;return out end
    return value
end
local function Equal(a,b,path)
    path=path or 'value'
    if type(a)~=type(b) then return false,path..' type' end
    if type(a)=='number' then return a==b or math.abs(a-b)<1e-7*math.max(1,math.abs(b)),path end
    if type(a)~='table' then return a==b,path end
    for k,v in pairs(a) do local ok,why=Equal(v,b[k],path..'.'..tostring(k));if not ok then return false,why end end
    for k in pairs(b) do if a[k]==nil then return false,path..' missing '..tostring(k) end end
    return true,path
end
local function Same(a,b,name)
    local ok,why=Equal(Normalize(a),Normalize(b));Check(ok,name..': '..why)
end
local function Async(fn)
    local result,yields=nil,0
    local co=coroutine.create(function() result=table.pack(fn(function() coroutine.yield() end)) end)
    while coroutine.status(co)~='dead' do local ok,why=coroutine.resume(co);assert(ok,why);yields=yields+1 end
    return result,yields-1
end
local function Blueprint(parts)
    local bp=BP.New();for _,p in ipairs(parts) do bp:Add(p) end;return bp
end
local function Contract(spec)
    local out={}
    for _,key in ipairs({'ok','reason','partIds','dropped','boxes','hulls','sensors','wheels','hovers','legs','thrusters','weapons','bounds','motion'}) do out[key]=spec[key] end
    return out
end
-- Exercise every source model/rotation, including the exact Float32 track hull.
for i,c in ipairs(fixture.cases) do
    local expected=Contract(c.spec)
    local actual=Contract(Spec.BuildParts({c.part}))
    local sourceEqual,why=Equal(Normalize(actual),Normalize(expected))
    if sourceEqual then Check(true,'source part '..i) else
        checkpoint_source_differences[#checkpoint_source_differences+1]={case=i,type=c.part.type,rot=c.part.rot,path=why}
    end
    if i%24==1 then
        local result=Async(function(pause) return Spec.BuildParts({c.part},nil,nil,nil,pause) end)
        Same(Contract(result[1]),actual,'cooperative source part '..i)
    end
end
for i,c in ipairs(rotor_fixture.specs) do
    local bp=Blueprint(c.parts);local adj=bp:Graph();local conn=bp:Connectivity(adj)
    local result,n=Async(function(pause) return bp:Graph(pause),bp:Connectivity(adj,pause) end)
    Same(result[1],adj,'cooperative graph '..i);Same(result[2],conn,'cooperative connectivity '..i)
    Check(n>0,'graph actually yields '..i)
    local r,owner=Rotors.Spec(bp,adj,conn.reached)
    local rotorAsync=Async(function(pause) return Rotors.Spec(bp,adj,conn.reached,pause) end)
    Same(rotorAsync[1],r,'cooperative rotor sweep '..i);Same(rotorAsync[2],owner,'cooperative rotor owner '..i)
end
for i,c in ipairs(fixture.turrets) do
    local owner={};for id,value in pairs(c.owner) do owner[tonumber(id)]=value end
    local bp=Blueprint(c.parts)
    local expected=Turret.Compute(bp:List(),bp.parts[1],owner)
    local sourceEqual,why=Equal(Normalize(expected),Normalize(c.range))
    if sourceEqual then Check(true,'source turret '..i) else
        checkpoint_source_differences[#checkpoint_source_differences+1]={turret=i,path=why}
    end
    local result=Async(function(pause) return Turret.Compute(bp:List(),bp.parts[1],owner,pause) end)
    Same(result[1],expected,'cooperative turret sweep '..i)
end
local Prefab=require 'construction.Prefab'
for _,id in ipairs({'raceCar','megaMech','scorpion','hawk','feather','vanguard','tianyuan','fuyuan','fox','trooper'}) do
    local source=Prefab.Create(BP.New(),id):ToTable()
    local sync=Spec.Build(BP.New():Load(source))
    local progress,last={},0
    local result,n=Async(function(pause)
        return Spec.Build(BP.New():Load(source),function(p)
            assert(p>=last and p<=1,'monotonic spec progress');last=p;progress[#progress+1]=p;pause()
        end)
    end)
    Same(result[1],sync,'full prefab cooperative spec '..id)
    Check(n>0 and last==1,'prefab completed cooperative progress '..id)
end
local Unit=require 'combat.CarUnit'
local source=Prefab.Create(BP.New(),'raceCar'):ToTable()
local created,disposed=0,0
local env={time=0,viewEvents={},units={}}
function env:NewVehicle(spec,unit)
    created=created+1
    return {Dispose=function() disposed=disposed+1 end,Place=function() end,
        body={translation=function() return {x=0,y=0,z=0} end,rotation=function() return {x=0,y=0,z=0,w=1} end,
            center=function() return {x=0,y=0,z=0} end}}
end
local config={name='checkpoint fixture',spawn={pos={0,0,0},yaw=0}}
local candidate
local co=coroutine.create(function()
    Unit.New(env,source,config,function() assert(candidate and env.units[1]==candidate);coroutine.yield() end,
        function(unit) candidate=unit;env.units[#env.units+1]=unit end)
end)
assert(coroutine.resume(co));Check(coroutine.status(co)=='suspended','initial spawn can suspend')
Check(candidate and env.units[1]==candidate,'partial candidate retained before first suspension')
Check(created==0,'no native vehicle before spec checkpoint')
candidate:Dispose();Check(candidate.alive==false and candidate.vehicle==nil,'partial candidate safely disposed')
assert(coroutine.close(co));Check(coroutine.status(co)=='dead','cancelled coroutine closed')
local full,n=Async(function(pause) return Unit.New(env,source,config,function() pause() end) end)
Check(n>0 and created==1 and full[1].alive,'cooperative complete CarUnit spawn')
full[1]:Dispose();Check(disposed==1,'complete native stub vehicle disposed once')
local sync=Unit.New(env,source,config);Check(sync.alive and created==2,'no-checkpoint CarUnit remains synchronous');sync:Dispose()
return checks

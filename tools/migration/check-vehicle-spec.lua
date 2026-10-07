local Spec=require "drive.VehicleSpec"
local BP=require "build.Blueprint"
local Prefab=require "build.Prefab"
local file=assert(io.open("tools/migration/source-vehicle-fixtures.json","r"))
local fixture=cjson.decode(file:read("*a"));file:close()
local function Normalize(v)
    if type(v)=="number" then
        if v==math.huge or v==-math.huge or v~=v then return nil end
        return math.tointeger(v) or v
    elseif type(v)=="table" then for k,x in pairs(v) do v[k]=Normalize(x) end end
    return v
end
fixture=Normalize(fixture)
local function Equal(a,b,path)
    if type(b)=="number" then
        if type(a)~="number" or math.abs(a-b)>1e-7*math.max(1,math.abs(b)) then return false,path..": "..tostring(a).." != "..tostring(b) end
    elseif type(b)=="table" then
        if type(a)~="table" then return false,path..": missing table" end
        for k,v in pairs(b) do local ok,why=Equal(a[k],v,path.."."..tostring(k));if not ok then return false,why end end
        for k in pairs(a) do if b[k]==nil then return false,path..": unexpected "..tostring(k) end end
    elseif a~=b then return false,path..": "..tostring(a).." != "..tostring(b) end
    return true,path
end
V.atFrame(55,function()
    V.assert(not Spec.Build(BP.New()).ok,"core is required")
    for _,case in ipairs(fixture.cases) do
        local label=case.part.type.." rotation "..case.part.rot
        local actual=Normalize(Spec.BuildParts({case.part}))
        local ok,why=Equal(actual,case.spec,label.." vehicle");V.assert(ok,why)
        ok,why=Equal(Normalize(Spec.Debris({case.part})),case.debris,label.." debris");V.assert(ok,why)
    end
    for key,build in pairs({buildRaceCar=Prefab.BuildRaceCar,buildTank=Prefab.BuildTank}) do
        local bp=build(BP.New())
        local ok,why=Equal(Normalize(Spec.Build(bp)),fixture.prefabs[key],key.." full spec");V.assert(ok,why)
        bp:Add{type="cube",pos={100,100,100},rot=0,color=0xffffff}
        V.assert(Spec.Build(bp).dropped==1,key.." disconnected structure excluded")
    end
    V.finish()
end)

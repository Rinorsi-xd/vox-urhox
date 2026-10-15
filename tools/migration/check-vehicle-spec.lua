local Spec=require "drive.VehicleSpec"
local BP=require "construction.Blueprint"
local Prefab=require "construction.Prefab"
local Turret=require 'construction.TurretRange'
local file=assert(io.open("tools/migration/source-vehicle-fixtures.json","r"))
local fixture=cjson.decode(file:read("*a"));file:close()
local function Normalize(v)
    if type(v)=="number" then
        if v==math.huge or v==-math.huge or v~=v then return nil end
        return math.tointeger(v) or v
    elseif type(v)=="table" then local out={};for k,x in pairs(v) do out[k]=Normalize(x) end;return out end
    return v
end
fixture=Normalize(fixture)
-- This suite compares migrated geometry/motion. Turntables have a separate
-- source-motion suite; mechLegs and aerodynamic wings remain migration gaps.
local function Contract(spec)
    local out={}
    for _,key in ipairs({'ok','reason','partIds','dropped','boxes','hulls','sensors','wheels','hovers','legs','thrusters','weapons','bounds','motion'}) do out[key]=spec[key] end
    return out
end
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
local rules=coroutine.create(function()
    V.assert(not Spec.Build(BP.New()).ok,"core is required")
    for i,case in ipairs(fixture.cases) do
        local label=case.part.type.." rotation "..case.part.rot
        local actual=Contract(Normalize(Spec.BuildParts({case.part})))
        local ok,why=Equal(actual,Contract(case.spec),label.." vehicle");V.assert(ok,why)
        ok,why=Equal(Normalize(Spec.Debris({case.part})),case.debris,label.." debris");V.assert(ok,why)
        if i%80==0 then coroutine.yield() end
    end
    for key,build in pairs({buildRaceCar=Prefab.BuildRaceCar,buildTank=Prefab.BuildTank}) do
        local bp=build(BP.New())
        local ok,why=Equal(Contract(Normalize(Spec.Build(bp))),Contract(fixture.prefabs[key]),key.." full spec");V.assert(ok,why)
        bp:Add{type="cube",pos={100,100,100},rot=0,color=0xffffff}
        V.assert(Spec.Build(bp).dropped==1,key.." disconnected structure excluded")
    end
    for i,case in ipairs(fixture.turrets) do
        local bp=BP.New();local owner={}
        for _,p in ipairs(case.parts) do bp:Add(p) end
        for id,value in pairs(case.owner) do owner[tonumber(id)]=value end
        local expected=case.range
        local range=Turret.For(bp,owner)[1]
        local ok,why=Equal(Normalize(range),Normalize(expected),'turret '..i..' source range');V.assert(ok,why)
        V.assert((range and Turret.Text(range) or '')==case.text,'turret '..i..' source warning text')
        local cached=Turret.For(bp,owner)[1];V.assert(cached==range,'turret '..i..' unchanged blueprint reuses sweep')
        local part=require('combat.WeaponLoadout').Part(bp.parts[1]);part.range=range
        local ws=require('combat.WeaponSystem').New({weapons={part}});local w=ws.groups[1].weapons[1]
        for frame,f in ipairs(case.frames) do
            ws:Aim(w,1/30,f.state)
            local ok,why=Equal({yaw=w.yaw,pitch=w.pitch,limited=w.limited,err=w.err},
                {yaw=f.yaw,pitch=f.pitch,limited=f.limited,err=f.err},'turret '..i..' source motion '..frame);V.assert(ok,why)
        end
        if case.layout=='wall' and range and not range.free then
            local diag=require('construction.BlueprintDiagnostics').Compute(bp,require('Config').TIERS[5]);local found=false
            for _,warning in ipairs(diag.list) do if warning.text:find(case.text,1,true) then found=true end end
            V.assert(found,'turret '..i..' production build diagnostics display the source restriction')
        end
        for _,p in ipairs(bp:List()) do if p.id~=1 then bp:Remove(p.id) end end
        V.assert(Turret.For(bp,owner)[1]==nil,'turret '..i..' destroyed wall clears cached restriction')
        coroutine.yield()
    end
    local scene=Scene();local space=require('physics.Space').New(scene)
    for _,type in ipairs({'track2','track3','track4','track5'}) do
        local bp=BP.New();bp:Add{type=type,pos={0,3,0},rot=0}
        local spec=Spec.BuildParts(bp:List());local vehicle=require('drive.Vehicle').New(space,spec)
        V.assert(vehicle.node:GetComponent('CollisionShape').shapeType==SHAPE_CONVEXHULL,type..' production native chassis uses convex track contour')
        local h=spec.hulls[1];local v={h.shape[1],h.shape[2],h.shape[3]}
        local center=require('core.Math3').Add(h.center,require('core.Math3').Rotate(h.quat,v))
        local hit=space:Raycast({center[1],center[2]+10,center[3]},{0,-1,0},20)
        V.assert(hit and hit.owner.ref==vehicle,type..' convex contour participates in native world rays')
        vehicle:Dispose()
    end
    scene:Dispose()
end)
for frame=55,215 do V.atFrame(frame,function()
    if coroutine.status(rules)~='dead' then
        local ok,why=coroutine.resume(rules);V.assert(ok,'source vehicle coroutine: '..tostring(why))
    end
end) end
V.atFrame(220,function() V.assert(coroutine.status(rules)=='dead','all source vehicle fixtures completed');V.finish() end)

-- Actual Native modules, alternating same-process comparisons. No game saves.
local root='D:/Rino_Project/maker/Vox/VoxelCraft/.tmp/perf-optimization-20261016/'
local rows,checks={},0
local scene
local function Check(ok,msg) checks=checks+1;assert(ok,msg) end
local function Now() return Time:GetSystemTime() end
local function Measure(label,n,fn)
    collectgarbage('collect')
    local t=Now()
    for i=1,n do fn(i) end
    local ms=(Now()-t)&0xffffffff
    rows[#rows+1]={label=label,count=n,totalMs=ms,msPerCall=ms/n}
    print('[perf-opt] '..label..' '..ms..'ms / '..n)
end
local function Equal(a,b,path)
    path=path or ''
    if type(a)=='number' and type(b)=='number' then
        Check(a==b or math.abs(a-b)<1e-8,'number mismatch '..path..' '..a..' '..b);return
    end
    Check(type(a)==type(b),'type mismatch '..path)
    if type(a)=='table' then
        for k,v in pairs(a) do Equal(v,b[k],path..'.'..tostring(k)) end
        for k in pairs(b) do Check(a[k]~=nil,'extra '..path..'.'..tostring(k)) end
    else Check(a==b,'value mismatch '..path) end
end
local function Run()
    local BP=require 'construction.Blueprint'
    local Prefab=require 'construction.Prefab'
    local Spec=require 'drive.VehicleSpec'
    local Vehicle=require 'drive.Vehicle'
    local Space=require 'physics.Space'
    local Ray=require 'combat.VehicleRay'
    local OldRay=assert(loadfile(root..'before/scripts/combat/VehicleRay.lua'))()
    local View=require 'render.VehicleView'
    local Drive=require 'render.DriveView'
    local Sync=require 'combat.PlayerViewSync'
    local OldSync=assert(loadfile(root..'before/scripts/combat/PlayerViewSync.lua'))()
    local V=require 'core.Math3'
    local Defs=require('parts.Defs').PARTS
    local Arena=require 'combat.ArenaData'
    scene=Scene();scene:CreateComponent('Octree')
    local space=Space.New(scene)
    local bps={Prefab.Create(BP.New(),'raceCar'),BP.New():Load(Arena.prefabs['red:3:heavy:0']),BP.New():Load(Arena.prefabs['red:3:sniper:0'])}
    local cars={}
    for _,bp in ipairs(bps) do
        local spec=Spec.Build(bp);Check(spec.ok,'invalid vehicle')
        local car=Vehicle.New(space,spec);car:Place({0,0,0},.37);cars[#cars+1]=car
    end
    local seed=20261016
    local function Random() seed=(seed*1664525+1013904223)&0xffffffff;return seed/4294967296 end
    local rays={}
    for index,car in ipairs(cars) do
        local p=car.body.translation()
        for i=1,4000 do
            local o={p.x+(Random()-.5)*40,p.y+(Random()-.5)*16,p.z+(Random()-.5)*40}
            local target={p.x+(Random()-.5)*6,p.y+(Random()-.5)*4,p.z+(Random()-.5)*6}
            local d=i%5==0 and ({ {1,0,0},{0,1,0},{0,0,1} })[i%3+1] or V.Normalize(V.Sub(target,o))
            rays[#rays+1]={car=car,o=o,d=d,length=i%7==0 and 0 or Random()*60}
        end
        -- Origins inside, on surfaces, and parallel to slab boundaries.
        for _,shape in ipairs(car.spec.boxes) do
            for axis=1,3 do for _,side in ipairs({-1,0,1}) do
                local o={table.unpack(shape.center)};o[axis]=o[axis]+shape.half[axis]*side
                local q=car.body.rotation();o=V.Add(V.Rotate(q,o),{p.x,p.y,p.z})
                local d={0,0,0};d[axis]=1;d=V.Rotate(q,d)
                rays[#rays+1]={car=car,o=o,d=d,length=50}
            end end
        end
    end
    for _,r in ipairs(rays) do
        local a,b=OldRay.Cast(r.car,r.o,r.d,r.length),Ray.Cast(r.car,r.o,r.d,r.length)
        if a then a.body=nil end;if b then b.body=nil end;Equal(a,b,'ray')
    end
    for pass=1,4 do
        local order=pass%2==1 and {{'ray-before',OldRay},{'ray-after',Ray}} or {{'ray-after',Ray},{'ray-before',OldRay}}
        for _,item in ipairs(order) do Measure(item[1]..'-'..pass,2,function()
            for _,r in ipairs(rays) do item[2].Cast(r.car,r.o,r.d,r.length) end
        end) end
    end
    local bp,car=bps[1],cars[1]
    local before,after=Drive.New(scene,bp,car),Drive.New(scene,bp,car)
    local function Controller(view)
        local u={bp=bp,vehicle=car,weapons={},alive=true}
        return {player=u,world={viewEvents={}},session={view=view,vehicle=car,weapons=u.weapons}}
    end
    local a,b=Controller(before),Controller(after)
    local victim
    for _,part in ipairs(bp:List()) do if Defs[part.type].shape then victim=part;break end end
    Check(victim~=nil,'missing removable block')
    local oldNodes={};for id,vis in pairs(after.view.visuals) do oldNodes[id]=vis.node end
    local function Changed(controller,spawn)
        controller.world.viewEvents={{type=spawn and 'unitSpawn' or 'unitRebuilt',unit=controller.player}}
    end
    local function CompareVisuals()
        local n=0
        for id,p in pairs(bp.parts) do
            local va,vb=before.view.visuals[id],after.view.visuals[id]
            Check(va~=nil and vb~=nil,'missing visual '..id)
            Check(va.part==p and vb.part==p,'stale part '..id)
            Equal({va.node.position.x,va.node.position.y,va.node.position.z},{vb.node.position.x,vb.node.position.y,vb.node.position.z},'position')
            Check(#va.models==#vb.models,'model count');n=n+1
        end
        local count=0;for id in pairs(after.view.visuals) do Check(bp.parts[id]~=nil,'ghost part');count=count+1 end
        Check(count==n,'visual count')
        local ba,bb=before.view:GetWorldBounds(),after.view:GetWorldBounds()
        Equal({ba.min.x,ba.min.y,ba.min.z,ba.max.x,ba.max.y,ba.max.z},{bb.min.x,bb.min.y,bb.min.z,bb.max.x,bb.max.y,bb.max.z},'bounds')
    end
    for pass=1,4 do
        for i=1,8 do
            if bp.parts[victim.id] then bp:Remove(victim.id) else bp:Add(victim) end
            Changed(a);Changed(b)
            local order=pass%2==1 and {{'view-before',OldSync,a},{'view-after',Sync,b}} or {{'view-after',Sync,b},{'view-before',OldSync,a}}
            for _,item in ipairs(order) do Measure(item[1]..'-'..pass,1,function() item[2].Update(item[3]) end) end
            CompareVisuals()
            for id,node in pairs(oldNodes) do if id~=victim.id then Check(after.view.visuals[id].node==node,'survivor rebuilt') end end
        end
    end
    Changed(a,true);Changed(b,true);OldSync.Update(a);Sync.Update(b);CompareVisuals()
    Check(after.view.visuals[victim.id].node~=oldNodes[victim.id],'spawn did not rebuild')
    before:Dispose();after:Dispose()
    for _,vehicle in ipairs(cars) do vehicle:Dispose() end
    space:Dispose();scene:Dispose();scene=nil
    return {result='PASS',checks=checks,rayCases=#rays,rows=rows,scope='Native headless alternating microbenchmarks and exact hit/visual assertions; not rendered FPS or phone acceptance'}
end
function Start()
    local ok,result=xpcall(Run,debug.traceback)
    if not ok then result={result='FAIL',error=result,checks=checks,rows=rows};print(result.error) end
    local f=assert(io.open(root..'probe-result.json','wb'));f:write(cjson.encode(result));f:close()
    engine:Exit()
end

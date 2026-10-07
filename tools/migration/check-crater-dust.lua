-- Same production effect, deterministic seeds and camera poses before/after GPU port.
-- The full map still loads first; hidden geometry isolates tiny particles for image QA.
local label='gpu';local batch=4
for _,arg in ipairs(GetArguments()) do
    label=arg:match('^-dust%-label=(%w+)$') or label
    batch=tonumber(arg:match('^-dust%-batch=(%d+)$')) or batch
end
local air,camera,root
local samples,allocations={},{}
V.atFrame(150,function()
    local ctx=CRATER_PREVIEW
    V.assert(ctx~=nil,'authored map available for effect probe')
    if not ctx then return end
    ctx.environment.Update=function() end
    for _,n in ipairs(ctx.scene:GetChildren()) do n:SetEnabledRecursive(false) end
    camera=ctx.camera.node;camera.enabled=true;camera.position=Vector3(0,12,0);camera.rotation=Quaternion.IDENTITY
    root=ctx.scene:CreateChild('DustProbe')
    math.randomseed(7319)
    air=require('render.CraterDust').New(root,ctx.environment.effects)
    air.streak.enabled=false
    air:Update(7,camera)
end)
for frame=155,254 do V.atFrame(frame,function()
    if not air then return end
    collectgarbage('collect');collectgarbage('stop')
    local memory=collectgarbage('count');local started=os.clock()
    for i=1,batch do air:Update(frame/60+i/(60*batch),camera) end
    samples[#samples+1]=(os.clock()-started)*1000/batch
    allocations[#allocations+1]=(collectgarbage('count')-memory)/batch
    collectgarbage('restart')
end) end
local function Pose(x,y,z,yaw,t)
    if not air then return end
    camera.position=Vector3(x,y,z);camera.rotation=Quaternion(yaw,Vector3.UP)
    air:Update(t,camera)
end
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img),'render dust '..name)
    V.assert(img:SavePNG('docs/migration/evidence/dust-'..label..'-'..name..'.png'),'save dust '..name);img:Dispose()
end
V.atFrame(260,function() Pose(0,12,0,0,7) end)
V.atFrame(263,function() Shot('origin') end)
V.atFrame(270,function() Pose(-220,45,160,127,17) end)
V.atFrame(273,function() Shot('teleport') end)
V.atFrame(280,function() Pose(95,8,-130,-70,257) end)
V.atFrame(283,function() Shot('wrap') end)
V.atFrame(290,function()
    V.assert(#samples==100,'all effect CPU samples collected')
    if label=='gpu' and air then
        V.assert(air.g:GetNumVertices(0)==9606 and not air.g.dynamic,'1600 particle seeds remain in a static native buffer')
        V.assert((air.g.node.position-camera.position).length<.001,'culling bounds follow teleported camera')
        local before=air.g:GetVertex(0,0).position
        local original=air.g;local streak=air.streak
        -- Intercept actual geometry upload entry points; steady updates may only
        -- set shader time and camera translation, never rebuild either buffer.
        local uploads=0
        air.g=setmetatable({},{__index=function(_,key)
            if key=='BeginGeometry' or key=='Commit' then return function() uploads=uploads+1 end end
            local value=original[key]
            if type(value)=='function' then return function(_,...) return value(original,...) end end
            return value
        end})
        air.streak=setmetatable({},{__index=function(_,key)
            if key=='BeginGeometry' or key=='Commit' then return function() uploads=uploads+1 end end
            local value=streak[key]
            if type(value)=='function' then return function(_,...) return value(streak,...) end end
            return value
        end})
        for i=1,30 do air:Update(257+i/60,camera) end
        air.g=original;air.streak=streak
        V.assert(uploads==0,'steady camera updates upload no mote or ground-streak geometry')
        V.assert((air.g:GetVertex(0,0).position-before).length<.00001,'animation leaves native particle seeds unchanged')
    end
    if #samples>0 then
        table.sort(samples);table.sort(allocations)
        print('[CraterDustMetrics] '..cjson.encode({label=label,samples=#samples,calls_per_sample=batch,cpu_median_ms=samples[50],cpu_p95_ms=samples[95],lua_alloc_median_kib=allocations[50],lua_alloc_p95_kib=allocations[95]}))
    end
    if air then air:Dispose();air=nil end
    if root then root:Remove() end
    V.finish()
end)

-- The active Zone must keep its applied SH/IBL while reusable cache is purged.
local work=nil ---@type thread|nil
local done=false
local function Capture(name)
    for _=1,10 do coroutine.yield() end
    local image=Image:new();assert(graphics:TakeScreenShot(image))
    V.assert(image:SavePNG('docs/migration/evidence/environment-cache-'..name..'.png'),'capture '..name);image:Dispose()
end
local function Exercise()
    local p=CRATER_PREVIEW;p.environment.Update=function() end
    p.environment.effects.root:SetEnabledRecursive(false)
    p.camera.node.position=Vector3(-70,28,-200);p.camera.node:LookAt(Vector3(0,8,-272));p.camera.fov=32
    local zone=p.scene:GetComponent('Zone',true)
    local source=zone.sourceTexture
    V.assert(source and source.name=='Crater/Sky.hdr','production Zone has original sky')
    Capture('before')
    environmentBakeCache:ClearCache();collectgarbage('collect');cache:ReleaseAllResources(false)
    V.assert(zone.sourceTexture==source,'active Zone retains sky while reusable cache clears')
    Capture('after');done=true;V.finish()
end
for frame=130,290 do V.atFrame(frame,function()
    if not CRATER_PREVIEW or done then return end
    if not work then work=coroutine.create(Exercise) end
    if coroutine.status(work)~='dead' then local ok,err=coroutine.resume(work);assert(ok,err) end
end) end
V.atFrame(295,function() V.assert(done,'active environment remains renderable');V.finish() end)

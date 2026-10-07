-- Actual production terrain. Changing baked direct visibility must not
-- darken its indirect lighting; then prove the same map still shades sunlight.
local work=nil ---@type thread|nil
local done=false
local function Capture(name)
    for _=1,5 do coroutine.yield() end
    local image=Image:new();assert(graphics:TakeScreenShot(image))
    V.assert(image:SavePNG('docs/migration/evidence/crater-direct-'..name..'.png'),'capture baked light channel '..name)
    image:Dispose()
end
local function Exercise()
    local p=CRATER_PREVIEW
    p.environment.Update=function() end
    p.camera.node.position=Vector3(-70,28,-200);p.camera.node:LookAt(Vector3(0,8,-272))
    p.camera.fov=2*math.atan(18/26/(graphics:GetWidth()/graphics:GetHeight()))*180/math.pi
    p.environment.effects.root.enabled=false
    local lights=p.scene:GetComponents('Light',true)
    for _,light in ipairs(lights) do light.enabled=false end
    cache:AddResourceDir('.tmp',false)
    local dark=assert(cache:GetResource('Texture2D','crater-direct-shadow.png'))
    local clear=assert(cache:GetResource('Texture2D','crater-direct-clear.png'))
    local material=assert(cache:GetResource('Material','Crater/material-1.xml'))
    material:SetSurfaceTexture('tGround',dark);Capture('indirect-shadow')
    material:SetSurfaceTexture('tGround',clear);Capture('indirect-clear')
    local sun=p.scene:GetChild('CraterSun',true):GetComponent('Light');sun.enabled=true
    material:SetSurfaceTexture('tGround',dark);Capture('sun-shadow')
    material:SetSurfaceTexture('tGround',clear);Capture('sun-clear')
    done=true;V.finish()
end
for frame=100,290 do V.atFrame(frame,function()
    if not CRATER_PREVIEW or done then return end
    if not work then work=coroutine.create(Exercise) end
    if coroutine.status(work)~='dead' then local ok,err=coroutine.resume(work);assert(ok,err) end
end) end
V.atFrame(295,function() V.assert(done,'all direct and indirect captures completed');V.finish() end)

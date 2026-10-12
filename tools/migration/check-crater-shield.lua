-- Production map and material; fixed source sequence independent of frame speed.
local work=nil ---@type thread|nil
local done=false
local function Capture(name)
    coroutine.yield();coroutine.yield();coroutine.yield()
    local image=Image:new();assert(graphics:TakeScreenShot(image))
    V.assert(image:SavePNG('docs/migration/evidence/crater-shield-'..name..'.png'),'render shield '..name)
    image:Dispose()
end
local function Exercise()
    cache:AddResourceDir('tools/migration',false)
    local reference=require('core.ResourceData').Read('crater-shield-reference.json')
    local p=CRATER_PREVIEW;local shield=p.environment.effects.shields[1]
    local environmentUpdate=p.environment.Update
    p.environment.Update=function() end
    local color=shield.material:GetShaderParameter('uColor'):GetVector3()
    V.assert(math.abs(color.x-reference.team_color[1])<1e-6 and math.abs(color.y-reference.team_color[2])<1e-6 and math.abs(color.z-reference.team_color[3])<1e-6,'source team sRGB color is converted exactly once')
    local names={update='Update',hit='Hit',setHP='SetHP',down='Down',raise='Raise'}
    local function Close(a,b) return math.abs(a-b)<1e-5 end
    for i,sample in ipairs(reference.trace) do
        shield[names[sample.action[1]]](shield,sample.action[2])
        local buffer=shield.material:GetShaderParameter('uHits'):GetBuffer();buffer:Seek(0)
        local hits=buffer.size==128
        for _,hit in ipairs(sample.hits) do for _,value in ipairs(hit) do hits=Close(buffer:ReadFloat(),value) and hits end end
        V.assert(Close(shield.time,sample.time) and Close(shield.hp,sample.hp) and Close(shield.down,sample.down) and Close(shield.raise,sample.raise) and (shield.animation~=nil)==sample.anim and hits,'original H5 controller and GPU hit buffer step '..i)
    end
    local uploads=shield.uploads
    for i=1,120 do shield:Update(20+i/60) end
    V.assert(shield.uploads==uploads and #shield.hits==8,'idle shield does not allocate or upload a growing hit list')
    shield:Reset();V.assert(shield.nextHit==1 and shield.hits[1][4]==-1 and shield.hp==1 and shield.raise==1 and shield.down==0,'reset restores complete shield and clears hits')
    -- Same camera as the formal H5 fort reference.
    p.camera.node.position=Vector3(-70,28,-200);p.camera.node:LookAt(Vector3(0,8,-272))
    p.camera.fov=2*math.atan(18/26/(graphics:GetWidth()/graphics:GetHeight()))*180/math.pi
    p.environment.time=10;environmentUpdate(p.environment,0,p.camera.node)
    shield:Update(10);Capture('intact')
    shield:Hit(reference.hit);shield:Update(10.08);Capture('flash')
    shield:Update(10.4);Capture('ring')
    shield:Update(12);Capture('expired')
    shield:SetHP(.1);Capture('low')
    shield:Down();shield:Update(12.8);Capture('dissolve')
    shield:Update(13.6);Capture('down')
    shield:Raise();shield:Update(14.7);Capture('raise')
    shield:Update(15.8);Capture('raised')
    shield:Reset();shield:Update(10)
    V.assert(not p.environment.effects.shields[2].disposed,'own shield events do not dispose enemy presentation')
    done=true;V.finish()
end
for frame=100,225 do V.atFrame(frame,function()
    if not CRATER_PREVIEW or done then return end
    if not work then work=coroutine.create(Exercise) end
    if coroutine.status(work)~='dead' then local ok,err=coroutine.resume(work);assert(ok,err) end
end) end
V.atFrame(230,function() V.assert(done,'shield source sequence and all rendered states completed');V.finish() end)

-- Actual converted meshes/materials rendered in isolation for normal-map QA.
local work=nil ---@type thread|nil
local done=false
local function Capture(name)
    for _=1,8 do coroutine.yield() end
    local im=Image:new();assert(graphics:TakeScreenShot(im))
    V.assert(im:SavePNG('docs/migration/evidence/crater-scatter-'..name..'.png'),'capture '..name);im:Dispose()
end
local function Exercise()
    local p=CRATER_PREVIEW;p.environment.Update=function() end
    local originals={}
    for _,group in ipairs(p.scene:GetComponents('StaticModelGroup',true)) do
        for _,i in ipairs({91,97}) do
            if group.material and group.material.name=='Crater/material-'..i..'.xml' then originals[i]=group.model end
        end
    end
    for i=91,98 do
        local mat=assert(cache:GetResource('Material','Crater/material-'..i..'.xml'))
        V.assert(mat:GetSurfaceTexture('normal_map')~=nil,'original scatter normal texture bound '..i)
    end
    for _,node in ipairs(p.scene:GetChildren()) do
        if node.name~='Camera' and node.name~='Environment' and node.name~='CraterSky' then node:SetEnabledRecursive(false) end
    end
    local node=p.scene:CreateChild('ScatterNormalProbe');local model=node:CreateComponent('StaticModel')
    p.camera.node.position=Vector3(-4,3,-8);p.camera.node:LookAt(Vector3.ZERO);p.camera.fov=38
    for _,item in ipairs({{91,'rock'},{97,'leaves'}}) do
        model.model=assert(originals[item[1]])
        local box=model.model.boundingBox;local scale=5/box.size.length
        node:SetScale(scale);node.position=-box.center*scale
        local mat=assert(cache:GetResource('Material','Crater/material-'..item[1]..'.xml')):Clone();model.material=mat
        mat:SetShaderParameter('normal_scale',Variant(Vector2(0,0)));Capture(item[2]..'-flat')
        mat:SetShaderParameter('normal_scale',Variant(Vector2(1,1)));Capture(item[2]..'-normal')
    end
    done=true;V.finish()
end
for frame=100,290 do V.atFrame(frame,function()
    if not CRATER_PREVIEW or done then return end
    if not work then work=coroutine.create(Exercise) end
    if coroutine.status(work)~='dead' then local ok,err=coroutine.resume(work);assert(ok,err) end
end) end
V.atFrame(295,function() V.assert(done,'scatter captures completed');V.finish() end)

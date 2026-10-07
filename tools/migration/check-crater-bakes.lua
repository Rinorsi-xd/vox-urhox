local work=nil ---@type thread|nil
local done=false
local views={{'fort',{-70,28,-200},{0,8,-272}},{'ship',{150,45,-190},{0,0,0}},{'interior',{-100,-5,-20},{40,-2,10}}}
local function Capture(name)
    for _=1,8 do coroutine.yield() end
    local image=Image:new();assert(graphics:TakeScreenShot(image))
    V.assert(image:SavePNG('docs/migration/evidence/crater-bakes-'..name..'.png'),'capture '..name);image:Dispose()
end
local function Exercise()
    local p=CRATER_PREVIEW;p.environment.Update=function() end;p.environment.effects.root:SetEnabledRecursive(false)
    cache:AddResourceDir('.tmp/crater-bakes',false)
    local bindings={}
    for i,d in ipairs(require('core.ResourceData').Read('Crater/Materials.json')) do
        if d.textures.tBake then
            local mat=assert(cache:GetResource('Material','Crater/material-'..i..'.xml'))
            local originalPath=d.textures.tBake:gsub('%.ktx$','.png')
            local original=assert(cache:GetResource('Texture2D',originalPath))
            local packedPath=d.textures.tBake:gsub('%.png$','.ktx')
            local packed=assert(cache:GetResource('Texture2D',packedPath))
            -- Current Runtime's LA format constant is native RG8. GetFormat
            -- does not recognize "rg8" and silently returns RGB instead.
            V.assert(packed.width==original.width and packed.height==original.height and packed.levels==1 and packed.format==Graphics:GetLuminanceAlphaFormat(),'RG8 atlas dimensions and format '..i)
            bindings[#bindings+1]={material=mat,original=original,packed=packed}
        end
    end
    V.assert(#bindings>0,'actual building materials tested')
    for _,view in ipairs(views) do
        p.camera.node.position=Vector3(table.unpack(view[2]));p.camera.node:LookAt(Vector3(table.unpack(view[3])));p.camera.fov=32
        for _,b in ipairs(bindings) do b.material:SetSurfaceTexture('tBake',b.original) end;Capture(view[1]..'-original')
        for _,b in ipairs(bindings) do b.material:SetSurfaceTexture('tBake',b.packed) end;Capture(view[1]..'-rg8')
    end
    done=true;V.finish()
end
for frame=130,290 do V.atFrame(frame,function()
    if not CRATER_PREVIEW or done then return end
    if not work then work=coroutine.create(Exercise) end
    if coroutine.status(work)~='dead' then local ok,err=coroutine.resume(work);assert(ok,err) end
end) end
V.atFrame(295,function() V.assert(done,'bake atlas candidate comparison complete');V.finish() end)

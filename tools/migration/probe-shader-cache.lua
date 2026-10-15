-- Diagnostic only: exercise the actual hangar clustered-light material path.
-- A cache-directory property echo alone is not evidence of cache persistence.
local original=''
V.atFrame(5,function()
    original=graphics:GetShaderCacheDir()
    print('[ShaderProbe] original cache='..original)
    for _,arg in ipairs(GetArguments()) do
        if arg=='-shader-isolated-cache' then graphics:SetShaderCacheDir('.tmp/shader-cache-probe/') end
    end
    print('[ShaderProbe] selected cache='..graphics:GetShaderCacheDir())
end)
V.atFrame(35,function()
    local app=VOX_HANGAR.app
    V.assert(app and app.car and app.hangar,'authored hangar loaded')
    local bp=require('construction.Prefab').BuildTank(require('construction.Blueprint').New())
    V.assert(app:LoadBlueprint(bp:ToTable()),'load real tank with rotating radar')
    app.camera.autoSpin=false
    app.hangar.greet=0;app.hangar.scanTime=10
    require('urhox-libs/UI').SetRoot(nil)
    for _,slot in ipairs({'spinSteel','spinGlow','glowBlink','glowCyan','glowGreen'}) do
        require('parts.Materials').Get(slot):SetShaderParameter('animation_time',Variant(1.95))
    end
end)
V.atFrame(55,function()
    local image=Image:new()
    V.assert(graphics:TakeScreenShot(image) and image:SavePNG('docs/migration/evidence/shader-probe.png'),'capture tank with original lights')
    image:Dispose()
    graphics:SetShaderCacheDir(original)
    V.finish()
end)

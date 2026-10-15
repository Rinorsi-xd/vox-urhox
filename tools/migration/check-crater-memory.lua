-- Read only resource residency across the actual application scene lifecycle.
local label='current'
local purgeBakes=false
-- Hidden standalone validation must not inherit the game's 10 FPS idle cap.
engine.maxInactiveFps=120
for _,arg in ipairs(GetArguments()) do label=arg:match('^%-memory%-label=([%w-]+)$') or label;if arg=='-memory-purge-bakes' then purgeBakes=true end end
local records={};local stage='boot';local app;local settle=0;local cycle=0
local types={'Texture2D','Texture2DArray','TextureCube','Image','Model','Material','XMLFile','JSONFile','SurfaceShader','Shader','Font','Sound'}
local paths=nil ---@type table|nil
local function Snapshot(name)
    local r={name=name,lua_kib=collectgarbage('count'),cache_bytes=cache:GetTotalMemoryUse(),types={},resources={}}
    for _,typ in ipairs(types) do r.types[typ]=cache:GetMemoryUse(StringHash(typ)) end
    paths=paths or require('core.ResourceData').Read('Crater/Resources.json')
    for _,path in ipairs(paths) do
        local suffix=path:match('%.(%w+)$')
        local typ=path=='Crater/albedo.xml' or path=='Crater/nra.xml'
        typ=typ and 'Texture2DArray' or (suffix=='png' or suffix=='hdr' or suffix=='ktx') and 'Texture2D' or suffix=='mdl' and 'Model' or nil
        if typ then
            local resource=cache:GetExistingResource(typ,path)
            if resource then
                local entry={path=path,type=typ,bytes=resource.memoryUse}
                if typ~='Model' then
                    entry.width=resource.width;entry.height=resource.height;entry.levels=resource.levels
                    entry.format=resource.format;entry.compressed=resource.compressed
                    if typ=='Texture2DArray' then entry.layers=resource.layers end
                    if suffix=='ktx' then V.assert(resource.format==Graphics:GetLuminanceAlphaFormat() and resource.levels==1,'packed RG8 building atlas loaded without expansion: '..path) end
                end
                r.resources[#r.resources+1]=entry
            end
        end
    end
    records[#records+1]=r;print('[CraterMemory] '..name..' cache_bytes='..r.cache_bytes)
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then app=VOX_HANGAR.app;stage='garage';settle=0
    elseif stage=='garage' then
        settle=settle+1
        if settle>=20 and not app.pendingAssetRelease then
            Snapshot('garage-'..cycle);cycle=cycle+1;app:EnterTrial('crater');stage='enter'
        end
    elseif stage=='enter' and app.trial then stage='map';settle=0
    elseif stage=='map' then
        settle=settle+1
        if settle>=20 and not app.pendingAssetRelease then
            Snapshot('crater-'..cycle)
            V.assert(#records[#records].resources>300,'actual map models and textures resident in cycle '..cycle)
            V.assert(cache:GetExistingResource('Texture2D','Hangar/HangarEnv.hdr')==nil,'inactive garage sky released in cycle '..cycle)
            app:Reload();stage='return'
        end
    elseif stage=='return' and app.mode=='hangar' and not app.pendingAssetRelease then
        stage='returned';settle=0
    elseif stage=='returned' then
        settle=settle+1
        if settle>=20 then
            if purgeBakes then
                environmentBakeCache:ClearCache();collectgarbage('collect');cache:ReleaseAllResources(false)
            end
            Snapshot('returned-'..cycle)
            V.assert(#records[#records].resources==0,'all exclusive crater models and textures released in cycle '..cycle)
            if cycle<3 then stage='garage';settle=0 else
                local file=File('docs/migration/evidence/crater-memory-'..label..'.json',FILE_WRITE)
                file:WriteLine(cjson.encode({records=records,scope='Engine resource accounting and Lua heap; excludes driver allocations and noncached render targets; Texture2D reports zero in this Runtime'}));file:Dispose()
                stage='done';V.finish()
            end
        end
    end
end
for frame=20,1750 do V.atFrame(frame,Poll) end
V.atFrame(1760,function() V.assert(stage=='done','three actual map entry and release cycles complete');V.finish() end)

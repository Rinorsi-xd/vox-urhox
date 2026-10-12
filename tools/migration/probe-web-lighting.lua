-- Isolate native contributions and inspect the engine's actual shader resources.
local app,zone,spot
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img),'capture '..name)
    local crop=img:GetSubimage(IntRect(0,0,1280,720))
    V.assert(crop:SavePNG('docs/migration/evidence/web-lighting-'..name..'.png'),'save '..name)
    crop:Dispose();img:Dispose()
end
V.atFrame(55,function()
    app=VOX_HANGAR.app;app.camera.autoSpin=false;_G.VOX_DEBUG={time=10}
    zone=app.scene:GetComponent('Zone',true)
    renderer:GetViewport(0):SetRect(IntRect(0,0,1280,720))
    for _,light in ipairs(app.scene:GetComponents('Light',true)) do
        if light.lightType==LIGHT_SPOT then spot=light end
    end
    local list=io.open('.tmp/shader-resource-list.json','r');local names=cjson.decode(list:read('*a'));list:close()
    fileSystem:CreateDir('.tmp/engine-shaders')
    for _,name in ipairs(names) do
        local f=cache:GetFile(name)
        if f then
            local out=io.open('.tmp/engine-shaders/'..name:gsub('/','_'),'w')
            while not f.eof do out:write(f:ReadLine(),'\n') end
            out:close();f:Dispose()
        end
    end
    print('[LightingProbe] api='..graphics.apiName..' quality='..renderer.materialQuality)
end)
V.atFrame(75,function()
    renderer:GetViewport(0):SetViewClusterEnabled(false)
    app.garage.reflTex.renderSurface:GetViewport(0):SetViewClusterEnabled(false)
end)
V.atFrame(95,function() Shot('no-cluster');spot.enabled=false end)
V.atFrame(115,function() Shot('no-cluster-no-spot');V.finish() end)

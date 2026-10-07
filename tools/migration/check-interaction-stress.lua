-- Exercise the real runtime paths used by camera, catalog and quality changes.
-- Deliberately collect between operations to expose stale native references.
local quality=require "render.Quality"
local initialMax=quality.current.reflectionMax
local cycles=0
V.atFrame(60,function()
    local app=assert(VOX_HANGAR).app
    local authored=app.scene:GetNode(553)
    V.assert(authored~=nil and app.camera.node==authored,"authored camera identity survives app installation")
end)
for cycle=1,30 do
    local frame=70+(cycle-1)*32
    V.atFrame(frame,function()
        local app=assert(VOX_HANGAR).app
        print("[InteractionQA] open cycle="..cycle)
        app:ToggleGallery((cycle-1)%15+1)
        V.assert(app.gallery~=nil,"catalog opens "..cycle)
    end)
    V.atFrame(frame+10,function()
        local app=VOX_HANGAR.app
        app.gallery:Page(cycle%15+1)
        app.camera.yaw=cycle*47;app.camera.pitch=cycle%80
        app.camera.dist=5+cycle%40
        app.hangar:SetTier(cycle%5+1)
        app.hangar:SetGrid(cycle%2==0)
        app.hangar:Welcome(app.blueprint)
        quality.current.reflectionMax=cycle%2==0 and initialMax or math.floor(initialMax/2)
        collectgarbage("collect")
    end)
    V.atFrame(frame+24,function()
        local app=VOX_HANGAR.app
        print("[InteractionQA] close cycle="..cycle)
        app:ToggleGallery()
        collectgarbage("collect")
        V.assert(app.gallery==nil and app.scene:GetChild("Gallery")==nil,"catalog removed "..cycle)
        V.assert(app.car.root.enabled,"car restored "..cycle)
        cycles=cycles+1
    end)
end
V.atFrame(1040,function()
    quality.current.reflectionMax=initialMax
    V.assert(cycles==30,"all interaction cycles reached completion")
end)

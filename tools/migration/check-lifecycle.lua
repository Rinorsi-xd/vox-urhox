-- Real scene replacement, authored transforms, failure retention and deferred catalog.
local generation=0
---@type Scene|nil
local retained=nil
---@type Blueprint|nil
local blueprint=nil
local errors=0
local function LoadFixture(path)
    local app=VOX_HANGAR.app
    app.loader:Load(path,function(scene) app:Install(scene) end,function(message)
        errors=errors+1
        print("[LifecycleQA] Expected rejected candidate: "..message)
    end)
end
V.atFrame(60,function()
    local app=assert(VOX_HANGAR).app
    V.assert(app.loader.state=="ready","initial authored scene ready")
    V.assert(app.gallery==nil,"catalog not instantiated during startup")
    blueprint=app.blueprint
    app.tier=4
    app.camera.dist=19
    app.camera.cur.dist=19
    app.hangar:SetGrid(true)
    generation=app.generation
    LoadFixture("Scenes/HangarLifecycleFixture.xml")
end)
V.atFrame(140,function()
    local app=VOX_HANGAR.app
    V.assert(app.generation==generation+1,"candidate scene committed once")
    V.assert(math.abs(app.hangar:Node("Equipment").position.x-1.25)<0.001,"authored object move is visible in game")
    V.assert(app.blueprint==blueprint and app.tier==4,"blueprint and tier survive scene reload")
    V.assert(math.abs(app.camera.dist-19)<0.001 and app.hangar.gridOn,"camera and grid survive scene reload")
    retained=app.scene
    LoadFixture("Scenes/HangarInvalidFixture.xml")
end)
V.atFrame(220,function()
    local app=VOX_HANGAR.app
    V.assert(errors==1 and app.loader.state=="failed","invalid scene rejected")
    V.assert(app.scene==retained and app.scene:GetChild("Car")~=nil,"failed update preserves live scene and vehicle")
    app:Reload()
end)
V.atFrame(300,function()
    local app=VOX_HANGAR.app
    V.assert(app.loader.state=="ready" and app.generation==generation+2,"retry recovers without restarting game")
    V.assert(math.abs(app.hangar:Node("Equipment").position.x)<0.001,"retry returns to saved production layout")
    local cars,cameras=0,0
    for _,node in ipairs(app.scene:GetChildren()) do
        if node.name=="Car" then cars=cars+1 end
        if node.name=="ReflectionCamera" then cameras=cameras+1 end
    end
    V.assert(cars==1 and cameras==1,"repeated reload creates no duplicate car or reflection")
    app:ToggleGallery()
    V.assert(app.gallery~=nil and app.galleryOn,"catalog is available on demand")
    app:ToggleGallery()
end)

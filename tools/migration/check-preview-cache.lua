local Cache=require 'storage.PreviewCache'
local Blueprint=require 'build.Blueprint'
local Prefab=require 'build.Prefab'
local app,store,service
local delivered={}
local function Data(slot)
    local data,generation,_,context=store:LoadSlot(slot)
    data.preview=Cache.Ref(store,slot,generation,context);return data
end
local function Request(slot,key)
    return service:Request(Data(slot),function(image,err)
        V.assert(image~=nil,'preview delivered '..key..': '..tostring(err))
        if image then
            V.assert(image.width==320 and image.height==200,'source 320x200 image '..key)
            delivered[key]=true
            image:SavePNG('docs/migration/evidence/pc-preview-'..key..'.png');image:Dispose()
        end
    end)
end
V.atFrame(50,function()
    app=VOX_HANGAR.app;require('ui.GarageHud').Dispose();service=app.previews
    store=require('storage.BlueprintStore').New('vox-preview-cache-check')
    for i=1,20 do store:DeleteSlot(i) end
    store:SaveSlot(1,Prefab.BuildEmpty(Blueprint.New()))
    Request(1,'empty')
end)
V.atFrame(85,function()
    V.assert(delivered.empty,'empty preset captured')
    V.assert(not service.scene and not service.job,'idle capture scene is released')
    local before=service.captures;Request(1,'cached');delivered.before=before
end)
V.atFrame(95,function()
    V.assert(delivered.cached and service.captures==delivered.before and service.cacheHits==1,'persistent image reload skips 3D capture')
    V.assert(not service.scene,'cached-only reads allocate no scene')
    store:SaveSlot(2,Prefab.BuildRaceCar(Blueprint.New()));Request(2,'race')
end)
V.atFrame(130,function()
    V.assert(delivered.race,'second scene capture after release completes')
    local image=Cache.Load(Data(2).preview)
    V.assert(image~=nil,'actual persisted JPEG decodes')
    if image then image:Dispose() end
    for i=3,10 do store:SaveSlot(i,Prefab.BuildEmpty(Blueprint.New()));Request(i,'batch'..i) end
end)
V.atFrame(215,function()
    for i=3,10 do V.assert(delivered['batch'..i],'serial batch capture '..i) end
    V.assert(not service.scene and not service.job,'batch capture scene and render targets retire')
    service:Dispose()
    for i=1,20 do store:DeleteSlot(i) end
    V.finish()
end)

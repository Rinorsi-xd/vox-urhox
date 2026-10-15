local ep=nil ---@type table|nil
V.atFrame(43,function()
    local app=VOX_HANGAR and VOX_HANGAR.app;V.assert(app~=nil,'actual application exists for isolated ending render')
    app.loadingFlow:Close();if app.tutorial then app.tutorial:Dispose();app.tutorial=nil end
    app.Update=function()end;app.PostUpdate=function()end
    local UI=require 'urhox-libs/UI';local scene=Scene:new();local root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root,true)
    local image=Image:new();graphics:TakeScreenShot(image)
    local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetData(image);image:Dispose()
    ep=require('ui.Epilogue').Attach(scene,root,function()end,{down=texture});ep.qaTexture=texture
    local data=require('core.ResourceData').Read('Story/Boss/Epilogue.json').data
    local photo=nil ---@type table|nil
    for _,entry in ipairs(data.scenes) do if entry.panel and entry.panel.shot then photo=entry.panel;break end end
    ep.panels={{panel=assert(photo),at=0}};ep.rules.current={kind='panel'};ep.rules.time=3
    ep.qaData=data;ep.qaScene=scene
end)
V.atFrame(46,function()
    local count=0
    for vg,handles in pairs(ep.page.captures or {}) do for texture,handle in pairs(handles) do
        local w,h=nvgImageSize(vg,handle);V.assert(handle>0 and w==texture.width and h==texture.height,'actual Boss screenshot Texture2D has a valid NanoVG video bridge');count=count+1
    end end
    V.assert(count==1,'original battle report panel renders exactly one owned capture bridge')
    local data=ep.qaData;ep.panels={{panel=data.scenes[3].panel,at=0},{panel=data.scenes[4].panel,at=0}}
    ep.rules.index=17;ep.rules.current=ep.rules.steps[17];ep.rules.age=.5;ep.rules.time=50
    V.assert(ep.rules.current.kind=='stamp','original version six stamp step selected only for render fixture')
end)
V.atFrame(49,function()
    local image=Image:new();graphics:TakeScreenShot(image)
    for _,at in ipairs({{.15,.15},{.75,.25},{.1,.8},{.85,.85}}) do
        local c=image:GetPixel(math.floor(image.width*at[1]),math.floor(image.height*at[2]))
        V.assert(math.max(c.r,c.g,c.b)<.12,'page-out keeps authored comic hidden under final rejection stamp '..at[1]..'/'..at[2])
    end
    local red=0;for y=math.floor(image.height*.34),math.floor(image.height*.58),5 do for x=math.floor(image.width*.35),math.floor(image.width*.65),5 do
        local c=image:GetPixel(x,y);if c.r>.35 and c.g<.3 and c.b<.3 then red=red+1 end
    end end
    V.assert(red>20,'real rejection stamp is visible above the dark background')
    image:SavePNG('docs/migration/evidence/epilogue-stamp-native.png');image:Dispose()
    ep:Dispose();ep:Dispose()
    V.assert(next(ep.page.captures)==nil and next(ep.shots)==nil,'ending releases every external texture bridge and stale capture reference idempotently')
    V.assert(ep.qaTexture.width==graphics:GetWidth() and ep.qaTexture.height==graphics:GetHeight(),'ending bridge release preserves Boss-owned capture texture until its owner disposes')
    ep.qaTexture:Dispose();ep.qaScene:Dispose();V.finish()
end)

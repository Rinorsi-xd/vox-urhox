V.atFrame(145,function()
    V.assert(CRATER_PREVIEW~=nil,'authored crater scene loaded')
    if CRATER_PREVIEW then
        V.assert(#CRATER_PREVIEW.environment.dynamics==54,'all 54 source dynamic parts bound')
        V.assert(CRATER_PREVIEW.scene:SaveXML('.tmp/CraterBound.xml'),'scene can serialize imported instances')
        local img=Image:new();graphics:TakeScreenShot(img);img:SavePNG('docs/migration/evidence/crater-native-overview.png');img:Dispose()
    end
    V.finish()
end)

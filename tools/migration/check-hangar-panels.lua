local app,panels,initialRenders,initialComputations,oldPanels,baseline,added
local function Textures(label)
    for id,e in pairs(panels.entries) do
        local image=e.texture:GetImage()
        V.assert(image and image.width==e.width and image.height==e.height,'read actual '..id..' canvas '..label)
        if image then
            if id=='bay' and label=='renamed' then
                V.assert(image:GetPixel(800,550).a>.8,'large bay numeral has actual filled pixels')
                V.assert(image:GetPixel(870,500).a<.01,'zero counter stays transparent')
                V.assert(image:GetPixel(65,400).a<.01 and image:GetPixel(150,500).a>.2,'arrow is shaped, not its bounding rectangle')
            end
            V.assert(image:SavePNG('docs/migration/evidence/native-panel-'..id..'-'..label..'.png'),'save '..id..' '..label);image:Dispose()
        end
    end
end
local function View(id)
    local h=app.hangar;local node=h:Node(id)
    local camera=app.camera.node
    camera.position=node.worldPosition+node.worldRotation*Vector3(0,0,10)
    camera:LookAt(node.worldPosition)
    local rig=app.camera;local angles=camera.rotation.eulerAngles
    rig.autoSpin=false;rig.target=node.worldPosition;rig.dist=10;rig.pitch=angles.x;rig.yaw=angles.y
    rig.cur={target=rig.target,dist=rig.dist,pitch=rig.pitch,yaw=rig.yaw}
    app.camera.camera.fov=50
    require('urhox-libs/UI').SetRoot(require('urhox-libs/UI').Panel{width='100%',height='100%',pointerEvents='none'},true)
end
V.atFrame(60,function()
    app=VOX_HANGAR.app;panels=app.hangar.panels;baseline=app.blueprint:ToTable()
    V.assert(panels and panels.renders==4,'all four authored surfaces have live canvases')
    V.assert(panels.info.diag.stats.count==209 and panels.info.hp==7530,'initial displays use current 209-part source car')
    for _,e in pairs(panels.entries) do
        V.assert(e.material:GetSurfaceTexture(e.sampler)==e.fallback,'authored fallback retained for '..e.id)
        V.assert(e.material:GetSurfaceTexture('canvas_map')==e.texture,'raw premultiplied sampler bound for '..e.id)
        V.assert(not e.texture:GetSRGB(),'canvas is sampled before sRGB decoding for '..e.id)
    end
    initialRenders=panels.renders;initialComputations=panels.computations;Textures('race')
end)
V.atFrame(75,function()
    V.assert(panels.renders==initialRenders and panels.computations==initialComputations,'idle scene neither redraws canvases nor recomputes diagnostics')
    app.bays:Rename('动态展示验证');app.bays.active=7;app.bays.revision=app.bays.revision+1;app.tier=5
end)
V.atFrame(83,function()
    V.assert(panels.info.name=='动态展示验证' and panels.info.no=='07' and panels.info.tier.id==5,'rename tier and slot reach runtime surfaces')
    V.assert(panels.renders==initialRenders+4,'multiple metadata changes coalesce into one redraw per surface')
    Textures('renamed');initialRenders=panels.renders
    added=app.blueprint.nextId
    app.editor.history:Commit({{op='add',data={id=added,type='cube',pos={25,5,0},rot=require('core.Rotations').IDENTITY,color=0x33ff44}}})
end)
V.atFrame(93,function()
    V.assert(panels.info.diag.stats.count==210 and panels.info.diag.conn.floatingCount==1,'real edit changes panel count and disconnected warning')
    V.assert(panels.renders==initialRenders+2,'geometry edit redraws holograms without rebaking unchanged wall and floor paint')
    local found=false;for _,c in ipairs(panels.info.projection.top) do if c.x==25 and c.z==0 and c.color==0x33ff44 then found=true end end
    V.assert(found,'blueprint scan contains new colored cell in source logical coordinates')
    Textures('edited');app.editor:Undo()
end)
V.atFrame(103,function()
    V.assert(panels.info.diag.stats.count==209 and panels.info.diag.conn.floatingCount==0,'undo refreshes panels and removes old warning')
    app:LoadBlueprint(require('construction.Prefab').BuildTank(require('construction.Blueprint').New()):ToTable())
end)
V.atFrame(116,function()
    V.assert(panels.info.diag.stats.count==223,'switching actual vehicle updates both projections and data')
    Textures('tank');app:LoadBlueprint(require('construction.Blueprint').New():ToTable())
end)
V.atFrame(126,function()
    V.assert(panels.info.diag.stats.count==0 and #panels.info.projection.top==0 and #panels.info.projection.side==0,'empty blueprint removes previous cells and retains finite layout')
    Textures('empty');app:LoadBlueprint(baseline);app.bays.active=false;app.tier=3
    oldPanels=panels;app:Reload()
end)
V.atFrame(183,function()
    panels=app.hangar.panels
    V.assert(oldPanels.disposed and oldPanels.provider==nil,'reload releases old canvas provider and unsubscribes events')
    for _,e in pairs(oldPanels.entries) do V.assert(not e.texture and not e.vg,'reload releases '..e.id..' GPU canvas') end
    V.assert(panels~=oldPanels and panels.renders==4 and panels.info.no=='--','new scene creates exactly one fresh canvas set')
    View('Holo_stats')
end)
V.atFrame(188,function()
    local img=Image:new();V.assert(graphics:TakeScreenShot(img) and img:SavePNG('docs/migration/evidence/hangar-live-data-screen.png'),'actual scene displays live data screen');img:Dispose()
    initialRenders=oldPanels.renders;app:EnterTrial()
end)
V.atFrame(245,function()
    V.assert(app.mode=='trial' and panels.disposed,'entering trial unloads all hall canvases')
    V.assert(oldPanels.renders==initialRenders,'disposed scene has no late NanoVG redraws')
    V.finish()
end)

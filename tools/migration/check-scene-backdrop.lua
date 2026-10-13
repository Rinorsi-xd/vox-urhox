local UI=require 'urhox-libs/UI'
local Backdrop=require 'render.SceneBackdrop'
local Graph=require 'render.FilterGraph'
---@type table
local state={samples={},scale=1}
local function Screenshot(name)
    local image=Image:new();assert(graphics:TakeScreenShot(image))
    image:SavePNG('docs/migration/evidence/backdrop-'..name..'.png')
    return image
end
V.atFrame(55,function()
    local app=VOX_HANGAR.app;app:EnterBuild();state.app=app;state.source=renderer:GetViewport(0)
    state.panel=app.build:OpenInventory()
    V.assert(state.panel.backdrop.graph.passCount==3,'inventory uses one scene and two blur passes')
    V.assert(state.panel.backdrop.graph.viewports[1]==state.source,'blur reuses the existing scene viewport')
    V.assert(state.panel.backdrop.graph.colorBytes<=1920*1080*10,'blur render targets have a bounded color budget')
end)
V.atFrame(70,function()
    Screenshot('inventory'):Dispose()
    local graph=state.panel.backdrop.graph
    for _=1,20 do state.panel.backdrop:Update() end
    V.assert(state.panel.backdrop.graph==graph,'unchanged inventory does not reallocate targets')
    state.panel:Close();V.assert(renderer:GetViewport(0)==state.source,'close restores the exact source viewport')
    for i=1,10 do
        local panel=state.app.build:OpenInventory();local backdrop=panel.backdrop
        panel:Close()
        V.assert(backdrop.disposed and not backdrop.graph and not backdrop.source,'open close cycle '..i..' releases graph ownership')
        V.assert(renderer:GetViewport(0)==state.source,'open close cycle '..i..' retains active camera')
    end
    state.app:ExitBuild()
    require('render.RenderTargetLifetime').Flush()
    V.assert(require('render.RenderTargetLifetime').PendingCount()==0,'closed menus leave no render targets waiting for retirement')
end)
V.atFrame(85,function()
    UI.SetRoot(nil);state.saved=renderer:GetViewport(0)
    cache:AddResourceDir('tools/migration/probes',false)
    state.pattern=Graph.New({{shader='Shaders/BLGL/BackdropProbe.shader'}},64,64)
    local zone=state.pattern.output.scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(-100,100)
    zone:SetAttribute('Bloom Enable',Variant(false));zone:SetAttribute('Auto Exposure Enable',Variant(false));zone.vignetteEnabled=false
    state.pattern.output:SetRenderPath(renderer:GetDefaultRenderPath():Clone())
    renderer:SetViewport(0,state.pattern.output)
    state.backdrop=Backdrop.New()
end)
for frame=86,110 do V.atFrame(frame,function()
    state.pattern:Parameter(1,'phase',frame%2);state.backdrop:Update()
    if frame<=90 then return end
    local image=Screenshot('pattern-'..frame)
    local w,h=image.width,image.height
    local phase=image:GetPixel(w//4,math.floor(h*.6))
    V.assert(math.abs(phase.r-frame%2)<.015,'blur uses current frame, phase '..frame)
    if frame==100 or frame==110 then
        local left=image:GetPixel(w//4,math.floor(h*.4));local right=image:GetPixel(w*3//4,math.floor(h*.4))
        V.assert(left.r<.01 and right.r>.99,'Gaussian preserves black and white without whitening')
        local top=image:GetPixel(w//4,h//8);local bottom=image:GetPixel(w//4,h*7//8)
        V.assert(top.r>.99 and top.b<.01 and bottom.b>.99 and bottom.r<.01,'render target orientation matches direct scene')
        local samples={}
        for x=-12,12 do
            local c=image:GetPixel(math.floor(w/2+x*UI.GetScale()),math.floor(h*.4));samples[#samples+1]=c.r
        end
        V.assert(samples[9]>.02 and samples[9]<.35 and samples[18]>.65 and samples[18]<.99,'four CSS pixel blur softens both sides of an edge')
        state.samples[#state.samples+1]={scale=UI.GetScale(),values=samples,width=state.backdrop.graph.width,height=state.backdrop.graph.height,colorBytes=state.backdrop.graph.colorBytes}
        if frame==100 then UI.SetScale(2);state.backdrop:Update() end
    end
    image:Dispose()
end) end
V.atFrame(115,function()
    local a,b=state.samples[1],state.samples[2]
    for i=1,#a.values do V.assert(math.abs(a.values[i]-b.values[i])<.09,'CSS blur scales with DPR, edge sample '..i) end
    local file=assert(io.open('docs/migration/evidence/backdrop-pixels.json','w'));file:write(cjson.encode(state.samples));file:close()
    local other=state.saved;renderer:SetViewport(0,other);state.backdrop:Update()
    V.assert(state.backdrop.disposed and renderer:GetViewport(0)==other,'an external scene switch is never overwritten')
    state.pattern:Dispose();state.pattern=nil;state.backdrop=nil;UI.SetScale(1)
    require('render.RenderTargetLifetime').Flush();V.finish()
end)

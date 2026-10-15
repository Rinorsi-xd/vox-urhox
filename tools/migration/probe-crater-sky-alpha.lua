-- Read the production scene's HDR/alpha; no replacement sky or render path.
local Graph=require 'render.FilterGraph'
local ready,graph,blocker
local records={}
local function Shot(name)
    local im=Image:new();assert(graphics:TakeScreenShot(im))
    local c=im:GetPixel(im.width//2,im.height//2)
    records[#records+1]={name=name,r=c.r,g=c.g,b=c.b}
    im:SavePNG('docs/migration/evidence/crater-sky-'..name..'.png');im:Dispose()
    return c
end
local function Poll(frame)
    if not ready and CRATER_PREVIEW then
        ready=frame;local p=CRATER_PREVIEW
        p.settings.Update=function() end;p.settings.PostUpdate=function() end
        p.camera.node.position=Vector3(0,300,0)
        p.camera.node:LookAt(p.camera.node.position+Vector3(.52,.5,-.69).normalized*1500)
        cache:AddResourceDir('tools/migration/probes',false)
        local post=p.settings.post
        renderer:SetViewport(0,nil);post.graph:Dispose()
        graph=Graph.New({{viewport=post.source},{shader='Shaders/BLGL/InspectAlpha.shader',inputs={source_map=1}}},graphics:GetWidth(),graphics:GetHeight())
        post.graph=graph;renderer:SetViewport(0,graph.output)
    end
    if graph then graph:Queue() end
    if ready and frame==ready+15 then
        V.assert(Shot('alpha').r<.01,'native sky preserves zero alpha for sun occlusion')
        V.assert(CRATER_PREVIEW.environment.sky.position.length<.001,'Skybox stays at origin while camera is translated')
        graph:Parameter(2,'mode',1)
    end
    if ready and frame==ready+25 then
        V.assert(Shot('hdr').r>.85,'source sun retains HDR brightness above 42.5 before clamp')
        local p=CRATER_PREVIEW
        blocker=p.scene:CreateChild('ShaftOccluder');blocker.position=p.camera.node.position+p.camera.node.worldDirection*5
        local model=blocker:CreateComponent('StaticModel');model.model=cache:GetResource('Model','Models/Box.mdl')
        model.material=cache:GetResource('Material','Crater/material-1.xml')
        graph:Parameter(2,'mode',0)
    end
    if ready and frame==ready+40 then
        V.assert(Shot('occluded').r>.99,'opaque geometry writes alpha one over the sky')
        blocker:Dispose();renderer:SetViewport(0,nil);graph:Dispose();graph=nil
        local f=File('docs/migration/evidence/crater-sky-alpha.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Dispose();V.finish()
    end
end
for frame=1,350 do V.atFrame(frame,function() Poll(frame) end) end
V.atFrame(355,function() V.assert(ready~=nil,'source map loaded for sky verification') end)

-- Exercise the production graph with alternating HDR input on every frame.
local Graph=require 'render.FilterGraph'
local graph,source
local count=28
V.atFrame(45,function()
    cache:AddResourceDir('tools/migration/probes',false);require('urhox-libs/UI').SetRoot(nil)
    source=Graph.New({{shader='Shaders/BLGL/FilterGraphProbe.shader',parameters={stage=0}}},64,64)
    local zone=source.output.scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(-100,100)
    zone:SetAttribute('Bloom Enable',Variant(false));zone:SetAttribute('Auto Exposure Enable',Variant(false));zone.vignetteEnabled=false
    source.output:SetRenderPath(renderer:GetDefaultRenderPath():Clone())
    local specs={{viewport=source.output}}
    for i=1,count do specs[#specs+1]={shader='Shaders/BLGL/FilterGraphProbe.shader',inputs={source_map=#specs},parameters={stage=1}} end
    specs[#specs+1]={shader='Shaders/BLGL/FilterGraphProbe.shader',inputs={source_map=#specs},parameters={stage=2}}
    graph=Graph.New(specs,64,64);renderer:SetViewport(0,graph.output)
end)
for frame=46,85 do V.atFrame(frame,function()
    local value=frame%2==0 and Vector3(4,2,.5) or Vector3(.2,3,1)
    source:Parameter(1,'value',value);graph:Parameter(count+2,'value',value*(.98^count));graph:Queue()
    if frame>50 then
        local image=Image:new();assert(graphics:TakeScreenShot(image));local color=image:GetPixel(image.width//2,image.height//2)
        V.assert(color.g>.95 and color.r<.05,'same-frame HDR chain '..frame);image:Dispose()
    end
end) end
V.atFrame(86,function()
    renderer:SetViewport(0,nil);graph:Dispose();source:Dispose();graph=nil;source=nil;V.finish()
end)

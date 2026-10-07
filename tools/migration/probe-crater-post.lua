local Graph=require 'render.FilterGraph'
local Post=require 'render.CraterPostProcess'
local graph,sourceGraph,indices
local source=File('tools/migration/crater-post-reference.json',FILE_READ)
local reference=cjson.decode(source:ReadString());source:Dispose()
local data={bloom=.18,mist=.04,exposure=1.1,vignette=.3,grain=0}
local results={}
local function Create(width,height)
    if graph then renderer:SetViewport(0,nil);graph:Dispose() end
    local specs
    specs,indices=Post.Specs(sourceGraph.output,width,height,data)
    graph=Graph.New(specs,width,height);graph.output:SetRect(IntRect(600,250,600+width,250+height))
    renderer:SetViewport(0,graph.output)
end
local function Shot(index)
    local ref=reference[index];local im=Image:new();assert(graphics:TakeScreenShot(im))
    local maxError=0;local total=0
    for _,point in ipairs(ref.points) do
        local c=im:GetPixel(600+point.x,250+point.y);local rgb={c.r,c.g,c.b}
        for channel=1,3 do
            local err=math.abs(rgb[channel]*255-point.rgb[channel]);maxError=math.max(maxError,err);total=total+err
        end
    end
    local crop=im:GetSubimage(IntRect(600,250,600+ref.width,250+ref.height))
    crop:SavePNG('.tmp/post-native-'..ref.name..'.png');crop:Dispose();im:Dispose()
    results[#results+1]={name=ref.name,max_error=maxError,mean_error=total/(#ref.points*3),color_bytes=graph.colorBytes,passes=graph.passCount}
    print('[CraterPostProbe] '..ref.name..' max='..maxError..' mean='..total/(#ref.points*3))
    V.assert(maxError<=4,'H5 spatial bloom, grade and lens '..ref.name)
end
V.atFrame(45,function()
    cache:AddResourceDir('tools/migration/probes',false)
    require('urhox-libs/UI').SetRoot(nil)
    sourceGraph=Graph.New({{shader='Shaders/BLGL/PostPattern.shader'}},256,192)
    Create(256,192)
end)
for frame=46,125 do V.atFrame(frame,function() if graph then graph:Queue() end end) end
V.atFrame(53,function() Shot(1);graph:Parameter(indices.grade,'exposure',.6) end)
V.atFrame(57,function() Shot(2);graph:Parameter(indices.grade,'exposure',1.1);graph:Parameter(indices.mist,'strength',0) end)
V.atFrame(61,function() Shot(3);graph:Parameter(indices.mist,'strength',.04);graph:Parameter(indices.bloom,'strength',0) end)
V.atFrame(65,function() Shot(4);Create(129,97) end)
V.atFrame(73,function() Shot(5);Create(256,192) end)
V.atFrame(81,function() Shot(1) end)
V.atFrame(85,function()
    sourceGraph:Parameter(1,'shaft_mode',1)
    graph:Parameter(indices.clamp,'shaft_on',1);graph:Parameter(indices.clamp,'shaft_aspect',256/192)
end)
local function ShaftShot(name)
    local im=Image:new();assert(graphics:TakeScreenShot(im))
    local crop=im:GetSubimage(IntRect(600,250,856,442));crop:SavePNG('.tmp/post-native-'..name..'.png');crop:Dispose();im:Dispose()
end
V.atFrame(93,function() ShaftShot('shafts');sourceGraph:Parameter(1,'shaft_mode',2) end)
V.atFrame(101,function() ShaftShot('shafts-blocked') end)
V.atFrame(106,function()
    renderer:SetViewport(0,nil);graph:Dispose();sourceGraph:Dispose()
    V.assert(next(graph.textures)==nil and next(graph.scenes)==nil and next(graph.materials)==nil,'filter graph releases textures, scenes and materials')
    local file=File('docs/migration/evidence/crater-post-probe.json',FILE_WRITE);file:WriteString(cjson.encode(results));file:Dispose()
    graph=nil;sourceGraph=nil;V.finish()
end)

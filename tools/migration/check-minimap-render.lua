local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Minimap=require 'ui.MatchMinimap'
local mm,root
local function Capture(name)
    local image=assert(mm.texture:GetImage())
    V.assert(image:SavePNG('docs/migration/evidence/minimap-'..name..'-texture.png'),'minimap RT '..name)
    local center=image:GetPixel(236,236);local backdrop=image:GetPixel(180,236)
    V.assert(center.a>.99 and center.r>.8,'actual RT player arrow is visible '..name)
    V.assert(backdrop.a>.7 and backdrop.b>backdrop.r+.03,'actual RT fallback is not erased '..name)
    V.assert(image:GetPixel(0,0).a<.01,'complete rectangle mask clears outside '..name)
    local blue=image:GetPixel(149,237);local red=image:GetPixel(199,199)
    V.assert(blue.b>blue.r+.4 and red.r>red.b+.4,'actual RT enemy/ally arrow colors '..name)
    V.assert(image:GetPixel(247,221).r<.7,'concave player arrow has no white bounding rectangle '..name)
    local corner=image:GetPixel(30,30)
    V.assert(mm.style=='square' and corner.a>.7 or mm.style=='round' and corner.a<.01,'source round/square alpha geometry '..name)
    print('MINIMAP_PIXELS '..name..' '..cjson.encode({center={center.r,center.g,center.b,center.a},backdrop={backdrop.r,backdrop.g,backdrop.b,backdrop.a}}))
    image:Dispose()
    image=Image:new();V.assert(graphics:TakeScreenShot(image),'minimap screen '..name)
    V.assert(image:SavePNG('docs/migration/evidence/minimap-'..name..'-screen.png'),'minimap screenshot '..name);image:Dispose()
end
V.atFrame(2,function()
    UI.Init({scale=1});root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root)
    local function Unit(team,x,z,me)
        return {team=team,alive=true,Position=function()return {x,0,z}end,vehicle={Yaw=function()return 0 end},me=me}
    end
    local me=Unit('blue',0,0,true)
    local s={app={store={Read=function()return nil end}},yaw=0,battle={entries={{unit=me},{unit=Unit('blue',70,0)},{unit=Unit('red',30,30)}},player=me,mode='elimination',rules={},objectives={}}}
    mm=Minimap.New(s);mm:Update(100)
    root.Render=function(_,vg)
        D.Rect(vg,0,0,graphics.width,graphics.height,{160,90,130,255})
        mm:Draw(vg)
        nvgSave(vg);nvgTranslate(vg,290,52);nvgScale(vg,.5,.5);mm:Paint(vg);nvgRestore(vg)
    end
end)
V.atFrame(8,function() Capture('default');nvgSetRenderOrder(mm.vg,999980);mm.requested=true end)
V.atFrame(14,function() Capture('ordered');mm.style='square';mm.requested=true end)
V.atFrame(20,function() Capture('square');mm:Dispose();UI.SetRoot(nil);root:Destroy();UI.Shutdown();V.finish() end)

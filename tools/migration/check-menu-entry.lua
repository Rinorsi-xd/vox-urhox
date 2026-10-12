-- Render the actual menu, freeze its clock at measured Chromium CSS times,
-- then verify ownership, steady-state unloading and input during animation.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local E=require 'urhox-libs/UI/Core/PointerEvent'
local Menu=require 'ui.HomeNewMenu'
local root,menu,advance,layer
local scale,clicked=1,false
local evidence={}
local f=assert(io.open('tools/migration/fixtures/source-menu-entry.json','r'))
local source=cjson.decode(f:read('*a'));f:close()
local function Capture(sample)
    local im=Image:new();assert(graphics:TakeScreenShot(im))
    local crop=assert(im:GetSubimage(IntRect(80*scale,40*scale,560*scale,530*scale)))
    assert(crop:SavePNG('docs/migration/evidence/pc-menu-entry-'..scale..'-'..sample.time..'.png'))
    crop:Dispose();im:Dispose()
    local alpha=menu.entry and menu.entry.value or 1
    V.assert(math.abs(alpha-sample.opacity)<.0001,'DPR '..scale..' actual menu opacity matches source CSS at '..sample.time..'ms')
    V.assert(math.abs(menu.props.translateY-(sample.box.y-120))<.001,'DPR '..scale..' actual menu translation matches source CSS at '..sample.time..'ms')
    if sample.time<200 then
        V.assert(layer.ready and layer.bytes>0,'entry uses prepared group, including first transparent frame')
    else
        V.assert(not layer.texture and not layer.rgbTexture and layer.bytes==0 and not next(layer.images),'settled menu releases both targets and image bridges')
    end
    evidence[#evidence+1]={scale=scale,time=sample.time,alpha=alpha,translate=menu.props.translateY,bytes=layer.bytes,renders=layer.renders,allocations=layer.allocations}
end
V.atFrame(20,function()
    UI.Init({scale=1});root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root)
    root.Render=function(_,vg) D.Rect(vg,0,0,1280,1080,{160,160,160,255}) end
    menu=Menu.Create({Track=function(w) return w end,CreateVehicle=function(id) clicked=id end})
    root:AddChild(menu);menu:SetStyle({left=160,top=120,width=320,height=Menu.height})
    advance=menu.Update;menu.Update=function() end;menu:SetOpen(true);advance(menu,0);layer=menu.layer
end)
for pass=1,2 do
    for index,sample in ipairs(source.samples) do
        local frame=23+(pass-1)*28+(index-1)*4
        V.atFrame(frame,function()
            Capture(sample)
            if index<#source.samples then advance(menu,(source.samples[index+1].time-sample.time)/1000) end
        end)
    end
    if pass==1 then V.atFrame(49,function() scale=2;UI.SetScale(2);menu:SetOpen(true);advance(menu,0) end) end
end
V.atFrame(80,function()
    local renders=layer.renders
    V.assert(renders==evidence[#evidence].renders,'steady menu does not render offscreen again')
    V.assert(layer.allocations==2,'one target pair per entry/DPR; no reallocations for animation offsets')
    V.assert(layer.renders==2,'unchanged menu contents draw once per entry/DPR, not once per animation frame')
    menu:SetOpen(true);advance(menu,.025)
end)
V.atFrame(84,function()
    local r=menu.children[1]:GetAbsoluteLayoutForHitTest()
    local data={x=(r.x+r.w/2)*scale,y=(r.y+r.h/2+menu.props.translateY)*scale,pointerType='mouse',pointerId=94,button=MOUSEB_LEFT}
    UI.HandlePointerEvent(E.new('PointerDown',data));UI.HandlePointerEvent(E.new('PointerUp',data))
    V.assert(clicked=='empty','translated menu remains clickable through actual UI pointer routing during entry')
    menu:SetOpen(false)
    V.assert(not layer.texture and layer.bytes==0,'early close releases transition textures immediately')
    menu:SetOpen(true);advance(menu,.01)
end)
V.atFrame(88,function()
    V.assert(layer.ready and layer.bytes>0,'quick reopen redraws current content')
    local oldAllocations=layer.allocations
    menu:SetStyle({left=160.25,top=120.25});menu.resizeAllocations=oldAllocations
    menu.children[2].state.hovered=true;menu.children[2]:Update(.06);menu.hoverRenders=layer.renders
end)
V.atFrame(92,function()
    V.assert(layer.allocations==menu.resizeAllocations,'fractional reposition reuses bounded targets')
    V.assert(layer.renders>menu.hoverRenders,'hover and layout changes repaint entry contents')
    local shadow=menu.shadow;UI.SetRoot(nil);root:Destroy()
    V.assert(layer.disposed and not layer.vg and not layer.texture and not next(layer.images) and not next(shadow.images),'owner destruction during entry releases contexts, shadow handles and target bridges')
    UI.Shutdown()
    local out=assert(io.open('docs/migration/evidence/pc-menu-entry.json','w'));out:write(cjson.encode(evidence));out:close();V.finish()
end)

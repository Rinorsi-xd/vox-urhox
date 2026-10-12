local UI=require 'urhox-libs/UI'
local Host=require 'ui.DialogHost'
local Settings=require 'render.GraphicsSettings'
local E=require 'urhox-libs/UI/Core/PointerEvent'
local app,owner,panel,zone,previous
local oldSize,oldW,oldH,oldScale=UI.GetViewportSize,UI.GetWidth,UI.GetHeight,UI.GetScale()
local width,height=1920,1080
local function Click(widget,fraction)
    local r=widget:GetAbsoluteLayoutForHitTest()
    local e={x=r.x+r.w*(fraction or .5),y=r.y+r.h/2,pointerId=88,pointerType='mouse',button=MOUSEB_LEFT}
    UI.HandlePointerEvent(E.new('PointerDown',e));UI.HandlePointerEvent(E.new('PointerUp',e))
end
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img),'native capture '..name)
    local crop=img:GetSubimage(IntRect(0,0,width,height));V.assert(crop:SavePNG('docs/migration/evidence/pc-graphics-'..name..'.png'),'saved '..name)
    crop:Dispose();img:Dispose()
end
local function Clean()
    for _,key in ipairs({'graphics','draft','garage-state'}) do for _,suffix in ipairs({'-a.json','-b.json'}) do
        local p=app.store.prefix..key..suffix;if fileSystem:FileExists(p) then fileSystem:Delete(p) end
    end end
end
V.atFrame(55,function()
    UI.SetScale(1);UI.GetViewportSize=function() return width,height end;UI.GetWidth=function() return width end;UI.GetHeight=function() return height end
    app=VOX_HANGAR.app;previous=app.previousState;app.camera.autoSpin=false
    app.store=require('storage.BlueprintStore').New('vox-graphics-test');app.bays.store=app.store;Clean()
    app:EnterBuild();owner=app.build;owner.hud.root:SetStyle({width=width,height=height})
    renderer:GetViewport(0):SetRect(IntRect(0,0,width,height));panel=require('ui.GraphicsPanel').Open(owner)
    zone=app.scene:GetComponent('Zone',true);local s=app.graphicsSettings
    V.assert(zone:GetAutoExposureEnabled() and zone:GetAttribute('Auto Exposure Plus Enable'):GetBool(),'fixed native exposure active')
    V.assert(not s:Set('bloom',0/0) and not s:Set('fps',120) and not s:Set('unknown',1),'invalid or removed options do not mutate settings')
    for _,key in ipairs({'quality','mist','grain','ao'}) do V.assert(not s:Supports(key) and not s:Set(key,0),'unverified effect cannot pretend to apply: '..key) end
end)
V.atFrame(74,function()
    Shot('1920');local box=panel.modalLayout_
    V.assert(math.abs(box.x-570)<1 and math.abs(box.y-276.5)<1 and box.w==780 and box.h==527,'original 780x527 H5 PC modal geometry')
    local row=panel.rows[2]:GetAbsoluteLayout();local slider=panel.controls.bloom:GetAbsoluteLayout()
    V.assert(math.abs(row.x-598)<1 and math.abs(row.y-429.5)<1 and row.w==724 and row.h==47,'original 724px graphics row and source vertical position')
    V.assert(math.abs(slider.x-758)<1 and math.abs(slider.w-468)<1 and slider.h==16,'original source range position and dimensions')
    V.assert(#panel.rows==7 and not panel.controls.fps and not panel.controls.shadows and not panel.controls.reflection,'seven original rows replace invented options')
    Click(panel.controls.bloom,.75)
    V.assert(math.abs(zone:GetBloomUEIntensity()-app.graphicsSettings.data.bloom)<.0001 and app.graphicsSettings.data.bloom>.5,'pointer updates native bloom')
    Click(panel.controls.exposure,.75)
    V.assert(app.graphicsSettings.data.exposure>1.15,'pointer updates exposure value')
    V.assert(UI.GetFocus()==panel.controls.exposure,'pointer focuses original range for keyboard input')
    local before=app.graphicsSettings.data.exposure
    UI.HandleKeyDown(KEY_LEFT)
    V.assert(math.abs(app.graphicsSettings.data.exposure-(before-.01))<.0001,'PC arrow key adjusts by original step')
    panel.controls.bloom:SetValue(0);panel.controls.vignette:SetValue(0)
    V.assert(zone:GetBloomUEIntensity()==0 and not zone:GetVignetteEnabled() and zone:GetAttribute('Bloom Enable'):GetBool(),'zero bloom retains tone mapping')
    width,height=1440,900
end)
V.atFrame(90,function()
    owner.hud.root:SetStyle({width=width,height=height});renderer:GetViewport(0):SetRect(IntRect(0,0,width,height))
end)
V.atFrame(104,function()
    Shot('1440');V.assert(owner.dialog==panel and panel.modalLayout_.w==780 and panel.modalLayout_.h==527,'PC resize retains same original modal')
    Click(panel.actions.done);V.assert(not owner.dialog and not app.graphicsSettings.pending,'done flushes saved settings')
    local saved=app.store:Read('graphics',Settings.Valid);V.assert(saved and saved.v==2 and saved.bloom==0,'source graphics persisted in isolated store')
    app.isValidation=false;local restored=Settings.New(app);app.isValidation=true
    V.assert(restored.data.exposure==saved.exposure,'new owner restores exposure')
    local s=app.graphicsSettings;local write=app.store.Write
    app.store.Write=function() return false,'injected failure' end;s:Set('vignette',.4);local ok=s:Flush()
    V.assert(not ok and s.pending and s.error=='injected failure','save error remains pending')
    app.store.Write=write;V.assert(s:Flush() and not s.pending and s.error=='','retry persists settings')
    local before=zone:GetBloomUEIntensity();app.ownsScene=false;s:Set('bloom',.2)
    V.assert(zone:GetBloomUEIntensity()==before,'editor-owned preview is untouched')
    app.ownsScene=true;s:Apply(app.scene)
    local read=app.store.Read;app.store.Read=function(_,_,valid) local d={v=1,bloom=.25,vignette=.2,fps=30};V.assert(valid(d),'legacy preferences accepted for migration');return d end
    app.isValidation=false;local migrated=Settings.New(app);app.isValidation=true;app.store.Read=read
    V.assert(migrated.data.v==2 and migrated.data.bloom==.25 and migrated.data.fps==nil and migrated.pending,'v1 migrates real effects and drops abandoned options')
    app:EnterTrial()
end)
V.atFrame(174,function()
    V.assert(app.mode=='trial' and app.trial~=nil,'actual trial transition completed')
    local z=app.scene:GetComponent('Zone',true)
    V.assert(math.abs(z:GetBloomUEIntensity()-.2)<.0001 and math.abs(z:GetVignetteIntensity()-.4)<.0001,'new scene receives saved graphics')
    V.assert(math.abs(z:GetAttribute('Auto Exposure Bias'):GetFloat()-math.log(app.graphicsSettings.data.exposure,2))<.0001,'new scene receives fixed exposure')
    app:Reload()
end)
V.atFrame(244,function()
    V.assert(app.mode=='hangar' and app.build~=nil,'same build flow restored')
    owner=app.build;panel=require('ui.GraphicsPanel').Open(owner)
end)
V.atFrame(258,function() Click(panel.actions.reset);panel=owner.dialog end)
V.atFrame(272,function()
    V.assert(app.graphicsSettings.data.exposure==1.1 and app.graphicsSettings.data.bloom==.18,'reset restores H5 defaults')
    Click(panel.actions.done);V.assert(not owner.dialog,'done closes reset menu')
    for _=1,10 do local m=require('ui.GraphicsPanel').Open(owner);local c=m.contentContainer_;Host.Close(owner);Host.Update(owner,.16);V.assert(not c.node,'graphics layout disposed after fade') end
    app:Stop();V.assert(renderer.drawShadows==previous.shadows and renderer.shadowMapSize==previous.shadowSize and engine.maxFps==previous.maxFps,'renderer state restored on stop')
    Clean();UI.GetViewportSize=oldSize;UI.GetWidth=oldW;UI.GetHeight=oldH;UI.SetScale(oldScale);V.finish()
end)

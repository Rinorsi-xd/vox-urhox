local UI=require 'urhox-libs/UI'
local E=require 'urhox-libs/UI/Core/PointerEvent'
local app,s,hud,oldRoot,beforeHistory
local w,h=1920,1080
local oldSize,oldW,oldH,oldScale=UI.GetViewportSize,UI.GetWidth,UI.GetHeight,UI.GetScale()
local function At(x,y,kind,button)
    UI.HandlePointerEvent(E.new(kind,{x=x,y=y,pointerId=88,pointerType='mouse',button=button or MOUSEB_LEFT}))
end
local function Click(widget)
    local r=widget:GetAbsoluteLayoutForHitTest();At(r.x+r.w/2,r.y+r.h/2,'PointerDown');At(r.x+r.w/2,r.y+r.h/2,'PointerUp')
end
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img),'native build frame captured')
    local crop=img:GetSubimage(IntRect(0,0,w,h));V.assert(crop:SavePNG('docs/migration/evidence/pc-build-'..name..'.png'),'saved '..name);crop:Dispose();img:Dispose()
end
local function Bound()
    hud=s.hud;hud.root:SetStyle({width=w,height=h});renderer:GetViewport(0):SetRect(IntRect(0,0,w,h))
end
local function Cleanup()
    app.store.pending=nil
    for _,key in ipairs({'draft','garage-state','build-settings'}) do for _,suffix in ipairs({'-a.json','-b.json'}) do local p=app.store.prefix..key..suffix;if fileSystem:FileExists(p) then fileSystem:Delete(p) end end end
    for i=1,20 do for _,suffix in ipairs({'-a.json','-b.json'}) do local p=app.store.prefix..'slot'..i..suffix;if fileSystem:FileExists(p) then fileSystem:Delete(p) end end end
end
V.atFrame(55,function()
    app=VOX_HANGAR.app;app.store=require('storage.BlueprintStore').New('vox-pc-build-ui-test');app.bays.store=app.store;app.bays.active=false;Cleanup()
    UI.SetScale(1);UI.GetViewportSize=function() return w,h end;UI.GetWidth=function() return w end;UI.GetHeight=function() return h end
    app:EnterBuild();s=app.build;Bound()
end)
V.atFrame(80,function()
    Shot('1920');local r=hud.dock:GetAbsoluteLayoutForHitTest()
    V.assert(math.abs(r.x-401.5)<=.5 and r.y==986 and r.w==1117 and r.h==76,'PC dock matches source within Yoga half-pixel rounding: '..cjson.encode(r))
    local bar=hud.toolbar:GetAbsoluteLayoutForHitTest();V.assert(bar.x==18 and bar.y==12 and bar.h==46,'toolbar uses original PC anchors')
    V.assert(not hud.buttons.inventory and not hud.buttons.menu and not hud.buttons.tools,'removed invented top-level actions and drawer')
    for i,slot in ipairs(hud.hotbar.slots) do local q=slot.widget:GetAbsoluteLayoutForHitTest();V.assert(q.w==64 and q.h==76 and q.x>=r.x and q.x+q.w<=r.x+r.w,'original single-row slot '..i) end
    local mirror=s.editor.mirror;Click(hud.buttons.mirror);V.assert(s.editor.mirror~=mirror,'native mirror toggle invokes editor');Click(hud.buttons.mirror)
    Click(hud.buttons.erase);V.assert(s.editor.tool=='erase','source delete tool invokes existing editor')
    Click(hud.hotbar.slots[3].widget);V.assert(s.inventory.active==3 and s.editor.tool=='build','source hotbar selects and leaves delete mode')
    Click(hud.name);hud.name:SelectAll();hud.name:OnTextInput('PC车名测试');hud.name:OnKeyDown(KEY_RETURN)
    V.assert(app.blueprint.name=='PC车名测试' and not UI.GetFocus(),'inline source name editor commits and releases focus')
    Click(hud.buttons.color)
end)
V.atFrame(98,function()
    Shot('palette');V.assert(hud.colorOpen and hud.palette.props.visible,'source anchored color popover is open')
    local f=assert(io.open('tools/migration/fixtures/source-palette-1920.json','r'));local ref=cjson.decode(f:read('*a'));f:close()
    local box=hud.palette:GetAbsoluteLayoutForHitTest()
    V.assert(math.abs(box.x-ref.palette.x)<=.5 and math.abs(box.y-ref.palette.y)<=.5 and math.abs(box.h-ref.palette.h)<=.5,'palette matches original 296x113.25 box and color-button anchor')
    V.assert(hud.palette.paragraph.layout.height==ref.label.h,'palette label uses source normal line height')
    for i,b in ipairs(hud.swatches) do
        local r=b:GetAbsoluteLayoutForHitTest();local expected=ref.swatches[i]
        V.assert(math.abs(r.x-expected.box.x)<=.5 and math.abs(r.y-expected.box.y)<=.5 and math.abs(r.w-expected.box.w)<=1 and b.props.hex==expected.hex,'palette swatch '..i..' matches source grid position and color: '..cjson.encode(r))
    end
    V.assert(not hud.palette.entry and hud.palette.layer.bytes==0 and not hud.palette.layer.texture,'settled palette releases transition textures')
    local revision=s.editor.history.revision;At(900,500,'PointerDown');At(900,500,'PointerUp')
    V.assert(not hud.colorOpen and revision==s.editor.history.revision,'outside popover click closes without editing through')
    Click(hud.buttons.color)
end)
V.atFrame(103,function()
    local b=hud.swatches[2];local r=b:GetAbsoluteLayoutForHitTest()
    At(r.x+r.w/2,r.y+r.h/2,'PointerMove');b:Update(.15)
end)
V.atFrame(108,function()
    V.assert(hud.swatches[2].state.hovered and hud.swatches[2].props.translateY==-2,'actual swatch hover uses original 2px lift')
    Shot('palette-hover')
end)
V.atFrame(110,function()
    Click(hud.swatches[2]);V.assert(s.editor.tool=='paint' and s.editor.color==0xff6a13 and not hud.colorOpen,'color swatch enters paint and closes popover')
end)
V.atFrame(123,function()
    Shot('paint');V.assert(not hud.hotbar.root.props.visible and hud.paint.props.visible,'paint channels replace hotbar in original dock')
    local r=hud.dock:GetAbsoluteLayoutForHitTest();V.assert(r.w==663 and math.abs(r.x-628.5)<=.5,'paint dock matches source 663px width')
    Click(hud.buttons.accent);V.assert(s.editor.paintChannel=='accent','source accent channel routes to editor')
    Click(hud.buttons.shell)
    local painted=false
    for y=350,800,20 do
        for x=500,1400,20 do
            if not painted then s:Trace(x,y);if s.editor.hit then
                local rev=s.editor.history.revision;At(x,y,'PointerDown');At(x,y,'PointerUp');painted=s.editor.history.revision>rev
            end end
        end
    end
    V.assert(painted,'actual playfield pointer paints vehicle through command history')
    beforeHistory=#s.editor.history.undoStack;Click(hud.buttons.undo);V.assert(#s.editor.history.undoStack==beforeHistory-1,'source undo reverses edit')
    Click(hud.buttons.redo);V.assert(#s.editor.history.undoStack==beforeHistory,'source redo restores edit')
    Click(hud.buttons.build);Click(hud.stats.pane.more)
end)
V.atFrame(140,function()
    Shot('details');V.assert(hud.stats.pane.expanded and hud.stats.pane.props.height>500,'original detailed vehicle data expands inline')
    Click(hud.stats.pane.tiers[4]);V.assert(app.tier==4 and hud.stats.pane.diag==s.inspection:Get(),'source tier buttons refresh actual diagnostics')
    Click(hud.stats.pane.tiers[3]);Click(hud.buttons.xray);V.assert(app.buildXray and app.car.xray,'source xray toggle changes actual vehicle materials');Click(hud.buttons.xray)
    s:OpenInventory()
end)
V.atFrame(158,function()
    V.assert(s.inventoryPanel and hud.toolbar.props.visible==false and hud.dock.props.visible==false,'inventory hides original build chrome')
    s.inventoryPanel:Close()
end)
V.atFrame(174,function()
    V.assert(hud.toolbar.props.visible~=false and hud.dock.props.visible~=false,'closing inventory restores build chrome')
    Click(hud.name);hud.name:SelectAll();hud.name:OnTextInput('尚未提交的车名');hud.name:SelectAll()
    oldRoot=hud.root;w,h=1440,900
end)
V.atFrame(187,function()
    Bound();V.assert(not oldRoot.node and s==app.build,'PC window resize releases old UI without replacing editor session')
    V.assert(hud.stats.pane.expanded,'PC resize preserves expanded vehicle data')
    V.assert(hud.name:GetValue()=='尚未提交的车名' and UI.GetFocus()==hud.name and app.blueprint.name=='PC车名测试','PC resize preserves focused name draft without committing it')
    local first,last=hud.name:GetSelectionRange();V.assert(first==0 and last==7,'PC resize preserves Unicode name selection')
    hud.name:SetValue('PC车名测试');UI.ClearFocus()
    V.assert(hud.name.props.width==280 and hud.name.props.sourceFontSize==28,'PC 1440 breakpoint uses original smaller name field and font')
    Click(hud.buttons.color)
end)
V.atFrame(200,function()
    local f=assert(io.open('tools/migration/fixtures/source-palette-1440.json','r'));local ref=cjson.decode(f:read('*a'));f:close()
    local box=hud.palette:GetAbsoluteLayoutForHitTest()
    V.assert(math.abs(box.x-ref.palette.x)<=.5 and math.abs(box.y-ref.palette.y)<=.5,'1440 PC palette follows original compact dock anchor')
    for _,slot in ipairs(hud.hotbar.slots) do V.assert(slot.widget.props.width==56 and slot.widget.props.thumbnailSize==42,'1440 PC uses original 56px slot and 42px thumbnail') end
    Shot('palette-1440');At(900,500,'PointerDown');At(900,500,'PointerUp')
end)
V.atFrame(205,function()
    Shot('1440');local r=hud.dock:GetAbsoluteLayoutForHitTest()
    local f=assert(io.open('tools/migration/fixtures/source-palette-1440.json','r'));local ref=cjson.decode(f:read('*a'));f:close()
    V.assert(math.abs(r.x-ref.dock.x)<=.5 and r.y==ref.dock.y and r.w==ref.dock.w,'16:10 PC uses original compact single row and anchors: '..cjson.encode(r))
    Click(hud.buttons.paint)
end)
V.atFrame(215,function()
    local f=assert(io.open('tools/migration/fixtures/source-paint-1440.json','r'));local ref=cjson.decode(f:read('*a'));f:close()
    local r=hud.dock:GetAbsoluteLayoutForHitTest()
    local label=hud.paintLabel:GetAbsoluteLayout()
    V.assert(hud.paintLabel.paragraph and math.abs(label.x-682.453125)<=.5 and label.y==836 and label.w==52 and label.h==16,
        '1440 PC paint region label actually renders at source span position: '..cjson.encode(label))
    -- Yoga rounds both edges independently: a 609.09375 box may occupy 610 pixels.
    V.assert(math.abs(hud.dock.props.width-ref.dock.w)<.001 and math.abs(r.x-ref.dock.x)<=.5
        and math.abs(r.x+r.w-ref.dock.x-ref.dock.w)<=.5,'1440 PC paint dock preserves source width and independently rounded edges: '..cjson.encode(r))
    Shot('paint-1440');Click(hud.buttons.build)
end)
V.atFrame(225,function()
    Click(hud.buttons.save);V.assert(app.bays.active and app.store:LoadSlot(app.bays.active).name=='PC车名测试','source save button persists renamed edited car to isolated bay')
    local field=hud.name;Click(field);V.assert(UI.GetFocus()==field,'name input focused before disposal')
    app:ExitBuild();V.assert(not field.node and UI.GetFocus()==nil,'leaving build destroys and releases name editor')
    Cleanup();UI.GetViewportSize=oldSize;UI.GetWidth=oldW;UI.GetHeight=oldH;UI.SetScale(oldScale);V.finish()
end)

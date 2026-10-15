local app,session,panel
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image) and image:SavePNG('docs/migration/evidence/'..name..'.png'),'rendered '..name);image:Dispose()
end
V.atFrame(55,function()
    app=VOX_HANGAR.app;app:EnterBuild();session=app.build
    session.inventory=require('construction.Inventory').New();app.inventory=session.inventory
    session:SelectHotbar(1);panel=session:OpenInventory()
    V.assert(panel~=nil and not session.controls.pointer and #session.ghost.pool==0,'inventory cancels editing and releases ghost models')
    V.assert(not session:Act(),'inventory blocks world commands')
    panel.model.category='movement';panel:Fill();panel:Detail('leg5')
end)
V.atFrame(75,function()
    Shot('inventory-movement')
    V.assert(#panel.results>10,'movement category populated')
    local pool=panel.list:GetPoolStats()
    V.assert(pool.total<=math.ceil(panel.list:GetLayout().h/141)+2,'catalog virtualizes visible rows plus two spares')
    local UI=require 'urhox-libs/UI';local Events=require 'urhox-libs/UI/Core/PointerEvent'
    local function Click(widget,button)
        local r=widget:GetAbsoluteLayout();local s=UI.GetScale();local data={x=(r.x+r.w/2)*s,y=(r.y+r.h/2)*s,pointerType='mouse',pointerId=91,button=button or MOUSEB_LEFT}
        UI.HandlePointerEvent(Events.new('PointerDown',data));UI.HandlePointerEvent(Events.new('PointerUp',data))
    end
    local cell=panel.list.pool_.inUse[1].cells[1];Click(cell.root)
    V.assert(session.inventory:Current()==cell.type,'native pointer hit test selects thumbnail card')
    Click(panel.hotbar.slots[1].widget,MOUSEB_RIGHT)
    V.assert(session.inventory.hotbar[1]==false,'native right-click clears hotbar without reselecting')
    local source=cell.root:GetAbsoluteLayoutForHitTest();local target=panel.hotbar.slots[2].widget:GetAbsoluteLayoutForHitTest();local scale=UI.GetScale()
    local function DragEvent(kind,x,y)
        local event=Events.new(kind,{pointerId=92,pointerType='mouse',button=MOUSEB_LEFT,x=x*scale,y=y*scale})
        require('urhox-libs/UI/Core/Input').DispatchGlobal(event);UI.HandlePointerEvent(event)
    end
    DragEvent('PointerDown',source.x+source.w/2,source.y+source.h/2)
    DragEvent('PointerMove',source.x+source.w/2+20,source.y+source.h/2)
    DragEvent('PointerMove',target.x+target.w/2,target.y+target.h/2)
    DragEvent('PointerUp',target.x+target.w/2,target.y+target.h/2)
    V.assert(session.inventory.hotbar[2]==cell.type and not cell.root.state.isDragging,'native pan routing drops thumbnail into target slot')
    session:AssignHotbar(1,'cube')
    local current=session.editor.bp:Size()
    session.controls:Down({x=600,y=400});V.assert(not session.controls.pointer and session.editor.bp:Size()==current,'overlay intercepts pointer before world input')
    UI.ClearFocus();panel.keyboardFocus=nil;panel.hoverType='leg5';panel:Digit(8)
    V.assert(session.inventory.hotbar[8]=='leg5' and session.editor.type=='leg5','hover digit assigns actual build selection')
    session:ClearHotbar(8);V.assert(session.editor.emptySlot and not session.editor.preview,'cleared active slot cannot build previous part')
    session:AssignHotbar(8,'cube');V.assert(session.inventory.hotbar[1]==false and session.inventory.hotbar[8]=='cube','duplicate hotbar part swaps source slot')
    panel.model.query='玻璃';panel.search:SetValue('玻璃');panel:Fill();panel:Detail('glassSlope')
    V.assert(#panel.results>1,'search ignores active movement category')
end)
V.atFrame(95,function()
    Shot('inventory-search');panel:Trim(false)
    local images=require('urhox-libs/UI/Core/ImageCache');local cached,shadows,shadowBytes=0,0,0
    for _,p in ipairs(images.GetCachedPaths()) do
        if p:sub(1,17)=='UI/Parts/Shadows/' then local w,h=images.GetSize(p);shadows=shadows+1;shadowBytes=shadowBytes+w*h*4
        elseif p:sub(1,9)=='UI/Parts/' then cached=cached+1 end
    end
    V.assert(cached<=80,'thumbnail cache stays below full catalog')
    local first,last=panel.list:GetVisibleRange();local visible=0
    for i=first,last do visible=visible+#(panel.list.props.data[i] or {}) end
    V.assert(shadows<=visible+14,'shadow cache is limited to visible cards, ten slots, one detail and three kernels')
    V.assert(shadowBytes<=4*1024*1024,'decoded active shadow images stay under 4 MiB')
    print('[InventoryCache] '..cjson.encode({thumbnails=cached,shadows=shadows,shadowBytes=shadowBytes}))
    local row=panel.list.pool_.inUse[1];local cell=row.cells[1];local selected=cell.type
    local UI=require 'urhox-libs/UI';local Gesture=require 'urhox-libs/UI/Core/GestureEvent'
    UI.SetFocus(panel.search)
    UI.HandleGestureEvent(Gesture.new('DoubleTap',{target=cell.root,pointerType='mouse',x=300,y=300}))
    V.assert(not session.inventoryPanel and session.inventory:Current()==selected,'native double tap selects part and closes overlay')
    V.assert(not row.node and not cell.root.node,'closing destroys detached pooled rows and their Yoga nodes')
    local remaining=0;for _,p in ipairs(images.GetCachedPaths()) do if p:sub(1,17)=='UI/Parts/Shadows/' then remaining=remaining+1 end end
    V.assert(remaining==0,'closing releases all inventory-only shadow handles')
    V.assert(UI.GetFocus()==nil,'closed search cannot retain keyboard focus on destroyed widgets')
    session:AssignHotbar(10,'leg5')
    local stored=app.store:LoadBuildSettings();V.assert(stored.hotbar[10]=='leg5' and stored.active==10,'custom hotbar persists with slot selection')
    app:ExitBuild();V.assert(not app.build,'inventory and thumbnails disposed on leaving build')
    app:EnterBuild();session=app.build;V.assert(session.inventory.hotbar[10]=='leg5','hotbar retained across scene UI rebuild')
    session:SelectHotbar(1);session:PickHotbar('cube')
end)
V.atFrame(115,function() Shot('build-hud');session:OpenInventory();app:ExitBuild();V.assert(not session.inventoryPanel,'scene exit closes open inventory');V.finish() end)

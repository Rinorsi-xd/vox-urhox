local UI=require 'urhox-libs/UI'
local Motion=require 'ui.InventoryCardMotion'
local Keys=require 'ui.InventoryKeys'
local state={}
local fixtureFile=assert(io.open('tools/migration/source-inventory-effects.json','r'))
local fixture=cjson.decode(fixtureFile:read('*a'));fixtureFile:close()
assert(fixture.baseline.commit=='90862445074e7e146da900037979ad97899ecf6c','Inventory motion fixture baseline mismatch')
local function Near(actual,expected,label,tolerance) V.assert(math.abs(actual-expected)<(tolerance or .001),label..': '..actual..' / '..expected) end
local function Translate(text)
    if text=='none' then return 0,0 end
    local x,y=text:match('([^%s]+)px%s+([^%s]+)px')
    if not x then x=text:match('^([^%s]+)px$');y='0' end
    assert(x and y,'Unexpected source CSS translation: '..text)
    return assert(tonumber(x)),assert(tonumber(y))
end
V.atFrame(55,function()
    local app=VOX_HANGAR.app;app:EnterBuild();state.app=app;state.panel=app.build:OpenInventory()
end)
V.atFrame(75,function()
    local owner=state.panel;local card=owner.list.pool_.inUse[1].cells[1].root
    state.card=card;UI.ClearFocus();owner.keyboardFocus=nil
    for _,case in ipairs(fixture.entry) do
        card.state.hovered=false;card.state.pressed=false;Motion.Bind(card,case.index+1,0)
        local previous=0
        for _,sample in ipairs(case.samples) do
            card:Update((sample.time-previous)/1000);previous=sample.time
            Near(card.props.opacity,sample.opacity,'source card '..case.index..' opacity at '..sample.time)
            if sample.opacity<1 then local _,y=Translate(sample.translate);Near(card.props.translateY,y,'source card '..case.index..' entry displacement at '..sample.time,.002) end
        end
    end
    Motion.Bind(card,1,1)
    Near(card.props.opacity,1,'late virtual cells do not flash an invisible first frame')
    local feedback=require('ui.InventoryFeedback')
    for name,samples in pairs(fixture.controls) do
        if name~='slot' then
            local button=require('ui.InventoryChrome').Button{kind=name=='material' and 'material' or nil,width=90,height=40}
            button.state.hovered=true;button.state.pressed=name=='closePress';local previous=0
            for _,sample in ipairs(samples) do
                button:Update((sample.time-previous)/1000);previous=sample.time
                Near(button.props.translateX,sample.x,'source '..name..' X at '..sample.time,.002)
                local _,extra=Translate(sample.translate)
                Near(button.props.translateY,sample.y+extra,'source '..name..' Y at '..sample.time,.002)
                local color=feedback.Mix({25,62,110,255},{33,76,128,255},button.inventoryFeedback.hover.value)
                local r,g,b=sample.background:match('rgb%((%d+), (%d+), (%d+)%)')
                for i,v in ipairs({tonumber(r),tonumber(g),tonumber(b)}) do Near(color[i],v,'source '..name..' RGB at '..sample.time,1.01) end
            end
            button:Destroy()
        end
    end
    local slot=owner.hotbar.slots[2].widget;slot.props.active=false;slot.inventoryFeedback=nil;slot.state.hovered=true
    local previous=0
    for _,sample in ipairs(fixture.controls.slot) do
        slot:Update((sample.time-previous)/1000);previous=sample.time;local _,y=Translate(sample.translate)
        Near(slot.props.translateY,y,'source slot hover at '..sample.time,.002)
    end
    slot.props.active=true;slot:Update(.2);Near(slot.props.translateY,-5,'selected source slot lift')
    local r=slot:GetAbsoluteLayoutForHitTest();owner.dragType=card.props.partType;owner.dragPoint={x=r.x+r.w/2,y=r.y+r.h/2};owner:Update(0)
    V.assert(slot.props.dropTarget==true,'dragged part highlights the actual transformed drop target')
    owner.dragPoint={x=-50,y=-50};owner:Update(0);V.assert(slot.props.dropTarget==false,'leaving target clears highlight')
    owner.dragType=nil;owner.dragPoint=nil;slot.state.hovered=false;owner.hotbar.Refresh()
    local Input=require 'urhox-libs/UI/Core/Input';local Pointer=require 'urhox-libs/UI/Core/PointerEvent'
    local function PointerEvent(kind,x,y,button)
        local event=Pointer.new(kind,{pointerId=77,pointerType='mouse',button=button or MOUSEB_LEFT,x=x*UI.GetScale(),y=y*UI.GetScale(),isPrimary=true})
        Input.DispatchGlobal(event);UI.HandlePointerEvent(event);return event
    end
    local source=card:GetAbsoluteLayoutForHitTest();local target=owner.hotbar.slots[8].widget:GetAbsoluteLayoutForHitTest()
    local down=PointerEvent('PointerDown',source.x+source.w/2,source.y+source.h/2)
    V.assert(down.target==card,'adapter order pins the initial card before Gesture observes PointerDown')
    PointerEvent('PointerMove',source.x+source.w/2+20,source.y+source.h/2)
    PointerEvent('PointerMove',target.x+target.w/2,target.y+target.h/2);owner:Update(0)
    V.assert(owner.hotbar.slots[8].widget.props.dropTarget==true,'captured gesture continues across other cards to a real target')
    local point=owner.dragPoint
    card:OnPanMove({pointerId=78,x=-50,y=-50})
    V.assert(owner.dragPoint==point,'another pointer cannot move the active drag')
    card.props.onPanEnd({pointerId=78,x=target.x+target.w/2,y=target.y+target.h/2},card)
    V.assert(owner.dragType==card.props.partType,'another pointer cannot finish the active drag')
    card.props.onPointerCancel({pointerId=78},card)
    V.assert(owner.dragType==card.props.partType and card.state.isDragging,'another pointer cannot cancel the active drag')
    local unchanged=owner.model.hotbar[8]
    PointerEvent('PointerCancel',target.x+target.w/2,target.y+target.h/2);owner:Update(0)
    V.assert(owner.model.hotbar[8]==unchanged and not owner.dragType,'pointer cancellation does not turn into a drop')
    PointerEvent('PointerDown',source.x+source.w/2,source.y+source.h/2,MOUSEB_RIGHT)
    PointerEvent('PointerMove',target.x+target.w/2,target.y+target.h/2,MOUSEB_RIGHT)
    V.assert(not owner.dragType,'right-button pan cannot begin part assignment')
    PointerEvent('PointerUp',target.x+target.w/2,target.y+target.h/2,MOUSEB_RIGHT)
    V.assert(owner.model.hotbar[8]==unchanged,'right-button drag leaves the target unchanged')
    card.state.hovered=false;card.state.pressed=false;card:Update(0)
    for _,phase in ipairs({'hover','press','release','leave'}) do
        card.state.hovered=phase~='leave';card.state.pressed=phase=='press'
        local previous=0
        for _,sample in ipairs(fixture[phase]) do
            card:Update((sample.time-previous)/1000);previous=sample.time
            local x,y=Translate(sample.translate)
            Near(card.props.translateX,x,phase..' X at '..sample.time,.002)
            Near(card.props.translateY,y,phase..' Y at '..sample.time,.002)
            local m=card.inventoryMotion
            Near(-3*m.image.value,sample.image.angle,phase..' image rotation at '..sample.time,.002)
            Near(1+.06*m.image.value,sample.image.scale,phase..' image scale at '..sample.time,.001)
            Near(-2*m.image.value,sample.image.y,phase..' image lift at '..sample.time,.002)
            Near(m.budget.value,sample.budget.opacity,phase..' budget opacity at '..sample.time)
            Near(-5*(1-m.budget.value),sample.budget.y,phase..' budget displacement at '..sample.time,.002)
        end
    end
    local index=1
    V.assert(Keys.Focus(owner,{part=owner.results[index].id,index=index}),'keyboard focuses a real source card')
    local selected=owner.results[index].id
    V.assert(Keys.Activate(owner,KEY_RETURN) and owner.model:Current()==selected,'Enter selects focused part without closing')
    owner:Digit(7);V.assert(owner.model.hotbar[7]==selected,'focused digit assigns a source part')
    V.assert(Keys.Focus(owner,{widget=owner.hotbar.slots[7].widget}),'hotbar receives keyboard focus')
    V.assert(Keys.Activate(owner,KEY_DELETE) and owner.model.hotbar[7]==false,'Delete clears only the focused hotbar slot')
    V.assert(Keys.Activate(owner,KEY_SPACE) and owner.model.active==7,'Space activates a focused slot')
    Keys.Focus(owner,{widget=owner.search});V.assert(not Keys.Activate(owner,KEY_RETURN),'search does not trigger card activation')
    V.assert(Keys.Tab(owner,true),'Shift Tab wraps within inventory')
    V.assert(Keys.Tab(owner,false) and UI.GetFocus()==owner.search,'Tab wraps back to the first source stop')
    local last=#owner.results
    V.assert(Keys.Focus(owner,{part=owner.results[last].id,index=last}),'offscreen source card is materialized before focusing')
    V.assert(UI.GetFocus().props.partType==owner.results[last].id and owner.list.scrollOffset_>0,'virtual scrolling preserves the exact requested part')
    local stats=owner.list:GetPoolStats();V.assert(stats.total<20,'keyboard navigation retains a bounded row pool')
    V.assert(Keys.Focus(owner,{widget=owner.matButtons.light}) and owner.list.scrollOffset_==0,'material focus scrolls its source control into view')
    V.assert(Keys.Focus(owner,{part=owner.results[last].id,index=last}),'catalog focus returns to exact last part after material scrolling')
    state.owner=owner
end)
V.atFrame(90,function()
    local owner=state.owner
    local focused=UI.GetFocus();V.assert(focused and focused.props.partType==owner.results[#owner.results].id,'focused virtual card remains stable across frames')
    local image=Image:new();assert(graphics:TakeScreenShot(image));image:SavePNG('docs/migration/evidence/inventory-keyboard.png');image:Dispose()
    owner:Close();V.assert(UI.GetFocus()==nil,'closing clears focused virtual widgets')
    state.app:ExitBuild();V.finish()
end)

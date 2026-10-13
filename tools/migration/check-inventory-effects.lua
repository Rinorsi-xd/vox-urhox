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

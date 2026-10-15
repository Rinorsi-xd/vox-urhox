local UI=require 'urhox-libs/UI'
local Hud=require 'ui.GarageHud'
local Page=require 'ui.SalvagePage'
local Carousel=require 'ui.WorkshopCarousel'
local Entrance=require 'ui.WorkshopEntrance'
local phase=0
local frames=0
local owner=nil ---@type table|nil
local function Find(widget,text)
    if widget.props and widget.props.text==text then return widget end
    for _,child in ipairs(widget.children or {}) do local found=Find(child,text);if found then return found end end
end
local function Action(text)
    Hud.Update(0)
    local widget=assert(Find(owner.page,text),'Actual workshop control '..text)
    V.assert(not widget.props.disabled,'Actual workshop control enabled '..text)
    widget.props.onClick(widget)
end
local function Key(key)
    local native=input
    input={GetKeyPress=function(_,value) return value==key end}
    local ok,err=pcall(Page.Key,owner)
    input=native
    if not ok then error(err) end
end
local function Shot(name)
    local image=Image();V.assert(graphics:TakeScreenShot(image),'Actual nested workshop capture '..name)
    image:SavePNG('docs/migration/evidence/salvage-workshop-'..name..'-native.png');image:Dispose()
end
local function Step()
    if phase==0 then
        if not VOX_HANGAR or VOX_HANGAR.app.loadingFlow.active then return end
        owner=Hud.GetState()
        -- This focused UI fixture supplies the lobby owner; natural switching
        -- and persisted purchases are verified separately through the Web UI.
        owner.app.lobby='salvage'
        owner.app.salvageLobby=owner.app.salvageLobby or require('app.SalvageLobby').New(owner.app)
        owner.SetTab('salvage');phase=1
    elseif phase==1 then
        if owner.app.lobby~='salvage' or owner.app.vehicleSwitch:IsBusy() then return end
        V.assert(owner.tab=='salvage','Real lobby switch enters salvage HUD')
        Page.Tab(owner,'workshop');phase=2;frames=0
    elseif phase==2 then
        frames=frames+1
        if not owner.workshop or not Carousel.Ready(owner.workshop,owner.workshop.selected) or frames<35 then return end
        local ws=owner.workshop
        V.assert(ws.elapsed>0 and ws.caption.elapsed>0 and ws.shelf.elapsed>0,'Nested feature clock and both source animations advance in actual GarageHud.Update')
        local native=input
        input={focus=false,minimized=false,touchEmulation=false,GetKeyPress=function() return false end}
        local before=ws.elapsed;local ok,err=pcall(Hud.Update,.01);input=native;if not ok then error(err) end
        V.assert(ws.elapsed>before,'Nested source clock update remains independent of window focus')
        local alpha=Carousel.Shelf(ws,6);V.assert(alpha>.9,'Source nested shelf card reaches visible alpha')
        local card=assert(Find(owner.page,'量产机兵 · 突击'))
        V.assert((card.props.opacity or 1)>.9,'Actual nested feature card is rendered visible')
        Shot('feature')
        local selected=Carousel.Target(ws);Key(KEY_RIGHT)
        V.assert(Carousel.Target(ws)~=selected and owner.salvage.tab=='workshop','Original right key changes nested featured vehicle')
        Key(KEY_LEFT);V.assert(Carousel.Target(ws)==selected,'Original left key restores nested selection')
        Key(KEY_RETURN);V.assert(ws.view=='detail' and owner.salvage.tab=='workshop','Original Enter opens nested detail instead of deploying')
        phase=3;frames=0
    elseif phase==3 then
        frames=frames+1;if frames<35 then return end
        V.assert(owner.workshop.entrance.elapsed>0 and Entrance.Fill(owner.workshop)>.9,'Nested detail source entrance and stat fill advance')
        local action=assert(Find(owner.page,'放进新车位'))
        V.assert((action.props.opacity or 1)>.9,'Actual nested detail purchase action is visible')
        Shot('detail');Key(KEY_ESCAPE)
        V.assert(owner.workshop.view=='feature' and owner.salvage.tab=='workshop','Original detail Escape returns one level and stays in workshop')
        Action('查看全部');V.assert(owner.workshop.view=='browse','Actual nested browse command opens full source workshop')
        phase=4;frames=0
    elseif phase==4 then
        frames=frames+1;if frames<35 then return end
        V.assert(owner.workshop.entrance.elapsed>0,'Nested browse entrance advances')
        Action('机甲');V.assert(owner.workshop.group=='mech','Actual nested source group selector works')
        phase=5;frames=0
    elseif phase==5 then
        frames=frames+1;if frames<35 then return end
        local card=assert(Find(owner.page,'量产机兵 · 重装'))
        V.assert((card.props.opacity or 1)>.9,'Actual miniHeavy full-list card becomes visible')
        Shot('browse');Key(KEY_ESCAPE)
        V.assert(owner.workshop.view=='feature' and owner.salvage.tab=='workshop','Browse Escape returns to feature before leaving salvage workshop')
        for i,key in ipairs({KEY_1,KEY_2,KEY_3,KEY_4,KEY_5}) do
            Key(key);local wanted=({'loadout','ops','market','garage','workshop'})[i]
            V.assert(owner.salvage.tab==wanted,'Original numeric salvage page shortcut '..i)
        end
        Key(KEY_ESCAPE);V.assert(owner.salvage.tab=='loadout','Feature Escape returns to original loadout')
        phase=6;V.finish()
    end
end
V.atFrame(3,function() engine.maxInactiveFps=1000;engine.maxFps=1000 end)
for frame=40,590 do V.atFrame(frame,function()
    if phase<0 or phase==6 then return end
    local ok,err=pcall(Step);if not ok then phase=-1;V.assert(false,tostring(err));V.finish() end
end) end
V.atFrame(595,function() V.assert(phase==6,'Nested workshop lifecycle sequence completes');V.finish() end)

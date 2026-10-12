local UI=require 'urhox-libs/UI'
local Hud=require 'ui.GarageHud'
local Dialogs=require 'ui.GarageDialogs'
local app,oldPicture
local retired=setmetatable({},{__mode='v'})
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image) and image:SavePNG('docs/migration/evidence/'..name..'.png'),'rendered '..name);image:Dispose()
end
local function Click(w)
    local E=require 'urhox-libs/UI/Core/PointerEvent';local r=w:GetAbsoluteLayout();local scale=UI.GetScale()
    local d={x=(r.x+r.w/2)*scale,y=(r.y+r.h/2)*scale,pointerId=97,pointerType='mouse',button=MOUSEB_LEFT}
    UI.HandlePointerEvent(E.new('PointerDown',d));UI.HandlePointerEvent(E.new('PointerUp',d))
end
V.atFrame(45,function()
    dofile('tools/migration/check-garage-rules.lua')()
end)
V.atFrame(55,function()
    app=VOX_HANGAR.app;app.store=require('storage.BlueprintStore').New('vox-garage-ui-test');app.bays.store=app.store;app.bays.active=false
    for i=1,20 do app.store:DeleteSlot(i) end
    V.assert(app.bays:Save(),'save starter into first bay')
    V.assert(app.bays:CreateVehicle('tank'),'create tank into second bay');app.bays:Open(1)
end)
V.atFrame(82,function()
    Shot('garage-home');local s=Hud.GetState();oldPicture=s.previews.items[1]
    V.assert(oldPicture.ready and oldPicture.image and not s.previews.job,'visible vehicle has completed native thumbnail')
    Click(s.buttons.settings);V.assert(Hud.IsBlocked(),'native settings click opens blocking overlay')
    local content=s.dialog.contentContainer_;Dialogs.Close(s)
    V.assert(content.node and not Hud.IsBlocked(),'closing modal immediately unblocks world and retains visual fade')
    require('ui.DialogHost').Update(s,.16);V.assert(not content.node,'160ms retirement destroys owned layout')
    Click(s.buttons.battle)
    V.assert(s.tab=='battle' and app.mode=='hangar','first battle click selects modes without changing scene')
end)
V.atFrame(92,function() Shot('garage-battle');Click(Hud.GetState().buttons.workshop) end)
V.atFrame(104,function()
    Shot('garage-workshop');local s=Hud.GetState();s.SetTab('hangar');app:EnterBuild()
end)
V.atFrame(110,function()
    Click(app.build.hud.name)
    V.assert(UI.GetFocus()==app.build.hud.name,'original inline vehicle name owns keyboard focus')
    app:ExitBuild();V.assert(UI.GetFocus()==nil,'leaving build releases inline name focus')
end)
V.atFrame(115,function()
    local s=Hud.GetState();local saved=app.store:LoadSlot(2);Click(s.cards[2])
    V.assert(app.bays.active==1 and app.vehicleSwitch:IsBusy(),'bay click retains old car until it sinks')
    app.vehicleSwitch:Update(.2)
    V.assert(app.bays.active==2 and app.blueprint:Size()==#saved.parts and app.blueprint.name==saved.name,'native bay click switches saved tank')
end)
V.atFrame(129,function()
    Shot('garage-tank');retired[1]=Hud.GetState().previews.items[1].texture;app:EnterBuild();collectgarbage('collect');collectgarbage('collect')
    V.assert(not oldPicture.texture and not oldPicture.node,'leaving home releases thumbnail texture and widget')
    V.assert(retired[1]==nil,'released thumbnail Texture2D wrapper is garbage collected')
    V.assert(app.build and app.build.slot==2,'build follows selected bay')
    app.bays:Rename('车位回归');app:ExitBuild()
    V.assert(app.store:LoadSlot(2).name=='车位回归' and not app.bays.unsaved,'return home autosaves occupied bay')
end)
for i=1,12 do
    V.atFrame(138+i*10,function() app:EnterBuild();collectgarbage('collect');app:ExitBuild();collectgarbage('collect') end)
end
V.atFrame(275,function()
    local s=Hud.GetState();local count=0;for _,p in ipairs(s.previews.items) do if p.texture then count=count+1 end end
    V.assert(count==2 and not s.previews.job,'repeated home/build retains only two visible previews')
    V.assert(not app.build and not Hud.IsBlocked(),'repeated scene UI lifecycle completes')
    local empty=require('construction.Prefab').BuildEmpty(require('construction.Blueprint').New())
    for i=3,20 do empty.name='车位 '..i;app.store:SaveSlot(i,empty) end
    local blank=require('construction.Blueprint').New();blank.name='空蓝图';app.store:SaveSlot(20,blank)
    app.bays.revision=app.bays.revision+1
end)
V.atFrame(320,function()
    local s=Hud.GetState();local count=0
    for _,p in ipairs(s.previews.items) do if p.texture then count=count+1 end end
    V.assert(count<#s.previews.items and count<=math.ceil(s.bayScroll:GetLayout().w/174)+1,'full garage renders only visible bay previews')
    s.bayScroll:SetScroll(100000,0)
end)
V.atFrame(365,function()
    local s=Hud.GetState()
    Shot('garage-scroll')
    V.assert(not s.previews.items[1].texture and s.previews.items[20].texture,'horizontal scrolling releases first bay and loads last bay')
    V.assert(s.previews.items[20].ready and not s.previews.job,'empty blueprint thumbnail completes with finite camera bounds')
    app.bays.active=false;app.bays.unsaved=true;Dialogs.Save(s)
    V.assert(s.dialog~=nil and Hud.IsBlocked(),'full garage save opens overwrite chooser')
    local content=s.dialog.contentContainer_;Dialogs.Close(s);require('ui.DialogHost').Update(s,.16)
    V.assert(not content.node,'overwrite chooser releases its scroll tree after source fade')
    Hud.Dispose();app.store.pending=nil
    for _,key in ipairs({'draft','garage-state'}) do for _,suffix in ipairs({'-a.json','-b.json'}) do local p=app.store.prefix..key..suffix;if fileSystem:FileExists(p) then fileSystem:Delete(p) end end end
    for i=1,20 do for _,suffix in ipairs({'-a.json','-b.json'}) do local p=app.store.prefix..'slot'..i..suffix;if fileSystem:FileExists(p) then fileSystem:Delete(p) end end end
    V.finish()
end)

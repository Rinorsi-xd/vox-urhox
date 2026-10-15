local UI=require('urhox-libs/UI')
local Buy=require('ui.SalvageBuy')
local Lobby=require('app.SalvageLobby')
local Blueprint=require('construction.Blueprint')
local History=require('construction.EditHistory')
local owner=nil ---@type table|nil
local phase=0
local waitFrames=0
local inventory=nil ---@type table|nil
local function Find(widget,text)
    if widget.props and widget.props.text==text then return widget end
    for _,child in ipairs(widget.children or {}) do local found=Find(child,text);if found then return found end end
end
local function Click(text)
    local button=assert(Find(owner.dialog.contentContainer_,text),'Actual source action '..text)
    V.assert(not button.props.disabled,'Actual action enabled '..text);button.props.onClick(button)
end
local function Data() return {v=1,credits=1000000,items={}} end
local function Capture(name)
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/salvage-buy-'..name..'-native.png');image:Dispose()
end
local function Run()
    if phase==0 then
        if not VOX_HANGAR or VOX_HANGAR.app.loadingFlow.active then return end
        local bp=Blueprint.New();local app={lobby='salvage',blueprint=bp,toasts={Push=function() end}}
        local slots={};app.bays={active=false,Slots=function() return slots end,FirstEmpty=function() return 1 end}
        local lobby=setmetatable({app=app,data=Data(),Save=function() return true end},Lobby);app.salvageLobby=lobby
        owner={app=app,Notify=function() end,Refresh=function() end,disposed=false,PickHotbar=function(s,t) s.picked=t end,Dispose=function(s) s.disposed=true end}
        owner.editor={history=History.New(bp),tool='build',type='cube'};owner.SetTab=function(t) owner.tab=t end
        owner.AssignHotbar=function(s,slot,t) s.assigned={slot,t} end
        owner.Run=function(fn,done) local ok,err,reason=fn(false);owner.last={ok,err,reason};if ok and done then done() end end
        require('app.SalvageBuild').Attach(owner)
        owner.history=owner.editor.history
        local original=bp:Size();local ops={{op='add',data={type='laser1',pos={0,3,0},rot=1}}}
        V.assert(not owner.history:Commit(ops) and bp:Size()==original and owner.dialog~=nil,'actual editor rejects missing stock and opens source purchase')
        waitFrames=0;phase=1;return
    elseif phase==1 then
        waitFrames=waitFrames+1;if waitFrames>28 then phase=2 end;return
    elseif phase==2 then
        Capture('missing');Click('购买并装上')
        V.assert(owner.app.blueprint:Size()==1 and owner.app.salvageLobby:Owned('part:laser1')==1,'purchase callback retries rejected actual placement')
        local cash=owner.app.salvageLobby.data.credits
        owner:PickHotbar('laser2');Click('×5');Click('购买')
        V.assert(owner.picked=='laser2' and owner.app.salvageLobby:Owned('part:laser2')==5 and owner.app.salvageLobby.data.credits<cash,'inventory quantity five buys five then picks source part')
        local _,p=next(owner.app.blueprint.parts)
        owner.history:Commit({{op='remove',data=History.Snapshot(p)}})
        owner.app.salvageLobby.data.items['part:laser1']=0
        V.assert(not owner.history:Undo() and owner.dialog~=nil and owner.app.blueprint:Size()==0,'undo cannot re-add sold part without buying')
        Click('取消');owner.app.salvageLobby.data.items['part:laser1']=1;owner.history:Undo()
        owner.app.salvageLobby.data=Data();owner.app.bays.CreateVehicle=function() return false,'injected placement rejection','discard' end
        V.assert(Buy.Car(owner,'raceCar'),'actual source car purchase modal mounts')
        waitFrames=0;phase=3;return
    elseif phase==3 then
        waitFrames=waitFrames+1;if waitFrames>28 then phase=4 end;return
    elseif phase==4 then
        Capture('car');local before=owner.app.salvageLobby.data;Click('购买整车')
        V.assert(owner.app.salvageLobby.data==before and owner.last[1]==false and owner.last[3]=='discard','failed real purchase callback refunds all items and credits and retains discard reason')
        owner.app.bays.CreateVehicle=function() return false,'injected slot cleanup failure','rollback' end
        Buy.Car(owner,'raceCar');Click('购买整车')
        V.assert(owner.last[3]=='rollback' and owner.app.salvageLobby.data.credits<before.credits,'unresolved created-slot rollback cannot refund a potentially retained paid car')
        owner.app.bays.CreateVehicle=function() return true end
        owner.salvage={tab='workshop'};owner.app.HomeView=function() end
        Buy.Car(owner,'raceCar');Click('购买整车')
        V.assert(owner.last[1] and owner.app.salvageLobby.data.credits<before.credits and owner.tab=='salvage' and owner.salvage.tab=='garage','successful source car purchase consumes credits and selects actual salvage garage page')
        require('ui.DialogHost').Dispose(owner)
        owner.controls={Cancel=function() end};owner.ghost={Refresh=function() end};owner.buildCamera={Release=function() end}
        owner.inventory=require('construction.Inventory').New();owner.inventory.query='激光'
        owner.app.salvageLobby.data.items['part:laser2']=0
        inventory=require('ui.InventoryPanel').Open(owner)
        waitFrames=0;phase=5;return
    elseif phase==5 then
        waitFrames=waitFrames+1;if waitFrames>28 then phase=6 end;return
    elseif phase==6 then
        Capture('inventory');local actual=nil ---@type table|nil
        for _,row in pairs(inventory.list.pool_.inUse) do for _,cell in ipairs(row.cells) do if cell.type=='laser2' then actual=cell.root end end end
        V.assert(actual~=nil and inventory:Unavailable('laser2') and inventory:Remaining('laser2')==0,'actual virtual inventory binds source zero-stock purchase card')
        actual.props.onClick(actual)
        V.assert(inventory.closed and owner.inventoryPanel==nil and owner.dialog~=nil,'actual inventory click closes/destroys library and opens purchase without accessing destroyed widgets')
        Click('购买');V.assert(owner.picked=='laser2','actual inventory purchase retries original pick callback')
        local installed=owner.history.Commit;owner:Dispose()
        V.assert(owner.history.salvageRestore==nil and owner.history.Commit~=installed,'disposing build restores shared history before other lobby')
        require('ui.DialogHost').Dispose(owner);phase=7;V.finish()
    end
end
for frame=40,850 do V.atFrame(frame,function()
    if phase<0 then return end
    local ok,err=pcall(Run);if not ok then phase=-1;V.assert(false,tostring(err));V.finish() end
end) end
V.atFrame(855,function() V.assert(phase==7,'salvage purchase/edit native flow completes');V.finish() end)

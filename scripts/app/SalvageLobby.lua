local Data=require('core.ResourceData').Read('UI/Outgame.json')
local Rules=require('core.ResourceData').Read('UI/SalvageRules.json')
local M={};M.__index=M
local function Valid(d)
    return type(d)=='table' and d.v==1 and type(d.credits)=='number' and d.credits>=0 and type(d.items)=='table'
end
function M.New(app)
    local self=setmetatable({app=app,store=require('storage.BlueprintStore').New(app.isValidation and 'vox-validation-salvage' or 'vox-salvage')},M)
    self.data=self.store:Read('stash',Valid) or {v=1,credits=8000,items={scrap=36,wire=8,alloy=3,repair=2,smokePack=2,ration=3,drive=1},op=1}
    if Rules.testFill>0 then for id in pairs(Data.items) do self.data.items[id]=math.max(Rules.testFill,self.data.items[id] or 0) end;self:Save() end
    return self
end
function M:Owned(id) return self.data.items[id] or 0 end
function M:Usage()
    local used={}
    if self.app.lobby~='salvage' then return used end
    local function Add(parts) for _,p in ipairs(parts) do local id='part:'..p[1];if p[1]~='core' then used[id]=(used[id] or 0)+1 end end end
    for i,data in ipairs(self.app.bays:Slots()) do if data and i~=self.app.bays.active then Add(data.parts) end end
    Add(self.app.blueprint:ToTable().parts);return used
end
function M:Loose(id,usage) return math.max(0,self:Owned(id)-((usage or self:Usage())[id] or 0)) end
function M:Save() return self.store:Write('stash',self.data,Valid) end
function M:Cells(usage)
    local count=0;for id in pairs(Data.items) do local n=self:Loose(id,usage);if n>0 then count=count+math.ceil(n/(Rules.stack[id] or 1)) end end;return count
end
function M:MaxQuantity(id,sell)
    local it=Data.items[id];if not it then return 1 end
    return sell and math.max(1,self:Loose(id)) or math.max(1,math.min(99,math.floor(self.data.credits/it.price)))
end
function M:Trade(id,qty,sell)
    local item=Data.items[id];qty=math.floor(qty)
    if not item or qty<1 then return false,'数量无效' end
    local price=sell and math.max(1,math.floor(item.price*Rules.sellRate)) or item.price
    if sell and self:Loose(id)<qty then return false,'库存不足' end
    if not sell and self.data.credits<price*qty then return false,'信用点不足' end
    if not sell then
        local usage=self:Usage();local loose=self:Loose(id,usage);local stack=Rules.stack[id] or 1
        if self:Cells(usage)-math.ceil(loose/stack)+math.ceil((loose+qty)/stack)>Rules.cells then return false,'仓库放不下了' end
    end
    local previous={credits=self.data.credits,count=self:Owned(id)}
    self.data.credits=self.data.credits+price*qty*(sell and 1 or -1)
    self.data.items[id]=self:Owned(id)+qty*(sell and -1 or 1)
    local ok,err=self:Save()
    if not ok then self.data.credits=previous.credits;self.data.items[id]=previous.count end
    return ok,err
end
function M.VehicleData(app,mode)
    if (app.lobby or 'arena')==mode then return app.blueprint:ToTable() end
    local context=app.lobbies and app.lobbies[mode]
    if context then return context.data end
    app.salvageLobby=app.salvageLobby or M.New(app)
    return app.salvageLobby.store:Read('draft') or require('core.ResourceData').Read('Warehouse/Manifest.json').starter
end
function M.Switch(app,mode)
    if (app.lobby or 'arena')==mode then return true end
    local ok,err=app.bays:KeepCurrent(false);if not ok then return false,err end
    ok,err=app.store:Flush();if not ok then return false,err end
    app.lobbies=app.lobbies or {};app.lobbies[app.lobby or 'arena']={store=app.store,bays=app.bays,data=app.blueprint:ToTable()}
    app.salvageLobby=app.salvageLobby or M.New(app)
    local context=app.lobbies[mode]
    if not context then
        local store=app.salvageLobby.store
        local data=store:Read('draft')
        if not data then
            local bp=require('construction.Blueprint').New():Load(require('core.ResourceData').Read('Warehouse/Manifest.json').starter)
            data=bp:ToTable()
            if Rules.testFill==0 then
                for _,p in ipairs(data.parts) do if p[1]~='core' then local id='part:'..p[1];app.salvageLobby.data.items[id]=(app.salvageLobby.data.items[id] or 0)+1 end end
                for _,id in ipairs({'cube','slope','corner','inner','half','plate'}) do app.salvageLobby.data.items['part:'..id]=(app.salvageLobby.data.items['part:'..id] or 0)+40 end
                for _,id in ipairs({'drive1','steer1'}) do app.salvageLobby.data.items['part:'..id]=(app.salvageLobby.data.items['part:'..id] or 0)+2 end
                app.salvageLobby.data.items['part:laser1']=(app.salvageLobby.data.items['part:laser1'] or 0)+1
            end
            app.salvageLobby:Save();store:SaveSlot(1,bp);store:SaveGarageState(1)
        end
        context={store=store,data=data};app.lobbies[mode]=context
    end
    local oldStore,oldBays,oldMode=app.store,app.bays,app.lobby
    app.store=context.store;app.lobby=mode
    if not context.bays then context.bays=require('construction.Garage').New(app.blueprint,context.store,function(data) return app:LoadBlueprint(data) end,true) end
    app.bays=context.bays
    ok,err=app:LoadBlueprint(context.data)
    if not ok then app.store=oldStore;app.bays=oldBays;app.lobby=oldMode;return false,err end
    app.inventory=nil
    app.bays.revision=app.bays.revision+1
    app.bays.unsaved=false
    return true
end
return M

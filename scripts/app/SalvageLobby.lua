local ResourceData=require("core.ResourceData")
local Prefab=require("construction.Prefab")
local Blueprint=require("construction.Blueprint")
local Garage=require("construction.Garage")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local Data=require('core.ResourceData').Read('UI/Outgame.json')
local Rules=require('core.ResourceData').Read('UI/SalvageRules.json')
local M={};M.__index=M
local Stash=require('salvage.StashRules')
local Valid=Stash.Valid
M.Valid=Valid
function M.New(app)
    local self=setmetatable({app=app,store=DeferredModules['storage.BlueprintStore'].New(app.isValidation and 'vox-validation-salvage' or 'vox-salvage')},M)
    local saved=self.store:Read('stash',Valid);self.fresh=not saved
    self.data=saved or Stash.Initial()
    if Rules.testFill>0 then for id in pairs(Data.items) do self.data.items[id]=math.max(Rules.testFill,self.data.items[id] or 0) end end
    if self.fresh or Rules.testFill>0 then self:Save() end
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
function M:Shortfall(usage) return Stash.Shortfall(self.data.items,usage or self:Usage()) end
function M:DeploymentShortfall(usage)
    -- Debug departures test authored vehicles without granting persistent stock.
    if self.app.debugEnabled==true then return {} end
    return self:Shortfall(usage)
end
function M:BuyAll(list)
    local result=Stash.Buy(self.data,list);if not result.ok then return result end
    local previous=self.data;self.data=result.data
    local ok,err=self:Save()
    if not ok then self.data=previous;return {ok=false,cost=result.cost,reason=err} end
    return {ok=true,cost=result.cost}
end
function M:BeginRun(runId,pocket)
    if self.data.lastStartedRun==runId then return true end
    local previous=self.data;local nextData={};for k,v in pairs(previous) do nextData[k]=v end
    local stats=previous.stats or {};nextData.stats={};for k,v in pairs(stats) do nextData.stats[k]=v end
    nextData.items={};for id,n in pairs(previous.items) do nextData.items[id]=n end
    for id,n in pairs(pocket or {}) do
        if n>(nextData.items[id] or 0) then return false,'道具库存不足' end
        nextData.items[id]=nextData.items[id]-n
    end
    nextData.stats.raids=(stats.raids or 0)+1;nextData.lastStartedRun=runId;self.data=nextData
    local ok,err=self:Save();if not ok then self.data=previous end;return ok,err
end
function M:CommitRun(runId,result,originalParts)
    if self.data.lastRun==runId then return true end
    local previous=self.data;local nextData={};for k,v in pairs(previous) do nextData[k]=v end
    nextData.items={};for id,n in pairs(previous.items) do nextData.items[id]=n end
    local stats=previous.stats or {};nextData.stats={raids=(stats.raids or 0)+(previous.lastStartedRun==runId and 0 or 1),extracted=(stats.extracted or 0)+(result.ok and 1 or 0),lost=(stats.lost or 0)+(result.ok and 0 or 1)}
    if result.ok then for id,n in pairs(result.cargo) do nextData.items[id]=(nextData.items[id] or 0)+n end
    elseif not result.keepCar then
        for _,p in ipairs(originalParts) do if p[1]~='core' then local id='part:'..p[1];nextData.items[id]=math.max(0,(nextData.items[id] or 0)-1) end end
    end
    if result.ok or result.keepCar then for id,n in pairs(result.pocket or {}) do nextData.items[id]=(nextData.items[id] or 0)+n end end
    nextData.lastRun=runId;self.data=nextData
    local ok,err=self:Save();if not ok then self.data=previous end;return ok,err
end
function M:Cells(usage)
    local count=0;for id in pairs(Data.items) do local n=self:Loose(id,usage);if n>0 then count=count+math.ceil(n/(Rules.stack[id] or 1)) end end;return count
end
function M:MaxQuantity(id,sell)
    local it=Data.items[id];if not it then return 1 end
    return sell and math.max(1,self:Loose(id)) or math.max(1,math.min(99,math.floor(self.data.credits/it.price)))
end
function M:CargoSale()
    local usage=self:Usage();local sale={items={},gain=0,count=0}
    for _,id in ipairs(Rules.itemOrder) do
        local item=Data.items[id];local n=self:Loose(id,usage)
        if item.cat=='cargo' and n>0 then
            sale.items[#sale.items+1]={id=id,n=n}
            sale.gain=sale.gain+math.max(1,math.floor(item.price*Rules.sellRate))*n;sale.count=sale.count+n
        end
    end
    return sale
end
function M:SellCargo()
    local sale=self:CargoSale();if sale.count==0 then return true,nil,0,0 end
    local previous=self.data;local nextData={};for k,v in pairs(previous) do nextData[k]=v end
    nextData.items={};for id,n in pairs(previous.items) do nextData.items[id]=n end
    for _,row in ipairs(sale.items) do local left=nextData.items[row.id]-row.n;nextData.items[row.id]=left>0 and left or nil end
    nextData.credits=previous.credits+sale.gain;self.data=nextData
    local called,ok,err=pcall(self.Save,self)
    if not called or not ok then self.data=previous;return false,called and err or tostring(ok),0,0 end
    return true,nil,sale.gain,sale.count
end
function M:Trade(id,qty,sell)
    local item=Data.items[id];qty=math.floor(qty)
    if not item or qty<1 then return false,'数量无效' end
    local price=sell and math.max(1,math.floor(item.price*Rules.sellRate)) or item.price
    if sell and self:Loose(id)<qty then
        return false,(self:Usage()[id] or 0)>0 and '装在车上的不能卖，先从车上拆下来' or '库存不够'
    end
    if not sell and self.data.credits<price*qty then
        local digits=string.format('%.0f',price*qty-self.data.credits)
        local missing=digits:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
        return false,'信用点不够（还差 '..missing..'）'
    end
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
local function StoredVehicle(store)
    local state=store:LoadGarageState();local active=state and state.active
    local saved=active and store:LoadSlot(active)
    if saved then return saved,active end
    for i=1,20 do local data=store:LoadSlot(i);if data then return data,i end end
end
function M.VehicleData(app,mode)
    if (app.lobby or 'arena')==mode then return app.blueprint:ToTable() end
    local context=app.lobbies and app.lobbies[mode]
    if context then return context.data end
    app.salvageLobby=app.salvageLobby or M.New(app)
    local saved=StoredVehicle(app.salvageLobby.store)
    if saved then return saved end
    if app.salvageLobby.fresh then return ResourceData.Read('Warehouse/Manifest.json').starter end
    return Prefab.BuildEmpty(Blueprint.New()):ToTable()
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
        -- Source enters the selected saved bay; a missing draft is not a new garage.
        local data,slot=StoredVehicle(store)
        if not data then
            local bp=Blueprint.New()
            if app.salvageLobby.fresh then bp:Load(ResourceData.Read('Warehouse/Manifest.json').starter)
            else Prefab.BuildEmpty(bp) end
            data=bp:ToTable()
            slot=1;ok,err=store:SaveSlot(slot,bp);if not ok then return false,err end
        end
        ok,err=store:SaveGarageState(slot);if not ok then return false,err end
        context={store=store,data=data};app.lobbies[mode]=context
    end
    local oldStore,oldBays,oldMode=app.store,app.bays,app.lobby
    app.store=context.store;app.lobby=mode
    if not context.bays then context.bays=Garage.New(app.blueprint,context.store,function(data) return app:LoadBlueprint(data) end,true) end
    app.bays=context.bays
    ok,err=app:LoadBlueprint(context.data)
    if not ok then app.store=oldStore;app.bays=oldBays;app.lobby=oldMode;return false,err end
    app.inventory=nil
    app.bays.revision=app.bays.revision+1
    app.bays.unsaved=false
    return true
end
return M

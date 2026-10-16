-- Native client storage, isolated by engine project/user. Two alternating
-- generations preserve the previous good write if an app exits during saving.
-- WASM memory files are session-only; cloud persistence is a separate adapter.
local Inventory=require("construction.Inventory")
local PreviewCache=require("storage.PreviewCache")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local M={};M.__index=M
local Code=require 'storage.BlueprintCode'
local Numbers=require 'storage.RecordNumbers'
local stores=setmetatable({},{__mode='k'})
local function Read(path)
    if not fileSystem:FileExists(path) then return nil end
    local file=File(path,FILE_READ);if not file:IsOpen() then file:Dispose();return nil end
    if file.size>4*1024*1024 then file:Dispose();return nil end
    local text=file:ReadString();file:Dispose()
    local ok,data=pcall(cjson.decode,text)
    return ok and type(data)=='table' and data or nil
end
function M.New(namespace)
    assert(not namespace or namespace:match('^[%w_%-]+$'),'Invalid storage namespace')
    local store=setmetatable({namespace=namespace or 'vox-garage',prefix=(namespace or 'vox-garage')..'-',pending=nil,delay=0},M)
    stores[store]=true;return store
end
function M:Read(key,validator)
    local a,b=Read(self.prefix..key..'-a.json'),Read(self.prefix..key..'-b.json')
    local valid=function(v)
        local ok,result=pcall(validator or Code.Validate,v and v.data)
        return Numbers.Metadata(v) and (v.deleted==true or ok and result)
    end
    if a and not valid(a) then DeferredModules['storage.CloudStorage'].Invalid(self.namespace);a=nil end
    if b and not valid(b) then DeferredModules['storage.CloudStorage'].Invalid(self.namespace);b=nil end
    local best=a and b and (a.generation>b.generation and a or b) or a or b
    return best and not best.deleted and best.data or nil,best and best.generation or 0,best and best.time or nil,best and best.capture or nil
end
function M:Write(key,data,validator,deleted,savedTime,capture)
    local _,generation=self:Read(key,validator)
    if generation>=Numbers.MAX_INTEGER then return false,'存档版本号已超出安全范围，保留上一版' end
    generation=generation+1
    local path=self.prefix..key..(generation%2==1 and '-a.json' or '-b.json')
    local text=cjson.encode({v=1,generation=generation,data=data,deleted=deleted or nil,time=savedTime,capture=capture})
    local file=File(path,FILE_WRITE)
    if not file:IsOpen() then file:Dispose();return false,'无法打开存档' end
    file:WriteString(text);file:Flush();file:Dispose()
    local check=Read(path)
    if not check or check.generation~=generation then return false,'存档校验失败，保留上一版' end
    DeferredModules['storage.CloudStorage'].Queue(self.namespace,key,text)
    return true
end
function M.Hydrate(namespace,key,record)
    if not Numbers.Metadata(record) then return false end
    local text=cjson.encode(record)
    for _,suffix in ipairs({'-a.json','-b.json'}) do
        local path=namespace..'-'..key..suffix;local file=File(path,FILE_WRITE)
        if not file:IsOpen() then file:Dispose();return false end
        file:WriteString(text);file:Flush();file:Dispose()
        local check=Read(path);if not check or check.generation~=record.generation then return false end
    end
    return true
end
function M.UpdateAll(dt) for store in pairs(stores) do store:Update(dt) end end
function M.FlushAll() for store in pairs(stores) do store:Flush() end end
function M:SaveMessage(text) return DeferredModules['storage.CloudStorage'].Message(self.namespace,text) end
function M:LoadBuildSettings() return self:Read('build-settings',Inventory.ValidSettings) end
function M:SaveBuildSettings(settings) return self:Write('build-settings',settings,Inventory.ValidSettings) end
function M:Queue(bp) self.pending=bp;self.delay=.5 end
function M:Flush()
    if not self.pending then return true end
    local ok,err=self:Write('draft',self.pending:ToTable())
    if ok then self.pending=nil end
    return ok,err
end
function M:Update(dt)
    if not self.pending then return end
    self.delay=self.delay-dt
    if self.delay<=0 then local ok,err=self:Flush();if not ok then print('[BlueprintStore] '..err);self.delay=5 end end
end
function M:SaveSlot(slot,bp)
    if slot%1~=0 or slot<1 or slot>20 then return false,'车位超出范围' end
    -- Keep library metadata in the same recoverable generation, outside the
    -- exchange blueprint. Source slots use Date.now() (milliseconds).
    local _,previous=self:LoadSlot(slot)
    local ok,err=self:Write('slot'..slot,bp:ToTable(),nil,nil,os.time()*1000,self.captureContext and self.captureContext() or nil)
    if ok and previous>1 then PreviewCache.Retire(self,slot,previous-1) end
    return ok,err
end
function M:LoadSlot(slot)
    if slot%1~=0 or slot<1 or slot>20 then return nil end
    return self:Read('slot'..slot)
end
function M:DeleteSlot(slot)
    if slot%1~=0 or slot<1 or slot>20 then return false,'车位超出范围' end
    local _,generation=self:LoadSlot(slot)
    local ok,err=self:Write('slot'..slot,nil,nil,true);if not ok then return false,err end
    local previews=PreviewCache
    previews.Retire(self,slot,generation);if generation>1 then previews.Retire(self,slot,generation-1) end
    -- Retire both backup generations so later corruption cannot resurrect it.
    return self:Write('slot'..slot,nil,nil,true)
end
local function GarageState(data)
    return type(data)=='table' and data.v==1 and (data.active==false or type(data.active)=='number' and data.active%1==0 and data.active>=1 and data.active<=20)
end
function M:LoadGarageState() return self:Read('garage-state',GarageState) end
function M:SaveGarageState(active) return self:Write('garage-state',{v=1,active=active or false},GarageState) end
return M

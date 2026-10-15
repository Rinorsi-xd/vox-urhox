-- Scene-owned pristine specs. Runtime instances must never share mutable poses.
local BP=require 'construction.Blueprint'
local Spec=require 'drive.VehicleSpec'
local M={VERSION='spawn-spec-1'};M.__index=M
local function Clone(value,memo,checkpoint)
    if value==cjson.null then return value end
    if type(value)~='table' then
        assert(type(value)=='number' or type(value)=='string' or type(value)=='boolean' or value==nil,'Spec contains a native/non-data value')
        return value
    end
    if memo[value] then return memo[value] end
    local out={};memo[value]=out
    for key,item in pairs(value) do out[Clone(key,memo,checkpoint)]=Clone(item,memo,checkpoint) end
    if checkpoint then checkpoint() end
    return out
end
function M.Clone(value) return Clone(value,{}) end
local function Signature(value,stack,checkpoint)
    if value==cjson.null then return 'z' end
    local kind=type(value)
    if kind=='nil' then return 'n' end
    if kind=='boolean' then return value and 't' or 'f' end
    if kind=='number' then return 'd'..string.pack('>d',value) end
    if kind=='string' then return 's'..#value..':'..value end
    if kind~='table' or stack[value] then return nil end
    stack[value]=true
    local entries={}
    for key,item in pairs(value) do
        local k=Signature(key,stack,checkpoint);local v=Signature(item,stack,checkpoint)
        if not k or not v then stack[value]=nil;return nil end
        entries[#entries+1]={key=k,value=v}
    end
    table.sort(entries,function(a,b) return a.key<b.key end)
    local out={'{'}
    for _,entry in ipairs(entries) do out[#out+1]=entry.key;out[#out+1]=entry.value end
    out[#out+1]='}';stack[value]=nil
    if checkpoint then checkpoint() end
    return table.concat(out)
end
function M.New()
    return setmetatable({entries={},disposed=false,hits=0,misses=0,prepared=0},M)
end
function M:Prepare(source,checkpoint)
    if self.disposed then return false end
    -- Capture before the first scheduling point; input may change while loading.
    local snapshot=Clone(source,{})
    local signature=Signature(snapshot,{},checkpoint)
    if not signature or self.disposed then return false end
    local key=M.VERSION..signature
    if self.entries[key] then return true end
    local spec=Spec.Build(BP.New():Load(snapshot),checkpoint and function() checkpoint() end or nil)
    if not spec.ok or self.disposed then return false end
    self.entries[key]=spec;self.prepared=self.prepared+1
    return true
end
function M:Get(source)
    if self.disposed then return nil end
    local signature=Signature(source,{})
    local template=signature and self.entries[M.VERSION..signature]
    if not template then self.misses=self.misses+1;return nil end
    self.hits=self.hits+1
    return Clone(template,{})
end
function M:Dispose()
    self.entries={};self.disposed=true
end
return M

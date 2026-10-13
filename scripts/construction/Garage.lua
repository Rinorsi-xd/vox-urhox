-- Vehicle bay semantics from shared/build/editor.js, with explicit failure
-- results. UI owns confirmations; storage writes must succeed before switching.
local Blueprint=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Code=require 'storage.BlueprintCode'
local M={};M.__index=M
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
function M.New(bp,store,replace,restore)
    local state=restore and store:LoadGarageState() or nil
    local active=state and state.active or false
    local saved=active and store:LoadSlot(active)
    if not saved then active=false end
    return setmetatable({bp=bp,store=store,replace=replace,active=active,
        unsaved=saved and not Same(Blueprint.New():Load(saved):ToTable(),bp:ToTable()) or not saved and bp:Size()>1,
        revision=0},M)
end
function M:Slots()
    local list={}
    for i=1,20 do
        local data,generation,savedTime,context=self.store:LoadSlot(i)
        if data then
            data.savedTime=savedTime
            data.preview=require('storage.PreviewCache').Ref(self.store,i,generation,context)
        end
        list[i]=data or false
    end
    return list
end
function M:FirstEmpty() for i=1,20 do if not self.store:LoadSlot(i) then return i end end end
function M:Changed() self.unsaved=true;self.revision=self.revision+1;self.store:Queue(self.bp) end
function M:Activate(slot)
    local ok,err=self.store:SaveGarageState(slot or false)
    if not ok then return false,err end
    self.store:Queue(self.bp);ok,err=self.store:Flush();if not ok then return false,err end
    self.active=slot or false;self.unsaved=false;self.revision=self.revision+1;return true
end
-- A failed metadata/draft write must not replace the player's visible vehicle.
-- Separate slot and draft files are recoverable generations, not one atomic DB.
function M:Switch(data,slot)
    local previous=self.bp:ToTable();local active,unsaved=self.active,self.unsaved
    local ok,err=self.replace(data);if not ok then return false,err end
    ok,err=self:Activate(slot)
    if not ok then
        self.replace(previous);self.active=active;self.unsaved=unsaved
        self.store:SaveGarageState(active);self.store:Queue(self.bp);self.store:Flush()
        self.revision=self.revision+1
    end
    return ok,err
end
function M:Save(slot)
    slot=slot or self.active or self:FirstEmpty()
    if not slot then return false,'20 个车位都满了，请选择覆盖车位','full' end
    local ok,err=self.store:SaveSlot(slot,self.bp);if not ok then return false,err end
    return self:Activate(slot)
end
function M:KeepCurrent(discard)
    if not self.unsaved then return true end
    if self.active then return self:Save(self.active) end
    if self.bp:Size()<=1 then return true end
    local slot=self:FirstEmpty()
    if slot then return self:Save(slot) end
    if discard then return true end
    return false,'当前草稿尚未保存，20 个车位已满','discard'
end
function M:Open(slot,discard)
    if slot==self.active then return true end
    local data=self.store:LoadSlot(slot);if not data then return false,'这个车位没有战车' end
    local ok,err,reason=self:KeepCurrent(discard);if not ok then return false,err,reason end
    return self:Switch(data,slot)
end
-- Explicit library restore differs from home bay switching: it also reloads
-- the current bay. The UI confirms losing unsaved changes before calling this.
function M:Restore(slot)
    local data=self.store:LoadSlot(slot);if not data then return false,'这个车位没有战车' end
    return self:Switch(data,slot)
end
-- Build import is a new unslotted draft, matching source _replace. It must not
-- overwrite the previously active bay when returning to the home screen.
function M:Import(data)
    local valid=pcall(Code.Validate,data);if not valid then return false,'无效蓝图' end
    local ok,err=self:Switch(data,false)
    if ok then self:Changed() end
    return ok,err
end
function M:CreateVehicle(kind,name,discard)
    local candidate=Blueprint.New()
    if type(kind)=='table' then
        local ok,data=pcall(Code.Validate,kind);if not ok then return false,'无效蓝图' end
        candidate:Load(data)
    elseif Prefab.keys[kind] then Prefab.Create(candidate,kind) else return false,'未知预制车' end
    if name then candidate.name=name end
    local ok,err,reason=self:KeepCurrent(discard);if not ok then return false,err,reason end
    local slot=self:FirstEmpty();if not slot then return false,'20 个车位都满了，先删除一个车位','full' end
    ok,err=self.store:SaveSlot(slot,candidate);if not ok then return false,err end
    return self:Switch(candidate:ToTable(),slot)
end
function M:Copy(discard) return self:CreateVehicle(self.bp:ToTable(),self.bp.name..' 副本',discard) end
function M:Rename(name)
    name=tostring(name):match('^%s*(.-)%s*$')
    if name=='' then return false,'车名不能为空' end
    local length=utf8.len(name)
    if not length or length>40 then return false,'车名最多 40 个字' end
    self.bp.name=name;self:Changed();return true
end
function M:ReplacementAfterDelete(slot)
    if slot~=self.active then return nil end
    for i=slot+1,20 do local data=self.store:LoadSlot(i);if data then return data,i end end
    for i=slot-1,1,-1 do local data=self.store:LoadSlot(i);if data then return data,i end end
    return Prefab.BuildEmpty(Blueprint.New()):ToTable()
end
function M:Delete(slot)
    if not self.store:LoadSlot(slot) then return false,'这个车位没有战车' end
    local ok,err=self.store:DeleteSlot(slot);if not ok then return false,err end
    if slot==self.active then
        local data,nextSlot=self:ReplacementAfterDelete(slot)
        ok,err=self.replace(data);if not ok then return false,err end
        return self:Activate(nextSlot)
    end
    self.revision=self.revision+1;return true
end
return M

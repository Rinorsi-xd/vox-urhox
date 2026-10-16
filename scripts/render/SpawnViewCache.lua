-- Session-owned, one-use visual assemblies. No simulation objects are spawned.
local BP=require 'construction.Blueprint'
local View=require 'render.VehicleView'
local M={};M.__index=M
local function Encode(value)
    if value==cjson.null then return 'z' end
    local kind=type(value)
    if kind=='number' then return 'd'..string.pack('>d',value) end
    if kind=='string' then return 's'..#value..':'..value end
    if kind=='nil' then return 'n' end
    if kind=='boolean' then return value and 't' or 'f' end
    assert(kind=='table','Visual signature contains a non-data value')
    local entries={}
    for key,item in pairs(value) do entries[#entries+1]=Encode(key)..Encode(item) end
    table.sort(entries)
    return '{'..table.concat(entries)..'}'
end
local function Signature(bp)
    local parts={}
    for _,p in ipairs(bp:List()) do
        parts[#parts+1]={p.id,p.type,p.pos,p.rot,p.color,p.shellColor or cjson.null,p.g or 0}
    end
    return Encode({parts=parts,livery=bp.livery or {}})
end
local function Retire(entry)
    if entry.view then entry.view:Dispose();entry.view=nil end
    entry.root:Dispose()
end
function M.New(scene,options)
    local self=setmetatable({},M);self:init(scene,options or {});return self
end
function M:init(scene,options)
    self.scene=scene;self.limit=math.max(0,math.min(8,math.floor(options.limit or 8)))
    self.entries={};self.count=0;self.prepared=0;self.hits=0;self.misses=0;self.disposed=false
end
function M:Prepare(source,spec,copies,checkpoint)
    if self.disposed or not spec or not spec.ok then return 0 end
    local bp=BP.New():Load(source);local keep={}
    for _,id in ipairs(spec.partIds) do keep[id]=true end
    for _,p in ipairs(bp:List()) do if not keep[p.id] then bp:Remove(p.id) end end
    local key=Signature(bp);local list=self.entries[key] or {}
    self.entries[key]=list
    local target=math.max(0,math.floor(copies or 1));local added=0
    local planned=math.max(0,math.min(target-#list,self.limit-self.count))
    while added<planned do
        local entry={root=self.scene:CreateChild('PreparedSpawn')}
        self.pending=entry;self.count=self.count+1;entry.root.enabled=false
        local ok,err=pcall(function()
            entry.view=View.New(entry.root,'DrivenCar')
            entry.view:Rebuild(bp,function(p)
                if checkpoint then checkpoint((added+p)/planned) end
                assert(not self.disposed,'Spawn view preparation canceled')
            end,true)
        end)
        if not ok then
            if self.pending==entry then self.pending=nil;self.count=self.count-1;Retire(entry) end
            error(err,0)
        end
        self.pending=nil;list[#list+1]=entry;self.prepared=self.prepared+1;added=added+1
    end
    return added
end
function M:Take(bp)
    if self.disposed then return nil end
    local list=self.entries[Signature(bp)]
    if not list or #list==0 then self.misses=self.misses+1;return nil end
    local entry=list[#list];local view=entry.view
    -- Keep the car hidden until Bind has applied the real native pose.
    view.root.enabled=false;view.root:SetParent(self.scene)
    table.remove(list);entry.view=nil;entry.root:Dispose();self.count=self.count-1;self.hits=self.hits+1
    return view
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.pending then Retire(self.pending);self.pending=nil end
    for _,list in pairs(self.entries) do for _,entry in ipairs(list) do Retire(entry) end end
    self.entries={};self.count=0
end
return M

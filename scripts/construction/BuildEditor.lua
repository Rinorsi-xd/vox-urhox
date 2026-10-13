-- Engine-independent editor commands. Input, previews and persistence are adapters.
local Blueprint=require 'construction.Blueprint'
local Placement=require 'construction.Placement'
local History=require 'construction.EditHistory'
local Ray=require 'construction.GridRay'
local Rot=require 'core.Rotations'
local Defs=require('parts.Defs').PARTS
local Config=require 'Config'
local Finish=require 'parts.Finish'
local Selection=require 'construction.SelectionTools'
local M={};M.__index=M
local function Copy(v) return {table.unpack(v)} end
function M.New(bp,onChange)
    local self=setmetatable({bp=bp,bounds=Config.TierBounds(),type='cube',tool='build',paintChannel='shell',color=Config.PALETTE[1].hex,
        autoColor=false,mirror=true,spin=0,forward={0,0,1},selection={},clipboard={},pasteSpin=0,pasting=false,dirty=true},M)
    self.history=History.New(bp,function(ops,revision)
        self.dirty=true;self.preview=nil
        self:SelectionChanged()
        if onChange then onChange(ops,revision) end
    end)
    return self
end
function M:SelectType(type)
    if not Defs[type] then return false end
    self.emptySlot=false
    self.type=type;self.tool='build';self.spin=0;self.sampledRot=nil;self.sampledFinish=nil;self.pasting=false;self.preview=nil
    return true
end
function M:SetTool(tool)
    assert(tool=='build' or tool=='erase' or tool=='paint')
    self.tool=tool;self.preview=nil;if tool~='build' then self.pasting=false end
end
function M:Rotate(step)
    if self.tool=='paint' then return end
    if self.pasting then self.pasteSpin=self.pasteSpin+step else self.spin=self.spin+step end
end
function M:Tilt(step)
    if self.tool~='build' or self.pasting or not Defs[self.type].shape then return end
    local normal=self.hit and self.hit.normal or {0,1,0}
    local rot=Placement.Rotation(self.type,normal,self.forward,self.spin,self.sampledRot)
    self.sampledRot=Rot.RotateAroundAxis(rot,normal[2]~=0 and {1,0,0} or {0,1,0},step);self.spin=0
end
function M:Trace(origin,direction)
    local hit=Ray.Cast(origin,direction,self.bp,160,false)
    if not hit.hit and self.bp:Size()==0 and self.type=='core' then hit={hit=true,cell={0,3,0},place={0,4,0},normal={0,1,0},anchor=true} end
    return self:Preview(hit.hit and hit or nil)
end
function M:Preview(hit)
    self.hit=hit;self.preview=nil;if not hit then return nil end
    if self.emptySlot and self.tool=='build' then return nil end
    if self.pasting then
        local items=self:PasteItems(hit.place);local ok=true
        for _,it in ipairs(items) do ok=ok and it.res.ok end
        self.preview={paste=items,ok=ok};return self.preview
    end
    if self.tool~='build' then return nil end
    local type=self.type
    local p=Placement.For(type,hit,hit.place,self.forward,self.spin,self.sampledRot)
    local res=self.bp:Check(type,p.pos,p.rot,self.bounds)
    if not res.ok and hit.alt then p=Placement.For(type,hit,hit.alt,self.forward,self.spin,self.sampledRot);res=self.bp:Check(type,p.pos,p.rot,self.bounds) end
    if p.reason then res.ok=false;res.reason=p.reason end
    local pv={type=type,pos=p.pos,rot=p.rot,res=res,normal=hit.normal}
    if self.mirror then
        local m=Placement.Mirror(type,p.pos,p.rot)
        if m then
            m.res=self.bp:Check(type,m.pos,m.rot,self.bounds)
            local own={};for _,c in ipairs(res.cells) do own[Blueprint.Key(table.unpack(c))]=true end
            local overlaps=false;for _,c in ipairs(m.res.cells) do overlaps=overlaps or own[Blueprint.Key(table.unpack(c))]~=nil end
            if not overlaps then pv.mirror=m end
        end
    end
    self.preview=pv;return pv
end
function M:Place()
    local pv=self.preview;if not pv or not pv.type then return false,'没有放置目标' end
    -- Revalidate current state; stale previews must never write an overlap.
    local res=self.bp:Check(pv.type,pv.pos,pv.rot,self.bounds)
    if not pv.res.ok or not res.ok then return false,pv.res.ok and res.reason or pv.res.reason end
    local finish=self.sampledFinish and self.sampledFinish.type==pv.type and self.sampledFinish or Defs[pv.type]
    local first={id=self.bp.nextId,type=pv.type,pos=Copy(pv.pos),rot=pv.rot,color=finish.color,shellColor=finish.shellColor}
    if not self.autoColor then first[Finish.Field(first,self.paintChannel) or 'color']=self.color end
    -- The mirror is checked after the first addition, as in source. Probe within
    -- the synchronous command, then remove it before committing the single delta.
    local ops={{op='add',data=first}}
    if pv.mirror then
        local nextId=self.bp.nextId;self.bp:Add(first)
        local m=pv.mirror;local valid=self.bp:Check(pv.type,m.pos,m.rot,self.bounds)
        if valid.ok then ops[#ops+1]={op='add',data={id=self.bp.nextId,type=pv.type,pos=Copy(m.pos),rot=m.rot,color=first.color,shellColor=first.shellColor}} end
        self.bp:Remove(first.id);self.bp.nextId=nextId
    end
    return self.history:Commit(ops)
end
function M:Targets(hit)
    local p=hit and self.bp.parts[hit.partId];if not p then return {} end
    local list={p};local mirror=self.mirror and Placement.MirrorPart(self.bp,p)
    if mirror then list[#list+1]=mirror end;return list
end
function M:Remove(hit)
    local ops={};for _,p in ipairs(self:Targets(hit or self.hit)) do ops[#ops+1]={op='remove',data=History.Snapshot(p)} end
    return self.history:Commit(ops)
end
function M:Paint()
    if self.tool~='paint' then return false end
    local ops={};for _,p in ipairs(self:Targets(self.hit)) do
        local field=Finish.Field(p,self.paintChannel)
        local target=self.autoColor and (field=='shellColor' and 0xcbd1d7 or Defs[p.type].color) or self.color
        if field and (p[field] or (field=='shellColor' and 0xcbd1d7 or Defs[p.type].color))~=target then ops[#ops+1]={op='color',id=p.id,channel=field,from=p[field],to=target} end
    end
    return self.history:Commit(ops)
end
function M:Pick(hit)
    local p=hit and self.bp.parts[hit.partId];if not p then return false end
    self:SelectType(p.type)
    local main=Finish.Field(p,'shell')
    self.autoColor=p[main]==nil;if p[main]~=nil then self.color=p[main] end
    if main=='shellColor' then self.sampledFinish={type=p.type,color=p.color} end
    return true
end
function M:Eyedrop(hit)
    local p=hit and self.bp.parts[hit.partId];if not p then return false end
    local field=Finish.Field(p,self.paintChannel);if not field then return false end
    self.color=p[field] or (field=='shellColor' and 0xcbd1d7 or Defs[p.type].color);self.autoColor=false;return true
end
function M:ToggleSelect(id)
    return self:ToggleSelectTarget({partId=id,cell=self.bp.parts[id] and self.bp.parts[id].pos})
end
function M:SelectionParts(parts)
    local out,seen={},{}
    for _,p in ipairs(parts) do
        if not seen[p.id] then out[#out+1]=p;seen[p.id]=true end
        local mirror=self.mirror and Placement.MirrorPart(self.bp,p)
        if mirror and not seen[mirror.id] then out[#out+1]=mirror;seen[mirror.id]=true end
    end
    return out
end
function M:SelectionChanged()
    for id in pairs(self.selection) do if not self.bp.parts[id] then self.selection[id]=nil end end
    local corners={}
    for _,c in ipairs(self.selectionCorners or {}) do if self.selection[c.id] then corners[#corners+1]=c end end
    self.selectionCorners=corners;self.selectionVersion=(self.selectionVersion or 0)+1;self.dirty=true
end
function M:ToggleSelectTarget(hit)
    hit=hit or self.hit;local p=hit and self.bp.parts[hit.partId];if not p then return nil end
    self:SelectionChanged()
    local cell=hit.cell or p.pos;local offset={cell[1]-p.pos[1],cell[2]-p.pos[2],cell[3]-p.pos[3]}
    local function Same(c) return c.id==p.id and Rot.Eq(c.offset,offset) end
    local corners=self.selectionCorners or {};local second=#corners==1 and not Same(corners[1])
    local on=second or not self.selection[p.id]
    if on then
        local nextCorners={};for _,c in ipairs(corners) do if not Same(c) then nextCorners[#nextCorners+1]=c end end
        nextCorners[#nextCorners+1]={id=p.id,offset=offset}
        if #nextCorners>2 then table.remove(nextCorners,1) end
        self.selectionCorners=nextCorners
    end
    for _,part in ipairs(self:SelectionParts({p})) do self.selection[part.id]=on or nil end
    self:SelectionChanged();return on
end
function M:SweepSelect(on,hit)
    hit=hit or self.hit;local p=hit and self.bp.parts[hit.partId]
    if not p or (self.selection[p.id]==true)==on then return false end
    for _,part in ipairs(self:SelectionParts({p})) do self.selection[part.id]=on or nil end
    self:SelectionChanged();return true
end
function M:DragPreview(drag)
    local hit=self.hit;local cell=hit and (hit.cell or hit.place)
    local key=table.concat({self.history.revision,self.selectionVersion or 0,tostring(self.mirror),cell and table.concat(cell,',') or '',hit and hit.partId or ''},'|')
    if drag.key==key then return end;drag.key=key;drag.parts={};drag.lo=nil;drag.hi=nil
    if cell then
        drag.lo,drag.hi=Selection.Bounds(drag.anchor,cell)
        if hit.partId and self.bp.parts[hit.partId] then
            for _,p in ipairs(self:SelectionParts(Selection.CornerParts(self.bp,drag.anchor,cell))) do
                if not self.selection[p.id] then drag.parts[#drag.parts+1]=p end
            end
        end
    end
    self.dirty=true
end
function M:AddSelection(parts)
    for _,p in ipairs(parts) do if self.bp.parts[p.id] then self.selection[p.id]=true end end
    self:SelectionChanged()
end
function M:SelectCorner()
    local corners=self.selectionCorners or {}
    if #corners~=2 then return false,'先左键选 A，再左键选 B，最后按 K 选中间的方块' end
    local cells={}
    for i,c in ipairs(corners) do
        local p=self.bp.parts[c.id];if not p then return false end
        cells[i]={p.pos[1]+c.offset[1],p.pos[2]+c.offset[2],p.pos[3]+c.offset[3]}
    end
    self:AddSelection(self:SelectionParts(Selection.CornerParts(self.bp,cells[1],cells[2])))
    return true
end
function M:SelectAll() for id in pairs(self.bp.parts) do self.selection[id]=true end;self:SelectionChanged() end
function M:BoxSelect(rect,project)
    if not rect.add then self.selection={} end
    local x0,x1=math.min(rect.x0,rect.x1),math.max(rect.x0,rect.x1)
    local y0,y1=math.min(rect.y0,rect.y1),math.max(rect.y0,rect.y1)
    for _,p in ipairs(self.bp:List()) do for _,c in ipairs(p._cells) do
        local x,y,visible=project(c)
        if visible and x>=x0 and x<=x1 and y>=y0 and y<=y1 then self.selection[p.id]=true;break end
    end end
end
function M:Selected()
    local out={};for _,p in ipairs(self.bp:List()) do if self.selection[p.id] then out[#out+1]=p end end;return out
end
function M:Move(parts,delta)
    if #parts==0 then return false end
    local ignore={};for _,p in ipairs(parts) do ignore[p.id]=true end
    for _,p in ipairs(parts) do
        local pos={p.pos[1]+delta[1],p.pos[2]+delta[2],p.pos[3]+delta[3]}
        local res=self.bp:Check(p.type,pos,p.rot,self.bounds,ignore,false)
        if not res.ok then return false,res.reason end
    end
    local ops={};for _,p in ipairs(parts) do ops[#ops+1]={op='remove',data=History.Snapshot(p)} end
    for _,p in ipairs(parts) do
        local data=History.Snapshot(p);for a=1,3 do data.pos[a]=data.pos[a]+delta[a] end
        ops[#ops+1]={op='add',data=data}
    end
    return self.history:Commit(ops)
end
function M:MoveSelection(delta) return self:Move(self:Selected(),delta) end
function M:Lift(delta) return self:Move(self.bp:List(),{0,delta,0}) end
function M:DeleteSelection()
    local ops,seen={},{}
    for _,p in ipairs(self:Selected()) do for _,target in ipairs(self:Targets({partId=p.id})) do
        if not seen[target.id] then seen[target.id]=true;ops[#ops+1]={op='remove',data=History.Snapshot(target)} end
    end end
    local ok=self.history:Commit(ops);self.selection={};return ok
end
function M:Copy()
    local parts=self:Selected();if #parts==0 then return false end
    table.sort(parts,function(a,b)
        if a.pos[2]~=b.pos[2] then return a.pos[2]<b.pos[2] end
        if a.pos[3]~=b.pos[3] then return a.pos[3]<b.pos[3] end
        return a.pos[1]<b.pos[1]
    end)
    local origin=parts[1].pos;self.clipboard={}
    for _,p in ipairs(parts) do self.clipboard[#self.clipboard+1]={type=p.type,rel={p.pos[1]-origin[1],p.pos[2]-origin[2],p.pos[3]-origin[3]},rot=p.rot,color=p.color,shellColor=p.shellColor} end
    return true
end
function M:StartPaste()
    if #self.clipboard==0 then return false end
    self.pasting=true;self.pasteSpin=0;return true
end
function M:PasteItems(place)
    local items={}
    for _,it in ipairs(self.clipboard) do
        local r=Rot.RotateVecY(it.rel,self.pasteSpin);local pos={place[1]+r[1],place[2]+r[2],place[3]+r[3]}
        local rot=Rot.RotateWorldY(it.rot,self.pasteSpin)
        items[#items+1]={type=it.type,pos=pos,rot=rot,color=it.color,shellColor=it.shellColor,res=self.bp:Check(it.type,pos,rot,self.bounds,nil,false)}
    end
    return items
end
function M:CommitPaste()
    local pv=self.preview;if not pv or not pv.paste then return false end
    if not pv.ok then return false,'这里放不下' end
    local ops={};local id=self.bp.nextId
    for _,it in ipairs(pv.paste) do
        local res=self.bp:Check(it.type,it.pos,it.rot,self.bounds,nil,false);if not res.ok then return false,res.reason end
        if not (Defs[it.type].unique and #self.bp:CoreParts()>0) then
            ops[#ops+1]={op='add',data={id=id,type=it.type,pos=Copy(it.pos),rot=it.rot,color=it.color,shellColor=it.shellColor}};id=id+1
        end
    end
    local ok=self.history:Commit(ops);self.selection={}
    for _,op in ipairs(ops) do self.selection[op.data.id]=true end
    self.pasting=false;return ok
end
function M:Act()
    if self.pasting then return self:CommitPaste() end
    if self.tool=='paint' then return self:Paint() elseif self.tool=='erase' then return self:Remove() end
    return self:Place()
end
function M:Undo()
    local ops=self.history.undoStack[#self.history.undoStack] or {}
    for _,op in ipairs(ops) do if op.op=='add' then self.selection[op.data.id]=nil end end
    return self.history:Undo()
end
function M:Redo()
    local ops=self.history.redoStack[#self.history.redoStack] or {}
    for _,op in ipairs(ops) do if op.op=='remove' then self.selection[op.data.id]=nil end end
    return self.history:Redo()
end
return M

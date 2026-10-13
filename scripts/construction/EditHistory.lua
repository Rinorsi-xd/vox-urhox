-- Reversible deltas, stable part IDs, source limit 300. Rendering is an observer.
local M={};M.__index=M
function M.Snapshot(p)
    local data={id=p.id,type=p.type,pos={table.unpack(p.pos)},rot=p.rot,color=p.color,shellColor=p.shellColor}
    if p.g and p.g>0 then data.g=p.g end
    return data
end
function M.New(bp,onChange)
    return setmetatable({bp=bp,onChange=onChange,undoStack={},redoStack={},revision=0},M)
end
function M:Apply(op)
    if op.op=='add' then return self.bp:Add(op.data)
    elseif op.op=='remove' then return self.bp:Remove(op.data.id)
    elseif op.op=='color' then return self.bp:SetColor(op.id,op.to,op.channel) end
    error('Unknown edit operation '..tostring(op.op))
end
function M.Inverse(op)
    if op.op=='color' then return {op='color',id=op.id,channel=op.channel,from=op.to,to=op.from} end
    return {op=op.op=='add' and 'remove' or 'add',data=op.data}
end
function M:Changed(ops)
    self.revision=self.revision+1
    if self.onChange then self.onChange(ops,self.revision) end
end
function M:Commit(ops)
    if #ops==0 then return false end
    for _,op in ipairs(ops) do self:Apply(op) end
    self.undoStack[#self.undoStack+1]=ops
    if #self.undoStack>300 then table.remove(self.undoStack,1) end
    self.redoStack={};self:Changed(ops);return true
end
function M:Undo()
    local ops=table.remove(self.undoStack);if not ops then return false end
    local inverse={}
    for i=#ops,1,-1 do local op=M.Inverse(ops[i]);self:Apply(op);inverse[#inverse+1]=op end
    self.redoStack[#self.redoStack+1]=ops;self:Changed(inverse);return true
end
function M:Redo()
    local ops=table.remove(self.redoStack);if not ops then return false end
    for _,op in ipairs(ops) do self:Apply(op) end
    self.undoStack[#self.undoStack+1]=ops;self:Changed(ops);return true
end
return M

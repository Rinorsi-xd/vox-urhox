-- Frozen editor.js: face-connected selection groups, joined placement and
-- splitting a group after a single-cell removal. All changes share one history.
local Defs=require('parts.Defs').PARTS
local Blueprint=require 'construction.Blueprint'
local Dirs=require('core.Rotations').DIRS
local M={}
local function Key(p) return Blueprint.Key(table.unpack(p)) end
local function At(parts,cells,single)
    local at={}
    for _,p in ipairs(parts) do for _,c in ipairs(cells and p._cells or {p.pos}) do
        local key=Key(c);at[key]=single and {} or at[key] or {};at[key][#at[key]+1]=p
    end end
    return at
end
local function Neighbours(at,p,fn,cells)
    for _,c in ipairs(cells and p._cells or {p.pos}) do for _,d in ipairs(Dirs) do
        for _,q in ipairs(at[Key({c[1]+d[1],c[2]+d[2],c[3]+d[3]})] or {}) do fn(q) end
    end end
end
function M.Selection(editor)
    local blocks={}
    for _,p in ipairs(editor:SelectionParts(editor:Selected())) do
        if Defs[p.type].shape and not Defs[p.type].panel then blocks[#blocks+1]=p end
    end
    if not next(editor.selection) then return nil,'先选中方块（左键点选，按住扫过连续选，Ctrl+A 全选），再按 F 转成连续块' end
    if #blocks==0 then return nil,'选中的零件里没有方块，只有方块能转成连续块' end
    local split=true;for _,p in ipairs(blocks) do if p.g==0 then split=false;break end end
    local at=At(blocks,false,true);local groups={};local count=0
    if not split then for _,p in ipairs(blocks) do if not groups[p.id] then
        local group=editor.bp.nextGroup+count;count=count+1
        local stack={p};groups[p.id]=group
        while #stack>0 do
            local q=table.remove(stack)
            Neighbours(at,q,function(r) if not groups[r.id] then groups[r.id]=group;stack[#stack+1]=r end end)
        end
    end end end
    local op={op='group',ids={},from={},to={}}
    for _,p in ipairs(blocks) do op.ids[#op.ids+1]=p.id;op.from[#op.from+1]=p.g;op.to[#op.to+1]=split and 0 or groups[p.id] end
    return op,split and ('已转回普通方块：'..#blocks..' 块') or ('已转成 '..count..' 块连续块（'..#blocks..' 格），没有接缝；再选中按 F 转回普通方块')
end
function M.JoinAdded(bp,ops)
    local all=bp:List();local at=At(all);local members={}
    for _,p in ipairs(all) do if p.g>0 then members[p.g]=members[p.g] or {};members[p.g][#members[p.g]+1]=p end end
    local out,visited={},{}
    for _,op in ipairs(ops) do local seed=op.op=='add' and bp.parts[op.data.id]
        if seed and seed.g>0 and not visited[seed.id] then
            local stack,component={seed},{};local group=seed.g
            while #stack>0 do
                local p=table.remove(stack)
                if not visited[p.id] then
                    visited[p.id]=true;component[#component+1]=p;group=math.min(group,p.g)
                    for _,q in ipairs(members[p.g] or {}) do if not visited[q.id] then stack[#stack+1]=q end end
                    Neighbours(at,p,function(q) if q.g>0 and Defs[q.type].mat==Defs[p.type].mat and not visited[q.id] then stack[#stack+1]=q end end)
                end
            end
            local change={op='group',ids={},from={},to={}}
            for _,p in ipairs(component) do if p.g~=group then change.ids[#change.ids+1]=p.id;change.from[#change.from+1]=p.g;change.to[#change.to+1]=group end end
            if #change.ids>0 then out[#out+1]=change end
        end
    end
    return out
end
function M.SplitRemoved(bp,ops)
    local out,seen={},{};local nextGroup=bp.nextGroup
    for _,op in ipairs(ops) do local g=op.op=='remove' and op.data.g
        if g and g>0 and not seen[g] then
            seen[g]=true;local members=bp:Group(g);local at=At(members,true,true);local visited={};local first=true
            for _,p in ipairs(members) do if not visited[p.id] then
                local comp={p};visited[p.id]=true;local i=1
                while i<=#comp do
                    Neighbours(at,comp[i],function(q) if not visited[q.id] then visited[q.id]=true;comp[#comp+1]=q end end,true);i=i+1
                end
                if first then first=false else
                    local change={op='group',ids={},from={},to={}}
                    for _,q in ipairs(comp) do change.ids[#change.ids+1]=q.id;change.from[#change.from+1]=g;change.to[#change.to+1]=nextGroup end
                    nextGroup=nextGroup+1;out[#out+1]=change
                end
            end end
        end
    end
    return out
end
return M

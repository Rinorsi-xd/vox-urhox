local Stash=require('salvage.StashRules')
local Buy=require('ui.SalvageBuy')
local M={}
function M.Attach(s)
    if s.app.lobby~='salvage' or s.salvageStock then return end;s.salvageStock=true
    local lobby=s.app.salvageLobby;local history=s.editor.history
    if history.salvageRestore then history.salvageRestore() end
    local commit,undo,redo=history.Commit,history.Undo,history.Redo
    local function Missing(ops)
        local usage=lobby:Usage()
        for _,op in ipairs(ops) do
            if (op.op=='add' or op.op=='remove') and op.data.type~='core' then
                local id='part:'..op.data.type;usage[id]=(usage[id] or 0)+(op.op=='add' and 1 or -1)
            end
        end
        local out={};for id,n in pairs(Stash.Shortfall(lobby.data.items,usage)) do out[id:sub(6)]=n end;return out
    end
    history.Commit=function(h,ops,derive)
        local short=Missing(ops)
        if next(short) then Buy.Parts(s,short,function() if not s.disposed then h:Commit(ops,derive);s:Refresh() end end);return false end
        return commit(h,ops,derive)
    end
    history.Undo=function(h)
        local ops=h.undoStack[#h.undoStack];if not ops then return false end
        local inverse={};for i=#ops,1,-1 do inverse[#inverse+1]=require('construction.EditHistory').Inverse(ops[i]) end
        local short=Missing(inverse)
        if next(short) then Buy.Parts(s,short,function() if not s.disposed then h:Undo();s:Refresh() end end);return false end
        return undo(h)
    end
    history.Redo=function(h)
        local ops=h.redoStack[#h.redoStack];if not ops then return false end
        local short=Missing(ops)
        if next(short) then Buy.Parts(s,short,function() if not s.disposed then h:Redo();s:Refresh() end end);return false end
        return redo(h)
    end
    local pick=s.PickHotbar
    s.PickHotbar=function(session,type)
        if type~='core' and lobby:Loose('part:'..type)<=0 then
            Buy.Parts(session,{[type]=1},function() if not session.disposed then pick(session,type);session:Refresh() end end,true);return false
        end
        return pick(session,type)
    end
    local assign=s.AssignHotbar
    s.AssignHotbar=function(session,slot,type)
        if type~='core' and lobby:Loose('part:'..type)<=0 then
            Buy.Parts(session,{[type]=1},function() if not session.disposed then assign(session,slot,type);session:Refresh() end end,true);return false
        end
        return assign(session,slot,type)
    end
    local function Restore() history.Commit=commit;history.Undo=undo;history.Redo=redo;history.salvageRestore=nil end
    history.salvageRestore=Restore
    local dispose=s.Dispose
    s.Dispose=function(session,...)
        if history.salvageRestore==Restore then Restore() end
        return dispose(session,...)
    end
end
return M

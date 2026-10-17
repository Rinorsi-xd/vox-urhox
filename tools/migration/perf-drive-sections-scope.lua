-- Probe-only wall clock scopes. Nested inclusive durations are not additive.
local M={active=false,rows={},stack={}}
local function Clock() return Time:GetSystemTime() end
function M.Enter(name)
 if not M.active then return end
 M.stack[#M.stack+1]={name=name,start=Clock(),children=0}
end
function M.Leave()
 if not M.active then return end
 local n=#M.stack;local token=assert(M.stack[n],'Unbalanced drive probe scope')
 local elapsed=(Clock()-token.start)&0xffffffff;M.stack[n]=nil
 local parent=M.stack[n-1];if parent then parent.children=parent.children+elapsed end
 local row=M.rows[token.name]
 if not row then row={calls=0,ms=0,selfMs=0,maxMs=0};M.rows[token.name]=row end
 row.calls=row.calls+1;row.ms=row.ms+elapsed;row.selfMs=row.selfMs+math.max(0,elapsed-token.children);row.maxMs=math.max(row.maxMs,elapsed)
end
function M.Switch(name)
 if not M.active then return end
 M.Leave();M.Enter(name)
end
function M.Wrap(object,key,name,insideOnly)
 local original=assert(object[key],name)
 object[key]=function(...)
  if not M.active or insideOnly and #M.stack==0 then return original(...) end
  M.Enter(name);local result=table.pack(original(...));M.Leave()
  return table.unpack(result,1,result.n)
 end
end
function M.AssertClosed() assert(#M.stack==0,'Leaked drive probe scopes') end
return M

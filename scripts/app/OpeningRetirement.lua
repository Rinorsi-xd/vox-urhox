-- Retire only objects captured by a completed opening. Active app scenes are
-- never traversed; stopping the app drains the same owned job synchronously.
local M={}
function M.New(work,done)
 local job={done=done,flushing=false,slices=0,workMs=0,maxMs=0}
 job.thread=coroutine.create(function()
  work(function()
   if not job.flushing and Time:GetSystemTime()-job.started>=3 then coroutine.yield() end
  end)
 end)
 return job
end
function M.Step(job,flush)
 if job.completed then return true end
 job.flushing=flush==true
 repeat
  job.started=Time:GetSystemTime()
  local ok,err=coroutine.resume(job.thread)
  local elapsed=Time:GetSystemTime()-job.started
  job.slices=job.slices+1;job.workMs=job.workMs+elapsed;job.maxMs=math.max(job.maxMs,elapsed)
  if not ok then error('Opening retirement failed: '..tostring(err)) end
 until not job.flushing or coroutine.status(job.thread)=='dead'
 if coroutine.status(job.thread)~='dead' then return false end
 job.completed=true;job.thread=nil
 print('[OpeningRetirement] done slices='..job.slices..' workMs='..job.workMs..' maxMs='..job.maxMs)
 local done=job.done;job.done=nil;if done then done() end
 return true
end
function M.Nodes(root,checkpoint)
 if not checkpoint then return end
 local children=root:GetChildren(false)
 for i=#children,1,-1 do
  M.Nodes(children[i],checkpoint)
  children[i]:Dispose();checkpoint()
 end
end
return M

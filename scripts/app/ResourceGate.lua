-- Download readiness only. Native cache owns deduplication, disk cache and I/O.
-- Each gate owns its group; cancelling it never cancels unrelated observers.
local M={};M.__index=M
local legacyPending={}
function M.UpdatePending(dt)
    for gate,job in pairs(legacyPending) do
        job.elapsed=job.elapsed+dt;job.interval=job.interval+dt
        if job.interval>=.1 then
            job.interval=0;local done,failed=0,0
            for _,path in ipairs(job.paths) do
                local state=gate.legacyManager:GetResourceTaskState(path)
                if state==DOWNLOAD_COMPLETED and gate.backend:Exists(path) then done=done+1
                elseif state==DOWNLOAD_FAILED or state==DOWNLOAD_CANCELLED then failed=failed+1 end
            end
            gate.completed=done
            if failed>0 or job.elapsed>90 then job.finish(false,math.max(1,failed))
            elseif done==#job.paths then job.finish(true,0) end
        end
    end
end
function M.New(backend)
    local self=setmetatable({},M);self:init(backend or cache);return self
end
function M:init(backend)
    self.backend=backend;self.generation=0;self.state='idle';self.group=nil
    self.completed=0;self.total=0;self.bytes=0;self.totalBytes=0;self.failure=''
end
function M:Cancel()
    self.generation=self.generation+1
    local group=self.group;self.group=nil;self.state='idle';self.callback=nil
    legacyPending[self]=nil
    if group then
        if self.legacyManager then self.legacyManager:CancelGroup(group)
        else self.backend:CancelDownloadGroup(group) end
    end
    self.legacyManager=nil
end
function M:Start(paths,callback)
    self:Cancel();local token=self.generation;self.callback=callback;self.state='loading'
    self.completed=0;self.total=0;self.bytes=0;self.totalBytes=0;self.failure=''
    local missing,seen={},{}
    for _,path in ipairs(paths) do if not seen[path] then
        seen[path]=true
        if not self.backend:Exists(path) then missing[#missing+1]=path end
    end end
    self.total=#missing
    local function Finish(ok,failed)
        if token~=self.generation or self.state~='loading' then return end
        self.group=nil;self.state=ok and 'ready' or 'failed'
        legacyPending[self]=nil
        self.failure=ok and '' or ('资源下载失败：'..tostring(failed or 1))
        if ok then self.completed=self.total end
        local done=self.callback;self.callback=nil;done(ok,self.failure)
    end
    if #missing==0 then Finish(true,0);return end
    if not self.backend.DownloadResources then
        -- The shipped older WASM binding exposes group download and task states,
        -- but no completion callback. Poll only pending groups across frames.
        self.legacyManager=GetDownloadManager()
        if not self.legacyManager then Finish(false,#missing);return end
        legacyPending[self]={paths=missing,finish=Finish,elapsed=0,interval=0}
        self.group=self.legacyManager:DownloadResources(missing)
        return
    end
    local group=self.backend:DownloadResources(missing,Finish,function(done,total,bytes,totalBytes)
        if token~=self.generation or self.state~='loading' then return end
        self.completed=done;self.total=total;self.bytes=bytes;self.totalBytes=totalBytes
    end)
    -- Local/cached implementations can complete synchronously before returning ID.
    if token==self.generation and self.state=='loading' then self.group=group end
end
return M

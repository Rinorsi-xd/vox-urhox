-- Download readiness only. Native cache owns deduplication, disk cache and I/O.
-- Each gate owns its group; cancelling it never cancels unrelated observers.
local M={};M.__index=M
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
    if group then self.backend:CancelDownloadGroup(group) end
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
        self.failure=ok and '' or ('资源下载失败：'..tostring(failed or 1))
        if ok then self.completed=self.total end
        local done=self.callback;self.callback=nil;done(ok,self.failure)
    end
    if #missing==0 then Finish(true,0);return end
    local group=self.backend:DownloadResources(missing,Finish,function(done,total,bytes,totalBytes)
        if token~=self.generation or self.state~='loading' then return end
        self.completed=done;self.total=total;self.bytes=bytes;self.totalBytes=totalBytes
    end)
    -- Local/cached implementations can complete synchronously before returning ID.
    if token==self.generation and self.state=='loading' then self.group=group end
end
return M

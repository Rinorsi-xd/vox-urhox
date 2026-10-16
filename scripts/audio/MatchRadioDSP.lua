-- Frozen Radio stems retain separate transient and fadeable source ownership.
local Data=require('core.ResourceData').Read('Combat/MatchRadioDSP.json')
local Levels=require 'audio.AudioLevels'
local Gate=require 'app.ResourceGate'
local M={};M.__index=M
---@class MatchRadioJob
---@field path string
---@field at number
---@field untilAt number
---@field fadeable boolean
---@field source SoundSource?
---@field fadeAt number?
---@field fadeSeconds number?
local function Release(job)
    if job.source then job.source:StopImmediate();job.source:Dispose();job.source=nil end
end
function M.Dependencies()
    local out,seen={},{}
    for _,line in pairs(Data.lines) do for _,stem in pairs(line.stems) do
        if not seen[stem.path] then seen[stem.path]=true;out[#out+1]=stem.path end
    end end
    return out
end
function M.New(root)
    local self=setmetatable({},M);self:init(root);return self
end
function M:init(root)
    self.root=root;self.time=0;self.jobs={};self.fading={};self.disposed=false
    self.gate=Gate.New();self.pending=nil;self.loading={};self.finished={};self.rejected={};self.touched={}
    self.cleanupNode=Node();local receiver=self.cleanupNode:CreateScriptObject('LuaScriptObject')
    receiver:SubscribeToEvent('ResourceBackgroundLoaded',function(_,second,third)
        local event=third or second;local path=event:GetString('ResourceName')
        if self.loading[path] then self.finished[path]=event:GetBool('Success') end
    end)
    receiver:SubscribeToEvent('Update',function() if self.disposed then self:Collect() end end)
end
function M:Collect()
    local used,pendingPaths={},{}
    for _,list in ipairs({self.jobs,self.fading}) do for _,job in ipairs(list) do used[job.path]=true end end
    if self.pending then for _,stem in pairs(Data.lines[self.pending.id].stems) do used[stem.path]=true;pendingPaths[stem.path]=true end end
    for path in pairs(self.loading) do
        local sound=cache:GetExistingResource('Sound',path)
        local rejected=self.rejected[path] and cache:GetNumBackgroundLoadResources()==0
        if sound and sound.length>0 or self.finished[path]==false or rejected then
            self.loading[path]=nil
            if (self.finished[path]==false or rejected) and not (sound and sound.length>0) and self.pending and pendingPaths[path] then self.pending.failed=true end
            self.finished[path]=nil;self.rejected[path]=nil
        end
    end
    for path in pairs(self.touched) do if not used[path] and not self.loading[path] then
        cache:ReleaseResource('Sound',path,false);self.touched[path]=nil
    end end
    if self.disposed and not next(self.loading) and self.cleanupNode then self.cleanupNode:Dispose();self.cleanupNode=nil end
end
function M:CancelPending()
    self.gate:Cancel();self.pending=nil;self:Collect()
end
function M:Prepare(id)
    if self.disposed or not Data.lines[id] then return false end
    if not self.pending or self.pending.id~=id then
        self:CancelPending();local pending={id=id,started=self.time};self.pending=pending
        local paths={};for _,stem in pairs(Data.lines[id].stems) do paths[#paths+1]=stem.path end
        self.gate:Start(paths,function(ok)
            if self.pending==pending and not self.disposed then pending.downloaded=ok;pending.failed=not ok end
        end)
    end
    local pending=self.pending
    if pending.failed or self.time-pending.started>20 then return false,true end
    if not pending.downloaded then return false end
    local ready=true;local queued=false
    for _,lane in ipairs({'lead','voice','hiss','tail'}) do
        local path=Data.lines[id].stems[lane].path
        local sound=cache:GetExistingResource('Sound',path)
        if not sound or sound.length<=0 then
            ready=false
            if not self.loading[path] and not queued then
                queued=true;self.loading[path]=true;self.touched[path]=true
                -- False also means another observer already queued this resource.
                if not cache:BackgroundLoadResource('Sound',path,true) then self.rejected[path]=true end
            end
        end
    end
    return ready
end
function M:Stop()
    for _,job in ipairs(self.jobs) do Release(job) end;self.jobs={}
end
function M:Halt()
    self:Stop();for _,job in ipairs(self.fading) do Release(job) end;self.fading={};self:CancelPending()
end
function M:Play(id,now)
    if not self:Prepare(id) then return 0,0 end
    self:Stop();self.time=now
    local line=Data.lines[id];if self.disposed or not line then return 0,0 end
    for _,lane in ipairs({'lead','hiss','voice','tail'}) do
        local stem=line.stems[lane]
        self.jobs[#self.jobs+1]={path=stem.path,at=now+stem.at,untilAt=now+stem.at+stem.seconds,fadeable=lane=='voice' or lane=='hiss'}
    end
    self.pending=nil;self.gate:Cancel();return line.total,line.speaking
end
function M:Fade(seconds)
    local duration=math.max(0,seconds or .35)
    for _,job in ipairs(self.jobs) do
        if job.fadeable and duration>0 and job.at<self.time+duration then
            job.fadeAt=self.time;job.fadeSeconds=duration;self.fading[#self.fading+1]=job
        else Release(job) end
    end
    self.jobs={}
end
---@param list MatchRadioJob[]
function M:Tick(list)
    for i=#list,1,-1 do
        local job=list[i]
        local envelope=job.fadeAt and math.max(0,1-(self.time-job.fadeAt)/job.fadeSeconds) or 1
        if self.time>=job.untilAt or envelope<=0 then Release(job);table.remove(list,i)
        elseif self.time>=job.at then
            if not job.source then
                local sound=cache:GetExistingResource('Sound',job.path)
                if sound and sound.length>0 then
                    job.source=self.root:CreateComponent('SoundSource');job.source:SetSoundType('VoxMatchVoice')
                    Levels.Play(job.source,sound,0,Data.runtimeGain*envelope)
                    -- Frame scheduling can be late; keep the authored audio clock.
                    if self.time>job.at then job.source:Seek(self.time-job.at) end
                else print('[MatchRadioDSP] Missing stem '..job.path);job.untilAt=0 end
            elseif job.fadeAt then Levels.SetGain(job.source,Data.runtimeGain*envelope) end
        end
    end
end
function M:Update(now)
    if self.disposed then return end;self.time=now;self:Tick(self.jobs);self:Tick(self.fading);self:Collect()
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self:Halt()
    -- The independent receiver retires cancelled native decodes after this battle dies.
end
return M

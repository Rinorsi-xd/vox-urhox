-- Dedicated QA only. Loading this factory does not query or change the collector.
local M={}
function M.New(env,options)
    options=options or {}
    local gc=assert(env.gc)
    local self={phase='off',active=false,rows={},transitions={},explicitCalls={},reason=false,
        restored=false,originalRunning=false,originalMode=false,framesB=0,changes=0}
    local durations={settle=1000,A1=2000,B=math.min(options.bMs or 1200,1200),recovery=2000,A2=2000}
    local maxFrames=math.min(options.bFrames or 48,48)
    local maxKB=math.min(options.maxKB or 131072,131072)
    local growthKB=math.min(options.growthKB or 16384,16384)
    local originalGlobal=false
    local wrapper=false
    local restoring=false
    local inExternal=false
    local start=0
    local phaseStart=0
    local baselineKB=0
    local signature=false
    local pending=false
    local function Elapsed(a,b) return (a-b)&0xffffffff end
    local function Transition(phase)
        self.phase=phase;phaseStart=env.clock();self.changes=self.changes+1
        self.transitions[#self.transitions+1]={phase=phase,wall=phaseStart,frame=env.frame(),luaKB=gc('count'),running=gc('isrunning')}
    end
    function self:Restore()
        if restoring then return false end
        restoring=true
        local ok,err=pcall(function()
            if self.originalMode then gc(self.originalMode) end
            if self.originalRunning then gc('restart') else gc('stop') end
            assert(gc('isrunning')==self.originalRunning,'Collector running state did not restore')
        end)
        restoring=false;self.restored=ok;self.restoreError=not ok and tostring(err) or false
        if wrapper and env.getGlobal()==wrapper then env.setGlobal(originalGlobal) end
        return ok
    end
    function self:Abort(reason)
        if not self.active then return end
        self.abortEvidence={phase=self.phase,frame=env.frame(),wall=env.clock(),luaKB=gc('count'),baselineKB=baselineKB}
        self.reason=tostring(reason);self.active=false
        self:Restore();Transition('invalid')
    end
    local function Check()
        local reason,value=env.gate()
        if reason then return reason end
        if signature and value~=signature then return 'vehicle/unit/part load changed' end
        if env.getGlobal()~=wrapper then return 'collectgarbage ownership changed' end
        local count=gc('count')
        if count>maxKB then return 'Lua absolute memory budget' end
        if self.phase=='B' and count-baselineKB>growthKB then return 'Lua no-auto-GC memory growth budget' end
        if Elapsed(env.clock(),start)>12000 then return 'experiment total deadline' end
        if gc('isrunning')~=(self.phase~='B') then return 'unexpected collector running state' end
    end
    function self:Arm()
        if self.phase~='off' then return false,'single-use probe' end
        local reason,value=env.gate()
        if reason then return false,reason end
        if not gc('isrunning') then return false,'initial automatic GC is stopped' end
        if gc('count')>maxKB then return false,'initial Lua memory exceeds budget' end
        self.originalRunning=true;originalGlobal=env.getGlobal()
        -- Lua has no read-only collector-mode query. Exclude discovery/finalizers
        -- and the following settle phase from all A/B windows.
        local ok,mode=pcall(gc,'incremental')
        if not ok then return false,tostring(mode) end
        self.originalMode=mode
        local restored,err=pcall(gc,mode)
        if not restored then self:Restore();return false,tostring(err) end
        wrapper=function(op,...)
            if op=='count' or op=='isrunning' then return gc(op,...) end
            if not self.active or inExternal then return gc(op,...) end
            inExternal=true
            self.explicitCalls[#self.explicitCalls+1]={op=tostring(op),frame=env.frame(),phase=self.phase}
            local result=table.pack(pcall(gc,op,...))
            inExternal=false
            self:Abort('explicit collectgarbage('..tostring(op)..') contamination')
            if not result[1] then error(result[2],0) end
            return table.unpack(result,2,result.n)
        end
        signature=value;start=env.clock();self.active=true;env.setGlobal(wrapper);Transition('settle')
        return true
    end
    local function LeaveB()
        gc('restart')
        Transition('recovery')
    end
    function self:BeginFrame()
        if not self.active then return end
        local reason=Check()
        if reason then self:Abort(reason);return end
        if self.phase=='B' and Elapsed(env.clock(),phaseStart)>=durations.B then LeaveB() end
        pending={frame=env.frame(),phase=self.phase,start=env.clock(),luaKB=gc('count'),running=gc('isrunning')}
    end
    function self:EndFrame()
        if not self.active then return end
        local reason=Check()
        if reason then self:Abort(reason);return end
        if not pending then self:Abort('missing begin-frame boundary');return end
        if pending.frame~=env.frame() then self:Abort('engine frame changed inside callbacks');return end
        local now=env.clock();pending.wallMs=Elapsed(now,pending.start);pending.endLuaKB=gc('count')
        self.rows[#self.rows+1]=pending;pending=false
        if #self.rows>512 then self:Abort('bounded row capacity');return end
        local elapsed=Elapsed(now,phaseStart)
        if self.phase=='B' then
            self.framesB=self.framesB+1
            if elapsed>durations.B+250 then self:Abort('B deadline overshot inside uninterruptible frame');return end
            if elapsed>=durations.B or self.framesB>=maxFrames then LeaveB() end
        elseif elapsed>=durations[self.phase] then
            if self.phase=='settle' then Transition('A1')
            elseif self.phase=='A1' then
                baselineKB=gc('count');gc('stop');Transition('B')
            elseif self.phase=='recovery' then Transition('A2')
            elseif self.phase=='A2' then
                self.active=false;self:Restore();Transition(self.restored and 'done' or 'invalid')
            end
        end
    end
    function self:Snapshot()
        return {phase=self.phase,active=self.active,reason=self.reason,restored=self.restored,
            restoreError=self.restoreError,originalRunning=self.originalRunning,originalMode=self.originalMode,
            rows=#self.rows,framesB=self.framesB,explicitCalls=#self.explicitCalls,changes=self.changes}
    end
    function self:Safe(method,...)
        local result=table.pack(pcall(self[method],self,...))
        if not result[1] then
            self:Abort(method..' exception: '..tostring(result[2]))
            return false,tostring(result[2])
        end
        return table.unpack(result,2,result.n)
    end
    function self:Report()
        return {state=self:Snapshot(),durations=durations,maxBFrames=maxFrames,maxLuaKB=maxKB,growthKB=growthKB,
            transitions=self.transitions,frames=self.rows,explicitCalls=self.explicitCalls,abortEvidence=self.abortEvidence,
            boundary='QA diagnostic only; mode discovery, settle and recovery are excluded. Frame wall includes observer overhead. Lua memory is not allocator/GPU memory. Frame-boundary guards cannot interrupt a blocked frame. No gain or target-device FPS follows.'}
    end
    return self
end
return M

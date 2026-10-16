-- Actual native Node/ScriptObject global events. Boss simulation is never updated.
-- Lifecycle references: lua-scripting-guide.md Script component template;
-- .emmylua/LuaScriptObject.manual.d.lua; Node.d.lua CreateScriptObject/Dispose.
local timers,owners={},{}
local started=0
local previousFps=0
local earlyChecked=false
local completed=false
local function Cleanup()
    for _,timer in ipairs(timers)do timer:Dispose()end
    if previousFps>0 then engine.maxFps=previousFps end
end
local function Owner()
    local owner={rules={hp=100},mission={},time=10,calls={}}
    function owner:Say(key,urgent)
        self.calls[#self.calls+1]={key=key,urgent=urgent,at=Time:GetSystemTime()}
    end
    return owner
end
V.atFrame(2,function()
    local ok,err=xpcall(function()
        print('[BossExposedNative] started')
        previousFps=engine.maxFps;engine.maxFps=60
        local Delay=require 'combat.BossExposedDelay'
        started=Time:GetSystemTime()
        for i=1,5 do
            owners[i]=Owner();timers[i]=Delay.New(owners[i])
            local timer=timers[i];local update=timer.Update
            timer.afterDisposeCalls=0
            timer.Update=function(self)
                if self.disposed then self.afterDisposeCalls=self.afterDisposeCalls+1 end
                return update(self)
            end
        end
        owners[2].mission.finished=true
        owners[3].rules.hp=0
        owners[4].mission.reason='leave'
        V.assert(timers[1].at>=started+2600 and timers[1].at<=Time:GetSystemTime()+2600,'actual native wall-clock deadline is 2600ms')
        local receiver=timers[1].node:GetScriptObject()
        V.assert(receiver~=nil and receiver:HasSubscribedToEvent('Update'),'actual native ScriptObject subscribes globally')
        V.assert(timers[1].node~=timers[2].node and timers[2].node~=timers[3].node,'each native timer owns its node')
        timers[5]:Dispose();owners[5].mission=nil
        V.assert(timers[5].disposed and timers[5].node==nil and timers[5].boss==nil,'explicit cancellation immediately clears native and owner references')
    end,debug.traceback)
    if not ok then V.assert(false,tostring(err));Cleanup();completed=true;V.finish()end
end)
local function Poll()
    if completed or started==0 then return end
    local ok,err=xpcall(function()
        local elapsed=Time:GetSystemTime()-started
        if not earlyChecked and elapsed>=2100 then
            V.assert(elapsed<2600 and #owners[1].calls==0 and #owners[2].calls==0,'actual Update listener remains silent before deadline')
            earlyChecked=true
        end
        if elapsed<3000 then return end
        V.assert(#owners[1].calls==1,'actual global Update speaks once without any Boss simulation update')
        V.assert(#owners[2].calls==1,'finished alone does not cancel actual listener')
        V.assert(#owners[3].calls==0,'dead Boss suppresses actual callback')
        V.assert(#owners[4].calls==0,'leaving mission suppresses actual callback')
        V.assert(#owners[5].calls==0,'disposed native timer never calls removed mission')
        local call=owners[1].calls[1]
        V.assert(call~=nil and call.key=='exposed' and call.urgent==true and call.at>=timers[1].at and call.at-started<3000,'native callback carries exact dialogue urgency after deadline')
        V.assert(owners[1].time==10 and owners[2].time==10,'wall time advances while both Boss simulation clocks remain unchanged')
        local released=true
        for _,timer in ipairs(timers)do released=released and timer.disposed and timer.node==nil and timer.boss==nil end
        V.assert(released,'all completed or cancelled native listeners release nodes and references')
        Cleanup();Cleanup()
        local noStaleCallbacks=true
        for _,timer in ipairs(timers)do noStaleCallbacks=noStaleCallbacks and timer.afterDisposeCalls==0 end
        V.assert(noStaleCallbacks and #owners[1].calls==1 and #owners[2].calls==1,'native disposal removes subscriptions and repeated disposal stays harmless')
        completed=true
        print('[BossExposedNative] completed 14 checks; elapsedMs='..elapsed..'; real Node/ScriptObject; no full mission or Web focus acceptance')
        V.finish()
    end,debug.traceback)
    if not ok then V.assert(false,tostring(err));Cleanup();completed=true;V.finish()end
end
for frame=3,640 do V.atFrame(frame,Poll)end
V.atFrame(645,function()
    if not completed then V.assert(false,'native Boss timer did not complete within the bounded fixture');Cleanup();V.finish()end
end)

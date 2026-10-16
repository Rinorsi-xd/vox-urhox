-- Actual native Update listener; Rules.Step is deliberately never called.
local timers,owners={},{}
local started,previousFps=0,0
local earlyChecked,choiceChecked,retryChecked,completed=false,false,false,false
local disposeAt=0
local function Cleanup()
    for _,timer in ipairs(timers)do timer:Dispose()end
    if previousFps>0 then engine.maxFps=previousFps end
end
local function Count(owner,kind)
    local count=0;for _,event in ipairs(owner.log)do if event.type==kind then count=count+1 end end;return count
end
local function Owner(kind)
    local step={kind=kind or 'hold',duration=20,pos={0,2,0},retryLines={{text='retry'}},path={{0,0,2},{100,0,2}},beats={}}
    local convoy=kind=='escort' and require('story.ConvoyRules').New(step,{nodes={}},function()return 2 end) or nil
    if convoy then convoy.cpD=20;convoy.cpHp=.75;convoy.d=60;convoy.hp=.1 end
    local rules=require('story.MissionRules').New({steps={step}},convoy,function()return Time:GetSystemTime()/1000 end)
    rules.begun=true;rules:Go(1);rules:Drain();rules.time=10
    local owner={rules=rules,log={}}
    function owner:Events()
        for _,event in ipairs(self.rules:Drain())do event.at=Time:GetSystemTime();self.log[#self.log+1]=event end
    end
    return owner
end
local function Choice(id)
    return {id=id,timeout=.9,default=1,options={{reply={{text='one'}}},{reply={{text='two'}}}}}
end
V.atFrame(2,function()
    local ok,err=xpcall(function()
        print('[MissionTimersNative] started')
        previousFps=engine.maxFps;engine.maxFps=60;started=Time:GetSystemTime()
        local Timers=require 'story.MissionTimers'
        for i=1,8 do
            owners[i]=Owner(i==2 and 'escort' or 'hold');timers[i]=Timers.New(owners[i])
            local timer=timers[i];local update=timer.Update;timer.afterDisposeCalls=0
            timer.Update=function(self)
                if self.disposed then self.afterDisposeCalls=self.afterDisposeCalls+1 end
                return update(self)
            end
        end
        for _,i in ipairs({1,2,5,6,7})do owners[i].rules:Fail('failure',{{text='fail'}});owners[i].retryAt=owners[i].rules.failAt*1000+3000;owners[i]:Events()end
        owners[1].rules:Fail('duplicate',{})
        owners[3].rules:Ask(Choice('choice'));owners[3]:Events()
        owners[4].rules:StepSpec().beats={{t=0,ask=Choice('beat')}}
        owners[4].rules:Beats(0,{talking=false,enemies=0});owners[4]:Events()
        owners[8].rules:Ask(Choice('manual'));owners[8].rules:Choose(1);owners[8]:Events()
        owners[6].reason='leave';owners[7].disposed=true
        local receiver=timers[1].node:GetScriptObject()
        V.assert(receiver~=nil and receiver:HasSubscribedToEvent('Update'),'native ScriptObject owns actual global Update subscription')
        V.assert(timers[1].node~=timers[2].node,'missions own separate native listener nodes')
        V.assert(owners[1].rules.failAt*1000>=started and owners[1].rules.failAt*1000<=Time:GetSystemTime(),'failure records actual native wall time')
        timers[5]:Dispose();timers[5]:Dispose()
        V.assert(timers[5].node==nil and timers[5].mission==nil and timers[5].disposed,'explicit Dispose immediately releases Node and owner')
    end,debug.traceback)
    if not ok then V.assert(false,tostring(err));Cleanup();completed=true;V.finish()end
end)
local function Poll()
    if completed or started==0 then return end
    local ok,err=xpcall(function()
        local now=Time:GetSystemTime();local elapsed=now-started
        if not earlyChecked and elapsed>=100 then
            V.assert(elapsed<300 and owners[4].rules.choice==nil and Count(owners[1],'clearEnemies')==0,'no 300ms beat or 3s retry fires early')
            earlyChecked=true
        end
        if not choiceChecked and elapsed>=500 then
            V.assert(elapsed<900 and owners[4].rules.choice~=nil and owners[3].rules.choice~=nil,'native Update opens delayed beat while both choices remain pending')
            V.assert(Count(owners[1],'clearEnemies')==0 and Count(owners[2],'clearEnemies')==0,'native retry remains pending before 3 seconds')
            choiceChecked=true
        end
        if not retryChecked and elapsed>=3200 then
            V.assert(owners[3].rules.choice==nil and owners[3].rules.flags.choice==1,'choice default expires on real wall clock without simulation')
            V.assert(owners[4].rules.choice==nil and owners[4].rules.flags.beat==1 and Count(owners[4],'choice')==1,'delayed beat opens once then times out on native listener')
            V.assert(owners[8].rules.flags.manual==0 and Count(owners[8],'say')==1,'manual choice is never repeated by expired native timer')
            V.assert(Count(owners[1],'clearEnemies')==1 and Count(owners[1],'place')==1 and Count(owners[1],'objective')==1,'actual hold retry dispatches clear place and objective once')
            V.assert(Count(owners[2],'clearEnemies')==1 and Count(owners[2],'place')==1 and owners[2].rules.convoy.d==20 and owners[2].rules.convoy.hp==.75,'actual escort retry restores checkpoint through native event dispatch')
            local deadlineCorrect=true
            for _,i in ipairs({1,2})do for _,event in ipairs(owners[i].log)do if event.type=='clearEnemies' then deadlineCorrect=deadlineCorrect and event.at>=owners[i].retryAt and event.at<=now end end end
            V.assert(deadlineCorrect,'both retry callbacks occur after actual 3000ms deadline')
            V.assert(owners[1].rules.stats.fails==1,'duplicate failure does not install another retry')
            V.assert(Count(owners[5],'clearEnemies')==0 and Count(owners[6],'clearEnemies')==0 and Count(owners[7],'clearEnemies')==0,'disposed timer leaving and disposed mission suppress callbacks')
            local frozen=true;for _,owner in ipairs(owners)do frozen=frozen and owner.rules.time==10 end
            V.assert(frozen,'all simulation clocks stay frozen while real wall-clock callbacks execute')
            for _,timer in ipairs(timers)do timer:Dispose();timer:Dispose()end
            disposeAt=now;retryChecked=true
        end
        if disposeAt==0 or now-disposeAt<400 then return end
        local released,noCallbacks=true,true
        for _,timer in ipairs(timers)do released=released and timer.disposed and timer.node==nil and timer.mission==nil;noCallbacks=noCallbacks and timer.afterDisposeCalls==0 end
        V.assert(released,'all native listeners and mission references release after repeated Dispose')
        V.assert(noCallbacks,'real later Update events do not call disposed ScriptObjects')
        V.assert(Count(owners[1],'clearEnemies')==1 and Count(owners[2],'clearEnemies')==1 and Count(owners[4],'choice')==1,'no duplicate retries or choices after disposal and later real frames')
        V.assert(earlyChecked and choiceChecked and retryChecked,'all real-time observation stages actually executed')
        Cleanup();completed=true
        print('[MissionTimersNative] completed 20 checks; elapsedMs='..elapsed..'; no Rules.Step, full mission or Web focus acceptance')
        V.finish()
    end,debug.traceback)
    if not ok then V.assert(false,tostring(err));Cleanup();completed=true;V.finish()end
end
for frame=3,640 do V.atFrame(frame,Poll)end
V.atFrame(645,function()if not completed then V.assert(false,'native mission timers exceeded bounded fixture');Cleanup();V.finish()end end)

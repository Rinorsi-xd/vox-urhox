"""Execute real monitor with a deterministic wall clock; no engine timing claims."""
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
source = (root / 'scripts/diagnostics/PerformanceMonitor.lua').read_text('utf8')
lua.globals().Monitor = lua.execute(source)
result = lua.execute(r'''
local clock=0
local records={}
local m=Monitor.New{clock=function() return clock end,session='deterministic',noFile=true,
    sink=function(r) records[#records+1]=r end}
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local original
local object={}
function object:Child(x) clock=clock+30;return nil,x,nil,42 end
function object:Parent(x) clock=clock+10;local a,b,c,d=self:Child(x);clock=clock+50;return a,b,c,d end
original=object.Parent
m:Wrap(object,'Child','child');m:Wrap(object,'Parent','parent')
local wrapped=object.Parent;m:Wrap(object,'Parent','parent');check(wrapped==object.Parent,'idempotent')
m:BeginFrame(.016)
local a,b,c,d=object:Parent('payload')
check(a==nil and b=='payload' and c==nil and d==42,'nil returns and self/args preserved')
m:EndFrame{trialId='one',stepsTotal=2,luaKiB=100,units=8}
clock=100;m:BeginFrame(.1)
local slow=records[2]
check(slow.type=='slow_frame' and slow.frame==1,'aligned completed frame')
check(slow.frameMs==100 and slow.wallMs==90 and slow.scriptMs==90,'frame interval and script duration')
check(slow.stages[1].name=='parent' and slow.stages[1].ms==90 and slow.stages[1].selfMs==60,'nested inclusive/self')
check(slow.stages[2].name=='child' and slow.stages[2].ms==30,'child counted once')
check(slow.context.units==8 and slow.context.trialId=='one','old frame context retained')
check(slow.outsideEndFrameMs==10 and slow.unattributedMs==0,'unattributed not GPU')
clock=105;m:EndFrame{trialId='one',stepsTotal=5,luaKiB=110}
clock=116;m:BeginFrame(.016)
check(m:Snapshot().steps==3,'fixed catch-up steps')
local async={Run=function() coroutine.yield();return 'ok' end};m:Wrap(async,'Run','async')
local co=coroutine.create(async.Run);check(coroutine.resume(co),'yield succeeds')
clock=120;m:EndFrame{trialId='one',stepsTotal=5}
clock=140;m:BeginFrame(.02)
local ok,value=coroutine.resume(co)
check(ok and value=='ok' and m.discardedAsyncSpans==1,'cross-frame duration excluded')
check(m.scriptMs==0,'async wait not charged')
clock=150;m:EndFrame{trialId='two',stepsTotal=700}
clock=1160;m:BeginFrame(1.01)
local sample=records[#records]
check(sample.type=='sample' and #sample.frameSamples==4,'all frames retained in sample')
check(sample.frameStats.maxMs==1020,'complete interval captures stalls outside EndFrame')
check(m:Snapshot().steps==0,'new trial counter not attributed as catch-up')
m:Marker('repro',{map='crater'})
check(records[#records].type=='marker','user mark')
m:EndFrame{trialId='two',stepsTotal=701};m:Dispose()
check(object.Parent==original and object.Child~=nil,'original methods restored')
check(records[#records].type=='session_end','session end')
local disabled=Monitor.New{enabled=false,clock=function() return clock end,noFile=true,sink=function() error('disabled emitted') end}
disabled:BeginFrame(1);disabled:Wrap(object,'Parent','disabled');disabled:EndFrame{};
check(object.Parent==original,'disabled no wrappers')
local n=4294967290
local wrap=Monitor.New{clock=function() return n end,session='wrap',noFile=true,sink=function() end}
wrap:BeginFrame(0);n=5;wrap:EndFrame{};n=10;wrap:BeginFrame(.016)
check(wrap:Snapshot().frameMs==16,'uint32 wrap')
local ticks=0
local nested=Monitor.New{clock=function() return ticks end,session='nested',noFile=true,sink=function() end}
local jobs={Child=function() ticks=ticks+12 end}
function jobs.Middle() ticks=ticks+3;assert(coroutine.resume(coroutine.create(jobs.Child)));ticks=ticks+5 end
function jobs.Root() ticks=ticks+2;assert(coroutine.resume(coroutine.create(jobs.Middle)));ticks=ticks+7 end
nested:Wrap(jobs,'Root','root');nested:Wrap(jobs,'Middle','middle');nested:Wrap(jobs,'Child','leaf')
nested:BeginFrame(.016);jobs.Root()
check(nested.scriptMs==29,'nested coroutine CPU union counted once')
check(nested.stages.root.selfMs==9 and nested.stages.middle.selfMs==8 and nested.stages.leaf.selfMs==12,'coroutine children deducted once')
local weak=setmetatable({},{__mode='v'})
do
    local retired={};local captured=retired
    retired.Update=function() return captured end
    weak[1]=retired;nested:Wrap(retired,'Update','retired')
end
collectgarbage('collect');collectgarbage('collect')
check(weak[1]==nil,'wrapped HUD closure does not retain retired session')
local throws={Bad=function() ticks=ticks+4;error('expected-marker') end}
function throws.Catches() ticks=ticks+1;local ok=pcall(throws.Bad);assert(not ok);ticks=ticks+2 end
nested:Wrap(throws,'Bad','bad');nested:Wrap(throws,'Catches','catches')
local prior=nested.scriptMs;throws.Catches()
check(nested.scriptMs-prior==7,'caught exception closes timing stack')
check(#nested.errors==1 and nested.errors[1]:find('expected-marker',1,true),'caught error attached to frame')
local frameClock=0
local frameRecords={}
local perFrame=Monitor.New{clock=function() return frameClock end,session='per-frame',noFile=true,
    sink=function(record) frameRecords[#frameRecords+1]=record end}
local function span(name,ms)
    local token=perFrame:Begin(name);frameClock=frameClock+ms;perFrame:End(token)
end
perFrame:BeginFrame(.016)
span('zero',0);span('zero',0);span('work',3)
perFrame:EndFrame{trialId='frames',stepsTotal=1}
frameClock=10;perFrame:BeginFrame(.016)
span('work',7);span('new-zero',0)
perFrame:EndFrame{trialId='frames',stepsTotal=2}
frameClock=1005;perFrame:BeginFrame(.016)
local perSample=frameRecords[#frameRecords]
check(perSample.type=='sample' and #perSample.frameSamples==2,'normal frames emitted with per-frame sections')
local names=perSample.stageNames
check(#names==3 and names[1]=='zero' and names[2]=='work' and names[3]=='new-zero','stable one-based stage dictionary')
local first=perSample.frameSamples[1].stageTimes
local second=perSample.frameSamples[2].stageTimes
check(#first==10 and #second==10,'each called stage occupies exactly five flat numbers')
check(first[1]==1 and first[2]==0 and first[3]==0 and first[4]==2 and first[5]==0,'zero-duration calls retained with exact count')
check(first[6]==2 and first[7]==3 and first[8]==3 and first[9]==1 and first[10]==3,'first frame duration tuple exact')
check(second[1]==2 and second[2]==7 and second[3]==7 and second[4]==1 and second[5]==7,'second frame counters reset instead of accumulating')
check(second[6]==3 and second[7]==0 and second[9]==1,'new called stage added without reusing absent stage id')
for _,value in ipairs(first) do check(type(value)=='number','flat per-frame values are numeric') end
span('new-zero',0);perFrame:EndFrame{trialId='frames',stepsTotal=3};perFrame:Dispose()
local tail=frameRecords[#frameRecords-1]
check(tail.type=='sample_tail' and #tail.frameSamples==1,'dispose flushes unsampled frame')
check(tail.stageNames[3]=='new-zero' and tail.frameSamples[1].stageTimes[1]==3,'tail dictionary decodes final frame')
check(perSample.stageNames~=tail.stageNames and perSample.stageNames[1]=='zero','emitted dictionary snapshot is independent')
local boundClock=0
local bounded=Monitor.New{clock=function()return boundClock end,session='bounded',noFile=true,sink=function()end}
for i=1,1027 do
    bounded:BeginFrame(0)
    local token=bounded:Begin('called');bounded:End(token)
    bounded:EndFrame{}
end
check(#bounded.window==1024 and bounded.sampleDrops==2,'per-frame stage storage preserves 1024-frame window bound')
local reuseClock=0
local reused=Monitor.New{clock=function()return reuseClock end,session='reuse',noFile=true,sink=function()end}
reused:BeginFrame(.016)
local firstToken=reused:Begin('first');reuseClock=2;reused:End(firstToken)
reused:EndFrame{};reuseClock=16;reused:BeginFrame(.016)
local nextToken=reused:Begin('next')
check(firstToken==nextToken,'closed scope token reused across frames')
check(nextToken.frame==2 and nextToken.name=='next' and nextToken.children==0,'reused timing fields reset')
reuseClock=19;reused:End(nextToken)
check(reused.stages.next.ms==3 and reused.scriptMs==3,'reused token keeps exact frame duration')
local yielding={Child=function()reuseClock=reuseClock+1 end}
function yielding.Run()coroutine.yield();yielding.Child();coroutine.yield();return 'closed' end
reused:Wrap(yielding,'Run','yielding');reused:Wrap(yielding,'Child','yield-child')
local paused=coroutine.create(yielding.Run);assert(coroutine.resume(paused))
local oldToken=reused.stacks[paused].tokens[1]
reused:EndFrame{};reuseClock=32;reused:BeginFrame(.016)
local rootToken=reused:Begin('root')
check(oldToken.active and oldToken.frame==2,'suspended scope token remains owned by original frame')
local resumed=coroutine.resume(paused)
check(resumed and oldToken.frame==2 and oldToken.active,'active yielded token is not overwritten by resumed child')
check(reused.stacks[paused].tokens[1]~=oldToken,'new frame child uses an independent scope token')
local closed,resumeResult=coroutine.resume(paused)
check(closed and resumeResult=='closed' and not oldToken.active,'cross-frame yielded scope still closes safely')
reuseClock=34;reused:End(rootToken)
check(reused.scriptMs==2 and reused.discardedAsyncSpans==1,'reused slots do not charge suspended wait')
return checks
''')
files = list((root / 'scripts').rglob('*.lua'))
loader = lua.eval('function(source, name) local f,e=load(source,name); assert(f,e); return true end')
for file in files:
    loader(file.read_text('utf-8-sig'), '@' + file.relative_to(root).as_posix())
print(json.dumps({'result': 'PASS', 'behaviorChecks': result, 'luaSyntax': len(files)}))

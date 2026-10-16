-- Controlled monitor verification only; the 90ms sleep is not a game benchmark.
local Monitor=require 'diagnostics.PerformanceMonitor'
local monitor
local frames=0
local work={Run=function() if frames==3 then Time:Sleep(90) end end}
function Start()
    monitor=Monitor.New({session='native-fixture-'..tostring(Time:GetSystemTime())})
    monitor:Wrap(work,'Run','fixture.controlled-sleep')
    SubscribeToEvent('Update','UpdateProbe')
    SubscribeToEvent('EndFrame','EndProbe')
end
function UpdateProbe(_,data)
    frames=frames+1;monitor:BeginFrame(data:GetFloat('TimeStep'));work.Run()
end
function EndProbe()
    monitor:EndFrame({trialId='fixture',mode='fixture',units=6,stepsTotal=frames,luaKiB=collectgarbage('count')})
    if frames<8 then return end
    monitor:Marker('fixture-end',{fixture=true});monitor:Dispose()
    assert(monitor.fileError=='',monitor.fileError)
    local file=File(monitor.logPath..'-1.jsonl',FILE_READ)
    assert(file:IsOpen(),'Native performance file not open')
    local records,slow,ended=0,false,false
    while not file.eof do
        local line=file:ReadLine()
        if line~='' then
            local record=cjson.decode(line);records=records+1
            if record.type=='slow_frame' then
                for _,stage in ipairs(record.stages) do
                    if stage.name=='fixture.controlled-sleep' and stage.ms>=80 then slow=true end
                end
            end
            if record.type=='session_end' then ended=true end
        end
    end
    file:Dispose()
    assert(slow and ended and records>=4,'Native diagnostic records incomplete')
    print('PERF_NATIVE_CHECK '..cjson.encode({result='PASS',fixture=true,records=records,path=monitor.logPath..'-1.jsonl'}))
    engine:Exit()
end

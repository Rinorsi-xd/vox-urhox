local source=assert(io.open('tools/migration/monitor-disabled-observer.lua')):read('*a')
local checks=0
local function check(value,label)assert(value,label);checks=checks+1 end
for _,fail in ipairs({false,true}) do
    local originalArguments={'-log=info','-vox-debug=1'}
    local args=function()return originalArguments end
    local calls=0
    GetArguments=args
    Start=function()
        calls=calls+1
        local received=GetArguments()
        check(received~=originalArguments,'original argument owner unchanged')
        check(#received==3 and received[1]=='-log=info' and received[2]=='-vox-debug=1','original arguments retained')
        check(received[3]=='-vox-perf=0','production disable argument delivered')
        if fail then error('expected startup failure') end
    end
    assert(load(source))()
    local ok,message=pcall(Start)
    check(ok~=fail,'startup result preserved')
    check(not fail or tostring(message):find('expected startup failure',1,true),'startup error preserved')
    check(GetArguments==args and #originalArguments==2,'argument binding and contents restored')
    check(calls==1,'production Start called once')
end
print('Monitor-disabled QA startup: '..checks..' checks PASS')

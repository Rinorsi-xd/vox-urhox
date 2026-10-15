-- Injected native event bridge only; this is not an OS/browser input test.
local Pointer=require 'controls.DrivePointer'
local goldenPath,reportPath
for _,arg in ipairs(GetArguments())do
    goldenPath=arg:match('^%-mouse%-golden=(.+)$') or goldenPath
    reportPath=arg:match('^%-mouse%-native%-output=(.+)$') or reportPath
end
assert(goldenPath and reportPath,'mouse golden and native output paths required')
local file=assert(io.open(goldenPath,'rb'));local golden=cjson.decode(file:read('*a'));file:close()
local report={schema=1,complete=false,checks=0,frames=0,scenarios=0,events=0,
    baseline=golden.baseline,reference=golden.source,graphicsApi=graphics.apiName,
    boundary='Injected actual native Node/LuaScriptObject MouseMove events and VariantMap GetInt through production DrivePointer/Poll. Real input global is retained. No OS/Web movement, rendered camera, mobile or performance acceptance.'}
local pointer,sender
local oldMode=input.mouseMode
local function Write()
    local output=assert(io.open(reportPath,'wb'));output:write(cjson.encode(report));output:close()
end
local function Check(ok,label)
    V.assert(ok,label);assert(ok,label);report.checks=report.checks+1
end
local function Near(a,b)return math.abs(a-b)<1e-8 end
local function Cleanup()
    if pointer then pointer:Release();pointer=nil end
    if sender then sender:Dispose();sender=nil end
    input.mouseMode=oldMode
end
local function Inject(dx,dy)
    local data=VariantMap()
    data['DX']=Variant(dx);data['DY']=Variant(dy)
    data['X']=Variant(0);data['Y']=Variant(0)
    data['Buttons']=Variant(0);data['Qualifiers']=Variant(0)
    sender:SendEvent('MouseMove',data);report.events=report.events+1
end
local function Pause()coroutine.yield()end
local function Ready(p)
    Check(p:Capture(),'native capture accepted')
    p:Poll(1/60);p:Poll(1/60)
    Check(p.captured and p.ready and not p.skip and p.eventNode~=nil,'native receiver ready')
end
local function Run()
    while not(rawget(_G,'VOX_HANGAR') and VOX_HANGAR.app and VOX_HANGAR.app.car)do Pause()end
    while VOX_HANGAR.app.loadingFlow and (VOX_HANGAR.app.loadingFlow.active or VOX_HANGAR.app.loadingFlow.pageVisible)do Pause()end
    Check(input:GetTypeName()=='Input','retain actual native Input object')
    sender=Node();Check(sender:GetTypeName()=='Node','retain actual native sender Node')
    for _,scenario in ipairs(golden.scenarios)do
        report.stage=scenario.name;Write()
        local session={touch=false,scope=false,controls={held={},x=0,y=0},HasFocus=function()return true end}
        function session.controls:Clear()self.held={};self.x=0;self.y=0 end
        function session.controls:Look(dx,dy)self.x=self.x+dx;self.y=self.y+dy end
        function session:Zoom()end
        pointer=Pointer.New(session);pointer.web=false;Ready(pointer)
        Check(pointer.eventNode:GetTypeName()=='Node','production owns actual native receiver Node')
        for i,frame in ipairs(scenario.frames)do
            if frame.reset then pointer:Release();Ready(pointer)end
            -- Real mouse activity invalidates an injected frame rather than
            -- silently replacing the engine Input object with a test double.
            Check(input.mouseMoveX==0 and input.mouseMoveY==0,'no OS motion contaminates injected frame')
            session.controls.x=0;session.controls.y=0
            for _,move in ipairs(frame.moves)do Inject(move[1],move[2])end
            Check(pointer.mouse.events==#frame.moves,'native VariantMap delivered every event '..scenario.name..':'..i)
            pointer:Poll(1/60)
            local expected=frame.expected
            Check(Near(session.controls.x,expected.delta[1]) and Near(session.controls.y,expected.delta[2]),'native source delta '..scenario.name..':'..i)
            Check(Near(pointer.mouse.avgMove,expected.avg) and pointer.mouse.lastSpike==expected.lastSpike,'native source history '..scenario.name..':'..i)
            session.controls.x=0;session.controls.y=0;pointer:Poll(1/60)
            Check(session.controls.x==0 and session.controls.y==0,'native event consumed once')
            report.frames=report.frames+1
            if i%10==0 then Write();Pause()end
        end
        local former=pointer
        pointer:Release();Check(pointer.eventNode==nil,'production releases native event owner')
        Inject(73,31)
        Check(former.mouse.events==0 and former.mouse.dx==0 and former.mouse.dy==0,'disposed native receiver no longer receives events')
        pointer=nil;report.scenarios=report.scenarios+1;Write();Pause()
    end
    Cleanup();report.complete=true;report.stage='complete';Write();V.finish()
end
local worker=coroutine.create(Run)
for frame=20,700 do V.atFrame(frame,function()
    if coroutine.status(worker)=='dead'then return end
    local ok,err=coroutine.resume(worker)
    if not ok then
        report.error=tostring(err)
        if debug and debug.traceback then report.traceback=debug.traceback(worker,tostring(err))end
        local cleaned,why=pcall(Cleanup);if not cleaned then report.cleanupError=tostring(why)end
        Write();error(err)
    end
end)end
V.atFrame(705,function()Check(report.complete,'injected native pointer fixture completed');V.finish()end)

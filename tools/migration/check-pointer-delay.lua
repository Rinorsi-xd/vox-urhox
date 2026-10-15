local Pointer=require 'controls.DrivePointer'
local BuildCamera=require 'controls.BuildCamera'
V.atFrame(48,function()
    local native=input;local mode=MM_ABSOLUTE
    local fake={mouseMode=mode,mouseLocked=false,focus=true,minimized=false,mouseMoveX=0,mouseMoveY=0,
        GetMouseButtonDown=function()return false end,GetMouseMoveWheel=function()return 0 end}
    input=fake
    local ok,err=pcall(function()
        local clears=0;local session={scope=false,touch=false,disposed=false,controls={Clear=function()clears=clears+1 end,Look=function()end,held={}},HasFocus=function()return true end}
        local p=Pointer.New(session);p.web=true;p.SetMouseMode=function(_,value)mode=value;fake.mouseMode=value end
        p:Capture();V.assert(p.pending and not p.captured,'browser click waits for genuine lock completion')
        p:Poll(14.3);V.assert(p.pending and not p.captured,'14-second blocked frame does not cancel its pending lock request')
        fake.mouseLocked=true;p:Poll(.016)
        V.assert(p.captured and not p.pending and not p.skip and not p.ready,'delayed browser completion consumes and suppresses its first input')
        p:Release();V.assert(not p.captured and not p.pending and mode==MM_ABSOLUTE,'explicit escape cancels authorization')
        fake.mouseMode=MM_RELATIVE;mode=MM_RELATIVE;p:Poll(.016)
        V.assert(not p.captured and mode==MM_ABSOLUTE,'late completion after explicit release is unlocked without automatic capture')
        fake.mouseLocked=false;p:Capture()
        for _=1,130 do p:Poll(1/60) end
        V.assert(not p.pending and not p.captured,'a denied request still expires after responsive processing and can be retried')
        fake.mouseLocked=true;fake.mouseMode=MM_ABSOLUTE
        V.assert(not p:Capture() and not p.pending,'an unfinished browser unlock cannot be reused as a fresh capture')
        local buildSession={controls={Cancel=function()end},disposed=false}
        local b=setmetatable({session=buildSession,mode='fp',touch=false,pending=true,captured=false,skipInput=true,lockWait=0,flight={Stop=function()end}},BuildCamera)
        b.Apply=function()end;b.SetMouseMode=function(_,value)fake.mouseMode=value end
        fake.mouseLocked=false;fake.mouseMode=MM_RELATIVE;b:Update(14.3,false)
        V.assert(b.pending and not b.captured,'construction capture survives the same delayed browser frame')
        fake.mouseLocked=true;b:Update(.016,false)
        V.assert(b.captured and not b.pending,'construction accepts a real delayed completion')
    end)
    input=native;if not ok then error(err) end
    V.finish()
end)

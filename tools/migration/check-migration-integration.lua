local UI=require 'urhox-libs/UI'
V.atFrame(10,function()
    local Prefs=require 'controls.TouchPreferences'
    local writes={};local persisted
    local app={store={Read=function() return persisted end,Write=function(_,key,value,valid) V.assert(key=='touch-settings' and valid(value),'touch settings validated before storage');persisted=value;writes[#writes+1]=key;return true end},toasts={Push=function() error('unexpected save failure') end}}
    local prefs=Prefs.Get(app)
    V.assert(prefs.build=='tap' and prefs.plane=='point' and prefs.assist and not prefs.autoFire,'source touch defaults')
    for key,choices in pairs(Prefs.options) do for _,value in ipairs(choices) do prefs[key]=value;V.assert(Prefs.Valid(prefs),'source setting choice '..key..tostring(value)) end end
    prefs.assist=false;prefs.autoFire=true;V.assert(app:SaveTouchPrefs(prefs),'preferences save succeeds')
    app.touchPrefs=nil;local reloaded=Prefs.Get(app);V.assert(not reloaded.assist and reloaded.autoFire and reloaded.build=='aim','false values survive reloading')
    local invalid={};for key,value in pairs(Prefs.defaults) do invalid[key]=value end;invalid.sens=9
    V.assert(not Prefs.Valid(invalid) and not app:SaveTouchPrefs(invalid) and #writes==1,'invalid settings cannot overwrite saved values')
    local traceCalls={};local act,removed,refresh=0,0,0
    local session={app=app,editor={Remove=function() removed=removed+1;return true end},buildCamera={mode='fp',touch=true},hud={touchControls={prefs={build='tap'}}}}
    session.Trace=function(_,x,y,explicit) traceCalls[#traceCalls+1]={x,y,explicit} end
    session.Act=function() act=act+1;return true end;session.Refresh=function() refresh=refresh+1 end
    local c=require('controls.BuildInput').New(session);session.controls=c
    V.assert(c:TouchAt(123,87,0) and act==1 and c.touchTarget and c.x==123 and c.y==87,'tap edit uses explicit finger coordinates')
    V.assert(traceCalls[#traceCalls][3]==true,'tap bypasses desktop centred ray')
    V.assert(c:TouchAt(147,91,2) and removed==1 and refresh==1,'long press atomic erase refreshes actual editor')
    local before=#traceCalls;local native=input;input={focus=true,minimized=false}
    local ok,err=pcall(function() c:Update(.1) end);input=native;if not ok then error(err) end
    V.assert(#traceCalls==before,'tap mode does not overwrite finger ray with centre every frame')
    c:Cancel();V.assert(not c.touchTarget and not c.inside and act==1 and removed==1,'pointer cancellation neither places nor removes')
    session.dialog={};V.assert(not c:TouchAt(33,44,0) and act==1,'modal blocks atomic touch edits');session.dialog=nil
    local w,h=UI.GetViewportSize();local rays={}
    session.camera={camera={GetScreenRay=function(_,x,y) rays[#rays+1]={x,y};return {origin=Vector3.ZERO,direction=Vector3.FORWARD} end},node={rotation=Quaternion.IDENTITY}}
    session.editor.Trace=function() end
    local Trace=require('app.BuildSession').Trace
    session.buildCamera.touch=false;Trace(session,23,41);V.assert(rays[1][1]==.5 and rays[1][2]==.5,'desktop FP ray stays centred')
    session.buildCamera.touch=true;Trace(session,23,41,true);V.assert(math.abs(rays[2][1]-23/w)<1e-8 and math.abs(rays[2][2]-41/h)<1e-8,'explicit touch ray follows screen position')
    c.touchTarget=true;Trace(session,23,41);V.assert(rays[3][1]==rays[2][1],'refresh preserves explicit touch ray')
    local places={};local p={x=1,y=2,z=3}
    local v={spec={bounds={radius=5}},body={translation=function() return p end},Yaw=function() return .7 end,Place=function(_,pos,yaw) places[#places+1]={pos,yaw};p={x=pos[1],y=pos[2],z=pos[3]} end}
    local Actions=require 'combat.DriverActions'
    Actions.Apply({vehicle=v},nil);V.assert(#places==0,'legacy three-output drivers remain valid')
    Actions.Apply({vehicle=v},{reset={pos={4,5,6},yaw=.3},flip=true})
    V.assert(#places==2 and places[1][2]==.3 and places[2][1][2]==8 and places[2][2]==.7,'AI reset then exact source flip height before simulation')
    local aim=require 'controls.DriveAim'
    local s={touch=true,app=app,assist={ref={}},pointer={captured=true},scope=false}
    V.assert(aim.AutoFire(s),'touch autofire requires a valid assist target')
    s.scope=true;V.assert(not aim.AutoFire(s),'scope disables source automatic fire');s.scope=false;s.pointer.captured=false
    V.assert(not aim.AutoFire(s),'paused input never fires');s.pointer.captured=true;s.dialog={}
    V.assert(not aim.AutoFire(s),'modal never fires');s.dialog=nil;s.touch=false;V.assert(not aim.AutoFire(s),'PC does not automatically fire')
    V.finish()
end)

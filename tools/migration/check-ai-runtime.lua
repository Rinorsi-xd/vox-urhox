local app=nil ---@type HangarApp|nil
local work=nil ---@type thread|nil
local stage='boot'
engine.maxInactiveFps=120
local function Exercise(s)
    local b=s.battle;s.Update=function()end;s.HasFocus=function()return true end
    if s.intro and not s.intro.done then s.intro:Finish() end
    local starts={};for _,entry in ipairs(b.entries) do starts[entry]=entry.unit:Position() end
    local decisions,moves,shots,resets,flips=0,0,0,0,0;local modes={}
    for _,entry in ipairs(b.entries) do if entry.driver then local old=entry.driver.Step
        entry.driver.Step=function(driver,...)
            local cmd,aim,fire,info=old(driver,...);decisions=decisions+1
            modes[driver.mode or 'nil']=true;if fire then shots=shots+1 end;if info and info.reset then resets=resets+1 end;if info and info.flip then flips=flips+1 end
            return cmd,aim,fire,info
        end
    end end
    local traces={}
    for frame=1,1800 do
        s:Tick(1/60,{throttle=0,steer=0,handbrake=true});s:PostUpdate(1/60)
        if frame%60==0 then
            local row={time=s.world.time,units={}}
            for _,entry in ipairs(b.entries) do row.units[#row.units+1]={team=entry.unit.team,alive=entry.unit.alive,pos=entry.unit:Position(),life=entry.unit:Life(),mode=entry.driver and entry.driver.mode} end
            traces[#traces+1]=row
        end
        if frame%4==0 then coroutine.yield() end
    end
    for _,entry in ipairs(b.entries) do if entry.driver and require('combat.EnemyDriverMath').Distance(entry.unit:Position(),starts[entry])>3 then moves=moves+1 end end
    V.assert(decisions>1000,'production AI naturally receives fixed-step combat decisions')
    V.assert(moves>=2,'multiple native enemies naturally drive on authored terrain')
    V.assert(shots>0 and s.effects.events>0,'native source AI naturally aims and fires mounted weapons')
    V.assert(b.player.vehicle==s.vehicle and b.player.weapons==s.weapons,'player damageable body and real weapons retain session ownership')
    local file=File('docs/migration/evidence/ai-runtime-traces.json',FILE_WRITE);file:WriteString(cjson.encode({decisions=decisions,moved=moves,triggerFrames=shots,resets=resets,flips=flips,modes=modes,traces=traces}));file:Dispose()
    coroutine.yield();coroutine.yield();local picture=Image:new();graphics:TakeScreenShot(picture);picture:SavePNG('docs/migration/evidence/ai-runtime.png');picture:Dispose()
    app:Reload();stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then app=VOX_HANGAR.app;V.assert(app:EnterTrial('trial','elimination'),'natural AI uses production asynchronous battle entry');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then work=coroutine.create(function()Exercise(app.trial)end);stage='exercise'
    elseif stage=='exercise' then local ok,err=coroutine.resume(work);if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active then V.assert(app.hangar and app.car,'natural AI session returns and releases combat');stage='done';V.finish() end
end
for frame=40,1600 do V.atFrame(frame,Poll) end
V.atFrame(1605,function()V.assert(stage=='done','natural AI full runtime check finishes');V.finish()end)

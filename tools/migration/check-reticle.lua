local S=require 'ui.ReticleState'
local app,trial
V.atFrame(35,function()
    local file=File('tools/migration/source-reticle.json',FILE_READ);local fixture=cjson.decode(file:ReadString());file:Dispose()
    for i,case in ipairs(fixture.cases) do
        local a=case.args;local g={kind=a.kind,weapons={{stats=a.stats,windup=a.windup}}}
        local w={energy=17,energyMax=100,offline=a.status=='offline',blocked=a.status=='limited' and 1 or 0}
        w.Group=function() return g end;w.Readiness=function() return a.ready end
        local firing=a.status=='fire' or a.status=='limited' or a.status=='blocked' or a.status=='windup'
        local actual=S.Fire(w,firing,a.status=='blocked' and 'blocked' or 'ok',a.status=='far' and 300 or 50,a.status=='far',a.lock)
        local e=case.expected
        V.assert(actual.word==e.word and actual.tone==e.tone and math.abs(actual.frac-e.frac)<.00001 and actual.sub==(e.sub or ''),'frozen fire state '..i)
    end
    for _,size in ipairs({{1920,1080},{2520,1134},{2048,1536},{1200,540}}) do
        local l=S.Layout(size[1],size[2]);local boxes=S.Chips(l,{{kind='mg'},{kind='sniper'},{kind='laser'},{kind='missile'}},2,false)
        for _,b in ipairs(boxes) do V.assert(b.x>=0 and b.y>=0 and b.x+b.w+30*l.k<=size[1] and b.y+b.h+9*l.k<size[2],'source slots within landscape viewport') end
        for _,p in ipairs({{0,0},{size[1],0},{0,size[2]},{size[1],size[2]}}) do
            local x,y=S.TargetPlate(l,{x=p[1],y=p[2],half=100*l.k})
            V.assert(x>=0 and y-24*l.k>=0 and x+168*l.k<=size[1] and y+38*l.k<=size[2],'target plate within landscape viewport')
        end
    end
    for kind,zoom in pairs(S.zoom) do V.assert(math.abs(math.tan(S.ScopeFov(48,kind)*math.pi/360)*zoom-math.tan(48*math.pi/360))<1e-8,'source optical zoom '..kind) end
end)
V.atFrame(45,function() app=assert(VOX_HANGAR).app;V.assert(app:EnterTrial(),'enter production trial') end)
local function Shot(name)
    local im=Image:new();V.assert(graphics:TakeScreenShot(im),'capture '..name)
    V.assert(im:SavePNG('docs/migration/evidence/reticle-native-'..name..'.png'),'save '..name);im:Dispose()
end
V.atFrame(310,function()
    trial=assert(app.trial);trial.pointer.captured=true;trial.follow=false
    trial.yaw=0;trial.pitch=15;trial:PostUpdate(1);trial:Aim();trial.hud.Update(trial,.1)
    trial.Update=function() end;trial.PostUpdate=function() end
    V.assert(not trial.hud.meter:IsVisible(),'obsolete speed panel hidden')
    V.assert(trial.hud.vitals:IsVisible(),'source reticle visible in production drive HUD')
    V.assert(trial.hud.vitals.fire~=nil,'fire state uses actual mounted weapon')
end)
V.atFrame(320,function() Shot('frame');trial.scope=true;trial.weapons:Select(2);trial.hud.Update(trial,.1) end)
V.atFrame(330,function() Shot('scope');trial.scope=false;trial.hud.vitals.hit=.55;trial.hud.vitals.hitDuration=.55;trial.hud.vitals.killed=true end)
V.atFrame(335,function() Shot('hit') end)
V.atFrame(336,function()
    local seed=917
    local function Random() seed=(seed*16807)%2147483647;return seed/2147483647 end
    local f=trial.hud.overlay.feedback;f:Kill('试验靶车',false,nil,nil,S.Layout(graphics.width,graphics.height),Random);f:Update(.15,1)
end)
V.atFrame(338,function() Shot('kill');trial.hud.overlay.feedback:Clear() end)
V.atFrame(340,function()
    local unit=assert(trial.world.units[1]);local ray=trial.camera:GetCamera():GetScreenRay(.5,.5)
    local point=ray.origin+ray.direction*16
    point.y=math.max(.5,point.y)
    unit.vehicle:Place({-point.x,point.y,point.z},0);unit:SavePose()
    local view=assert(trial.combatView.units[unit]);view:ResetPose();view:Update(1,0,trial.fxContext)
    trial.aimHit={owner={type='car',ref=unit},point={-point.x,point.y,point.z}}
    local o=trial.hud.overlay;require('ui.ReticleTarget').Update(o,.1)
    V.assert(o.focus and o.focus.ref==unit and o.focus.progress==0,'production target starts acquisition')
    trial.world.time=trial.world.time+.5;require('ui.ReticleTarget').Update(o,.5)
    V.assert(o.focus and o.focus.locked and o.focus.progress==1,'source target acquisition finishes in 420ms')
end)
V.atFrame(350,function() Shot('target') end)
V.atFrame(352,function()
    local f=trial.hud.overlay.feedback;f:Heal(false);f:Update(.18,.5);Shot('repair')
end)
V.atFrame(355,function()
    trial.aimHit=nil;local o=trial.hud.overlay;require('ui.ReticleTarget').Update(o,.2)
    V.assert(o.focus~=nil,'source target hold survives brief aim loss')
    require('ui.ReticleTarget').Update(o,.4);V.assert(o.focus==nil,'source target hold expires after 500ms')
    app:Reload()
end)
V.atFrame(445,function() V.assert(trial.disposed,'reticle owner disposed on return');V.finish() end)

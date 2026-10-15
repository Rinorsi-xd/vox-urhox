local UI=require 'urhox-libs/UI'
local Event=require 'urhox-libs/UI/Core/PointerEvent'
local app,s,hud,oldRoot,worldTime,shots,readCount,originalRead
local checkpoints={};local readyFrame=nil
local function At(frame,callback) checkpoints[frame-90]=callback end
local w,h=1920,1080
local viewportSize,getWidth,getHeight,oldScale=UI.GetViewportSize,UI.GetWidth,UI.GetHeight,UI.GetScale()
engine.maxInactiveFps=120
local function Click(widget)
    UI.Layout()
    local r=widget:GetAbsoluteLayoutForHitTest()
    local scale=UI.GetScale()
    for _,kind in ipairs({'PointerDown','PointerUp'}) do UI.HandlePointerEvent(Event.new(kind,{x=(r.x+r.w/2)*scale,y=(r.y+r.h/2)*scale,pointerId=88,pointerType='mouse',button=MOUSEB_LEFT})) end
end
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img),'native drive frame captured')
    V.assert(img:SavePNG('docs/migration/evidence/pc-drive-'..name..'.png'),'saved actual framebuffer '..name);img:Dispose()
end
local function Bound()
    UI.SetScale(1)
    hud=s.hud;hud.root:SetStyle({width=w,height=h});UI.MarkLayoutDirty();UI.Layout()
    renderer:GetViewport(0):SetRect(IntRect(0,0,w,h))
end
local function Keys()
    local key
    s.KeyPressed=function(_,candidate) return candidate==key end
    local function Press(value,typing) key=value;s:PollKeys(typing);key=nil end
    local details=s.details
    Press(KEY_I);V.assert(s.details~=details and not s.pointer.captured,'I toggles source details while mouse is released')
    Press(KEY_I,true);V.assert(s.details~=details,'typing prevents trial shortcuts')
    s.HasFocus=function() return false end
    Press(KEY_I);Press(KEY_ESCAPE);V.assert(s.details~=details and not s.wantsReturn,'unfocused window ignores details and Escape')
    s.HasFocus=function() return true end
    s.dialog={};Press(KEY_I);s.dialog=nil;V.assert(s.details~=details,'modal focus prevents trial shortcuts')
    Press(KEY_I);V.assert(s.details==details,'details toggle restores paused display')
    local follows=s.follow;Press(KEY_C)
    V.assert(s.follow~=follows and app.toasts.text:find('镜头跟车：',1,true),'C toggles follow and source notification while released')
    Press(KEY_C)
    local area=s.teleport;Press(KEY_N)
    V.assert(s.teleport==area%#s.world.layout.teleports+1 and app.toasts.text=='传送：'..s.world.layout.teleports[s.teleport].name,'N teleports and reports real area while released')
    s.controls.held.forward=true;Press(KEY_R)
    V.assert(not next(s.controls.held),'R flips and clears held drive input while released')
    Press(KEY_BACKSPACE)
    V.assert(s.teleport==1 and app.toasts.text=='已复原：车辆、靶子、靶车、锥桶','Backspace restores course while released')
    local select=s.weapons.Select;local selected={}
    s.weapons.Select=function(self,index) selected[#selected+1]=index;return select(self,index) end
    for _,digit in ipairs({KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0}) do Press(digit) end
    for i=1,10 do V.assert(selected[i]==i,'source digit weapon mapping '..i) end
    Press(KEY_TAB);V.assert(#selected==10,'Tab does not invent weapon switching');s.weapons.Select=select;s.weapons:Select(1)
    local elapsed=s.enteredTime;s.enteredTime=.4;Press(KEY_T)
    V.assert(not s.wantsReturn,'entry T guard includes exactly 400 ms')
    s.enteredTime=.401;Press(KEY_T);V.assert(s.wantsReturn,'T returns after entry debounce')
    s.wantsReturn=false;s.enteredTime=elapsed
end
local function Rules()
    local f=assert(io.open('tools/migration/source-trial-metrics.json'));local data=cjson.decode(f:read('*a'));f:close()
    local metrics=require('drive.TrialMetrics').New(data.drag)
    for i,c in ipairs(data.cases) do
        metrics:Timing(c.time,c.pos,c.speed,c.prevZ)
        V.assert(metrics.timing.state==c.state and metrics.timing.t0==c.t0,'source timing boundary '..i)
        local expected=type(c.timer)=='number' and c.timer or nil;local actual=metrics:Timer(c.time)
        V.assert(actual==expected,'source timer display '..i)
        if type(c.last)=='table' then V.assert(metrics.timing.last.time==c.last.time and metrics.timing.last.speed==c.last.speed,'source finish result '..i) end
    end
    metrics:Reset()
    for i,c in ipairs(data.damage) do
        if c.amount>0 then metrics:Damage(c.time,'target',c.amount,{0,0,0},false) end
        metrics:Step(c.time);V.assert(math.abs(metrics.dps-c.dps)<.000001,'source three-second DPS '..i)
    end
    V.assert(metrics.damage==215 and #metrics.recent==0,'DPS expires while total damage remains')
end
V.atFrame(50,function()
    app=VOX_HANGAR.app;Rules()
    UI.SetScale(1);UI.GetViewportSize=function() return w,h end;UI.GetWidth=function() return w end;UI.GetHeight=function() return h end
    app:EnterTrial()
end)
At(90,function()
    s=assert(app.trial);Bound();oldRoot=hud.root
    -- Hidden window input is injected without capturing the user's desktop.
    s.HasFocus=function() return true end
    s.pointer.SetMouseMode=function(self,mode) self.lastMouseMode=mode end
    s.pointer.Poll=function(self,dt) self:Sample({},dt) end
    Keys()
    V.assert(not s.pointer.captured and hud.pause:IsVisible(),'trial starts in original click-to-drive state')
    V.assert(not hud.buttons.menu and not hud.buttons.details and not hud.holds,'invented menu/detail buttons and mobile pads removed')
    V.assert(#hud.cards==#s.weapons.groups and #hud.overlay.pops==40 and #hud.overlay.tags==3,'bounded actual weapon and target feedback data')
end)
At(100,function()
    -- Advance the existing notification lifecycle for a clean post-toast frame.
    app.toasts:Update(3)
end)
At(105,function()
    Shot('paused-1920')
    V.assert(not hud.meter:IsVisible(),'replaced speed panel stays hidden')
    local b=hud.buttons['return']:GetAbsoluteLayoutForHitTest();V.assert(math.abs(b.x-1804.96875)<.6 and b.y==12 and b.h==36,'source return button at top right')
    local q=hud.stats:GetAbsoluteLayoutForHitTest();V.assert(q.x==1702 and q.y==56 and q.w==206 and q.h==51,'source damage statistics dimensions')
    for i,card in ipairs(hud.cards) do V.assert(not card.widget:IsVisible(),'replaced weapon card hidden '..i) end
    local reticleLayout=require('ui.ReticleState').Layout(w,h)
    local chips=require('ui.ReticleState').Chips(reticleLayout,s.weapons.groups,s.weapons.current,false)
    for i,chip in ipairs(chips) do V.assert(chip.x>=0 and chip.y>=0 and chip.x+chip.w<=w and chip.y+chip.h<=h,'actual reticle weapon chip within viewport '..i) end
    V.assert(hud.pause.box and hud.pause.box.w>180 and hud.pause.box.w<400 and hud.pause.box.h==90,'current source pause message has a bounded centered box')
    Click(hud.playfield);hud.Update(s,0)
    V.assert(s.pointer.captured and not hud.pause:IsVisible() and s.pointer.lastMouseMode==MM_RELATIVE,'native playfield click captures PC mouse and hides pause')
    V.assert(not s.controls.held.fire,'capture click never fires')
    local p=s.pointer;p:Sample({left=true,dx=100},.016);p:Sample({left=true,dx=100},.016)
    V.assert(not s.controls.held.fire and s.controls.lookX==0,'capture waits for held buttons to release and discards capture delta')
    p:Sample({},.016);p:Sample({left=true,dx=12,dy=-6},.016)
    local dx,dy=s.controls:TakeLook();V.assert(s.controls.held.fire and dx==12 and dy==-6,'captured mouse moves aim without right drag and left fires')
    p:Sample({},.016);V.assert(not s.controls.held.fire,'left release stops firing')
    p:Sample({right=true},.01);p:Sample({},.1);V.assert(s.scope,'short right click leaves scope on')
    p:Sample({right=true},.01);p:Sample({},.1);V.assert(not s.scope,'second short right click toggles scope off')
    p:Sample({right=true},.01);p:Sample({right=true},.26);p:Sample({},.01);V.assert(not s.scope,'right hold over 250ms exits scope on release')
    p:Sample({right=true},.01);p:Sample({},.25);V.assert(s.scope,'exact 250ms right press remains a toggle')
    s:PostUpdate(1)
    local group=s.weapons:Group();local scoped=require('ui.ReticleState').ScopeFov(48,group and group.kind)
    V.assert(math.abs(s.camera:GetCamera().fov-scoped)<.001,'source weapon optical zoom reaches actual camera')
    s:Pause();V.assert(not s.scope and not s.controls.held.fire and not s.pointer.captured and p.lastMouseMode==MM_ABSOLUTE,'pause releases mouse, scope and fire')
    s:Resume();p:Sample({},0);p:Sample({},0);hud.Update(s,0)
    s.details=true;hud.Update(s,0)
end)
At(118,function()
    Shot('active-1920');local r=hud.vitals:GetAbsoluteLayoutForHitTest()
    V.assert(r.x==0 and r.y==0 and r.w==w and r.h==h,'current source reticle owns full viewport')
    local layout=require('ui.ReticleState').Layout(r.w,r.h)
    V.assert(layout.cx==960 and layout.cy==540 and layout.radius==270,'source reticle center and radius')
    local d=hud.detailPanel:GetAbsoluteLayoutForHitTest();V.assert(d.x==12 and d.y==72 and d.w==280 and #hud.detailPanel.wheels==#s.vehicle.wheels,'source detailed data includes actual per-wheel compression')
    V.assert(not hud.meter:IsVisible(),'detailed data does not revive replaced speed panel')
    local before=hud.readoutUpdates;for _=1,60 do hud.Update(s,1/60) end
    V.assert(hud.readoutUpdates-before<=11,'formatted motion and suspension data refresh at most 10 Hz')
    s.controls.held.forward=true;s.controls.held.fire=true;s.controls:Look(50,50);s:Escape();hud.Update(s,0)
    V.assert(not s.pointer.captured and not next(s.controls.held) and s.controls.lookX==0 and not s.wantsReturn,'first Escape pauses and clears input')
    worldTime=s.world.time;shots=s.world.stats.shots;readCount=0;originalRead=s.controls.Read
    s.controls.Read=function() readCount=readCount+1;return {throttle=1,steer=1,firing=true} end
end)
At(133,function()
    V.assert(readCount==0 and s.world.stats.shots==shots and s.world.time>worldTime,'paused source world continues with neutral command and never polls driving input')
    s.controls.Read=originalRead;s:Escape();V.assert(s.wantsReturn,'Escape while released requests return');s.wantsReturn=false
    s:Resume();s.pointer.skip=false;s.pointer.ready=true;s.controls.held.fire=true
    s.HasFocus=function() return false end
    require('controls.DrivePointer').Poll(s.pointer,.016)
    V.assert(not s.pointer.captured and not next(s.controls.held),'native focus-loss adapter releases capture and fire')
    s.HasFocus=function() return true end;s:Resume();s.pointer.skip=false;s.pointer.ready=true
    local target=s.world.targets[1];s.world:Hit({owner={type='target',ref=target},point={48,1.6,8}},10000,{1,0,0},0,0)
    V.assert(not target.alive and s.world.stats.damage>0,'real target hit updates damage data')
    s.world.cones[1].body.setTranslation({x=100,y=10,z=100});s:ResetAll()
    local pos=s.world.cones[1].body.translation();local home=s.world.cones[1].home
    V.assert(s.world.targets[1].alive and s.world.stats.damage==0 and s.world.metrics.dps==0,'full reset restores targets and HUD statistics')
    V.assert(math.abs(pos.x+home.x)<.001 and math.abs(pos.z-home.z)<.001 and #s.world.debris.pieces==0,'full reset restores cones and clears debris')
    local c=s.camera:GetNode();local p=c.position+c.rotation*Vector3(0,0,12)
    hud.overlay:Pop({-p.x,p.y,p.z},135,false);V.assert(hud.overlay.pops[hud.overlay.index].t==0,'damage feedback projects into actual camera')
    for _=1,50 do hud.overlay:Pop({-p.x,p.y,p.z},25,false) end
    V.assert(#hud.overlay.pops==40,'damage events reuse bounded 40-entry pool')
    hud.overlay:Clear()
    hud.overlay:PopDamage({cells0=200,lostCells=30,lostMajor=1},{point={-p.x,p.y,p.z},normal=135,pierce=80,shield=55,cells0=0,major0=0})
    V.assert(hud.overlay.pops[hud.overlay.index].shield,'real HUD renders source shield-resist channel')
    s.weapons.energy=s.weapons.energyMax*.1;s.weapons.offline=true
    s.details=false;hud.Update(s,0)
    V.assert(hud.vitals.fire.word=='能量耗尽','current reticle reads actual offline weapon state')
end)
At(144,function()
    Shot('energy');s.weapons.offline=false;s.weapons.energy=s.weapons.energyMax;hud.Update(s,0)
    V.assert(hud.vitals.fire.word~='能量耗尽','weapon recovery retires actual offline state')
    s:Pause();s.details=true;oldRoot=hud.root;w,h=1440,900
end)
At(158,function()
    Bound();V.assert(not oldRoot.node and hud.width==1440 and s.details and not s.pointer.captured,'PC resize releases old UI and preserves details and released state')
end)
At(170,function()
    Shot('paused-1440');local q=hud.stats:GetAbsoluteLayoutForHitTest();V.assert(q.x==1222 and q.y==56,'16:10 PC keeps original right stats anchor: '..cjson.encode(q));Click(hud.playfield);hud.Update(s,0)
    V.assert(s.pointer.captured,'rebuilt PC playfield can resume')
    s.scope=true;s:PostUpdate(1)
end)
At(182,function()
    Shot('scope-1440');s:Pause();hud.Update(s,0)
    local m=require('ui.GraphicsPanel').Open(s);m:Close();s:Update(.16)
    V.assert(not m.node and not s.closingDialog and not s.dialog,'trial update retires shared modal without retaining input or resources')
end)
At(188,function()
    Click(hud.buttons['return']);V.assert(s.wantsReturn,'original return button works without source selector bug')
    UI.GetViewportSize=viewportSize;UI.GetWidth=getWidth;UI.GetHeight=getHeight;UI.SetScale(oldScale)
end)
At(370,function()
    V.assert(app.mode=='hangar' and s.disposed and not hud.root.node,'return releases PC trial UI and simulation')
    V.assert(not app.scene:GetChild('TrialPhysics',true),'trial physics and feedback do not remain in hangar');V.finish()
end)
-- HUD input starts only after the real loading overlay releases hit testing.
for frame=51,640 do
    local tick=frame
    V.atFrame(tick,function()
        if not readyFrame and app and app.trial and not app.loadingFlow.active then readyFrame=tick end
        local run=readyFrame and checkpoints[tick-readyFrame]
        if run then run() end
    end)
end
V.atFrame(645,function() V.assert(readyFrame~=nil,'production loading reached playable HUD');V.finish() end)

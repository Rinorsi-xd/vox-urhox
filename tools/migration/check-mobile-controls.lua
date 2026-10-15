-- Native UI dispatch, scaled landscape rendering and simultaneous touch input.
local UI=require 'urhox-libs/UI'
local Event=require 'urhox-libs/UI/Core/PointerEvent'
local Touch=require 'controls.TouchMode'
local Home=require 'ui.GarageHud'
local app,s,drive,build
local pw,ph=1280,720
Touch.override=true
Touch.Scale=function(surface) return ph/(surface=='home' and 760 or surface=='build' and 640 or 540) end
UI.GetViewportSize=function() return pw/UI.GetScale(),ph/UI.GetScale() end
UI.GetWidth=function() return pw/UI.GetScale() end
UI.GetHeight=function() return ph/UI.GetScale() end
engine.maxInactiveFps=120
local function Bound(root)
    local w,h=UI.GetViewportSize();root:SetStyle({width=w,height=h})
    renderer:GetViewport(0):SetRect(IntRect(0,0,pw,ph))
end
local function Point(widget)
    local r=widget:GetAbsoluteLayoutForHitTest();return r.x+r.w/2,r.y+r.h/2
end
local function Send(kind,id,x,y)
    UI.HandlePointerEvent(Event.new(kind,{x=x*UI.GetScale(),y=y*UI.GetScale(),pointerId=id,pointerType='touch',button=MOUSEB_LEFT}))
end
local function Click(widget)
    local x,y=Point(widget);Send('PointerDown',88,x,y);Send('PointerUp',88,x,y)
end
local function Visible(widget,label)
    local r=widget:GetAbsoluteLayoutForHitTest();local w,h=UI.GetViewportSize()
    V.assert(widget:IsVisible() and r.x>=0 and r.y>=0 and r.x+r.w<=w+1 and r.y+r.h<=h+1,label..' inside landscape viewport')
end
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image),'captured '..name)
    local crop=image:GetSubimage(IntRect(0,0,pw,ph));V.assert(crop:SavePNG('docs/migration/evidence/mobile-'..name..'.png'),'saved '..name)
    crop:Dispose();image:Dispose()
end
V.atFrame(45,function()
    app=VOX_HANGAR.app;Home.Create(app);Bound(Home.GetState().root)
end)
V.atFrame(58,function()
    for _,id in ipairs({'edit','trial','battle','new','workshop'}) do Visible(Home.GetState().buttons[id],id) end
    Shot('home');Click(Home.GetState().buttons.workshop)
end)
V.atFrame(66,function()
    Shot('workshop');V.assert(not Home.GetState().cta:IsVisible(),'workshop cards unobstructed by battle CTA')
    Click(Home.GetState().buttons.hangar)
end)
V.atFrame(72,function() Click(Home.GetState().buttons.edit);build=assert(app.build);Bound(build.hud.root) end)
V.atFrame(83,function()
    V.assert(build.buildCamera.touch and build.buildCamera.mode=='orbit','mobile builder uses orbit camera')
    for _,id in ipairs({'parts','rotate','tilt','zoomIn','zoomOut','home'}) do Visible(build.hud.buttons[id],'build '..id) end
    Shot('build');local before=build.camera.dist;Click(build.hud.buttons.zoomOut)
    V.assert(build.camera.dist>before,'touch button zooms actual build camera')
    local x,y=UI.GetWidth()*.55,UI.GetHeight()*.45;local yaw=build.camera.yaw;local count=build.editor.bp:Stats().count
    Send('PointerDown',90,x,y);Send('PointerMove',90,x+60,y+20);Send('PointerUp',90,x+60,y+20)
    V.assert(build.camera.yaw~=yaw and build.editor.bp:Stats().count==count,'touch orbit moves camera without placing parts')
    Click(build.hud.buttons.parts)
end)
V.atFrame(96,function()
    local inventory=assert(build.inventoryPanel);Visible(inventory.closeButton,'inventory close');Shot('inventory');Click(inventory.closeButton)
end)
V.atFrame(104,function() V.assert(not build.inventoryPanel,'inventory closes by touch');Click(build.hud.buttons.home);Bound(Home.GetState().root) end)
V.atFrame(116,function() Click(Home.GetState().buttons.trial) end)
V.atFrame(162,function()
    s=assert(app.trial);s.HasFocus=function() return true end;s:Resume();drive=s.hud;Bound(drive.root)
end)
V.atFrame(176,function()
    local t=assert(drive.touchControls)
    for id,button in pairs(t.buttons) do Visible(button,'drive '..id) end
    for i,card in ipairs(drive.cards) do Visible(card.widget,'weapon '..i) end
    V.assert(not drive.pause:IsVisible(),'mobile does not require mouse lock')
    local x,y=Point(t.stick);Send('PointerDown',11,x,y);Send('PointerMove',11,x-30,y-45)
    local fx,fy=Point(t.buttons.fire);Send('PointerDown',12,fx,fy)
    Send('PointerDown',13,480,230);Send('PointerMove',13,515,250)
    V.assert(s.controls.touchThrottle>.5 and s.controls.touchSteer>.2 and s.controls.held.fire,'joystick and firing work with independent fingers')
    local dx,dy=s.controls:TakeLook();V.assert(dx>0 and dy>0,'third finger controls view while driving and firing')
    -- Headless window lacks OS focus: inject only the keyboard adapter while
    -- preserving the actual Read implementation and touch command values.
    local native=input;input={focus=true,GetKeyDown=function() return false end}
    local command=s.controls:Read();input=native
    V.assert(command.throttle>.5 and command.steer>.2 and command.firing,'touch reaches actual vehicle command')
    local before=s.fixedSteps;s:Tick(.1,command);V.assert(s.fixedSteps>before,'touch command advances actual vehicle simulation')
    Send('PointerUp',11,450,50);Send('PointerUp',12,500,50);Send('PointerUp',13,515,250)
    V.assert(s.controls.touchThrottle==0 and s.controls.touchSteer==0 and not s.controls.held.fire,'release outside controls clears throttle and fire')
    Send('PointerDown',11,x,y-40);Send('PointerDown',12,fx,fy)
    s.HasFocus=function() return false end;s.pointer:Poll(.016)
    V.assert(not s.pointer.captured and s.controls.touchThrottle==0 and not next(s.controls.held) and not t.stick.pointer,'focus loss cancels every touch owner')
    s.HasFocus=function() return true end
    Send('PointerDown',11,x,y-40);V.assert(s.pointer.captured and s.controls.touchThrottle>.5,'new touch resumes after focus loss')
    UI.CancelPointer(11,'touch');V.assert(s.controls.touchThrottle==0,'OS touch cancellation clears joystick')
    Click(t.buttons.scope);V.assert(s.scope,'touch scope button works')
    Click(t.buttons.scope);V.assert(not s.scope,'touch scope toggles off')
    drive.Update(s,0)
end)
V.atFrame(188,function() Shot('drive');Click(drive.buttons['return']) end)
V.atFrame(230,function()
    V.assert(app.mode=='hangar' and s.disposed and not drive.root.node,'touch return disposes driving world and controls')
    V.finish()
end)

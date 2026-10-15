local UI=require 'urhox-libs/UI'
local Event=require 'urhox-libs/UI/Core/PointerEvent'
local app,session,layer,ready
local function Near(a,b,label,tolerance) V.assert(math.abs(a-b)<(tolerance or 1e-7),label..' '..tostring(a)..' / '..tostring(b)) end
local function Pointer(kind,id,x,y)
    UI.HandlePointerEvent(Event.new(kind,{pointerType='touch',pointerId=id,x=x*UI.GetScale(),y=y*UI.GetScale(),button=MOUSEB_LEFT}))
end
local function Center(widget)
    UI.Layout();local r=widget:GetAbsoluteLayoutForHitTest();return r.x+r.w/2,r.y+r.h/2
end
local function Click(widget)
    local x,y=Center(widget);Pointer('PointerDown',77,x,y);Pointer('PointerUp',77,x,y)
end
V.atFrame(10,function()
    local f=assert(io.open('docs/migration/evidence/source-touch.json'));local source=cjson.decode(f:read('*a'));f:close()
    local axes={};local adapter={mode='drive',width=840,height=378,floating=true,Move=function(x,y) axes={x,y} end}
    local gestures=require('controls.TouchGestures').New(adapter)
    for i,p in ipairs(source.gestures.samples) do gestures:Stick(p.x,p.y,source.gestures.rect);Near(axes[1],p.move[1],'source stick X '..i);Near(axes[2],p.move[2],'source stick Y '..i) end
    for _,viewport in ipairs(source.layouts) do for _,k in ipairs({1,2.4,3}) do
        local l=require('ui.SourceTouchLayout').Drive(viewport.width*k,viewport.height*k,viewport.width,viewport.height,{})
        for _,ref in ipairs(viewport.modes.drive) do
            local r=ref.action=='move' and l.stick or ref.action=='menu' and l.toggle or l.actions[ref.action]
            for i,v in ipairs({r.left/k,r.top/k,r.width/k,r.height/k}) do Near(v,ref.rect[i],'source layout '..viewport.width..' '..ref.action..' '..i,.025) end
        end
    end end
end)
V.atFrame(50,function()
    app=VOX_HANGAR.app;require('controls.TouchMode').override=true;app:EnterTrial()
end)
local actions={}
actions[10]=function()
    session=app.trial;layer=session.hud.touchControls
    V.assert(session.touch and layer~=nil,'production trial uses source touch controls')
    session.HasFocus=function() return true end;session.pointer.SetMouseMode=function() end
    session.pointer.Poll=function() end;session:Resume();layer.Update(false);UI.Layout()
    V.assert(not layer.buttons.aux:IsVisible() and not layer.buttons.interact:IsVisible(),'wheel vehicle hides unused lift and context controls')
    V.assert(layer.buttons.up.props.icon=='brake' and layer.toggle.props.icon=='menu','source wheel brake and icon menu')
    local w,h=UI.GetViewportSize();local k=layer.layout.k
    local x,y=w*.28,h*.6
    Pointer('PointerDown',11,x,y);UI.Layout()
    -- Yoga snaps final widget edges to pixels; source analytic layout stays separately checked.
    local sx,sy=Center(layer.stick);Near(sx,x,'floating stick follows initial left-zone contact',.6);Near(sy,y,'floating stick Y',.6)
    Pointer('PointerMove',11,x,y-30*k);V.assert(session.controls.touchThrottle>0,'floating stick drives production throttle')
    local fx,fy=Center(layer.buttons.primary);Pointer('PointerDown',12,fx,fy)
    V.assert(session.controls.held.fire and layer.gestures:Held('move'),'fire and movement have separate captured contacts')
    Pointer('PointerMove',12,fx-20*k,fy-5*k);V.assert(session.controls.lookX<0,'dragging fire aims production camera')
    Pointer('PointerUp',12,fx,fy);V.assert(not session.controls.held.fire and layer.gestures:Held('move'),'fire release preserves movement')
    Pointer('PointerCancel',11,x,y);V.assert(session.controls.touchThrottle==0 and not layer.stick.live,'cancel resets throttle and returns stick home')
    Click(layer.buttons.scope);V.assert(session.scope,'source scope tap executes')
    Click(layer.toggle);V.assert(layer.menu and not session.scope and not next(layer.gestures.pointers),'menu resets held firing and scope')
    Click(layer.menuButtons.menu);V.assert(not layer.menu,'continue restores production touch playfield')
    V.assert(layer.menuButtons.settings and not layer.settings and layer.prefs.build=='tap' and layer.prefs.plane=='point','source preferences now live behind the common settings entry')
    local settings=require('ui.TouchSettings').Open(session).settings
    local base=layer.layout.actions.primary.width
    settings.Set('size',1.15);layer.Update(false);Near(layer.layout.actions.primary.width,base*1.15,'live source button size setting',.025)
    settings.Set('size',1);settings.Set('sens',1.5);layer.Update(false)
    V.assert(layer.gestures.adapter.sensitivity==1.5,'live source touch sensitivity setting')
    settings.Set('autoFire',true);V.assert(session.app.touchPrefs.autoFire,'autofire preference saves through production UI')
    settings.Set('autoFire',false);settings.Set('sens',1)
    require('ui.DialogHost').Close(session);session:Resume();layer.Update(false)
end
actions[15]=function()
    local image=Image:new();V.assert(graphics:TakeScreenShot(image),'actual touch drive frame');image:SavePNG('docs/migration/evidence/touch-drive-native.png');image:Dispose()
    V.finish()
end
for tick=51,650 do local frame=tick;V.atFrame(frame,function()
    if not ready and app and app.trial and not app.loadingFlow.active then ready=frame end
    if ready and actions[frame-ready] then actions[frame-ready]() end
end) end
V.atFrame(655,function() V.assert(ready~=nil,'production loading completed');V.finish() end)

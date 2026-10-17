local UI=require 'urhox-libs/UI'
local Event=require 'urhox-libs/UI/Core/PointerEvent'
local app,session,layer,ready
local function Near(a,b,label,t) V.assert(math.abs(a-b)<(t or .13),label..' '..a..' / '..b) end
local function Pointer(kind,id,x,y)UI.HandlePointerEvent(Event.new(kind,{pointerType='touch',pointerId=id,x=x*UI.GetScale(),y=y*UI.GetScale(),button=MOUSEB_LEFT}))end
local function Click(widget)
    UI.Layout();local r=widget:GetAbsoluteLayoutForHitTest();local x,y=r.x+r.w/2,r.y+r.h/2;Pointer('PointerDown',66,x,y);Pointer('PointerUp',66,x,y)
end
local function Shot(name)local i=Image:new();V.assert(graphics:TakeScreenShot(i) and i:SavePNG('docs/migration/evidence/mobile-editor-'..name..'.png'),'actual rendered mobile editor '..name);i:Dispose()end
V.atFrame(20,function()
    local f=assert(io.open('docs/migration/evidence/source-mobile-editor.json'));local source=cjson.decode(f:read('*a'));f:close()
    V.assert(source.baseline=='2b169a9964645f5f346a7158bcb14447f040814a','mobile editor original baseline')
    for _,view in ipairs(source.layouts) do for _,k in ipairs({1,2.4,3}) do for _,mode in ipairs({'tap','aim'}) do
        local l=require('ui.TouchEditorLayout').Calculate(view.width*k,view.height*k,view.width,view.height,{},1,mode=='aim')
        for _,r in ipairs(view.states[mode]) do
            if ({['me-rotate']=true,['me-mirror']=true,['me-pick']=true,primary=true,erase=true,up=true,down=true})[r.action] then
                local actual=l.buttons[r.action];for i,v in ipairs({actual.left/k,actual.top/k,actual.width/k,actual.height/k}) do Near(v,r.rect[i],'original right rail '..view.width..' '..mode..' '..r.action..' '..i) end
            end
        end
        local slots=0
        for _,r in ipairs(view.states[mode]) do
            if r.action=='me-slot' then
                slots=slots+1
                local actual=l.slots[slots]
                V.assert(actual~=nil,'source visible slot '..slots)
                if actual then for i,v in ipairs({actual.left/k,actual.top/k,actual.width/k,actual.height/k}) do Near(v,r.rect[i],'source slot rectangle '..view.width..' '..slots..' '..i,1) end end
            end
        end
        V.assert(l.slotCount==slots,'actual source visible slot count '..view.width)
        for id,r in pairs(l.buttons) do V.assert(r.left>=0 and r.top>=0 and r.left+r.width<=view.width*k+1 and r.top+r.height<=view.height*k+1,'landscape control fits '..view.width..' '..id) end
    end end end
end)
V.atFrame(50,function()
    app=VOX_HANGAR.app;require('controls.TouchMode').override=true;V.assert(app:EnterBuild(),'actual authored hall enters touch build')
end)
local actions={}
actions[10]=function()
    session=app.build;layer=session.hud.touchControls;layer.focus=function()return true end;layer.Update(false);UI.Layout()
    V.assert(layer.prefs.build=='tap' and not layer.buttons.primary:IsVisible(),'default source tap hides aim build button')
    V.assert(not session.hud.toolbar:IsVisible() and not session.hud.dock:IsVisible(),'source mobile composition hides desktop toolbar and dock')
    Click(layer.buttons['me-tools']);V.assert(layer.sheet=='tools','actual tools button opens authored sheet')
    Click(layer.toolRows.paint);V.assert(session.editor.tool=='paint' and not layer.sheet,'actual source paint tool uses editor')
    Click(layer.buttons['me-paint']);V.assert(layer.sheet=='paint','actual paint button opens swatches')
    Click(layer.channels.accent);V.assert(session.editor.paintChannel=='accent' and layer.sheet=='paint','accent channel leaves source paint sheet open')
    Click(layer.swatches[2]);V.assert(not session.editor.autoColor and session.editor.color==layer.swatches[2].props.hex,'actual palette writes selected original color')
    Click(layer.eyedrop);V.assert(layer.colorTap and not layer.sheet,'eyedrop enters source next touch pickup')
    Click(layer.buttons['me-pick']);V.assert(layer.pickTap and not layer.colorTap,'part picker excludes color picker')
    layer.Action('me-pick');local before=session.editor.mirror;Click(layer.buttons['me-mirror']);V.assert(session.editor.mirror~=before,'actual mirror toggles editor')
    Click(layer.buttons['me-more']);V.assert(layer.sheet=='more','actual more button opens authored sheet')
    Click(layer.modeButtons.aim);V.assert(layer.prefs.build=='aim' and layer.buttons.primary:IsVisible() and layer.sheet=='more','aim mode adds source primary/erase without closing sheet')
    Click(layer.modeButtons.tap);V.assert(layer.prefs.build=='tap' and not layer.buttons.primary:IsVisible(),'source tap restoration')
    local base=layer.toolRows.paint.props.width;layer.prefs.size=1.15;layer.prefs.sens=1.5;layer.Update(false)
    Near(layer.toolRows.paint.props.width,base*1.15,'live source size scales sheet children',.01)
    Near(layer.gestures.adapter.sensitivity,1.5,'live source look sensitivity updates',.001)
    layer.prefs.size=1;layer.prefs.sens=1;layer.Update(false)
    layer.Action('me-more');layer.Action('me-tool','build');layer.Update(false);UI.Layout()
end
actions[13]=function()
    local w,h=UI.GetViewportSize();local k=layer.layout.k;local x,y=w*.6,h*.5
    local original=session.controls.TouchAt;local acts={};session.controls.TouchAt=function(self,px,py,button)acts[#acts+1]={x=px,y=py,button=button};return original(self,px,py,button)end
    Pointer('PointerDown',18,x,y);V.assert(session.controls.touchTarget and math.abs(session.controls.x-x)<.01,'touch ray keeps actual finger rather than screen center')
    Pointer('PointerUp',18,x,y);V.assert(#acts==1 and acts[1].button==0 and acts[1].x~=w/2,'release invokes one real editing atom at finger')
    Pointer('PointerDown',19,x,y);layer.Tick(.449);V.assert(#acts==1,'long press does not delete before 450ms')
    layer.Tick(.002);V.assert(#acts==2 and acts[2].button==2,'450ms long press invokes real deletion')
    layer.Tick(.249);V.assert(#acts==2,'source repeated delete waits 250ms')
    layer.Tick(.002);V.assert(#acts==3 and acts[3].button==2,'source repeated delete at 250ms')
    Pointer('PointerUp',19,x,y);V.assert(#acts==3,'long release never places a new part')
    Pointer('PointerDown',20,x,y);Pointer('PointerCancel',20,x,y);V.assert(#acts==3 and not layer.press:IsVisible(),'cancel has no edit and hides press ring')
    Pointer('PointerDown',21,x,y);Pointer('PointerMove',21,x+13*k,y);V.assert(layer.pointers[21].action=='look','source 12 CSS px drag becomes camera look')
    Pointer('PointerUp',21,x+13*k,y);V.assert(#acts==3,'orbit drag never places or deletes')
    Pointer('PointerDown',22,x,y);layer.Update(true);V.assert(not next(layer.pointers) and #acts==3,'blocking a contact cancels without edit')
    layer.Update(false);session.controls.TouchAt=original;layer.Action('me-tools');session:Refresh()
end
actions[17]=function()Shot('tools');layer.Action('me-paint');session:Refresh()end
actions[20]=function()Shot('paint');layer.Action('me-more');session:Refresh()end
actions[23]=function()Shot('more');layer.Action('me-more');session:Refresh()end
actions[26]=function()Shot('tap');layer.Action('me-stats');session:Refresh()end
actions[30]=function()
    Shot('stats');local p=session.hud.stats.pane;local r=p.scroll:GetAbsoluteLayout()
    local cssW=graphics:GetWidth()/math.max(1,graphics:GetDPR());Near(p.mobileFrame.props.scale,UI.GetWidth()/cssW*.65,'source mobile stats 0.65 physical CSS scale',.001)
    V.assert(p.mobileFrame.props.transformOrigin=='top-left' and p.props.width==264,'stats contents and hit targets share top-left transform')
    V.finish()
end
for tick=51,650 do local frame=tick;V.atFrame(frame,function()
    if not ready and app and app.build and not app.loadingFlow.active then ready=frame end
    if ready and actions[frame-ready] then actions[frame-ready]() end
end) end
V.atFrame(655,function()V.assert(ready~=nil,'production mobile editor loading completed');V.finish()end)

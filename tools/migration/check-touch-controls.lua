local UI=require 'urhox-libs/UI'
local E=require 'urhox-libs/UI/Core/PointerEvent'
local app,s,layer
local function Near(a,b,label) V.assert(math.abs(a-b)<1e-7,label) end
local function Point(widget)
    UI.Layout()
    local r=widget:GetAbsoluteLayoutForHitTest();return r.x+r.w/2,r.y+r.h/2
end
local function Pointer(kind,id,x,y)
    UI.HandlePointerEvent(E.new(kind,{pointerType='touch',pointerId=id,x=x*UI.GetScale(),y=y*UI.GetScale(),button=MOUSEB_LEFT}))
end
local function Click(widget,id)
    local x,y=Point(widget);Pointer('PointerDown',id or 99,x,y);Pointer('PointerUp',id or 99,x,y)
end
V.atFrame(5,function()
    local f=assert(io.open('docs/migration/evidence/source-touch.json'));local source=cjson.decode(f:read('*a'));f:close()
    local adapter={mode='drive',width=840,height=378,Hold=function() return false end,Action=function() end,Pan=function() end}
    local axes={0,0};local zoom=0;local look={0,0}
    adapter.Move=function(x,y) axes={x,y} end;adapter.Zoom=function(delta) zoom=delta end;adapter.Look=function(x,y) look={x,y} end
    local gestures=require('controls.TouchGestures').New(adapter);local golden=source.gestures
    for i,p in ipairs(golden.samples) do gestures:Stick(p.x,p.y,golden.rect);Near(axes[1],p.move[1],'source analog X '..i);Near(axes[2],p.move[2],'source analog Y '..i) end
    gestures:Down('look',1,200,150,{x=0,y=0,w=840,h=378});gestures:Down('look',2,400,150,{x=0,y=0,w=840,h=378})
    for i,p in ipairs(golden.moves) do gestures:Move(p.id,p.x,p.y);Near(zoom,p.zoom,'source pinch CSS pixels '..i) end
    gestures:Reset();gestures:Down('primary',3,410,120,{x=400,y=100,w=56,h=48});gestures:Move(3,437,131)
    Near(look[1],golden.primaryLook[1],'source primary drag aim X');Near(look[2],golden.primaryLook[2],'source primary drag aim Y');gestures:Reset()
    local taps=0;local fire=false
    adapter.Hold=function(id,on) if id=='primary' then fire=on;return true end;return false end
    adapter.Action=function() taps=taps+1 end
    local rect={x=0,y=0,w=56,h=48}
    V.assert(gestures:Down('primary',1,10,10,rect) and fire,'down fires directly')
    V.assert(not gestures:Down('primary',2,10,10,rect),'second fire contact rejected')
    gestures:Down('move',3,28,24,rect);gestures:Move(3,48,24)
    gestures:Up(1,900,900,false);V.assert(not fire and gestures:Held('move'),'release outside stops fire without losing stick')
    gestures:Down('scope',4,10,10,rect);gestures:Up(4,24,10,false);V.assert(taps==0,'14px drag is not tap')
    gestures:Down('scope',5,10,10,rect);gestures:Up(5,11,10,true);V.assert(taps==0,'cancel cannot activate scope')
    gestures:Down('scope',6,10,10,rect);gestures:Up(6,11,10,false);V.assert(taps==1,'short in-bounds release taps once')
    gestures:Reset();V.assert(not next(gestures.pointers) and axes[1]==0 and axes[2]==0,'reset retires all contacts')
    local actions={drive={'scope','interact','up','primary','aux','weapon'},edit={'up','primary','down','slot-prev','slot-next'}}
    for _,viewport in ipairs(source.layouts) do for mode,refs in pairs(viewport.modes) do
        for _,k in ipairs({1,2.4,3}) do
            local l=require('ui.SourceTouchLayout').Calculate(viewport.width*k,viewport.height*k,viewport.width,viewport.height,{},mode,actions[mode])
            for _,r in ipairs(refs) do
                local a=r.action=='menu' and l.toggle or r.action=='move' and l.stick or l.actions[r.action]
                local y=a.top or viewport.height*k-a.bottom-a.height
                Near(a.left/k,r.rect[1],'source touch left '..mode..r.action)
                Near(y/k,r.rect[2],'source touch top '..mode..r.action)
                Near(a.width/k,r.rect[3],'source touch width '..mode..r.action)
                Near(a.height/k,r.rect[4],'source touch height '..mode..r.action)
            end
        end
    end end
    local flight=require('controls.FreeFlight').New({0,5,0},{0,0,-1},{x=100,y0=0,y1=100,z0=-100,z1=100})
    flight:Step(.1,{forward=.2});Near(flight.vel[3],-.9*(1-math.exp(-1)),'analog stick retains fractional speed')
end)
V.atFrame(55,function()
    require('controls.TouchMode').override=true
    app=VOX_HANGAR.app;app.store=require('storage.BlueprintStore').New('vox-touch-validation');app.bays.store=app.store
    app:EnterBuild();s=app.build;layer=s.hud.touchControls
    V.assert(s.buildCamera.mode=='fp' and layer~=nil,'touch construction uses source first-person camera')
end)
V.atFrame(80,function()
    s=app.build;layer=s.hud.touchControls
    print('[TouchQA] '..cjson.encode({focus=input.focus,minimized=input.minimized,root=UI.GetRoot()==s.hud.root,blocked=layer.blocked,visible=layer.root:IsVisible(),stick=layer.stick:GetAbsoluteLayoutForHitTest()}))
    local originalInput=input
    input={focus=true,minimized=false,GetKeyDown=function() return false end,GetKeyPress=function() return false end,
        GetMouseButtonDown=function() return false end,GetMouseButtonPress=function() return false end}
    layer.Update(false);UI.Layout()
    local x,y=Point(layer.stick);Pointer('PointerDown',1,x,y);Pointer('PointerMove',1,x+layer.stick.props.width*.25,y-10)
    V.assert(s.buildCamera.touchRight>0,'real UI stick routes analog camera input')
    local px,py=Point(layer.playfield);Pointer('PointerDown',2,px,py);Pointer('PointerMove',2,px+12,py+4)
    V.assert(s.buildCamera.dx>0 and s.buildCamera.dy>0,'second contact aims while stick remains held')
    Pointer('PointerCancel',2,px,py);V.assert(layer.gestures:Held('move'),'look cancellation preserves moving contact')
    layer.Clear();V.assert(not next(layer.gestures.pointers) and s.buildCamera.touchRight==0,'UI cancellation clears all camera controls')
    Click(layer.toggle);V.assert(layer.menu and not layer.stick:IsVisible() and not layer.playfield:IsVisible(),'source menu hides play controls')
    Click(layer.menuButtons['tool-erase']);V.assert(s.editor.tool=='erase' and not layer.menu,'menu executes editor command and resumes')
    Click(layer.toggle);Click(layer.menuButtons.undo);V.assert(not layer.menu,'touch undo routes command and closes menu')
    local slot=s.inventory.active;Click(layer.buttons['slot-next']);V.assert(s.inventory.active~=slot,'source next-slot action works through UI')
    Click(layer.toggle);Click(layer.menuButtons.extra);V.assert(layer.expanded and layer.extra:IsVisible(),'more construction actions expand')
    local mirror=s.editor.mirror;Click(layer.menuButtons.mirror);V.assert(s.editor.mirror~=mirror,'touch mirror command changes real editor')
    local count=0;local original=s.Act;s.Act=function() count=count+1;return true end
    local x1,y1=Point(layer.buttons.primary);Pointer('PointerDown',3,x1,y1)
    V.assert(count==1,'center primary operates immediately')
    s.controls:TouchEdit(.29,false);V.assert(count==1,'no repeat before source 300ms')
    s.controls:TouchEdit(.011,false);V.assert(count==2,'source first repeat at 300ms')
    s.controls:TouchEdit(.101,false);V.assert(count==3,'source repeat every 100ms')
    Pointer('PointerCancel',3,x1,y1);s.controls:TouchEdit(1,false);V.assert(count==3 and not s.controls.touchPrimary,'cancel stops held editor operation');s.Act=original
    Click(layer.toggle);Click(layer.menuButtons.inventory);V.assert(s.inventoryPanel~=nil and not layer.menu,'touch inventory opens existing source panel')
    if s.inventoryPanel then s.inventoryPanel:Close() end;s:Refresh()
    local fx,fy=Point(layer.stick);Pointer('PointerDown',7,fx,fy);Pointer('PointerMove',7,fx+20,fy)
    V.assert(layer.gestures:Held('move'),'contact active before focus loss')
    input.focus=false;s.hud.Refresh()
    V.assert(not next(layer.gestures.pointers) and s.buildCamera.touchRight==0 and not s.controls.touchPrimary,'focus loss retires input ownership')
    input.focus=true;s.hud.Refresh()
    Pointer('PointerUp',7,fx,fy);V.assert(not next(layer.gestures.pointers),'late release after focus loss is inert')
    local getViewport=UI.GetViewportSize;local width,height=getViewport();local parts=#s.editor.bp.parts
    Pointer('PointerDown',8,fx,fy);Pointer('PointerMove',8,fx+20,fy)
    UI.GetViewportSize=function() return width+20,height end
    s:Update(0);UI.GetViewportSize=getViewport
    V.assert(layer.disposed and not next(layer.gestures.pointers),'resize disposes old touch contacts')
    V.assert(s.hud.touchControls~=layer and not next(s.hud.touchControls.gestures.pointers) and #s.editor.bp.parts==parts,'resize creates neutral controls and preserves blueprint')
    s:Update(0);layer=s.hud.touchControls;layer.Update(false);UI.Layout()
    local dx,dy=Point(layer.stick);Pointer('PointerDown',9,dx,dy);Pointer('PointerMove',9,dx+20,dy)
    layer.Dispose();V.assert(not next(layer.gestures.pointers) and s.buildCamera.touchRight==0,'dispose releases active contact state')
    input=originalInput
end)

local UI=require 'urhox-libs/UI'
local Host=require 'ui.DialogHost'
local app,s,cam,oldSession
local nativeInput=input
local function Fake(keys,press,buttons)
    return {focus=true,minimized=false,mouseMoveX=0,mouseMoveY=0,mouseMoveWheel=0,
        GetKeyDown=function(_,key) return keys and keys[key] or false end,
        GetKeyPress=function(_,key) return press and press[key] or false end,
        GetMouseButtonDown=function(_,key) return buttons and buttons[key] or false end,
        GetMouseButtonPress=function() return false end}
end
local function WithInput(fake,fn)
    input=fake;local ok,err=pcall(fn);input=nativeInput;if not ok then error(err) end
end
local function Key(key,mods) WithInput(Fake(mods,{[key]=true}),function() s:Keys();s:Refresh() end) end
local function Shot(name)
    local img=Image:new();V.assert(graphics:TakeScreenShot(img) and img:SavePNG('docs/migration/evidence/'..name..'.png'),'rendered '..name);img:Dispose()
end
local function Rules()
    local f=assert(io.open('tools/migration/source-build-camera.json'));local data=cjson.decode(f:read('*a'));f:close()
    local flight=require('controls.FreeFlight').New(data.initial.pos,data.initial.forward,data.initial.limit)
    local mapping={KeyW=KEY_W,KeyA=KEY_A,KeyS=KEY_S,KeyD=KEY_D,KeyQ=KEY_Q,KeyE=KEY_E,KeyR=KEY_R,KeyZ=KEY_Z,Space=KEY_SPACE,ShiftLeft=KEY_SHIFT,ControlLeft=KEY_CTRL}
    local function Near(a,b) for i=1,3 do if math.abs(a[i]-b[i])>1e-7 then return false end end;return true end
    for i,c in ipairs(data.cases) do
        local keys={};for _,name in ipairs(c.keys) do keys[mapping[name]]=true end
        local fake=Fake(keys,nil,{[MOUSEB_LEFT]=c.button});fake.mouseMoveX=c.dx;fake.mouseMoveY=c.dy
        WithInput(fake,function() flight:Step(c.dt,cam:Read()) end)
        V.assert(Near(flight.pos,c.pos) and Near(flight.vel,c.vel) and Near(flight:Forward(),c.forward),'source free camera frame '..i)
    end
end
local function SelectionRules()
    local file=assert(io.open('tools/migration/source-build-selection.json'))
    local data=cjson.decode(file:read('*a'));file:close()
    local bp=require('construction.Blueprint').New()
    for _,spec in ipairs(data.specs) do bp:Add(spec) end
    local tools=require 'construction.SelectionTools';local editor=require('construction.BuildEditor').New(bp)
    local function Ids(parts) local ids={};for _,p in ipairs(parts) do ids[#ids+1]=p.id end;table.sort(ids);return ids end
    local function Same(a,b) if #a~=#b then return false end;for i=1,#a do if a[i]~=b[i] then return false end end;return true end
    for i,c in ipairs(data.volumes) do
        V.assert(Same(Ids(tools.CornerParts(bp,c.a,c.b)),c.ids),'source occupied-cell selection volume '..i)
        V.assert(Same(Ids(tools.CornerParts(bp,c.b,c.a)),c.ids),'source reversed selection volume '..i)
    end
    for i,c in ipairs(data.operations) do
        editor.hit=c.hit~=cjson.null and c.hit or nil
        if c.action=='toggle' then
            local result=editor:ToggleSelectTarget();V.assert(result==c.result,'source explicit selection corner '..i)
        elseif c.action=='sweep' then editor:SweepSelect(c.on)
        elseif c.action=='corner' then editor:SelectCorner()
        elseif c.action=='clear' then editor.selection={};editor:SelectionChanged() end
        V.assert(Same(Ids(editor:Selected()),c.ids),'source selection command '..i)
    end
end
V.atFrame(55,function()
    app=VOX_HANGAR.app;app.inventory=require('construction.Inventory').New()
    app:EnterBuild();s=app.build;cam=s.buildCamera
    -- Validate capture state without changing the user's OS mouse mode.
    cam.SetMouseMode=function(self,mode) self.testMouseMode=mode end
    Rules()
    SelectionRules()
    V.assert(cam.mode=='fp' and not cam.captured,'PC enters current source first-person construction')
    local pos=s.camera.node.position
    cam:Capture();V.assert(cam.mode=='fp' and cam.captured and cam.testMouseMode==MM_RELATIVE,'playfield captures native relative camera state')
    V.assert(s.hud.root.props.pointerEvents=='none','captured mouse cannot activate HUD under the hidden cursor')
    V.assert((s.camera.node.position-pos).length<.001,'camera toggle preserves displayed position')
    cam.skipInput=false
    WithInput(Fake({[KEY_W]=true}),function() cam:Update(.1,false) end)
    V.assert((s.camera.node.position-pos).length>.1,'held manual movement moves real camera')
    cam:Release();local stopped=s.camera.node.position
    WithInput(Fake({[KEY_W]=true}),function() cam:Update(.1,false) end)
    V.assert((s.camera.node.position-stopped).length<.0001,'released capture blocks movement and clears inertia')
    Key(KEY_TAB);V.assert(cam.mode=='fp' and s.editor.tool=='paint','Tab enters paint without switching camera')
    Key(KEY_TAB);V.assert(s.editor.paintChannel=='accent','second Tab selects accent channel')
    Key(KEY_TAB);V.assert(s.editor.paintChannel=='shell','third Tab selects shell channel')
    s.editor:SetTool('build')
    Key(KEY_R,{[KEY_SHIFT]=true});V.assert(s.editor.spin==-1,'Shift R rotates backward')
    Key(KEY_P);V.assert(s.editor.tool=='paint','P enters paint');Key(KEY_P);V.assert(s.editor.tool=='build','P exits paint')
    Key(KEY_X);V.assert(s.editor.tool=='erase','X enters erase');Key(KEY_X);V.assert(s.editor.tool=='build','X exits erase')
    local slot=s.inventory.active;WithInput(Fake(),function() s:Wheel(-1) end);V.assert(s.inventory.active==slot%10+1,'plain wheel cycles hotbar')
    local distance=s.camera.dist;WithInput(Fake({[KEY_SHIFT]=true}),function() s:Wheel(1) end)
    V.assert(s.camera.dist==distance and s.inventory.active==slot%10+1,'modified wheel leaves first-person view and slot unchanged')
    s.editor:SetTool('paint');local channel=s.editor.paintChannel
    s.editor.autoColor=true;WithInput(Fake(),function() s:Wheel(-1) end)
    V.assert(not s.editor.autoColor and s.editor.color==require('Config').PALETTE[1].hex and s.editor.paintChannel==channel,'paint wheel cycles source palette without changing channel')
    WithInput(Fake(),function() s:Wheel(1) end);V.assert(s.editor.autoColor,'paint wheel returns to factory color')
    s.editor:SetTool('build');WithInput(Fake({[KEY_ALT]=true}),function() s:Wheel(-1) end)
    V.assert(s.editor.tool=='build' and not s.editor.autoColor,'Alt wheel changes color without switching build tool')
    local picked=s.editor.bp:List()[1];s.editor:Pick({partId=picked.id})
    V.assert(not s.editor.sampledRot,'middle pick leaves placement orientation face-driven')
    local main=require('parts.Finish').Field(picked,'shell')
    V.assert(s.editor.autoColor==(picked[main]==nil) and (s.editor.autoColor or s.editor.color==picked[main]),'middle pick copies source main color or factory color')
    local scale=s.flyScale;Key(KEY_EQUALS);V.assert(s.flyScale>scale,'equals increases source flight speed step')
    Key(KEY_MINUS);V.assert(s.flyScale==scale,'minus restores source flight speed step')
    local e=s.editor;local oldMove=e.MoveSelection;local delta
    e.MoveSelection=function(_,d) delta=d;return true end;e.selection={[e.bp:List()[1].id]=true}
    s.camera.node.rotation=Quaternion(0,90,0);Key(KEY_UP)
    V.assert(delta[1]==-1 and delta[3]==0,'selection forward follows rotated native camera')
    Key(KEY_RIGHT);V.assert(delta[1]==0 and delta[3]==-1,'selection right follows source handedness')
    Key(KEY_PAGEUP);V.assert(delta[2]==1,'PageUp moves selected parts instead of whole car')
    e.MoveSelection=oldMove;e.selection={}
    cam:Focus();cam:Release();s:Refresh()
end)
V.atFrame(80,function()
    Shot('build-first-person');cam:Capture();s:OpenInventory()
    V.assert(not cam.captured and cam.testMouseMode==MM_ABSOLUTE,'inventory releases cursor before opening')
    s.inventoryPanel:Close();V.assert(not cam.captured,'inventory close requires explicit recapture')
    local before=app.blueprint:Size();s.controls:Down({x=800,y=500})
    V.assert(cam.captured and app.blueprint:Size()==before,'first click recaptures without editing')
    s:Escape();V.assert(not cam.captured and not s.dialog,'first Escape releases capture without opening a menu')
    s:Escape();V.assert(s.dialog~=nil,'second Escape opens existing pause menu');Host.Close(s)
    cam:Capture();WithInput(Fake(),function() cam:Update(.1,true) end)
    V.assert(not cam.captured,'blocked camera input clears capture')
    oldSession=s;app:Reload()
end)
V.atFrame(145,function()
    s=assert(app.build);cam=s.buildCamera;cam.SetMouseMode=function(self,mode) self.testMouseMode=mode end
    V.assert(oldSession.disposed and cam.mode=='fp' and not cam.captured,'F5 restores free camera pose without stealing cursor')
    cam:Focus();cam:Capture();cam.buttonsReady=true
    local Event=require 'urhox-libs/UI/Core/PointerEvent'
    local r=s.hud.hotbar.slots[1].widget:GetAbsoluteLayoutForHitTest();local scale=UI.GetScale();local active=s.inventory.active
    for _,kind in ipairs({'PointerDown','PointerUp'}) do
        UI.HandlePointerEvent(Event.new(kind,{x=(r.x+r.w*.5)*scale,y=(r.y+r.h*.5)*scale,pointerId=77,pointerType='mouse',button=MOUSEB_LEFT}))
    end
    V.assert(s.inventory.active==active,'native pointer dispatch cannot activate hotbar while mouse is captured')
    s:Trace(0,0);local target=s.editor.hit and s.editor.hit.partId;s:Trace(2000,1000)
    V.assert(target and s.editor.hit and s.editor.hit.partId==target,'first-person grid picking uses camera center regardless of pointer coordinates')
    local revision=s.editor.history.revision;local autoColor=s.editor.autoColor
    s.editor:SetTool('paint');s.editor.color=0x12de34;s.editor.autoColor=false
    WithInput(Fake(nil,nil,{[MOUSEB_LEFT]=true}),function() s.controls:Update(.01) end)
    V.assert(s.editor.history.revision>revision,'captured mouse paints actual picked blueprint through command history')
    s.controls:Cancel();s.editor:Undo();s.editor.autoColor=autoColor;s.editor:SetTool('build')
    local before=app.blueprint:Size();local acts=0;local oldAct=s.Act
    s.Act=function() acts=acts+1;return true end
    WithInput(Fake(nil,nil,{[MOUSEB_LEFT]=true}),function() for _=1,10 do s.controls:Update(.05) end end)
    V.assert(acts>=3 and acts<=4,'captured left hold repeats at source cadence')
    s.Act=oldAct;s:OpenPause();V.assert(not cam.captured and not s.controls.pointer and app.blueprint:Size()==before,'menu cancels first-person edit hold')
    Host.Close(s)
    cam:Release();s:Refresh()
end)
V.atFrame(155,function()
    Key(KEY_TAB)
    V.assert(cam.mode=='fp' and not cam.captured and s.editor.tool=='paint','released Tab changes tool without capturing cursor')
    Key(KEY_TAB)
    V.assert(cam.mode=='fp' and not cam.captured and s.editor.paintChannel=='accent','Tab changes channel without orbit toggle')
    cam:Capture()
    s:Escape();V.assert(not cam.captured and not s.dialog,'PC Escape releases capture before opening menu')
    cam:Focus();s:Refresh()
end)
V.atFrame(168,function()
    Shot('build-first-person-released');app:ExitBuild()
    V.assert(not app.build and not app.buildCameraState,'leaving build discards free-camera session state')
    V.finish()
end)
V.atFrame(164,function()
    local e=s.editor;local trace=s.Trace;local targets=e.bp:List();local a,b=targets[1],targets[#targets]
    local target=a
    s.Trace=function() e.hit=target and {partId=target.id,cell={table.unpack(target._cells[1])},normal={0,1,0}} or nil end
    local function Step(buttons,dt) WithInput(Fake(nil,nil,buttons),function() s.controls:Update(dt or .04) end) end
    e:SetTool('build');s.selecting=true;e.selection={};e:SelectionChanged();cam:Capture();cam.buttonsReady=true
    local revision=e.history.revision;local size=e.bp:Size()
    Step({[MOUSEB_LEFT]=true});V.assert(e.selection[a.id] and s.controls.dragSelection,'select press starts source grid drag')
    target=b;Step({[MOUSEB_LEFT]=true});local drag=s.controls.dragSelection
    V.assert(drag.lo and drag.hi and #drag.parts>0,'held crosshair previews occupied-cell volume')
    local count=#drag.parts+#e:Selected();Step({})
    V.assert(not s.controls.dragSelection and #e:Selected()==count,'release commits the preview selection')
    Step({[MOUSEB_RIGHT]=true});V.assert(not e.selection[b.id],'selection right press deselects hit instead of removing')
    target=a;Step({[MOUSEB_RIGHT]=true})
    V.assert(not e.selection[a.id] and e.bp:Size()==size and e.history.revision==revision,'30ms right sweep leaves blueprint and history intact')
    Step({});e.selection={};e:SelectionChanged();target=a;Step({[MOUSEB_LEFT]=true});target=b;Step({[MOUSEB_LEFT]=true})
    e:SelectAll();e:DragPreview(s.controls.dragSelection)
    V.assert(#s.controls.dragSelection.parts==0,'changing selection invalidates cached pending drag even at the same hit cell')
    e.selection={[a.id]=true};e:SelectionChanged();e:DragPreview(s.controls.dragSelection)
    cam:Release();V.assert(not s.controls.dragSelection and not e.selection[b.id],'release capture cancels pending volume instead of committing it')
    cam:Capture();cam.buttonsReady=true;target=nil;Step({[MOUSEB_LEFT]=true});target=a;Step({[MOUSEB_LEFT]=true})
    V.assert(e.selection[a.id] and not s.controls.dragSelection,'pressing empty space does not start a deselection sweep when later crossing a part')
    cam:Release()
    e.selection={};e:SelectionChanged();s.Trace=trace;s.selecting=false;cam:Focus();s:Refresh()
end)
V.atFrame(160,function()
    local file=assert(io.open('docs/migration/evidence/source-build-modes.json'))
    local source=cjson.decode(file:read('*a')).cases.pc.modes;file:close()
    local badge=s.hud.modeBadge;local vg=UI.GetNVGContext();require('ui.SourceDraw').Begin(vg)
    s.editor.color=0xd0182a;s.editor.autoColor=false;s.editor.selection={}
    for _,mode in ipairs({'paint','accent','erase','select'}) do
        s.selecting=false;s.editor:SetTool(mode=='select' and 'build' or mode=='accent' and 'paint' or mode)
        s.selecting=mode=='select';s.editor.paintChannel=mode=='accent' and 'accent' or 'shell';s:Refresh();badge:Update(.6);badge:Layout(vg)
        V.assert(math.abs(badge.badgeWidth-source[mode].badge.rect[3])<.75,'source mode badge width '..mode)
        V.assert(badge.fadeTween.value==1 and badge.offsetTween.value==0,'source badge fully enters '..mode)
        s:Escape();V.assert(not s.dialog and not s.selecting and s.editor.tool=='build','Escape exits '..mode..' before opening pause')
    end
    Key(KEY_Q);Key(KEY_TAB);V.assert(not s.selecting and s.editor.tool=='paint','Tab cancels selection tool before paint')
    Key(KEY_Q);Key(KEY_P);V.assert(not s.selecting and s.editor.tool=='paint','P cancels selection tool before paint')
    Key(KEY_Q);Key(KEY_X);V.assert(not s.selecting and s.editor.tool=='erase','X cancels selection tool before erase')
    s:Escape();s:Refresh();badge:Update(.6);V.assert(badge.fadeTween.value==0 and badge.offsetTween.value==-12,'ordinary placement fades out source badge')
    Key(KEY_TAB);s:Refresh()
end)

-- Frozen mobileEditor.js composition; existing editor commands remain authoritative.
local UI=require 'urhox-libs/UI'
local W=require 'ui.TouchEditorWidgets'
local Layout=require 'ui.TouchEditorLayout'
local Config=require 'Config'
local Ticker=UI.Widget:Extend('VoxTouchEditorTick')
function Ticker:Update(dt) if self.owner then self.owner.Tick(dt) end end
local M={}
function M.Create(session,root,playfield)
    local camera,controls,e=session.camera,session.controls,session.editor
    local width,height=UI.GetViewportSize();local dpr=math.max(1,graphics:GetDPR())
    local cw,ch=graphics:GetWidth()/dpr,graphics:GetHeight()/dpr
    local prefs=session.app.touchPrefs or {build='tap',size=1,sens=1};prefs.build=prefs.build or 'tap'
    local layer={prefs=prefs,buttons={},slots={},sheets={},pointers={},menu=false,blocked=false,statsOpen=false,pickTap=false,colorTap=false,eraseTap=false,time=0,disposed=false}
    layer.focus=function()return input.focus and not input.minimized end
    local container=UI.Panel{position='absolute',width='100%',height='100%',pointerEvents='box-none'};root:AddChild(container);layer.root=container
    local ticker=Ticker{width=0,height=0,pointerEvents='none'};ticker.owner=layer;container:AddChild(ticker)
    local layout=Layout.Calculate(width,height,cw,ch,UI.GetSafeAreaInsets(),prefs.size,prefs.build=='aim');layer.layout=layout
    local s,k=layout.s,layout.k
    local function Close() layer.sheet=nil;layer.statsOpen=false end
    function layer.Clear()
        local ids={};for id in pairs(layer.pointers) do ids[#ids+1]=id end
        for _,id in ipairs(ids) do UI.CancelPointer(id,'touch') end
        layer.pointers={};if layer.gestures then layer.gestures:Reset() end
        if layer.press then layer.press:SetVisible(false) end
        controls:Cancel();session.buildCamera.held={};session.buildCamera.touchRight=0;session.buildCamera.touchForward=0
    end
    local function Ready() return not layer.disposed and not layer.blocked and not session.dialog and not session.inventoryPanel and layer.focus() end
    local function CenterTarget() if controls.TouchTarget then controls:TouchTarget(width/2,height/2) else session:Trace(width/2,height/2) end end
    function layer.EditAt(x,y,button)
        if controls.TouchTarget then controls:TouchTarget(x,y) else session:Trace(x,y) end
        if button==0 and layer.colorTap then e:Eyedrop(e.hit);layer.colorTap=false
        elseif button==0 and layer.pickTap then e:Pick(e.hit);layer.pickTap=false
        elseif controls.TouchAt then controls:TouchAt(x,y,button)
        elseif button==2 then e:Remove() else session:Act() end
        session:Refresh()
    end
    function layer.Action(name,value)
        if layer.disposed then return end
        local keep=name=='me-color' or name=='me-channel' or name=='me-xray' or name=='me-form' or name=='me-mode'
        local toggle=({['me-tools']='tools',['me-paint']='paint',['me-more']='more'})[name]
        if toggle then local was=layer.sheet==toggle;Close();layer.sheet=not was and toggle or nil
        elseif name=='me-stats' then local was=layer.statsOpen;Close();layer.statsOpen=not was
        else
            if not keep then Close() end
            controls:Cancel();UI.ClearFocus()
            if name=='me-back' then session.app:ExitBuild();return
            elseif name=='me-test' then session.app:EnterTrial();return
            elseif name=='me-save' then session:SaveSlot()
            elseif name=='me-undo' then e:Undo()
            elseif name=='me-redo' then e:Redo()
            elseif name=='me-liftUp' then e:Lift(1)
            elseif name=='me-liftDown' then e:Lift(-1)
            elseif name=='me-lesson' then session.buildCamera:Release();session.app.tutorial:Replay()
            elseif name=='me-settings' then require('ui.GameSettings').Open(session)
            elseif name=='me-tool' then session.selecting=value=='select';e:SetTool(value=='select' and 'build' or value)
            elseif name=='me-slot' then if session.inventory.hotbar[value] then session:SelectHotbar(value) else session:OpenInventory() end
            elseif name=='me-bag' then session:OpenInventory()
            elseif name=='me-rotate' then e:Rotate(1)
            elseif name=='me-mirror' then e.mirror=not e.mirror
            elseif name=='me-xray' then session:ToggleXray()
            elseif name=='me-form' then session:ToggleForm()
            elseif name=='me-color' then e.autoColor=value=='auto';if not e.autoColor then e.color=value end;e.dirty=true
            elseif name=='me-channel' then e.paintChannel=value=='accent' and 'accent' or 'shell';e.dirty=true
            elseif name=='me-eyedrop' then layer.colorTap=not layer.colorTap;layer.pickTap=false;layer.eraseTap=false;if prefs.build=='aim' and layer.colorTap then CenterTarget();e:Eyedrop(e.hit);layer.colorTap=false end
            elseif name=='me-pick' then if prefs.build=='tap' then layer.pickTap=not layer.pickTap;layer.colorTap=false else CenterTarget();e:Pick(e.hit) end
            elseif name=='erase' then layer.eraseTap=not layer.eraseTap;layer.pickTap=false
            elseif name=='me-mode' then
                layer.Clear();prefs.build=value or (prefs.build=='tap' and 'aim' or 'tap')
                if session.app.SaveTouchPrefs then session.app:SaveTouchPrefs(prefs) end
            end
        end
        if not session.disposed then session:Refresh() end
    end
    local function Button(parent,id,icon,text,kind,value)
        local b=W.Button{position='absolute',sourceScale=s,icon=icon,text=text or '',kind=kind,padding=0,minWidth=0,minHeight=0,
            onClick=function() if not layer.blocked then layer.Action(id,value) end end}
        parent:AddChild(b);return b
    end
    local specs={
        {'me-back','back','机库','row'},{'me-stats',nil,'','chip'},
        {'me-liftUp','liftUp','抬高','row'},{'me-liftDown','liftDown','放低','row'},
        {'me-undo','undo','','row'},{'me-redo','redo','','row'},{'me-test','wheel','试车','row'},
        {'me-save','save','保存','row'},{'me-more','list','更多'},
        {'me-rotate','rotate','旋转'},{'me-mirror','mirror','镜像'},{'me-pick','eyedrop','吸取'},
        {'primary','build','放置'},{'erase','erase','删除'},{'up','chev','镜头升'},{'down','chev','镜头降'},
        {'me-tools','build','建造','square'},{'me-bag','cube','背包','square'},{'me-paint',nil,'颜色','square'}
    }
    local dock=W.Surface{position='absolute',sourceScale=s,kind='dock',pointerEvents='none'};container:AddChild(dock);layer.dock=dock
    layer.separators={};for i=1,2 do local sep=W.Surface{position='absolute',sourceScale=s,kind='separator',pointerEvents='none'};container:AddChild(sep);layer.separators[i]=sep end
    local label=W.Surface{position='absolute',sourceScale=s,kind='label',text='车高',pointerEvents='none'};container:AddChild(label);layer.liftLabel=label
    local hint=W.Surface{position='absolute',sourceScale=s,kind='hint',pointerEvents='none'};container:AddChild(hint);layer.hint=hint
    local press=W.Surface{position='absolute',sourceScale=s,kind='press',visible=false,pointerEvents='none'};container:AddChild(press);layer.press=press
    for _,spec in ipairs(specs) do
        local b=Button(container,spec[1],spec[2],spec[3],spec[4]=='row' and 'action' or spec[4]);b.props.row=spec[4]=='row';b.props.primary=spec[1]=='me-save';b.props.more=spec[1]=='me-tools' or spec[1]=='me-paint';b.props.flip=spec[1]=='up'
        layer.buttons[spec[1]]=b
    end
    for i=1,10 do layer.slots[i]=Button(container,'me-slot',nil,'','slot',i) end
    local tools={{'build','build','建造','点车身放零件 · 长按删掉'},{'select','select','选择','点零件选中 · 拖动框选一片'},{'paint','brush','上色','点车身涂当前颜色'},{'stretch','ruler','拉伸','一次拉出一整排方块'}}
    local function Sheet(id,title,en)
        local p=W.Surface{position='absolute',sourceScale=s,kind='sheet',text=title,en=en,pointerEvents='auto',visible=false};container:AddChild(p);layer.sheets[id]=p;return p
    end
    local toolSheet=Sheet('tools','工具','TOOLS');layer.toolRows={}
    for i,t in ipairs(tools) do local b=Button(toolSheet,'me-tool',t[2],t[3],'row',t[1]);b.props.detail=t[4];b:SetStyle{left=8*s,top=(41+(i-1)*45)*s,width=304*s,height=40*s};layer.toolRows[t[1]]=b end
    local more=Sheet('more','更多','MORE');layer.moreRows={}
    for i,t in ipairs({{'me-xray','eye','透视'},{'me-form','cube','连块放置'},{'me-mode','build','建造方式'},{'me-lesson','help','重看改车教学'},{'me-settings','gear','设置','画面 · 声音 · 触屏'}}) do
        local b=Button(more,t[1],t[2],t[3],'row');b.props.detail=t[4];b:SetStyle{left=8*s,top=(41+(i-1)*45)*s,width=288*s,height=40*s};layer.moreRows[t[1]]=b
    end
    layer.modeButtons={}
    for i,t in ipairs({{'tap','点哪放哪'},{'aim','准星'}}) do local b=Button(more,'me-mode',nil,t[2],'segment',t[1]);b:SetStyle{left=(134+(i-1)*78)*s,top=137*s,width=76*s,height=28*s};layer.modeButtons[t[1]]=b end
    local paint=Sheet('paint','颜色','PAINT');layer.swatches={};layer.channels={}
    local entries={{hex=0x8a96a3,auto=true}};for _,c in ipairs(Config.PALETTE) do entries[#entries+1]=c end
    for i,c in ipairs(entries) do local b=Button(paint,'me-color',nil,'','swatch',c.auto and 'auto' or c.hex);b.props.hex=c.hex;b.props.auto=c.auto;b:SetStyle{left=(12+(i-1)%9*35)*s,top=(45+math.floor((i-1)/9)*35)*s,width=30*s,height=30*s};layer.swatches[i]=b end
    local colorRows=math.ceil(#entries/9);layer.paintHeight=45+colorRows*35+54
    for i,t in ipairs({{'shell','主色'},{'accent','装饰色'}}) do local b=Button(paint,'me-channel',nil,t[2],'segment',t[1]);b:SetStyle{left=(196+(i-1)*60)*s,top=4*s,width=58*s,height=27*s};layer.channels[t[1]]=b end
    layer.eyedrop=Button(paint,'me-eyedrop','eyedrop','从车上吸取颜色','row');layer.eyedrop.props.detail='点一下车身';layer.eyedrop:SetStyle{left=8*s,top=(45+colorRows*35+4)*s,width=324*s,height=40*s}
    local adapter={mode='edit',floating=true,width=cw,height=ch,sensitivity=prefs.sens or 1,
        Move=function(x,y) session.buildCamera.touchRight=x;session.buildCamera.touchForward=y end,
        Look=function(dx,dy)
            if session.buildCamera.mode=='fp' then local f=session.buildCamera;f.dx=f.dx+dx;f.dy=f.dy+dy;return end
            camera.flight=false;camera.autoSpin=false;camera.yaw=camera.yaw+math.deg(dx*.005);camera.pitch=math.max(90-math.deg(1.62),math.min(90-math.deg(.12),camera.pitch+math.deg(dy*.004)))
        end,
        Zoom=function(delta) if session.buildCamera.mode=='orbit' then camera.flight=false;camera.autoSpin=false;camera.dist=math.max(camera.minDist,math.min(camera.maxDist,camera.dist*1.0012^delta)) end end,
        Pan=function(dx,dy) if session.buildCamera.mode=='orbit' then local rot=camera.node.rotation;local amount=camera.dist*.0014;local target=camera.target-rot*Vector3.RIGHT*(dx*amount)+rot*Vector3.UP*(dy*amount);camera.target=Vector3(target.x,math.max(0,math.min(camera.panMaxY,target.y)),target.z) end end,
        Hold=function(action,on,cancelled)
            if action=='up' or action=='down' then session.buildCamera.held[action]=on;return true end
            if action=='primary' then controls:TouchPrimary(on,cancelled);return true end
            if action=='erase' and prefs.build=='aim' then controls:TouchErase(on,cancelled);return true end
            return false
        end,
        Action=function(id) layer.Action(id) end}
    local stick=require('ui.SourceTouchDriveWidgets').Stick{position='absolute',pointerEvents='none'};container:AddChild(stick);layer.stick=stick
    adapter.PlaceStick=function(r,live)stick:SetStyle{left=r.x*k,top=r.y*k,width=r.w*k,height=r.h*k};stick.live=live end
    adapter.HomeStick=function()stick:SetStyle(layer.layout.stick);stick.live=false end
    local move=adapter.Move;adapter.Move=function(x,y)stick.axisX=x;stick.axisY=-y;move(x,y)end
    local gesture=require('controls.TouchGestures').New(adapter);layer.gestures=gesture
    local fixedChildren={layer.eyedrop}
    for _,group in ipairs({layer.toolRows,layer.moreRows,layer.modeButtons,layer.channels,layer.swatches}) do for _,child in pairs(group) do fixedChildren[#fixedChildren+1]=child end end
    local function Target(x,y) if controls.TouchTarget then controls:TouchTarget(x*k,y*k) end end
    local function Bind(widget,id)
        widget.OnPointerDown=function(_,ev)
            if not ev:IsTouch() or not Ready() then return end;ev:StopPropagation();ev:PreventDefault()
            if id=='look' and (layer.sheet or layer.statsOpen) then Close();session:Refresh();return end
            if session.buildCamera.mode=='fp' and not session.buildCamera.captured then session.buildCamera:Capture() end
            local x,y=ev.x/k,ev.y/k;local action=id
            if id=='look' then
                local z=layer.layout.zone
                if x>=z[1] and x<=z[3] and y>=z[2] and y<=z[4] then action='move'
                elseif prefs.build=='tap' then local found=false;for _,p in pairs(layer.pointers) do if p.action=='tap' or p.action=='look' then found=true end end;if not found then action='tap' end end
            end
            if action=='tap' then layer.pointers[ev.pointerId]={action='tap',x=x,y=y,ox=x,oy=y,at=layer.time};Target(x,y);press:SetStyle{left=ev.x-27*s,top=ev.y-27*s,width=54*s,height=54*s};press.props.progress=0;press:SetVisible(true)
            else
                local r=action=='move' and layer.layout.stick or widget:GetAbsoluteLayoutForHitTest()
                gesture:Down(action,ev.pointerId,x,y,{x=(r.left or r.x)/k,y=(r.top or r.y)/k,w=(r.width or r.w)/k,h=(r.height or r.h)/k});layer.pointers[ev.pointerId]={action=action}
            end
            widget.touchHeld=true
        end
        widget.OnPointerMove=function(_,ev)
            local p=layer.pointers[ev.pointerId];if not p then return end;ev:StopPropagation();local x,y=ev.x/k,ev.y/k
            if p.action=='tap' then
                if (x-p.ox)^2+(y-p.oy)^2<144 then p.x=x;p.y=y;Target(x,y);return end
                gesture:Down('look',ev.pointerId,p.x,p.y,{});p.action='look';press:SetVisible(false);controls:Cancel()
            end
            gesture:Move(ev.pointerId,x,y)
        end
        local function End(widget,ev,cancelled)
            local p=layer.pointers[ev.pointerId];if not p then return end;ev:StopPropagation();layer.pointers[ev.pointerId]=nil
            if p.action=='tap' then if not cancelled and not p.long then layer.EditAt(p.x*k,p.y*k,layer.eraseTap and 2 or 0) end;press:SetVisible(false);controls:Cancel();session:Refresh()
            else gesture:Up(ev.pointerId,ev.x/k,ev.y/k,cancelled) end
            widget.touchHeld=false
        end
        widget.OnPointerUp=function(w,ev)End(w,ev,false)end;widget.OnPointerCancel=function(w,ev)End(w,ev,true)end
        if id=='look' then widget.props.onPointerLeave=nil;widget.props.onPointerEnter=nil end
    end
    Bind(playfield,'look');for _,id in ipairs({'primary','erase','up','down'}) do Bind(layer.buttons[id],id) end
    function layer.Tick(dt)
        if layer.disposed then return end;layer.time=layer.time+math.max(0,dt)
        if not Ready() then if next(layer.pointers) then layer.Clear() end;return end
        for _,p in pairs(layer.pointers) do if p.action=='tap' then
            press.props.progress=math.min(1,(layer.time-p.at)/.45)
            if not p.long and layer.time-p.at>=.45 then p.long=true;p.next=layer.time+.25;layer.EditAt(p.x*k,p.y*k,2)
            elseif p.long and layer.time>p.next then p.next=layer.time+.25;layer.EditAt(p.x*k,p.y*k,2) end
        end end
    end
    local toolsOf={build={'build','建造'},erase={'build','建造'},select={'select','选择'},paint={'brush','上色'},stretch={'ruler','拉伸'}}
    function layer.Update(blocked)
        if layer.disposed then return end
        if blocked and not layer.blocked then layer.Clear() end;layer.blocked=blocked;container:SetVisible(not blocked);playfield:SetVisible(not blocked)
        local name=e.bp.name or '';local nameWidth=math.min(120,(utf8.len(name) or #name)*15);local stats=session.inspection:Get().stats;local budget=tostring(math.floor(stats.budget or 0))
        local chipWidth=10+26+8+nameWidth+8+(cw<=760 and 0 or 26)+#budget*9+8+18+12
        layout=Layout.Calculate(width,height,cw,ch,UI.GetSafeAreaInsets(),prefs.size,prefs.build=='aim',chipWidth);layer.layout=layout
        if s~=layout.s then
            local ratio=layout.s/s
            for _,child in ipairs(fixedChildren) do
                local p=child.props;child:SetStyle{left=p.left*ratio,top=p.top*ratio,width=p.width*ratio,height=p.height*ratio};p.sourceScale=layout.s
            end
            s=layout.s
        end
        adapter.sensitivity=prefs.sens or 1
        for _,surface in ipairs({dock,label,hint,press}) do surface.props.sourceScale=s end
        for id,b in pairs(layer.buttons) do local r=layout.buttons[id];b:SetVisible(r~=nil);if r then b:SetStyle(r) end;b.props.narrow=layout.narrow and (id=='me-back' or id=='me-test' or id=='me-save');b.props.sourceScale=layout.s end
        layer.dock:SetStyle(layout.dock);layer.liftLabel:SetVisible(layout.liftLabel~=nil);if layout.liftLabel then layer.liftLabel:SetStyle(layout.liftLabel) end;hint:SetStyle(layout.hint)
        for i,sep in ipairs(layer.separators) do sep:SetStyle(layout.separators[i]) end
        local part=require('parts.Defs').PARTS[e.type];local color='原色';for _,c in ipairs(Config.PALETTE) do if not e.autoColor and c.hex==e.color then color=c.name;break end end
        local tool=session.selecting and 'select' or e.tool;local t=toolsOf[tool] or toolsOf.build
        layer.hint.props.text=layer.pickTap and '点一下车身吸取零件' or layer.colorTap and '点一下车身吸取颜色' or (t[2]..' · '..(part and part.name or '')..' · '..color)
        local info=layer.buttons['me-stats'].props;info.text=name;info.nameWidth=math.max(0,math.min(nameWidth,layout.buttons['me-stats'].width/s-(layout.narrow and 124 or 150)));info.narrow=layout.narrow;info.budget=budget;info.tier='T'..tostring((stats.fitTier or {}).id or 1);info.selected=layer.statsOpen
        layer.buttons['me-tools'].props.icon=t[1];layer.buttons['me-tools'].props.text=t[2];layer.buttons['me-tools'].props.selected=layer.sheet=='tools'
        layer.buttons['me-paint'].props.hex=e.autoColor and 0x8a96a3 or e.color;layer.buttons['me-paint'].props.auto=e.autoColor;layer.buttons['me-paint'].props.selected=layer.sheet=='paint'
        layer.buttons['me-more'].props.selected=layer.sheet=='more';layer.buttons['me-mirror'].props.selected=e.mirror;layer.buttons['me-pick'].props.selected=layer.pickTap;layer.buttons.erase.props.selected=layer.eraseTap
        for i,b in ipairs(layer.slots) do local r=layout.slots[i];b:SetVisible(r~=nil);if r then b:SetStyle(r) end;b.props.sourceScale=s;b.props.partType=session.inventory.hotbar[i];b.props.selected=i==session.inventory.active end
        for id,p in pairs(layer.sheets) do p.props.sourceScale=s;p:SetVisible(layer.sheet==id);local r=layout.sheets[id];if id=='paint' then r.height=layer.paintHeight*s;r.top=height-(UI.GetSafeAreaInsets().bottom or 0)-68*s-r.height end;p:SetStyle(r) end
        for id,b in pairs(layer.toolRows) do b.props.selected=id==(tool=='erase' and 'build' or tool) end
        layer.moreRows['me-xray'].props.toggle=session.app.buildXray==true;layer.moreRows['me-form'].props.toggle=e.joinNew
        for id,b in pairs(layer.modeButtons) do b.props.selected=id==prefs.build end
        for id,b in pairs(layer.channels) do b.props.selected=id==(e.paintChannel or 'shell') end
        for i,b in ipairs(layer.swatches) do b.props.selected=e.autoColor and i==1 or not e.autoColor and i>1 and b.props.hex==e.color end
        layer.eyedrop.props.selected=layer.colorTap
        if not gesture:Held('move') then stick:SetStyle(layout.stick);stick.live=false end
        stick:SetVisible(not blocked);stick.props.touchScale=k
    end
    function layer.Snapshot()
        local out={sheet=layer.sheet,statsOpen=layer.statsOpen,build=prefs.build,buttons={},slots={},sheets={},pickTap=layer.pickTap,colorTap=layer.colorTap,layout=layer.layout}
        local function Rect(widget) local r=widget:GetAbsoluteLayoutForHitTest();return {x=r.x,y=r.y,w=r.w,h=r.h} end
        for id,b in pairs(layer.buttons) do if b.props.visible~=false then out.buttons[id]=Rect(b) end end
        for i,b in ipairs(layer.slots) do if b.props.visible~=false then out.slots[i]=Rect(b) end end
        for id,b in pairs(layer.sheets) do if b.props.visible~=false then out.sheets[id]=Rect(b) end end;return out
    end
    function layer.Dispose() if layer.disposed then return end;layer.Clear();layer.disposed=true;ticker.owner=nil end
    layer.Update(false);return layer
end
return M

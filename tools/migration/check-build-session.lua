local app,session,editor,before,added,kept,saved,oldGhost,refreshGhost
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image) and image:SavePNG('docs/migration/evidence/build-'..name..'.png'),'rendered '..name);image:Dispose()
end
local function PickValid()
    local UI=require 'urhox-libs/UI';local w,h=UI.GetViewportSize()
    for y=.35,.72,.025 do for x=.32,.68,.025 do
        if session.buildCamera.mode=='fp' then
            -- Aim the free camera at each source-space grid candidate; FP rays
            -- originate at the crosshair, so varying screen XY cannot aim it.
            local st=editor.bp:Stats();local b=st.bb
            local target=Vector3(-(b.minX+(b.maxX-b.minX)*x)*require('Config').CELL,
                (b.minY+(b.maxY-b.minY)*y+.5)*require('Config').CELL,(b.minZ+b.maxZ)*.5*require('Config').CELL)
            local f=session.buildCamera.flight;local p=session.camera.node.position
            local forward=(target-p):Normalized()
            f.yaw=math.atan(forward.x,-forward.z);f.pitch=math.asin(forward.y);session.buildCamera:Apply()
        end
        session:Trace(x*w,y*h)
        if editor.preview and editor.preview.res and editor.preview.res.ok then
            session.controls.x=x*w;session.controls.y=y*h;session.controls.inside=true;session:Refresh();return true
        end
    end end
    return false
end
V.atFrame(55,function()
    app=VOX_HANGAR.app;app.store=require('storage.BlueprintStore').New('vox-build-session-test')
    app.bays.store=app.store;app.bays.active=false
    for _,key in ipairs({'draft','slot1'}) do for _,suffix in ipairs({'-a.json','-b.json'}) do
        local path=app.store.prefix..key..suffix;if fileSystem:FileExists(path) then fileSystem:Delete(path) end
    end end
    V.assert(app:EnterBuild(),'enter native build from authored hall')
    session=app.build;editor=app.editor;before=app.blueprint:Size()
    editor:SelectType('cube');editor.mirror=true;kept=app.car.visuals[1].node
    V.assert(PickValid(),'camera screen ray offers a connected build location')
    refreshGhost=session.ghost.Refresh;session.ghost:Refresh(editor,true);session.ghost.Refresh=function() end
end)
V.atFrame(69,function()
    -- Hidden runtime has no focused desktop pointer. Freeze only the render
    -- snapshot here; input cancellation itself is tested separately below.
    V.assert(#session.ghost.pool>0,'valid preview retains native renderable model before capture')
end)
V.atFrame(70,function() Shot('preview');added=editor.bp.nextId
    session.ghost.Refresh=refreshGhost
    local stale=editor.preview
    V.assert(session:Act() and editor.bp:Size()>before,'place native part from actual ray')
    editor.preview=stale;local count=editor.bp:Size();local history=#editor.history.undoStack
    V.assert(not editor:Place() and editor.bp:Size()==count and #editor.history.undoStack==history,'stale occupied preview cannot create overlap or history')
    V.assert(app.car.visuals[added]~=nil and app.car.visuals[1].node==kept,'incremental add preserves unrelated native rig')
    editor.selection={[added]=true};local node=app.car.visuals[added].node
    local part=editor.bp.parts[added];local delta
    for _,dy in ipairs({1,4,8,16}) do
        local res=editor.bp:Check(part.type,{part.pos[1],part.pos[2]+dy,part.pos[3]},part.rot,editor.bounds,{[added]=true},false)
        if res.ok then delta={0,dy,0};break end
    end
    V.assert(delta~=nil and editor:MoveSelection(delta) and app.car.visuals[added].node==node,'legal move changes transform without model recreation')
    editor:Undo();editor:Redo();editor:Undo()
    V.assert(app.car.visuals[added]~=nil,'undo redo movement preserves visual')
    editor:Undo();V.assert(not app.car.visuals[added] and editor.bp:Size()==before,'undo placement removes matching visual')
    editor:Redo();V.assert(app.car.visuals[added]~=nil,'redo restores stable ID')
    local weapon
    for _,p in ipairs(editor.bp:List()) do if require('parts.Finish').HasShell(p.type) then weapon=p;break end end
    V.assert(weapon~=nil,'starter has dual-channel equipment')
    if weapon then
        editor:SetTool('paint');editor.mirror=false;editor.hit={partId=weapon.id};editor.paintChannel='shell';editor.color=0x2f8cff;editor:Paint()
        local vis=app.car.visuals[weapon.id]
        V.assert(vis.shellMaterial~=nil and weapon.shellColor==0x2f8cff,'shell painting updates owned material')
        local material=vis.shellMaterial
        for i=1,40 do editor.color=i*2000;editor:Paint() end
        V.assert(vis.shellMaterial==material,'repeated shell colors reuse one owned material')
        for i=1,40 do editor:Undo() end
        V.assert(weapon.shellColor==0x2f8cff,'shell undo restores prior finish')
    end
    editor:SelectType('cube');PickValid();session:SaveSlot();saved=cjson.encode(editor.bp:ToTable())
    V.assert(app.store:LoadSlot(1)~=nil and app.store:Read('draft')~=nil,'engine file slots and draft persist')
    session.controls:Cancel();session:Refresh()
end)
V.atFrame(81,function()
    local ghost=session.ghost;local preview=editor.preview;local items={}
    for i=1,128 do items[i]={type='cube',pos={i%16,8,i//16},rot=require('core.Rotations').IDENTITY,res={ok=true,cells={{i%16,8,i//16}}}} end
    editor.preview={paste=items,ok=true};ghost:Refresh(editor,true)
    V.assert(#ghost.pool==ghost.limit and ghost.cellCount==128,'large paste limits detailed models but preserves occupancy outlines')
    editor.preview=nil;ghost:Refresh(editor,false);V.assert(#ghost.pool==0,'hidden preview releases every unused model slot')
    editor.preview=preview
    local data=app.blueprint:ToTable();V.assert(app.store:Write('slot1',data),'write second storage generation')
    local corrupt=File(app.store.prefix..'slot1-b.json',FILE_WRITE);corrupt:WriteString('{broken');corrupt:Dispose()
    V.assert(app.store:LoadSlot(1)~=nil,'torn latest write recovers previous valid generation')
    local current=cjson.encode(app.blueprint:ToTable())
    V.assert(not app:LoadBlueprint({parts={{'cube','bad',0,0,10}}}) and cjson.encode(app.blueprint:ToTable())==current,'malformed slot cannot clear active blueprint')
    require('ui.GarageDialogs').Code(session,true);V.assert(session.dialog~=nil,'source blueprint dialog opens')
    local content=session.dialog.contentContainer_;session.dialog:Close()
    V.assert(session.dialog==nil and session.closingDialog and content.node,'dialog closes input immediately and keeps the source exit animation')
    require('ui.DialogHost').Update(session,.16)
    V.assert(not session.closingDialog and not content.node,'160 ms source exit releases overlay and content layout')
    local function Event(x,y,kind,touch)
        return {x=x,y=y,pointerId=99,IsTouch=function() return touch end,IsPrimaryButton=function()return not touch and kind=='left'end,IsSecondaryButton=function()return not touch and kind=='right'end}
    end
    local controls=session.controls;local x,y=500,300;local n=editor.bp:Size()
    controls:Down(Event(x,y,'right',false));controls:Move(Event(x+40,y+20,'right',false));controls:Up(Event(x+40,y+20,'right',false))
    V.assert(editor.bp:Size()==n,'right drag orbits without deleting')
    controls:Down(Event(x,y,'left',true));controls:Move(Event(x+40,y+20,'left',true));controls:Up(Event(x+40,y+20,'left',true))
    V.assert(editor.bp:Size()==n,'touch drag orbits without accidental placement')
    editor.selection={};session:BoxSelect({x0=0,y0=0,x1=100000,y1=100000})
    V.assert(#editor:Selected()==editor.bp:Size(),'native projection box selects visible car cells');editor.selection={}
    controls:Cancel();local history=#editor.history.undoStack;controls:Update(1)
    V.assert(not controls.pointer and #editor.history.undoStack==history,'cancel releases repeat editing')
    local previous=app.camera.yaw;app.camera.yaw=140;app.camera.cur.yaw=140;app.camera.pitch=19;app.camera.cur.pitch=19;app.camera:Apply()
    session:Refresh()
end)
V.atFrame(85,function()
    Shot('edited');oldGhost=session.ghost
    app:Reload()
end)
V.atFrame(145,function()
    V.assert(app.build~=nil and app.build.ghost~=oldGhost,'reload replaces preview owner')
    V.assert(cjson.encode(app.blueprint:ToTable())==saved,'reload retains edited blueprint')
    session=app.build;editor=app.editor
    local history=#editor.history.undoStack
    session.controls:Cancel();session.controls:Update(.5)
    V.assert(#editor.history.undoStack==history,'cancelled pointer cannot continue edits')
    V.assert(app:EnterTrial(),'edited blueprint enters same-app trial')
end)
V.atFrame(245,function()
    V.assert(app.mode=='trial' and not app.build,'trial unloads build preview and controls')
    V.assert(cjson.encode(app.blueprint:ToTable())==saved,'trial retains source build configuration')
    app:Reload()
end)
V.atFrame(325,function()
    V.assert(app.build~=nil and app.mode=='hangar','return from trial restores building')
    V.assert(cjson.encode(app.blueprint:ToTable())==saved,'trial round trip preserves edited vehicle')
    local e=app.editor;e.selection={[added]=true};e:DeleteSelection();V.assert(not e.bp.parts[added],'slot restore setup mutates vehicle')
    app.build:LoadSlot()
    V.assert(cjson.encode(app.blueprint:ToTable())==saved,'saved native vehicle reloads identically')
    local rot=require('core.Rotations').IDENTITY
    V.assert(app:LoadBlueprint({v=1,name='legacy notices',parts={{'hover',0,4,0,rot},{'cube',0,4,0,rot},{'hover',12,4,0,rot}}}),'legacy save loads through application')
    V.assert(app.blueprint.dropped==1 and #app.blueprint.migrationWarnings==2,'application retains migration and dropped-part notices')
    app:LoadBlueprint(cjson.decode(saved))
    app:ExitBuild();V.assert(not app.build and not app.buildWanted,'leave build disposes preview')
    V.finish()
end)

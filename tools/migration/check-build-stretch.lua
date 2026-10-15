local Blueprint=require 'construction.Blueprint'
local Editor=require 'construction.BuildEditor'
local Stretch=require 'construction.BuildStretch'
local History=require 'construction.EditHistory'
local UI=require 'urhox-libs/UI'
local nativeInput=input
local function Equal(a,b)
    if a==cjson.null or a==false then a=nil end;if b==cjson.null or b==false then b=nil end
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<1e-6 end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k,v in pairs(b) do if not Equal(a[k],v) then return false end end
    return true
end
local function BP(specs) local bp=Blueprint.New();for _,p in ipairs(specs) do bp:Add(p) end;return bp end
local function Canonical(bp)
    local parts={};for _,p in ipairs(bp:List()) do local data=History.Snapshot(p);data.g=p.g or 0;data.shellColor=p.shellColor or cjson.null;parts[#parts+1]=data end
    return parts
end
local function Fake(press,buttons,buttonPress)
    return {focus=true,minimized=false,mouseMoveWheel=0,
        GetKeyDown=function() return false end,GetKeyPress=function(_,k) return press and press[k] or false end,
        GetMouseButtonDown=function(_,k) return buttons and buttons[k] or false end,
        GetMouseButtonPress=function(_,k) return buttonPress and buttonPress[k] or false end}
end
local function WithInput(fake,fn)
    input=fake;local ok,err=pcall(fn);input=nativeInput;if not ok then error(err) end
end
local function Rules()
    local file=assert(io.open('tools/migration/source-build-stretch.json'));local f=cjson.decode(file:read('*a'));file:close()
    local differences={}
    for i,c in ipairs(f.rays) do
        local s=c.s;s.a=s.a+1
        V.assert(Equal(Stretch.PlaneCell(s,c.origin,c.direction),c.cell),'frozen source horizontal plane ray '..i)
        V.assert(Equal(Stretch.HeightAlong(s,c.origin,c.direction),c.height),'frozen source closest height ray '..i)
        V.assert(Equal(Stretch.Cells(s),c.cells),'frozen source rectangle cells '..i)
    end
    for i,c in ipairs(f.extrusions) do
        local bp=BP(c.specs);local e=Editor.New(bp);e.mirror=c.mirror
        local seeds={};for _,id in ipairs(c.ids) do seeds[#seeds+1]=bp.parts[id];e.selection[id]=true end
        local plan=Stretch.ExtrusionPlan(e,seeds,c.n,c.h)
        local function Normalize(items) for _,p in ipairs(items) do p.g=p.g or 0;p.shellColor=p.shellColor or cjson.null end end
        Normalize(plan.items);Normalize(c.plan.items)
        V.assert(Equal(plan,c.plan),'frozen source complete extrusion plan '..i)
        if not Equal(plan,c.plan) and #differences<3 then differences[#differences+1]={case=i,actual=plan,expected=c.plan} end
        local before=Canonical(bp);local nextId=bp.nextId
        e.stretch={phase='selection',seeds=seeds,n=c.n,h=c.h};local ok=Stretch.Commit(e)
        if c.after then
            V.assert(ok and Equal(Canonical(bp),c.after),'frozen source extrusion transaction '..i)
            local ids={};for id in pairs(e.selection) do ids[#ids+1]=id end;table.sort(ids)
            V.assert(Equal(ids,c.selection),'frozen source selection after extrusion '..i)
            V.assert(#e.history.undoStack==1 and e:Undo() and Equal(Canonical(bp),before),'whole extrusion undone once '..i)
            V.assert(e:Redo() and Equal(Canonical(bp),c.after),'whole extrusion redone once '..i)
            V.assert(Equal(Canonical(Blueprint.New():Load(bp:ToTable())),c.after),'extrusion save/reload with source group metadata '..i)
        else
            V.assert(not ok and Equal(Canonical(bp),before) and bp.nextId==nextId and #e.history.undoStack==0,'failed extrusion leaves both sides and history unchanged '..i)
        end
    end
    for i,c in ipairs(f.rectangles) do
        local bp=BP(c.specs);local e=Editor.New(bp);e.mirror=c.mirror;e.autoColor=true
        local s=c.s;s.a=s.a+1;e.stretch=s
        local before=Canonical(bp);local ok=Stretch.Commit(e)
        V.assert(Equal(Canonical(bp),c.after) and #e.history.undoStack==c.history,'frozen source mirrored rectangle transaction '..i)
        if ok then V.assert(e:Undo() and Equal(Canonical(bp),before) and e:Redo() and Equal(Canonical(bp),c.after),'rectangle is one undo/redo '..i) end
    end
    local out=assert(io.open('.tmp/build-stretch-differences.json','w'));out:write(cjson.encode(differences));out:close()
    local e=Editor.New(Blueprint.New());e.mirror=false;e:SetTool('stretch');e:SelectType('core');e:SetTool('stretch')
    e:Preview({place={0,4,0},cell={0,3,0},normal={0,1,0}})
    V.assert(not e:Act() and not e.stretch and e.bp:Size()==0,'devices cannot start rectangle stretch')
    e:SelectType('cube');e:SetTool('stretch')
    e.preview={type='cube',pos={3,5,0},rot=require('core.Rotations').IDENTITY,normal={0,1,0},res={ok=true}}
    V.assert(e:Act() and e.stretch.phase=='rect' and e.bp:Size()==0,'first click only starts rectangle')
    V.assert(e:Act() and e.stretch.phase=='height' and e.bp:Size()==0,'second click only fixes rectangle')
    Stretch.Adjust(e,100);V.assert(e.stretch.h==48,'positive wheel height saturates at source 48 layers')
    Stretch.Adjust(e,-200);V.assert(e.stretch.h==1,'negative wheel height saturates at one layer')
    e:Remove();V.assert(e.stretch.phase=='rect' and e.bp:Size()==0,'right click in height returns to rectangle')
    e:Remove();V.assert(not e.stretch and e.bp:Size()==0,'second right click cancels rectangle')
    local code=require 'storage.BlueprintCode'
    local grouped=Blueprint.New();grouped:Add({type='cube',pos={0,4,0},rot=0,g=13})
    local encoded=code.Encode(grouped:ToTable());local loaded=Blueprint.New():Load(code.Decode(encoded))
    V.assert(loaded.parts[1].g==13 and loaded.nextGroup==14,'group metadata survives real exchange code')
    local paste=Editor.New(grouped);paste.mirror=false;paste.selection={[1]=true};paste:Copy();paste:StartPaste()
    paste:Preview({place={5,4,0},normal={0,1,0}})
    V.assert(paste:CommitPaste() and grouped.parts[2].g==14 and grouped.parts[1].g==13,'clipboard keeps its group with a new independent source group number')
    V.assert(paste:Undo() and not grouped.parts[2] and grouped.parts[1].g==13 and paste:Redo() and grouped.parts[2].g==14,'clipboard group remap survives real undo and redo')
    local invalid=grouped:ToTable();invalid.parts[1][8]='bad'
    V.assert(not pcall(code.Validate,invalid),'invalid source group metadata rejected before load')
end
local app,s,e,originalControls,originalUpdate,showGhost
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image) and image:SavePNG('docs/migration/evidence/build-stretch-'..name..'.png'),'rendered '..name);image:Dispose()
end
V.atFrame(55,function()
    Rules();app=VOX_HANGAR.app;app:EnterBuild();s=app.build;e=s.editor
    originalControls=s.controls.Update;originalUpdate=s.Update
    -- Freeze input polling only inside this hidden validation process; native
    -- click/hold ownership is exercised below with the same input adapter.
    s.controls.Update=function() end;s.Update=function() end
    e.mirror=false;e.selection={};e:SelectType('cube');e:SetTool('stretch')
    local p=e.bp:Add({type='cube',pos={20,8,10},rot=0});app.car:AddPart(p)
    e.selection={[p.id]=true};local pos=Vector3(-p.pos[1]*require('Config').CELL,(p.pos[2]+.5)*require('Config').CELL,0)
    s.camera.node.position=pos+Vector3(5,4,-5);s.camera.node:LookAt(pos)
    s.buildCamera.mode='orbit';s.controls.inside=true;s.controls.x=UI.GetWidth()*.5;s.controls.y=UI.GetHeight()*.5
    e.hit={partId=p.id,cell=p.pos,normal={0,1,0}};e.rayOrigin=nil
    V.assert(Stretch.Start(e) and e.stretch.phase=='selection','selected source block starts face extrusion')
    showGhost=s.ghost.Refresh;s:Refresh();s.ghost.Refresh=function() end
end)
V.atFrame(72,function()
    s.ghost.Refresh=showGhost;showGhost(s.ghost,e,true,false);s.ghost.Refresh=function() end
    V.assert(#s.ghost.pool>0 and #s.ghost.pool<=s.ghost.limit,'selection extrusion has bounded real model preview')
    local specs={};local def=require('parts.Defs').PARTS
    for _,type in ipairs({'cube','slope','corner','heavy','glass','light'}) do if def[type] and def[type].shape then
        for rot=0,23 do specs[#specs+1]={type=type,rot=rot} end
    end end
    local all=require('parts.Dependencies').For(specs);local requested={}
    local start=s.ghost.gate.Start;s.ghost.gate.Start=function(_,paths,done) requested=paths;done(true) end
    s.ghost.warmKey=nil;s.ghost:Warm(e,true,specs)
    V.assert(#specs>s.ghost.limit and Equal(requested,all),'resource warming covers complete batch beyond detailed preview budget')
    s.ghost.gate.Start=start;s.ghost.warmKey=nil;showGhost(s.ghost,e,true,false)
    Shot('selection');local version=e.stretch.planVersion;Stretch.Update(e)
    V.assert(e.stretch.planVersion==version,'unchanged selection preview reuses validated plan')
    WithInput(Fake(),function() s:Wheel(-1) end)
    V.assert(e.stretch.h==2,'actual wheel adapter changes extrusion height instead of hotbar')
    local before=e.bp:Size();local oldSlot=s.inventory.active
    s.buildCamera.mode='fp';s.buildCamera.captured=true;s.buildCamera.buttonsReady=true
    s.Trace=function() end
    WithInput(Fake(nil,{[MOUSEB_LEFT]=true},{[MOUSEB_LEFT]=true}),function() s.controls:FirstPerson(.01) end)
    V.assert(e.bp:Size()==before+2 and s.selecting and not e.stretch and s.inventory.active==oldSlot,'actual first-person click confirms extrusion and returns to selection')
    local committed=e.bp:Size()
    WithInput(Fake(nil,{[MOUSEB_LEFT]=true}),function() s.controls:FirstPerson(.8) end)
    V.assert(e.bp:Size()==committed,'held confirmation cannot repeat placement after extrusion')
    e:Undo();V.assert(e.bp:Size()==before,'native command history undoes complete extrusion')
    e:Redo();V.assert(e.bp:Size()==committed,'native command history restores complete extrusion')
    s.selecting=false;e.selection={};e.rayOrigin=nil;e:SetTool('stretch');e.preview={type='cube',pos={3,12,0},rot=0,normal={0,1,0},res={ok=true}}
    Stretch.Start(e);e.stretch.cur={5,12,2};Stretch.Update(e);e:Act();Stretch.Adjust(e,2)
    s.buildCamera.mode='orbit';s.buildCamera.captured=false;s.controls.inside=true
    showGhost(s.ghost,e,true,false);s.hud.hover:Sync()
    s.hud.modeBadge:Sync()
    local target=Vector3(-4*require('Config').CELL,13.5*require('Config').CELL,require('Config').CELL)
    s.camera.node.position=target+Vector3(5,4,-5);s.camera.node:LookAt(target)
    V.assert(s.ghost.volume.numGeometries>0 and e.stretch.h==3,'rectangle renders translucent native volume at correct height')
end)
V.atFrame(86,function()
    Shot('rectangle');local signature=s.ghost.signature;showGhost(s.ghost,e,true,false)
    V.assert(s.ghost.signature==signature,'unchanged rectangular ghost reuses geometry')
    local before=e.bp:Size();s:Escape()
    V.assert(not e.stretch and e.bp:Size()==before and not s.dialog,'Escape cancels active stretch before opening pause')
    e.preview={type='cube',pos={3,12,0},rot=0,normal={0,1,0},res={ok=true}};Stretch.Start(e)
    WithInput(Fake({[KEY_DELETE]=true,[KEY_F]=true,[KEY_RIGHT]=true}),function() s:Keys() end)
    V.assert(e.stretch and e.bp:Size()==before,'destructive build shortcuts are ignored during stretch')
    WithInput(Fake({[KEY_J]=true}),function() s:Keys() end)
    V.assert(not e.stretch and e.tool=='build','J exits active stretch without a write')
    e:SetTool('stretch');e.preview={type='cube',pos={3,12,0},rot=0,normal={0,1,0},res={ok=true}};Stretch.Start(e)
    s.ghost.Refresh=showGhost;s.Update=originalUpdate;s.controls.Update=originalControls
    s.buildCamera.captured=false
    local fake=Fake();fake.focus=false
    WithInput(fake,function() s:Update(.01) end)
    V.assert(not e.stretch and e.bp:Size()==before,'focus loss cancels transient stretch without a commit')
    app:ExitBuild();V.assert(not app.build,'stretch preview resources release on exit')
end)

local BP=require 'construction.Blueprint'
local Clearance=require 'construction.BuildClearance'
local Rot=require 'core.Rotations'
local file=assert(io.open('tools/migration/source-panel-fixtures.json'))
local function Normalize(v)
    if type(v)=='number' then return math.tointeger(v) or v end
    if type(v)=='table' then for k,x in pairs(v) do v[k]=Normalize(x) end end
    return v
end
local fixture=Normalize(cjson.decode(file:read('*a')));file:close()
local app,session,saved
local stage='boot'
local renderFrames=0
engine.maxInactiveFps=120
local function Equal(a,b)
    if a==cjson.null then a=nil end;if b==cjson.null then b=nil end
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<1e-7 end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k,v in pairs(b) do if not Equal(a[k],v) then return false end end
    return true
end
local function Shot(name)
    local image=Image:new()
    V.assert(graphics:TakeScreenShot(image) and image:SavePNG('docs/migration/evidence/'..name..'.png'),'render '..name)
    image:Dispose()
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app;app.store=require('storage.BlueprintStore').New('vox-panel-session-test');app.bays.store=app.store;app.bays.active=false
        V.assert(app:LoadBlueprint(fixture.initial) and app:EnterBuild(),'source vehicle opens in normal building flow')
        local e=app.editor;e.mirror=false
        local differences={}
        for _,p in ipairs(fixture.placements) do
            app.build:PickHotbar(p.type)
            local res=e.bp:Check(p.type,p.pos,p.rot,e.bounds)
            if not Equal(res,p.res) then differences[#differences+1]={type=p.type,actual=res,expected=p.res} end
            V.assert(Equal(res,p.res),'source connected placement '..p.type)
            e.preview={type=p.type,pos=p.pos,rot=p.rot,res=res}
            V.assert(app.build:Act() and app.car.visuals[p.id]~=nil,'actual native editor places '..p.type)
        end
        local diff=assert(io.open('.tmp/panel-placement-differences.json','w'));diff:write(cjson.encode(differences));diff:close()
        V.assert(Equal(e.bp:ToTable(),fixture.final),'all new panels preserve original assembly')
        e:Undo();e:Redo();V.assert(Equal(e.bp:ToTable(),fixture.final),'panel undo redo preserves assembly')
        V.assert(app.build:SaveSlot(),'panel vehicle saves through normal slot flow')
        saved=e.bp:ToTable();local read=app.store:LoadSlot(app.build.slot)
        V.assert(Equal(read,saved),'saved panel blueprint reads back exactly')
        for i,c in ipairs(fixture.clearance) do
            local a,b=BP.New(),BP.New();a:Add{type=c.type,pos=c.pos,rot=c.rot};b:Add{type='cube',pos=c.at,rot=Rot.IDENTITY}
            V.assert(Equal(a:Check('cube',c.at,Rot.IDENTITY,nil,nil,false),c.forward),'activity envelope forward '..i)
            V.assert(Equal(b:Check(c.type,c.pos,c.rot,nil,nil,false),c.reverse),'activity envelope reverse '..i)
            V.assert(Equal(a:Check('cube',c.at,Rot.IDENTITY,nil,{[1]=true},false),c.ignored),'ignored activity envelope '..i)
            V.assert(Equal(Clearance.Conflict(a,c.type,c.pos,c.rot,BP.PartCells(c.type,c.pos,c.rot)),c.same),'same equipment kind shares sweep '..i)
            a:Remove(1);V.assert(next(a.clearIds)==nil,'remove releases activity envelope '..i)
        end
        stage='build-shot'
    elseif stage=='build-shot' then
        renderFrames=renderFrames+1;if renderFrames<30 then return end
        Shot('panel-native-build');session=app.build;app:Reload();stage='reload'
    elseif stage=='reload' and app.build and app.build~=session and not app.pendingAssetRelease then
        V.assert(Equal(app.blueprint:ToTable(),saved),'reload keeps every new panel and finish')
        V.assert(app:EnterTrial('crater'),'panel vehicle enters debug crater');stage='loading'
    elseif stage=='loading' and app.trial then
        session=app.trial;session.controls.Read=function()return {throttle=0,steer=0}end
        V.assert(session.map.id=='crater' and Equal(app.blueprint:ToTable(),saved),'crater consumes same edited vehicle')
        for _,p in ipairs(fixture.placements) do
            local found=false;for _,id in ipairs(session.vehicle.spec.partIds) do if id==p.id then found=true;break end end
            V.assert(found and session.view.view.visuals[p.id]~=nil,'native physics and rendered rig retain '..p.type)
        end
        stage='settle';session.panelTestFrames=0
    elseif stage=='settle' then
        session.panelTestFrames=session.panelTestFrames+1
        if session.panelTestFrames<45 then return end
        V.assert(session.vehicle.telemetry.contact>0,'panel vehicle has working ground contact')
        session.HasFocus=function()return true end;session.pointer.SetMouseMode=function()end
        session.pointer:Capture();session.pointer.Poll=function()end
        session:PostUpdate(1);session.hud.Update(session,0);renderFrames=0;stage='crater-shot'
    elseif stage=='crater-shot' then
        renderFrames=renderFrames+1;if renderFrames<20 then return end
        local eye=session.camera:GetNode().position
        V.assert(session.yaw==0 and session.pitch==30,'unrotated default spawn is exercised')
        V.assert(eye.z>-289.35,'camera and near plane stay in front of 0.5 metre fortress sign')
        Shot('panel-native-crater')
        session.teleport=2;session:Reset();session:PostUpdate(1);renderFrames=0;stage='outdoor-shot'
    elseif stage=='outdoor-shot' then
        renderFrames=renderFrames+1;if renderFrames<30 then return end
        Shot('panel-crater-outdoors');app:Reload();stage='return'
    elseif stage=='return' and app.mode=='hangar' and app.build then
        V.assert(session.disposed and Equal(app.blueprint:ToTable(),saved),'return releases map and preserves panels')
        stage='done';V.finish()
    end
end
for frame=50,680 do V.atFrame(frame,Poll) end
V.atFrame(690,function()V.assert(stage=='done','panel place save reload crater return completed');V.finish()end)

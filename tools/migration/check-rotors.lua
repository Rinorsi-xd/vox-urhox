local BP=require 'construction.Blueprint'
local R=require 'construction.Rotors'
local Motion=require 'drive.RotorMotion'
local ID=require('core.Rotations').IDENTITY
local function Equal(a,b)
    if a==cjson.null then a=nil end;if b==cjson.null then b=nil end
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return a==b or math.abs(a-b)<1e-6 end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do local value=b[k];if value==nil then value=b[tostring(k)] end;if not Equal(v,value) then return false end end
    for k,v in pairs(b) do local value=a[k];if value==nil and tonumber(k) then value=a[tonumber(k)] end;if not Equal(value,v) then return false end end
    return true
end
local checks=0
local function Check(a,b,name)
    V.assert(Equal(a,b),name);checks=checks+1
    if not Equal(a,b) then print('[RotorDifference] '..name..' '..cjson.encode({actual=a,expected=b})) end
    if checks%80==0 then coroutine.yield() end
end
local function Blueprint(parts) local bp=BP.New();for _,p in ipairs(parts) do bp:Add(p) end;return bp end
local function Free(range) if range.lo==nil or range.lo==cjson.null then range.lo=-math.huge end;if range.hi==nil or range.hi==cjson.null then range.hi=math.huge end;return range end
local rules=coroutine.create(function()
    local file=assert(io.open('tools/migration/source-rotors-fixtures.json'));local data=cjson.decode(file:read('*a'));file:close()
    for i,c in ipairs(data.specs) do
        local bp=Blueprint(c.parts);local loads=R.Loads(bp);local tree=R.Tree(loads)
        Check(tree.owner,c.owner,'source load owner '..i);Check(tree.parent,c.parent,'source nested parent '..i);Check(tree.order,c.order,'source nested order '..i)
        Check(R.Frame(bp.parts[1]),c.frame,'source installation frame '..i);Check(R.AimRef(bp.parts[1]),c.aimRef,'source aim baseline '..i);Check(R.AimOffset(bp.parts[1]),c.aimOffset,'source arrow offset '..i)
        for id,info in pairs(loads) do local expected=c.inspect[tostring(id)]
            Check(R.Keys(info.load),expected.load,'source load set '..i..'/'..id);Check(info.problem,expected.problem,'source problem '..i..'/'..id)
            Check(info.blockers,expected.blockers,'source structural blockers '..i..'/'..id);Check(info.stuck,expected.stuck,'source jam flag '..i..'/'..id)
            local range=R.Range(bp,bp.parts[id],info.load);Check(range,Free(expected.range),'source sweep '..i..'/'..id)
        end
    end
    for i,c in ipairs(data.motions) do
        for _,r in ipairs(c.descriptors) do if r.parent==cjson.null then r.parent=nil end;r.range=Free(r.range) end
        local rotors=Motion.New(c.descriptors)
        for j,frame in ipairs(c.frames) do Motion.Step(rotors,frame.aim,frame.step,frame.dt)
            for k,r in ipairs(rotors) do local expected=frame.rotors[k]
                Check(r.angle,expected.angle,'source angle '..i..'/'..j..'/'..k);Check(r.target,expected.target,'source target '..i..'/'..j..'/'..k)
                Check(r.prev,expected.prev,'source previous '..i..'/'..j..'/'..k);Check(r.pose,expected.pose,'source compound pose '..i..'/'..j..'/'..k)
            end
        end
        local snap=Motion.Snapshot(rotors);local fresh=Motion.New(c.descriptors);Motion.Restore(fresh,snap)
        for k,r in ipairs(fresh) do Check(r.pose,rotors[k].pose,'damage rebuild preserves pose '..i..'/'..k) end
    end
end)
for frame=5,330 do V.atFrame(frame,function() if coroutine.status(rules)~='dead' then
    local ok,err=coroutine.resume(rules);V.assert(ok,'rotor source fixture coroutine '..frame..': '..tostring(err))
end end) end
V.atFrame(335,function() V.assert(coroutine.status(rules)=='dead','all source rotor fixtures completed') end)
local app,session,originalUpdate,originalEditor,originalCar,view,drive,vehicle,space,bp
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image) and image:SavePNG('docs/migration/evidence/rotors-'..name..'.png'),'real rotor screenshot '..name);image:Dispose()
end
V.atFrame(345,function()
    app=VOX_HANGAR.app;app:EnterBuild();session=app.build
    originalUpdate=session.Update;session.Update=function() end;originalEditor=session.editor;originalCar=session.car;app.car:SetVisible(false)
    bp=Blueprint({{type='core',pos={0,3,0},rot=ID},{type='rotorStep',pos={0,4,0},rot=ID},
        {type='cube',pos={0,5,0},rot=ID,g=7},{type='cube',pos={1,5,0},rot=ID,g=7},
        {type='cube',pos={2,5,0},rot=ID,g=7},{type='laser1',pos={0,6,0},rot=ID}})
    space=require('physics.Space').New(app.scene);vehicle=require('drive.Vehicle').New(space,require('drive.VehicleSpec').Build(bp))
    vehicle:Place({0,3,0},0);drive=require('render.DriveView').New(app.scene,bp,vehicle);view=drive.view
    local at=vehicle.native.position;local target=at+Vector3(0,3,0)
    session.camera.node.position=target+Vector3(8,5,-10);session.camera.node:LookAt(target)
    V.assert(#vehicle.rotors==1 and #vehicle.rotorShapes>0,'real native compound has moving rotor shapes')
    V.assert(vehicle.spec.rotorOf[6]==1 and vehicle.spec.rotorOf[3]==1,'native weapon and joined load share owner')
    local model=view.visuals[2];V.assert(model.head~=nil,'authored rotor base/head rig is available')
    session.editor=require('construction.BuildEditor').New(bp,function(ops) view:ApplyEdits(ops,bp) end);session.editor.mirror=false
    session.car=view;session.editor.hit={partId=2};session.controls.inside=true
    session.inspection.revision=-1;session.buildCamera.mode='orbit';session.ghost.root.enabled=false
    session.hud.rotor:Sync();session.hud.rotor.alpha=1
    V.assert(session.hud.rotor.mode==3 and session.hud.rotor.info.count==4,'source step HUD and blue load count')
end)
V.atFrame(355,function()
    Shot('step-before')
    local system=require('combat.WeaponSystem').New(vehicle.spec);local w=system.groups[1].weapons[1];local rest={table.unpack(w.pivot)}
    local b=view.rotorJoined[1];local rebuilds=b.rebuilds
    for i=1,45 do vehicle:StepRotors({10,8,10},i==1,1/60);Motion.Weapons(vehicle.rotors,system);drive:Update(1,1/60) end
    Check(vehicle.rotors[1].angle,math.pi/2,'real F step reaches ninety degrees')
    local expected=R.Apply(vehicle.rotors[1].pose,rest);Check(w.pivot,expected,'actual weapon mount follows rotor')
    V.assert(b.rebuilds==rebuilds,'rotating joined surfaces do not rebuild geometry')
    for _,entry in ipairs(vehicle.rotorShapes) do local center=entry.item.center
        if center then local actual=entry.shape.position
            V.assert(math.abs(actual.x+center[1])<1e-5 and math.abs(actual.y-center[2])<1e-5 and math.abs(actual.z-center[3])<1e-5,'native shape offset follows source pose')
        end
    end
    local id=5;local restPoint={bp.parts[id].pos[1]*.5,(bp.parts[id].pos[2]+.5)*.5,bp.parts[id].pos[3]*.5}
    local moved=R.Apply(vehicle.rotors[1].pose,restPoint)
    local unit=setmetatable({bp=bp,vehicle=vehicle},{__index=require('combat.CarUnit')})
    V.assert(unit:PartAt(moved)==id,'damage finds rotated joined load cell')
    V.assert(unit:PartAt(restPoint)~=id,'damage ignores vacated rest cell')
    local p=vehicle.body.translation();local origin={moved[1]+p.x,moved[2]+p.y+10,moved[3]+p.z}
    local hit=require('combat.VehicleRay').Cast(vehicle,origin,{0,-1,0},20)
    V.assert(hit~=nil and math.abs(hit.point[1]-origin[1])<1e-5,'analytic combat ray sees moved compound')
    local snapshot=vehicle:GetState();local fresh=require('drive.Vehicle').New(space,require('drive.VehicleSpec').Build(bp));fresh:SetState(snapshot)
    Check(fresh.rotors[1].pose,vehicle.rotors[1].pose,'real native damage rebuild retains rotor pose')
    local expectedNode=R.Apply(fresh.rotors[1].pose,restPoint)
    for i=1,3 do
        drive:Bind(bp,fresh);drive:Update(1,0);local node=view.visuals[id].node
        Check({-node.position.x*.5,node.position.y*.5,node.position.z*.5},expectedNode,'damage rebind has no accumulated rotor drift '..i)
    end
    drive:Bind(bp,vehicle);fresh:Dispose()
    vehicle.rayBounds={unchanged=true};vehicle:StepRotors(nil,false,0)
    V.assert(vehicle.rayBounds and vehicle.rayBounds.unchanged,'unchanged rotor pose preserves cached ray bounds and compound shapes')
    unit.alive=true;unit.weapons=system;vehicle.rotors[1].mode='spin'
    unit:Step(1/60)
    V.assert(vehicle.rotors[1].angle>snapshot.rotors[2].angle,'parked combat units advance spinning loads')
    vehicle.rotors[1].mode='step';vehicle:SetState(snapshot)
end)
V.atFrame(365,function()
    Shot('step-after')
    local editor=session.editor;local id=2;editor.hit={partId=id};editor:SetRotorMode(2);view:UpdateIdle(0,0)
    V.assert(bp.parts[id].type=='rotorSpin' and view.visuals[id].part.type=='rotorSpin','mode command replaces actual rig at same persistent id')
    editor:Undo();V.assert(bp.parts[id].type=='rotorStep','mode switch is one undo transaction')
    editor:Redo();V.assert(bp.parts[id].type=='rotorSpin','mode switch redo restores mode')
    session.hud.rotor:Sync();session.hud.rotor.alpha=1
end)
V.atFrame(375,function()
    Shot('spin-hud');session.controls.inside=false;session.hud.rotor:Sync()
    V.assert(session.hud.rotor.info==nil,'leaving build target hides rotor panel')
    drive:Dispose();vehicle:Dispose();session.editor=originalEditor;session.car=originalCar;session.Update=originalUpdate
    app.car:SetVisible(true);app:ExitBuild();V.assert(not app.build,'rotor checks release view body and input session')
    bp.parts[2].type='rotorStep'
    V.assert(app:LoadBlueprint(bp:ToTable()),'actual trial rotor fixture passes production model readiness gate')
    app:EnterTrial('trial')
end)
V.atFrame(435,function()
    local s=app.trial;V.assert(s~=nil,'rotor trial finishes production scene loading')
    s.Update=function() end;s.accumulator=0
    V.assert(#s.vehicle.rotors==1,'production trial owns authored rotor')
    s:Tick(0,{throttle=0,steer=0,rotorStep=true})
    V.assert(s.pendingRotorStep and s.vehicle.rotors[1].target==0,'sub-physics frame retains a real F command')
    s:Tick(1/60,{throttle=0,steer=0})
    Check(s.vehicle.rotors[1].target,math.pi/2,'next physics tick consumes retained F exactly once')
    s:Tick(.1,{throttle=0,steer=0,rotorStep=true})
    Check(s.vehicle.rotors[1].target,math.pi,'six catch-up ticks execute only one additional F step')
    s:Tick(0,{throttle=0,steer=0,rotorStep=true});s:Pause()
    V.assert(not s.pendingRotorStep,'pause discards pending rotor input')
    s.onReturn()
end)
V.atFrame(470,function() V.assert(not app.trial,'rotor trial returns and disposes compound vehicle') end)

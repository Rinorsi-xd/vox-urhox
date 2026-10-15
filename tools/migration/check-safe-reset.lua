local Safe=require 'controls.SafeReset'
local Coord=require 'core.Coord'
local UI=require 'urhox-libs/UI'
local scene,reset,session,uiRoot,progress
local rendered=false
local output='docs/migration/evidence'
for _,arg in ipairs(GetArguments()) do output=arg:match('^%-reset%-out=(.+)$') or output end
local function near(a,b) return math.abs(a-b)<1e-5 end
V.atFrame(3,function()
    -- The wrapper uses the repository's isolated retained-post entry, so this
    -- synthetic Bullet world and HUD never compete with an actual boot owner.
    scene=Scene();local space=require('physics.Space').New(scene)
    local world={space=space,time=0}
    function world:CastRay(...) return self.space:Raycast(...) end
    local function Box(name,p,size,owner,mass,trigger,rotation)
        local n=scene:CreateChild(name);n.position=Coord.Vec(table.unpack(p));n.rotation=rotation or Quaternion.IDENTITY
        n:CreateComponent('CollisionShape'):SetBox(Vector3(table.unpack(size)))
        local b=n:CreateComponent('RigidBody');b.mass=mass or 0;b.useGravity=false;b.trigger=trigger or false
        space:Register(b,owner);return b,n
    end
    local ground=Box('Floor',{0,-.5,0},{2000,1,2000},{type='ground'})
    local chassis=Box('OwnChassis',{0,1.8,0},{2,2,4},{type='vehicle'},20)
    local wrapped=space.bodies[chassis.node:GetID()].body
    local vehicle={native=chassis,body=wrapped,spec={bounds={min={-2,-1,-4},max={2,1,4},radius=5}},telemetry={contact=1}}
    function vehicle:Yaw() local f=chassis.rotation*Vector3.FORWARD;return math.atan(-f.x,f.z) end
    local cancel,applied=0,0;local toast=nil
    session={scene=scene,world=world,vehicle=vehicle,combat={player={alive=true}},weapons={energy=37,drill={Cancel=function() cancel=cancel+1 end}},app={toasts={Push=function(_,text) toast=text end}}}
    function session:ApplyResetSpot(spot) applied=applied+1;self.last=spot end
    reset=Safe.New(session)
    local p=wrapped.translation()
    V.assert(reset:Fits(0,0,0,p)~=nil,'Whole OBB excludes own chassis and accepts registered ground')
    V.assert(reset.queryBody.enabled==false and reset.queryBody.trigger and reset.queryBody.collisionLayer==0,'Reset query is disabled layer-zero sensor, outside solver')
    local wall,node=Box('InteriorThinWall',{1.5,1.5,1},{.12,2,.12},{type='ground'})
    V.assert(reset:Fits(0,0,0,p)==nil,'Whole-volume overlap catches thin interior wall away from ground ray and corners')
    local ring=reset:SafeSpot()
    V.assert(near(ring.pos[1],math.sin(math.pi/3)*5) and near(ring.pos[3],2.5),'Blocked origin searches radius five in exact source 12-angle order')
    local start=chassis.position;space.world:Update(1/60)
    V.assert(chassis.linearVelocity:Length()<1e-7 and (chassis.position-start):Length()<1e-6,'Disabled overlap query causes no chassis displacement or impulse')
    node:Dispose()
    local sensor,sensorNode=Box('TriggerInResetVolume',{1,1.5,1},{.3,2,.3},{type='car'},0,true)
    V.assert(reset:Fits(0,0,0,p)~=nil,'Unrelated trigger volumes excluded like source EXCLUDE_SENSORS');sensorNode:Dispose()
    vehicle.spec.bounds={min={-.5,-1,-4},max={.5,1,4},radius=5}
    local outside,outsideNode=Box('AabbFalsePositive',{3,1.5,-3},{.15,2,.15},{type='ground'})
    V.assert(reset:Fits(0,0,math.pi/4,p)~=nil,'Rotated narrow vehicle accepts clear OBB even when AABB overlaps blocker');outsideNode:Dispose()
    local inside,insideNode=Box('RotatedInteriorWall',{2,1.5,2},{.15,2,.15},{type='ground'})
    V.assert(reset:Fits(0,0,math.pi/4,p)==nil,'Native mirrored yaw tests actual rotated OBB interior');insideNode:Dispose()
    vehicle.spec.bounds={min={-15,-10,-20},max={15,10,20},radius=27}
    local giant,giantNode=Box('GiantVehicleInterior',{214,10,13},{.1,2,.1},{type='ground'})
    V.assert(reset:Fits(200,0,0,p)==nil,'Full giant vehicle dimensions reject distant internal blocker');giantNode:Dispose()
    V.assert(reset:Fits(200,0,0,p)~=nil,'Resized giant OBB accepts clear volume')
    vehicle.spec.bounds={min={1,-1,-2},max={5,1,2},radius=5}
    local offset,offsetNode=Box('OffsetBoundsInterior',{3,1.5,0},{.2,2,.2},{type='ground'})
    V.assert(reset:Fits(0,0,0,p)==nil,'Asymmetric bounds translate OBB centre instead of assuming chassis origin');offsetNode:Dispose()
    vehicle.spec.bounds={min={-2,-1,-4},max={2,1,4},radius=5}
    local owned,ownedNode=Box('TargetRoof',{20,1,0},{3,2,3},{type='target'})
    V.assert(reset:Fits(20,0,0,p)==nil,'Reset refuses target and vehicle roofs');ownedNode:Dispose()
    local slope,slopeNode=Box('SteepFloor',{30,0,0},{12,.5,12},{type='ground'},0,false,Quaternion(30,Vector3.FORWARD))
    V.assert(reset:Fits(30,0,0,p)==nil,'Real Bullet floor normal above 25 degrees is rejected');slopeNode:Dispose()
    local meshNode=scene:CreateChild('TriangleInterior');local geo=meshNode:CreateComponent('CustomGeometry');geo:BeginGeometry(0,TRIANGLE_LIST)
    for _,v in ipairs({{-1,0,-1},{-1,3,-1},{-1,0,2},{-1,0,2},{-1,3,-1},{-1,3,2}}) do geo:DefineVertex(Vector3(table.unpack(v))) end
    geo:Commit();geo.enabled=false
    meshNode:CreateComponent('CollisionShape'):SetCustomTriangleMesh(geo,Vector3.ONE)
    local mesh=meshNode:CreateComponent('RigidBody');space:Register(mesh,{type='ground'})
    V.assert(reset:Fits(0,0,0,p)==nil,'Actual static triangle-mesh wall intersects full reset OBB');meshNode:Dispose()
    -- Timing and safe history follow source simulation seconds; cooldown uses wall milliseconds.
    V.assert(reset:Begin() and session.resetChan.dur==1.2,'R begins exactly 1.2-second channel')
    reset:Update(.6);V.assert(near(session.resetChan.t,.6) and applied==0,'Partial channel does not teleport')
    V.assert(not reset:Begin() and not session.resetChan and session.resetReady==0,'Second R cancels without cooldown')
    reset:Begin();reset:Update(1.19);V.assert(applied==0,'No reset before 1.2 seconds')
    reset:Update(.011);V.assert(applied==1 and not session.resetChan and cancel==1 and session.weapons.energy==37,'Completed reset cancels drill once, applies spot, preserves weapon energy')
    V.assert(session.resetReady-Time:GetSystemTime()>3950 and not reset:Begin() and toast:find('冷却中'),'Source 4-second wall-clock cooldown rejects immediate retry')
    session.resetReady=0;reset:Begin();reset:Clear();V.assert(not session.resetChan,'Pause Clear removes channel')
    reset:ForgetHistory();world.time=0
    reset:Update(0);chassis.position=Coord.Vec(2,1.8,0);world.time=.5;reset:Update(0)
    V.assert(#reset.safeHist==1,'History interval exactly .5 seconds is excluded')
    chassis.position=Coord.Vec(1.5,1.8,0);world.time=.6;reset:Update(0)
    V.assert(#reset.safeHist==1,'History movement exactly 1.5 meters is excluded')
    reset:ForgetHistory()
    for i=1,30 do chassis.position=Coord.Vec(i*2,1.8,0);world.time=i*.6;reset:Update(0) end
    V.assert(#reset.safeHist==24 and near(reset.safeHist[1].pos[1],14),'Safe history caps at 24 and drops oldest entries')
    local n=#reset.safeHist;chassis.position=Coord.Vec(60.5,1.8,0);world.time=30;reset:Update(0)
    V.assert(#reset.safeHist==n and near(reset.safeHist[n].pos[1],60),'Safe records require movement greater than 1.5 meters')
    chassis.position=Coord.Vec(70,1.8,0);vehicle.telemetry={contact=0};reset:Update(0)
    V.assert(near(reset.safeHist[n].pos[1],60),'Unsupported body does not enter safe history')
    vehicle.telemetry={airspeed=16};reset:Update(0);V.assert(near(reset.safeHist[24].pos[1],70),'Source flying support airspeed above 15 is recorded')
    chassis.rotation=Quaternion(40,Vector3.FORWARD);chassis.position=Coord.Vec(80,1.8,0);world.time=31;reset:Update(0)
    V.assert(near(reset.safeHist[24].pos[1],70),'Tilted body upY <= .87 not recorded');chassis.rotation=Quaternion.IDENTITY
    chassis.position=Coord.Vec(0,1.8,0);world.time=100
    reset.safeHist={{t=90,pos={10,.8,0},yaw=.3},{t=99,pos={20,.8,0},yaw=.5}}
    local spot=reset:SafeSpot();V.assert(near(spot.pos[1],10) and near(spot.yaw,.3),'Newest eligible history skips records younger than 1.5 seconds')
    reset.safeHist={{t=90,pos={61,.8,0},yaw=.3},{t=90,pos={2,.8,0},yaw=.4}}
    spot=reset:SafeSpot();V.assert(near(spot.pos[1],0),'Safe history outside 2.5-to-60-meter band falls back to local search')
    reset:ForgetHistory();ground.enabled=false;spot=reset:SafeSpot();ground.enabled=true
    V.assert(near(spot.pos[1],0) and near(spot.pos[2],1.8+5),'No valid ground uses source radius lift fallback')
    session.combat.player.alive=false;V.assert(not reset:Begin(),'Dead player cannot start reset')
    session.combat.player.alive=true;reset:Begin();session.combat.player.alive=false;reset:Update(.2)
    V.assert(not session.resetChan,'Death cancels in-progress channel')
    session.combat.player.alive=true;session.resetChan={t=.6,dur=1.2}
    local fonts=require('ui.SourceFonts').Resolve()
    UI.Init({theme='default-dark',scale=UI.Scale.DEFAULT,fonts={{family='sans',weights={normal=fonts.body,bold=fonts.bold}}}})
    uiRoot=UI.Panel{width='100%',height='100%',backgroundColor={8,12,18,255}}
    UI.SetRoot(uiRoot);progress=require('ui.ResetProgress').Attach(session,uiRoot)
    local originalRender=progress.layer.Render
    progress.layer.Render=function(self,vg) rendered=true;return originalRender(self,vg) end
    V.assert(progress.layer.props.pointerEvents=='none','Reset progress cannot intercept gameplay input')
end)
V.atFrame(7,function()
    -- Isolate this HUD specimen from the real startup overlay. Functional
    -- loading-page and whole-session routes remain the parent's acceptance.
    UI.UnregisterGlobalComponent('vox-loading-page');UI.SetRoot(uiRoot);rendered=false
end)
V.atFrame(8,function()
    V.assert(rendered,'Actual reset component NanoVG Render executed after isolated root presentation')
    local image=Image();V.assert(graphics:TakeScreenShot(image),'Reset HUD renders through existing UI pipeline')
    V.assert(image:SavePNG(output..'/reset-progress.png'),'Actual reset HUD screenshot saved');image:Dispose()
end)
V.atFrame(9,function() UI.SetScale(.7);UI.Layout();rendered=false end)
V.atFrame(12,function()
    V.assert(rendered,'Actual reset HUD Render executed at .7 UI scale')
    local image=Image();V.assert(graphics:TakeScreenShot(image),'Actual .7-scale reset HUD screenshot')
    V.assert(image:SavePNG(output..'/reset-progress-scale-0.7.png'),'Source CSS pixel footprint specimen saved at .7 UI scale');image:Dispose()
    progress:Dispose();V.assert(not progress.layer.parent,'Reset HUD layer released on dispose')
    reset:Dispose();reset:Dispose();V.assert(not reset.queryNode and not session.resetChan and #reset.safeHist==0,'Reset dispose is idempotent and removes Bullet query/history/channel')
    scene:Dispose();V.finish()
end)

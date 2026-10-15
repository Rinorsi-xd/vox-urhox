local checks={}
local function Check(value,name) assert(value,name);checks[#checks+1]=name end
local function Near(a,b) return math.abs(a-b)<1e-6 end
local function Vec(a,b) for i=1,3 do if not Near(a[i],b[i]) then return false end end;return true end
MM_ABSOLUTE,MM_RELATIVE=100,101
MOUSEB_LEFT,MOUSEB_RIGHT,MOUSEB_MIDDLE=11,22,33
local now,created,disposed=0,0,0
Time={GetSystemTime=function() return now end}
Node=function()
    created=created+1
    local node={events={}}
    function node:CreateScriptObject()
        return {SubscribeToEvent=function(_,kind,callback) node.events[kind]=callback end}
    end
    function node:Dispose() disposed=disposed+1;self.events={} end
    return node
end
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function() return true end}
local Pointer=require 'controls.DrivePointer'
local focus=true
local buttons={}
input={mouseMode=MM_ABSOLUTE,mouseLocked=false,mouseMoveX=0,mouseMoveY=0,focus=true,minimized=false,
    GetMouseButtonDown=function(_,button) return buttons[button]==true end,GetMouseMoveWheel=function() return 0 end}
local function Session()
    local s={scope=false,touch=false,disposed=false,controls={held={}},HasFocus=function() return focus end}
    function s.controls:Clear() self.held={} end
    function s.controls:Look() end
    function s:Zoom() end
    return s
end
local function Ready(s)
    input.mouseMode=MM_ABSOLUTE;input.mouseLocked=false;buttons={};focus=true
    local p=Pointer.New(s);assert(p:Capture());input.mouseLocked=true;p:Poll(1/60);p:Poll(1/60)
    Check(p.captured and p.ready and not p.skip,'genuine capture waits for neutral input')
    return p
end
local function Edge(p,button,down)
    local callback=p.eventNode and p.eventNode.events[down and 'MouseButtonDown' or 'MouseButtonUp']
    if callback then callback({},'event',{GetInt=function() return button end}) end
end
for _,case in ipairs(scope_fixture.cases) do
    local s=Session();s.scope=case.initial
    local p=Ready(s)
    for i,e in ipairs(case.events) do
        now=e.at
        if e.type=='unlock' then input.mouseLocked=false;p:Poll(1/60)
        else Edge(p,e.button==2 and MOUSEB_RIGHT or MOUSEB_LEFT,e.type=='down') end
        Check(s.scope==e.scope and (s.controls.held.fire==true)==e.fire,'frozen actual H5 event trace '..case.name..'/'..i)
    end
    p:Release()
end
local s=Session();local p=Ready(s)
now=0;Edge(p,MOUSEB_RIGHT,true);now=1000;Edge(p,MOUSEB_RIGHT,false)
Check(not s.scope,'wall-clock long hold exits even with zero rendered frames')
now=1001;Edge(p,MOUSEB_RIGHT,true);now=1010;Edge(p,MOUSEB_RIGHT,false)
Check(s.scope,'quick click entirely between polls toggles scope')
local n=created;p:Capture();Check(created==n,'repeated capture does not duplicate subscribers')
focus=false;p:Poll(.016)
Check(not p.captured and p.eventNode==nil and not s.scope and not s.controls.held.fire,'focus loss clears scope and event owner')
focus=true;p:Poll(.016);Check(not p.captured and p.eventNode==nil,'focus return never auto-captures')
p=Ready(s);s.dialog={};Edge(p,MOUSEB_RIGHT,true);Check(not s.scope,'dialog cannot consume scope edges');s.dialog=nil
p:Suppress();Edge(p,MOUSEB_RIGHT,true);Check(not s.scope,'suppressed capture waits for neutral buttons')
p:Poll(.016);now=1020;Edge(p,MOUSEB_RIGHT,true);Check(s.scope,'scope input recovers after neutral polling')
p:Release();p:Release();Check(created==disposed,'all independent event nodes released exactly once')
input.mouseMode=MM_ABSOLUTE;input.mouseLocked=false
local delayed=Pointer.New(Session());delayed:Capture();delayed:Poll(14.3)
Check(delayed.pending and not delayed.captured,'blocked frame does not cancel pending browser capture')
input.mouseLocked=true;delayed:Poll(.016);Check(delayed.captured,'real delayed pointer lock accepted');delayed:Release()
local touch=Session();touch.touch=true;local tp=Pointer.New(touch);tp:Capture()
Check(tp.eventNode==nil,'touch controls do not allocate PC edge listeners');tp:Release()
local State=require 'controls.ChaseState'
for i,c in ipairs(camera_fixture.cases) do
    local state=State.New();state.minY=c.ground<0 and -math.huge or .35
    local pitch=state:Reset(c.pos,c.radius);local yaw=-.7*180/math.pi
    Check(Near(pitch,-c.resetPitch*180/math.pi),'frozen camera reset '..i)
    for j,sample in ipairs(c.samples) do
        state:Zoom(sample.delta);yaw,pitch=State.Look(yaw,pitch,sample.mouse[1],sample.mouse[2],sample.sens,c.flight)
        local calls=0
        local eye=type(sample.eye)=='table' and sample.eye~=cjson.null and sample.eye or nil
        local pose=state:Pose(sample.dt,sample.car.pos,yaw,pitch,function(origin,dir,span)
            calls=calls+1;local ray=sample.expected.ray
            Check(Vec(origin,ray.origin) and Vec(dir,ray.dir) and Near(span,ray.span),'frozen camera obstacle ray '..i..'/'..j)
            return type(c.obstacle)=='number' and c.obstacle or nil
        end,eye)
        local e=sample.expected
        local at=pose.eye or {pose.target[1]+pose.dir[1]*pose.distance,pose.target[2]+pose.dir[2]*pose.distance,pose.target[3]+pose.dir[3]*pose.distance}
        Check(Vec(at,e.position) and Vec(pose.forward,e.forward) and Vec(state.target,e.target),'frozen camera pose '..i..'/'..j)
        Check(Near(yaw,-e.yaw*180/math.pi) and Near(pitch,-e.pitch*180/math.pi) and Near(state.zoom,e.zoom) and Near(state.curDist,e.curDist),'frozen view input/framing '..i..'/'..j)
        if eye then Check(calls==0,'source first-person eye bypasses collision '..i..'/'..j) end
    end
end
local Fov=require 'controls.SpeedFov'
for i,c in ipairs(camera_fixture.fov) do
    local state=Fov.New();local spec=c.scenario
    local vehicle={spec={motion=spec},legMode=spec.legMode,mechMode=spec.mechMode,telemetry={legSpeedLimit=spec.legSpeedLimit}}
    for j,sample in ipairs(c.samples) do
        vehicle.body={linvel=function() return sample.lv end};local o=sample.options
        local value=state:Step(vehicle,sample.dt,48,sample.previous,{scope=type(o.scope)=='number' and o.scope or nil,rush=o.rush,charge=o.charge,punch=o.punch})
        local e=sample.expected
        Check(Near(value,e.current) and Near(state.speed,e.speed) and Near(state.peak,e.peak) and Near(state.scopeT,e.scopeT),'frozen FOV transition '..i..'/'..j)
    end
end
local settingsOpened,dialogClosed=0,0
local bridgeEnv=setmetatable({require=function(name)
    if name=='core.Coord' then return {Vec=function(x,y,z) return {x=-x,y=y,z=z} end} end
    if name=='controls.CameraObstacles' then return {LAYER=0x8000} end
    if name=='ui.GameSettings' then return {Open=function() settingsOpened=settingsOpened+1 end} end
    if name=='ui.DialogHost' then return {Close=function(s) dialogClosed=dialogClosed+1;s.dialog=nil end} end
    return {}
end,Ray=function(origin,direction) return {origin=origin,direction=direction} end},{__index=_G})
local Trial=assert(loadfile('scripts/app/TrialSession.lua','t',bridgeEnv))()
local own={};local origin,direction={3,4,5},{.6,0,.8}
for _,gameplay in ipairs({false,0,2,8}) do for _,surface in ipairs({false,0,1,7}) do
    local gameplayCalls,surfaceCalls=0,0
    local session=setmetatable({vehicle={body=own},world={space={world={}}}},Trial)
    function session.world:CastRay(o,d,span,exclude)
        gameplayCalls=gameplayCalls+1
        Check(o==origin and d==direction and span==10 and exclude==own,'camera gameplay query preserves source coordinates and excludes own body')
        return gameplay~=false and {dist=gameplay} or nil
    end
    function session.world.space.world:RaycastSingle(ray,span,mask)
        surfaceCalls=surfaceCalls+1
        Check(mask==0x8000 and span==(gameplay~=false and gameplay or 10),'camera-only query is narrow and capped to current nearest hit')
        Check(ray.origin.x==-3 and ray.origin.y==4 and ray.origin.z==5 and ray.direction.x==-.6 and ray.direction.z==.8,'camera surface query converts source coordinates once')
        return surface~=false and surface<=span and {body={},distance=surface} or {}
    end
    local expected=gameplay~=false and gameplay or nil
    if surface~=false and surface<=(expected or 10) then expected=surface end
    Check(session:CameraObstacle(origin,direction,10)==expected and gameplayCalls==1 and surfaceCalls==1,'camera obstruction chooses nearest gameplay or precise building hit')
end end
local paused=setmetatable({pointer={captured=true}},Trial)
local pauseCalls,banners=0,{}
function paused:Pause() pauseCalls=pauseCalls+1;self.pointer.captured=false end
paused.battle={Banner=function(_,...) Check(not paused.pointer.captured,'PAUSED mini banner appears after pointer release');banners[#banners+1]={...} end}
paused:Escape()
local p=scope_fixture.pauseBanner;local b=banners[1]
Check(pauseCalls==1 and #banners==1 and b[1]==p[1] and b[2]==p[5] and b[3]==p[2] and b[4]==p[3] and b[5]==p[4] and b[6]==p[6].mini,'battle release banner matches executable frozen source arguments')
paused:Escape();Check(settingsOpened==1 and #banners==1,'released second Escape retains existing settings route')
paused.dialog={};paused.pointer.captured=true;paused:Escape()
Check(dialogClosed==1 and pauseCalls==2 and #banners==1,'dialog Escape closes without spurious battle banner')
paused.battle=nil;paused.pointer.captured=true;paused:Escape()
Check(pauseCalls==3 and #banners==1,'non-battle release does not add competitive banner')
return checks

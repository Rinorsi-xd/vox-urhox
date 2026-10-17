-- Actual OrbitCamera, PreviewRoom and HangarAtmosphere; engine nodes are doubles.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function()return true end}
package.loaded['render.Quality']={current={reflectionHz=30}}
local checks=0
local function check(value,label)assert(value,label);checks=checks+1 end
local vec={}
vec.__index=function(self,key)
    if key=='length' then return math.sqrt(self.x*self.x+self.y*self.y+self.z*self.z) end
    return vec[key]
end
function vec.__add(a,b)return Vector3(a.x+b.x,a.y+b.y,a.z+b.z)end
function vec.__sub(a,b)return Vector3(a.x-b.x,a.y-b.y,a.z-b.z)end
function vec.__mul(a,b)return Vector3(a.x*b,a.y*b,a.z*b)end
function vec.__div(a,b)return Vector3(a.x/b,a.y/b,a.z/b)end
Vector3=setmetatable({}, {__call=function(_,x,y,z)return setmetatable({x=x,y=y,z=z},vec)end})
Vector3.ZERO=Vector3(0,0,0)
Variant=function(value)return value end
Ray=function(origin,direction)return {origin=origin,direction=direction}end
RAY_TRIANGLE=1;DRAWABLE_GEOMETRY=1
local function copy(source)local out={};for k,v in pairs(source)do out[k]=v end;return out end
local function same(value,original,label)
    for k,v in pairs(original)do check(value[k]==v,label..' field '..k)end
    for k in pairs(value)do check(original[k]~=nil,label..' no new field '..k)end
end
local node={}
node.__index=function(self,key)
    if key=='worldPosition'then return self.position elseif key=='worldRotation'then return self.rotation end
    return node[key]
end
function node:GetScene()return self.scene end
function node:CreateChild(name)return setmetatable({scene=self.scene or self,name=name,position=Vector3.ZERO,rotation={}},node)end
function node:CreateComponent(kind)
    check(kind=='Camera','only camera component allocated')
    self.component={node=self};return self.component
end
function node:GetComponent()return self.component end
function node:LookAt(target)
    if self.failLook then self.failLook=false;error('injected LookAt failure')end
    self.rotation={target=target}
end
function node:SetWorldTransform(position,rotation)self.position=position;self.rotation=rotation end
local Orbit=require 'controls.OrbitCamera'
local Room=require 'controls.PreviewRoom'
local Atmosphere=require 'scene.HangarAtmosphere'
local Warm=assert(load(CANDIDATE_SOURCE))()
local function fixture()
    local scene=setmetatable({},node);scene.scene=scene
    local c=Orbit.New(scene)
    local model={material={GetSurfaceShader=function()return {name='Shaders/BLGL/Hangar/Surface.shader'}end}}
    local root=scene:CreateChild('OrbitalHangar');root.enabled=true
    model.node={parent=root,name='Wall'}
    function root:GetComponents()return {model}end
    local hits=0
    local octree={Raycast=function()hits=hits+1;return {{drawable=model,distance=7}}end}
    function scene:GetComponent()return octree end
    c.safety=Room.New(scene,root)
    c:Apply()
    c:FlyTo({target={2,2,3},dist=20,yaw=160,pitch=22,fov=50,spin=true},.65)
    local h={root=root,scene=scene,time=10,greet=3.2,nextReflection=99,
        reflNode=scene:CreateChild('reflection'),reflAspect=1.8,
        reflCam={GetProjection=function()return 3 end,GetView=function()return 5 end},
        padMat={values={}},queued=0,filters=0,failQueue=false}
    function h.padMat:SetShaderParameter(key,value)self.values[key]=value end
    function h.padMat:GetShaderParameter(key)return self.values[key]end
    function h:ResizeReflection(cam)check(cam==c.camera,'reflection real camera reused')end
    h.reflTex={renderSurface={QueueUpdate=function()
        h.queued=h.queued+1
        if h.failQueue then h.failQueue=false;error('injected reflection queue failure')end
    end}}
    h.reflFilter={Queue=function()
        h.filters=h.filters+1
        if h.failFilter then h.failFilter=false;error('injected reflection filter failure')end
    end}
    h.nextReflection=h.time;Atmosphere.Update(h,c.node,c.camera,h.time)
    return {scene=scene,hangar=h,camera=c,loadingFlow={active=true}},function()return hits end
end
local function snapshot(app)
    local c=app.camera;local h=app.hangar
    return {camera=copy(c),cur=copy(c.cur),flight=copy(c.flight),from=copy(c.flight.from),to=copy(c.flight.to),
        safety=copy(c.safety),position=c.node.position,rotation=c.node.rotation,
        reflectionPosition=h.reflNode.worldPosition,reflectionRotation=h.reflNode.worldRotation,
        reflection=copy(h.reflCam),matrix=h.padMat:GetShaderParameter('refl_matrix'),nextReflection=h.nextReflection}
end
local function stable(app,s,restored)
    local c=app.camera;local h=app.hangar
    same(c,s.camera,'live camera');same(c.cur,s.cur,'live cur');same(c.flight,s.flight,'live flight')
    same(c.flight.from,s.from,'live flight.from');same(c.flight.to,s.to,'live flight.to')
    same(c.safety,s.safety,'live safety cache')
    check(h.time==10 and h.greet==3.2,'hangar animation time unchanged')
    if restored then
        check(c.node.position==s.position and c.node.rotation==s.rotation,'exact main transform restored')
        check(h.reflNode.worldPosition==s.reflectionPosition and h.reflNode.worldRotation==s.reflectionRotation,'exact reflection transform restored')
        same(h.reflCam,s.reflection,'reflection camera')
        check(h.nextReflection==s.nextReflection and h.padMat:GetShaderParameter('refl_matrix')==s.matrix,'reflection matrix and scheduling restored')
    end
end
local random,randomseed=math.random,math.randomseed
math.random=function()error('candidate consumed RNG')end
math.randomseed=function()error('candidate reset RNG')end
do
    local app,hits=fixture();local s=snapshot(app);local beforeHits=hits()
    local w=assert(Warm.New(app));stable(app,s,false)
    check(w.scratch.cur~=app.camera.cur and w.scratch.flight~=app.camera.flight,'independent mutable orbit state')
    check(w.scratch.safety~=app.camera.safety and hits()>beforeHits,'real clearance ran on isolated safety cache')
    check(w.scratch.flight.elapsed==.325 and app.camera.flight.elapsed==0,'real flight midpoint without live progression')
    check(not w:Presented() and w.phase==2 and w.scratch.flight==false,'real endpoint presented next')
    stable(app,s,false)
    check(not w:Presented() and w.phase==3,'restoration must await one real presentation')
    stable(app,s,true)
    check(w:Presented() and w.frames==3 and w.disposed,'restore frame presented before completion')
    check(app.hangar.queued==4 and app.hangar.filters==4,'midpoint endpoint and restored reflection queued')
    check(w:Presented() and w.frames==3,'completion idempotent')
    stable(app,s,true)
end
for phase=1,3 do
    local app=fixture();local s=snapshot(app);local w=assert(Warm.New(app))
    for _=2,phase do w:Presented()end
    w:Dispose();stable(app,s,true)
    check(not w:Presented() and w.disposed,'cancel never counts as presented phase '..phase)
    w:Dispose()
end
for _,failure in ipairs({'new-look','new-queue','new-filter','present-look','present-queue','present-filter','restore-queue','restore-filter'})do
    local app=fixture();local s=snapshot(app)
    local w
    if failure:match('^present')or failure:match('^restore')then w=assert(Warm.New(app))end
    if failure:match('^restore')then w:Presented()end
    if failure:match('look$')then app.camera.node.failLook=true
    elseif failure:match('filter$')then app.hangar.failFilter=true
    else app.hangar.failQueue=true end
    local ok,err=pcall(function()if w then w:Presented()else Warm.New(app)end end)
    check(not ok and tostring(err):find('injected',1,true),'injected failure surfaced '..failure)
    stable(app,s,true)
    if w then check(w.disposed and not w.completed,'failure disposes without completion')end
end
for _,invalid in ipairs({'uncovered','no-flight','finished-flight','zero-duration','nan-duration','disabled','disposed','foreign-hangar','foreign-root','foreign-camera','wrong-camera','no-reflection'})do
    local app=fixture();local h=app.hangar;local c=app.camera
    if invalid=='uncovered'then app.loadingFlow.active=false
    elseif invalid=='no-flight'then c.flight=false
    elseif invalid=='finished-flight'then c.flight.elapsed=c.flight.duration
    elseif invalid=='zero-duration'then c.flight.duration=0
    elseif invalid=='nan-duration'then c.flight.duration=0/0
    elseif invalid=='disabled'then h.root.enabled=false
    elseif invalid=='disposed'then h.disposed=true
    elseif invalid=='foreign-hangar'then h.scene={}
    elseif invalid=='foreign-root'then h.root.scene={}
    elseif invalid=='foreign-camera'then c.node.scene={}
    elseif invalid=='wrong-camera'then c.camera.node={}
    elseif invalid=='no-reflection'then h.reflTex=nil end
    local position,rotation,queues=c.node.position,c.node.rotation,h.queued
    local w=Warm.New(app)
    check(w==nil,'invalid state rejected '..invalid)
    check(c.node.position==position and c.node.rotation==rotation and h.queued==queues,'guard has no side effect '..invalid)
end
math.random=random;math.randomseed=randomseed
print('HangarCameraWarmup candidate: '..checks..' checks PASS')

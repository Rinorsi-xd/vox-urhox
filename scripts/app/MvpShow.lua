local ResourceGate=require("app.ResourceGate")
local Blueprint=require("construction.Blueprint")
local ImportedDependencies=require("parts.Dependencies")
local MvpMusic=require("audio.MvpMusic")
local ImageCache=require("urhox-libs/UI/Core/ImageCache")

local Motion=require 'combat.MvpMotion'
local Stage=require 'render.MvpStage'
local M={};M.__index=M
function M.New(session,entry,stats)
    local self=setmetatable({},M);self:init(session,entry,stats);return self
end
function M:init(session,entry,stats)
    self.session=session;self.entry=entry;self.stats=stats;self.t=0;self.fired={};self.deform={sy=1,twist=0,lx=0,lz=0,bulge=0}
    self.gate=ResourceGate.New();self.preparing=true;self.failed=false;self.done=false;self.cleared=false
    self.sq=Motion.Spring(140,4.2);self.lx=Motion.Spring(80,3.5);self.lz=Motion.Spring(80,3.5);self.tw=Motion.Spring(90,3.2)
    self.scene=Scene();self.scene:CreateComponent('Octree')
    local zone=self.scene:CreateChild('Zone'):CreateComponent('Zone');zone.boundingBox=BoundingBox(-500,500);zone.ambientSource=AMBIENT_COLOR
    zone.ambientColor=Color(.12,.14,.17);zone.fogColor=Color(38/255,51/255,66/255);zone.depthFogStart=70;zone.depthFogEnd=220
    local n=self.scene:CreateChild('Sun');n.direction=Vector3(-15,-30,-20);local light=n:CreateComponent('Light');light.lightType=LIGHT_DIRECTIONAL;light.color=Color(1,.76,.5);light.brightness=1.3
    self.cameraNode=self.scene:CreateChild('Camera');self.camera=self.cameraNode:CreateComponent('Camera');self.camera.fov=38;self.camera.farClip=500
    self.viewport=Viewport:new(self.scene,self.camera)
    local bp=Blueprint.New():Load(entry.unit.source)
    local paths=Stage.Dependencies();for _,p in ipairs(ImportedDependencies.For(bp:List())) do paths[#paths+1]=p end
    self.bp=bp
    self.gate:Start(paths,function(ok,err)
        if self.cleared then return end
        -- Download completion can run under the native download lock: only record
        -- the outcome here; stage construction and the synchronous music load run
        -- on the next Update.
        self.downloaded={ok=ok==true,err=err}
    end)
end
function M:Install()
    local download=self.downloaded;self.downloaded=nil
    local session,entry,bp=self.session,self.entry,self.bp
    if not download.ok then self.failed=true;self.preparing=false;self.done=true;print('[MVP] Resource loading failed: '..tostring(download.err));self:Dispose();return end
    local success,message=pcall(function()
        self.stage=Stage.New(self.scene,bp,entry.unit.name);self.prevY=Motion.PodY(0,self.stage.S,self.stage.height);self.prevVy=0;self.prevRot=0;self.prevW=0
        self.music=MvpMusic.New(self.scene,session.app.music)
        self.previousMusicPaused=session.app.music.userPaused;session.app.music:SetPaused(true);session.app.graphicsSettings:Show(self.scene,self.camera);session.app.graphicsSettings:Apply(self.scene)
        self.preparing=false;self.active=true;self:Update(.001)
        print('[MVP] Ready '..entry.unit.name..' / '..bp:Size()..' parts')
    end)
    if not success then print('[MVP] Preparation failed: '..tostring(message));self.preparing=false;self.failed=true;self.done=true;self:Dispose() end
end
function M:Skip()
    if self.done or self.preparing then return end
    if self.t<7.1 then self.t=7.1;self.jumped=true;self.prevY=Motion.PodY(7.1,self.stage.S,self.stage.height);self.prevRot=Motion.PodRot(7.1);self.prevVy=0;self.prevW=0
    else self.finishing=self.finishing or 0 end
end
local function Tanh(x) local e=math.exp(2*x);return (e-1)/(e+1) end
function M:Update(dt)
    if self.preparing and self.downloaded and not self.cleared then self:Install();return end
    if self.done or self.preparing then return end
    local elapsed=math.min(.05,math.max(.00001,dt));self.music:Update()
    if not self.session:HasFocus() then return end
    if self.finishing then self.finishing=self.finishing+math.max(0,dt);if self.finishing>=.36 then self.done=true;self:Dispose();return end end
    self.t=self.t+elapsed;local t,S,h=self.t,self.stage.S,self.stage.height
    local function Once(id,at,fn) if t>=at and not self.fired[id] then self.fired[id]=true;if not self.jumped or id=='title' then fn() end end end
    Once('land',2.1,function() self.sq.v=self.sq.v-4.6;self.lz.v=self.lz.v+2;self.music:Play('supply_open',.8) end)
    Once('pop',2.4,function() self.sq.v=self.sq.v+3.6;self.lx.v=self.lx.v+(math.random()*4-2);self.flashAt=t;self.shake=1;self.music:Play('wave_clear');self.music:Play('loot_drop',.9) end)
    Once('spin',2.55,function() self.tw.v=self.tw.v+5;self.sq.v=self.sq.v+2 end)
    Once('stop',5.1,function() self.sq.v=self.sq.v-4.4;self.tw.v=self.tw.v-6;self.lx.v=self.lx.v-2.5 end)
    Once('title',6.3,function() self.music:Play('supply_choose') end)
    local y,rot=Motion.PodY(t,S,h),Motion.PodRot(t);local vy=(y-self.prevY)/elapsed;local ay=(vy-self.prevVy)/elapsed;local w=(rot-self.prevRot)/elapsed;local aw=(w-self.prevW)/elapsed
    self.prevY=y;self.prevVy=vy;self.prevRot=rot;self.prevW=w
    local dance=Motion.Smooth((t-5.8)/1.5);local stage=1-dance;local beat=self.music.beat
    local clamp=function(x,m) return math.max(-m,math.min(m,x)) end
    local sq=Motion.Step(self.sq,elapsed,-clamp(ay,40)*.02)*stage+beat.bounce*.42*dance
    local tw=Motion.Step(self.tw,elapsed,-clamp(aw,30)*.25)*stage
    local lx,lz=Motion.Step(self.lx,elapsed,-clamp(aw,30)*.08),Motion.Step(self.lz,elapsed,-clamp(ay,40)*.004)
    self.deform={sy=1+.45*Tanh(sq/.45),bulge=math.max(0,-sq)*.35,twist=.5*Tanh((tw*.4+beat.twist*.16*dance)/.5),lx=lx*.22*stage+beat.lean*.12*dance,lz=lz*.22*stage}
    self.stage:Update(t,self.deform,self.jumped);self.cameraStep=elapsed
    self:Camera()
end
function M:Camera()
    if not self.stage or self.cleared then return end
    local p,at=Motion.Camera(self.t,self.stage.S,self.stage.height);local pos=Vector3(table.unpack(p))
    if (self.shake or 0)>.01 then pos=pos+Vector3((math.random()*2-1)*self.shake*self.stage.S*.05,(math.random()*2-1)*self.shake*self.stage.S*.05,0);self.shake=self.shake*math.exp(-(self.cameraStep or 0)*7) end
    self.cameraNode.position=pos;self.cameraNode:LookAt(Vector3(table.unpack(at)))
end
function M:Snapshot()
    return {preparing=self.preparing,active=self.active and not self.done,done=self.done,failed=self.failed,t=self.t,jumped=self.jumped,finishing=self.finishing,
        name=self.entry.unit.name,team=self.entry.unit.team,me=self.entry.unit==self.session.battle.player,stats=self.stats,deform=self.deform,
        stage=self.stage and {S=self.stage.S,h=self.stage.height,banner=self.stage.nodes.flag.enabled,column=self.stage.nodes.column.enabled,uploads=self.stage.confettiUploads,materials=#self.stage.carMaterials,
            smoke=self.stage.smoke.enabled,smokeUploads=self.stage.smokeUploads,bannerName=self.stage.awardBanner.bound,bannerRenders=self.stage.awardBanner.renders},
        music=self.music and not self.music.disposed and {playing=self.music.source.playing,position=self.music.source.timePosition,beat=self.music.beat.index}}
end
function M:Dispose()
    if self.cleared then return end;self.cleared=true;self.gate:Cancel()
    if self.music then self.music:Dispose();self.session.app.music:SetPaused(self.previousMusicPaused==true) end
    if self.stage then self.stage:Dispose();self.stage=nil end
    ImageCache.Release('Mvp/title.png')
    if self.active and not self.session.disposed then
        self.session.app.graphicsSettings:Show(self.session.scene,self.session.camera:GetCamera(),{scaled=true});self.session.app.graphicsSettings:Apply(self.session.scene)
    end
    self.scene:Dispose();self.scene=nil;self.viewport=nil
end
return M

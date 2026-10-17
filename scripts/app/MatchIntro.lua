-- Authored shots and timings from frozen three/src/battle/matchIntro.js.
local Matchmaker=require("combat.Matchmaker")
local StoryComms=require("audio.StoryComms")
local MatchIntro=require("ui.MatchIntro")

local UI=require 'urhox-libs/UI'
local Coord=require 'core.Coord'
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
local function Shot(duration,fov,label,from,look,to,toLook,say,vo,face)
    return {dur=duration,fov=fov,label=label,from=from,look=look,to=to,toLook=toLook,say=say,vo=vo,face=face or 'nono_talk'}
end
function M.New(session)
    local self=setmetatable({},M);self.session=session;self.time=0;self.index=0;self.localTime=0;self.done=false
    local battle=session.battle;local world=session.world;local maker=Matchmaker
    self.full=not maker.IntroSeen(session.app.store,session.map.battleMode);self.shots={}
    if self.full then
        local hall=world.layout.nav.nodes.iC1[2]
        self.shots={
            Shot(6,50,{'CRASH CRATER','坠舰陨坑'},{300,170,-260},{0,0,0},{230,120,40},{0,-10,0},'嘿，'..battle.player.name..'。欢迎来到坠舰陨坑——坑底躺着的那艘就是 CV-07 ARGUS 号，今天的战场就在它身上。',1,'nono_smile'),
            Shot(6,55,{'HULL HALL','舰体大厅'},{-120,hall+7,-14},{0,hall+2,0},{-40,hall+5,-10},{40,hall+1,0},'今天是歼灭战，三局两胜。对面三台车，回合里没有复活——把他们全部打爆就赢下这一回合。',2),
            Shot(6,48,{'AUTO REPAIR','自动维修'},{40,world:GroundAt(40,120)+30,110},{0,6,234},{20,world:GroundAt(20,160)+18,170},{0,6,234},'五秒没挨打，你的车会自己修结构，每秒 15%。打不过就先撤，修好了再回来。',3),
            Shot(6,50,{'FINAL MINUTE','决胜时刻'},{-150,70,-150},{0,-10,0},{-90,45,-110},{0,-10,0},'每回合最后一分钟是决胜时刻，修理系统会被干扰。时间到了还没分出胜负，就比谁活得多、谁剩的血多——记得活下来。',nil,'nono_deadpan'),
        }
    end
    if self.full and battle.mode~='elimination' then
        local first=self.shots[1];self.shots={first}
        local mx=battle.objectives
        if battle.mode=='conquest' then
            local function Orbit(p,a0,a1,label,say,vo)
                self.shots[#self.shots+1]=Shot(6,50,label,{p[1]+math.cos(a0)*55,p[2]+62,p[3]+math.sin(a0)*55},p,{p[1]+math.cos(a1)*55,p[2]+49.6,p[3]+math.sin(a1)*55},p,say,vo)
            end
            local A,B,C=mx.points[1].pos,mx.points[2].pos,mx.points[3].pos
            Orbit(A,-.9,-.2,{'POINT A','A 点'},'站点争夺，四对四。地图上有 A、B、C 三个站点，开进圈里就开始占领。',5)
            self.shots[#self.shots+1]=Shot(6,55,{'POINT C','C 点 · 舰体大厅'},{C[1]-90,C[2]+9,C[3]-14},C,{C[1]-50,C[2]+8,C[3]-10},C,'每个站点分三个节点，三个全推满才算占下来；推到一半人走了，没推完的那截会退回上一个节点。',6)
            Orbit(B,2.2,2.9,{'POINT B','B 点'},'占着的站点会给我们的目标条充能，先到 100% 的一方获胜。',7)
            local p=mx.bases.red.aim
            self.shots[#self.shots+1]=Shot(7,46,{'ENEMY REACTOR','敌方反应堆'},{p[1]+50,p[2]+26,p[3]-70},p,{p[1]+26,p[2]+12,p[3]-40},p,'三个站点全拿下，敌方基地的护盾就会熄灭——去打他们反应堆上的质子，把分偷过来。反过来也一样，别让他们偷咱们的。',8,'nono_deadpan')
        else
            local p=mx:At(0).pos;local q=mx:At(mx.length/3).pos
            self.shots[#self.shots+1]=Shot(6,48,{'PAYLOAD','运输车'},{p[1]+22,p[2]+9,p[3]+4},{p[1],p[2]+1.5,p[3]},{p[1]+10,p[2]+5,p[3]+12},{p[1],p[2]+1.5,p[3]},'推车，四对四。这台运输车要送到北要塞门口，路线要下坑、穿过舰体大厅。',9)
            local route=Shot(8,55,{'ROUTE','路线 · '..math.floor(mx.length+.5)..' 米'},p,p,q,q,'上半场我们进攻：贴着车就能推，车旁的敌人不比我们少，车就会停下来。',10);route.route=true;self.shots[#self.shots+1]=route
            self.shots[#self.shots+1]=Shot(6,48,{'CHECKPOINT','检查点'},{q[1]+20,q[2]+95,q[3]-70},q,{q[1]+10,q[2]+70,q[3]-40},q,'过检查点加时、复活点往前挪。下半场换边防守——两边比谁推得远。',11,'nono_deadpan')
        end
    end
    for _,team in ipairs(self.full and {'blue','red'} or {'red','blue'}) do
        local pad=world.layout.pads[team=='blue' and 'player' or 'enemy'];local yaw=pad.yaw;local p=pad.pos
        local fw,rt={math.sin(yaw),0,math.cos(yaw)},{math.cos(yaw),0,-math.sin(yaw)}
        local function Cam(side,dist,h) return {p[1]+fw[1]*dist+rt[1]*side,p[2]+h,p[3]+fw[3]*dist+rt[3]*side} end
        local function Look(side) return {p[1]+rt[1]*side,p[2]+1.5,p[3]+rt[3]*side} end
        local shot=Shot(self.full and 5 or 4,46,nil,Cam(-16,20,6),Look(-8),Cam(16,17,4.5),Look(8),
            team=='blue' and '这是你的小队。车都是大家自己拼的，别让它们白跑一趟。' or '这是今天的对手。我可不想再写一份事故报告。',team=='blue' and 12 or 13,team=='blue' and 'nono_smile' or 'nono_deadpan')
        shot.team=team;self.shots[#self.shots+1]=shot
    end
    self.root=session.scene:CreateChild('MatchIntroAudio');self.voice=self.root:CreateComponent('SoundSource');self.voice:SetSoundType('VoxMatchVoice')
    self.comms=StoryComms.New(session.scene,{voices={}},true)
    for _,shot in ipairs(self.shots) do
        if shot.vo then local sound=cache:GetResource('Sound',string.format('Sounds/Match/m%02d.wav',shot.vo));shot.voiceLength=sound.length;shot.dur=math.max(shot.dur,sound.length+1.1) end
    end
    session:Pause();session.hud.root:SetVisible(false)
    self.page=MatchIntro.New(self);UI.RegisterGlobalComponent('vox-match-intro',self.page);UI.PushOverlay(self.page)
    self:Update(0);return self
end
function M:Update(dt)
    if self.done then return end
    -- The bus is shared with the battle radio; pause on focus changes only and
    -- always release it in Dispose, or the radio stays muted for the match.
    if not self.session:HasFocus() then Levels.PauseBus(self,'VoxMatchVoice',true);return end
    Levels.PauseBus(self,'VoxMatchVoice',false)
    self.time=self.time+math.max(0,dt);local t=self.time;local index=1
    while index<=#self.shots and t>=self.shots[index].dur do t=t-self.shots[index].dur;index=index+1 end
    if index>#self.shots then self:Finish();return end
    self.localTime=t
    if index~=self.index then
        self.index=index;self.shot=self.shots[index]
        self.voice:StopImmediate()
        if self.shot.vo then Levels.Play(self.voice,cache:GetResource('Sound',string.format('Sounds/Match/m%02d.wav',self.shot.vo)),0,.7) end
    end
    local shot=self.shot;local duration=shot.voiceLength
    self.comms:Present('nono',shot.say,shot.face,self.time,self.localTime,duration and duration*.95 or utf8.len(shot.say)/26,duration and .18 or 0,duration and duration+.26 or nil)
end
function M:Camera()
    if self.done then return end
    local shot=self.shot;local x=math.min(1,self.localTime/shot.dur);local k=x<.5 and 4*x*x*x or 1-(-2*x+2)^3/2
    local function Lerp(a,b) return Coord.Vec(a[1]+(b[1]-a[1])*k,a[2]+(b[2]-a[2])*k,a[3]+(b[3]-a[3])*k) end
    local camera=self.session.camera:GetCamera();local node=camera.node
    if shot.route then
        local mx=self.session.battle.objectives;local p=mx:At(k*mx.length).pos;local ahead=mx:At(math.min(mx.length,k*mx.length+35)).pos
        node.position=Coord.Vec(p[1]+18,p[2]+35,p[3]-30);node:LookAt(Coord.Vec(table.unpack(ahead)));camera.fov=shot.fov;return
    end
    node.position=Lerp(shot.from,shot.to);node:LookAt(Lerp(shot.look,shot.toLook));camera.fov=shot.fov
end
function M:Finish()
    if self.done then return end;self.done=true
    Matchmaker.MarkIntro(self.session.app.store,self.session.map.battleMode)
    self:Dispose();self.session.hud.root:SetVisible(true);self.session.camera:GetCamera().fov=48
    if self.session.touch then self.session:Resume() end
end
function M:Dispose()
    if self.comms then self.comms:Dispose();self.comms=nil end
    if self.page then UI.PopOverlay(self.page);UI.UnregisterGlobalComponent('vox-match-intro');self.page:Destroy();self.page=nil end
    if self.voice then self.voice:StopImmediate();self.voice:Dispose();self.voice=nil end
    if self.root then self.root:Dispose();self.root=nil end
    Levels.ReleaseBuses(self,{'VoxMatchVoice'})
    self.done=true
end
return M

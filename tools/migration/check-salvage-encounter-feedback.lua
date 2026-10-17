local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return type(a)=='number' and math.abs(a-b)<1e-7 or a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
package.path='scripts/?.lua;'..package.path
dofile('tools/migration/g5-offline-imports.lua').Exclude({'parts.Dependencies','render.SalvageFx',
    'render.SalvageExplosion','render.SalvageView','combat.DriverActions','drive.RotorMotion',
    'combat.PlayerViewSync','render.CineDeathFilter','render.SalvageCineDust'})
package.loaded['core.ResourceData']={Read=function(name) return resources[name] end}
package.loaded['combat.CarUnit']={};package.loaded['combat.EnemyDriver']={}
package.loaded['ui.SalvageLootMotion']={Event=function() end}
package.loaded['render.SalvageCinematics']={};package.loaded['ui.SourceButtonMotion']={}
package.loaded['salvage.Drops']={rat={}}
local Director=require 'salvage.Director'
local Run=require 'salvage.Run'
local Cine=require 'salvage.Cinematics'
local function Make()
    local trace={};local player={alive=true,spec={bounds={min={0,0,0},max={2,2,2}}},vehicle={native={},mass=100},Position=function() return {10,2,30} end}
    local rules={time=360.6,op={},heat=0,kills=0,cargo={},Drain=function() return {} end,
        Step=function() end,Heat=function(_,n) trace[#trace+1]={'heat',n} end}
    local run=setmetatable({player=player,rules=rules,entries={{unit=player}},feed={},session={controls={held={}},pointer={captured=false}},
        explosion={Explode=function(_,...) trace[#trace+1]={'explode',...} end},
        audio={Event=function(_,e) if e.type=='airdropLanded' then trace[#trace+1]={'sound','wave_start',.8} end end},view={Update=function() end},protectionEnded=true,landed=true,begun=true,
        fx={Loot=function(_,...) trace[#trace+1]={'loot',...} end,Target=function() end,Update=function() end},
        cine={Elite=function() trace[#trace+1]={'elite'} end,NameCard=function(_,a,b,s) trace[#trace+1]={'card',a,b,s*1000} end,
            Flash=function(_,...) trace[#trace+1]={'flash',...} end,Death=function() trace[#trace+1]={'death'} end}},Run)
    local realFeed=Run.Feed
    function run:Feed(a,b,c) realFeed(self,a,b,c);trace[#trace+1]={'feed',a,b,c} end
    function rules:AddExtra(o) self.extra=o end
    local director=setmetatable({run=run,entries=run.entries,encounters={},huntLeft=60,timer=0},Director)
    function director:Surface(x,z) return {x,3,z} end
    function director:Noise(...) trace[#trace+1]={'noise',...} end
    function director:Step() end
    run.director=director
    return run,director,trace
end
input={GetKeyDown=function() return false end};KEY_E=1
for i,case in ipairs(fixtures.alerts) do
    local run,d,trace=Make()
    local enc={name='测试据点',kind=case.kind,units={{unit={alive=true,elite=case.hasElite},def={name='精英车',title='重装',gang='铁帮'}},{unit={alive=false}}}}
    d:Alert(enc,case.why);d:Alert(enc,'重复')
    Check(enc.alerted==true and Same(trace,case.trace),'alert '..i..' source alive count, reason, warning/card, once')
end
for i,case in ipairs(fixtures.clears) do
    local run,d,trace=Make();d.Step=Director.Step
    local enc={id='X',name='测试据点',kind=case.kind,reward=case.reward,g={1,2,3},lastPos={4,5,6},units={},state='active',hinted=true}
    d.encounters={enc};d:Step(.25)
    Check(Same(trace,case.trace),'clear '..i..' source rarity beam and location feed')
    Check(Same(run.rules.extra.g,case.cache),'clear '..i..' source cache ground')
    d:Step(.25);Check(Same(trace,case.trace),'clear '..i..' no repeated glow/reward')
end
for i,case in ipairs(fixtures.drops) do
    local run,d,trace=Make();run.player.vehicle={Yaw=function() return .4 end};run.rules.rand=function() return case.seed end
    run:Airdrop()
    Check(Same(trace,case.trace),'airdrop '..i..' source cyan beam, rounded distance, warning, feed and noise order')
    Check(run.rules.extra.id==case.id,'airdrop '..i..' source rounded drop identity')
end
for i,case in ipairs(fixtures.kills) do
    local run,d,trace=Make()
    local u={alive=false,elite=case.elite,name='敌车',spec={bounds={radius=4}},Position=function() return {1,2,3} end}
    run.entries[2]={unit=u,why=case.why~='' and case.why or nil,kind='rat'}
    function d:Remove() table.remove(run.entries,2) end
    run:AfterStep(0)
    Check(Same(trace,case.trace),'kill '..i..' source reason/tint/explosion/heat')
    Check(run.rules.extra.elite==case.elite,'kill '..i..' original elite wreck flag retained')
end
do
    local run,d,trace=Make();run.player.alive=false;run.rules.events={{type='failed'}}
    run.rules.Drain=function(self) return self.events end;run:Events()
    Check(Same(trace,fixtures.deathTrace),'death source title, subtitle, red warning, explosion and cinematic')
end
do
    local run,d,trace=Make();run.rules.time=7.9;run.protectionEnded=nil
    run:AfterStep(.1);Check(#trace==0,'protection source exact eight seconds remains silent')
    run:AfterStep(.2);Check(#trace==1 and trace[1][1]=='feed' and trace[1][2]=='落地保护结束' and trace[1][4]=='#f0a21c','protection source expiry warning')
    run:AfterStep(.3);Check(#trace==1,'protection expiry warning emitted once')
end
do
    local run,d,trace=Make();run.spawn={name='试验投放坪'};run.rules.op.name='探索'
    local cine=setmetatable({run=run,view={HideShip=function() end},ReleaseCar=function() end},Cine)
    cine:Finish({name='drop'})
    Check(trace[1][2]=='行动开始' and trace[1][3]=='试验投放坪 · 时限 15:00 · 货舱 20 格 · 探索行动 · 按 E 搜箱子 / 按住 E 拆残骸' and trace[1][4]=='#3ee6ff','landing source actionable cargo and control notice')
end
do
    local Audio=require 'audio.SalvageAudio';local Levels=require 'audio.AudioLevels'
    local now=0;Time={GetSystemTime=function() return now*1000 end};input.focus=true;input.minimized=false
    local sources={};local function Node()
        return {CreateChild=function() return Node() end,Dispose=function() end,CreateComponent=function()
            local s={playing=false};function s:SetSoundType(kind) self.soundType=kind end
            function s:StopImmediate() self.playing=false end
            function s:Play(sound,frequency,gain,pan) self.playing=true;self.sound=sound;self.gain=gain;self.pan=pan end
            sources[#sources+1]=s;return s
        end}
    end
    cache={GetResource=function(_,kind,path) return {path=path,length=.3} end}
    local a=Audio.New(Node());a:SetActive(true)
    local deps=Audio.Dependencies();Check(#deps==10,'all seven original reveal and three existing alert sounds predeclared')
    for _,case in ipairs({{'vaultStart','urgent_warning',.7},{'vaultOpened','supply_open',1},{'airdropLanded','wave_start',.8}}) do
        local kind,id,strength=table.unpack(case);local expected=fixtures.sounds[id];now=now+2
        Check(a:Event({type=kind}),'actual source alert event '..kind)
        local s=sources[#sources];Check(math.abs(s.gain-.65*expected.gain*strength)<1e-9 and s.pan==0,'source sample master, strength and feedback bus '..id)
        Check(not a:Event({type=kind}),'source duplicate event gap '..id)
        now=now+expected.gap+.001;Check(a:Event({type=kind}),'source cue recovers after gap '..id)
    end
    Check(a:Event({type='reveal',item={r=4}}) and #a.voices==1 and #a.sampleVoices>0,'reveal voices independent of alert voices')
    local before=a.counts.reveal4;input.focus=false
    Check(not a:Event({type='reveal',item={r=4}}) and a.counts.reveal4==before,'hidden/unfocused alert and reveal remain silent')
    a:SetActive(true);local stopped=true;for _,s in ipairs(sources) do stopped=stopped and not s.playing end;Check(stopped,'focus loss stops every voice')
    input.focus=true;Levels.Set('sfx',0)
    Check(not a:Event({type='vaultStart'}),'muted bus does not create alert voices')
    a:SetActive(true);stopped=true;for _,s in ipairs(sources) do stopped=stopped and not s.playing end;Check(stopped,'mute stops all retained voices')
    Levels.Set('sfx',.65);now=now+10
    Check(a:Event({type='airdropLanded'}),'unmuted source resumes normal alerts')
    a:SetActive(false);Check(not a:Event({type='vaultOpened'}),'paused/inactive rejects alert')
    a:Dispose();a:Dispose();Check(not a:Event({type='vaultStart'}) and #a.voices==0 and #a.sampleVoices==0,'dispose idempotent, all sources cleared and no late sound')
end
return checks

"""Execute frozen H5 impact clauses and compare the real Lua implementation."""
import json
import hashlib
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source = r"""
const fs=require('fs'),vm=require('vm'),path=require('path');
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const source=fs.readFileSync(path.join(baseline.snapshot,'three/src/drive/testDrive.js'),'utf8');
const update=source.slice(source.indexOf('if ( this.hitStop > 0 )'),source.indexOf('this.player.flush();',source.indexOf('if ( this.hitStop > 0 )')));
const begin=source.indexOf('this.hitStop = Math.max( this.hitStop, 0.08 )');
const finish=source.indexOf('this.trauma = Math.min( 1, Math.max( this.trauma, 0.35 ) );',begin)+'this.trauma = Math.min( 1, Math.max( this.trauma, 0.35 ) );'.length;
const confirm=source.slice(begin,finish);
const Step=vm.runInNewContext('(function(dt){'+update+';return dt})');
const Confirm=vm.runInNewContext('(function(sim){'+confirm+'})');
const rows=[];
for(const units of [[],[{team:'red',alive:false}],[{team:'red',alive:true}],[{team:'neutral',alive:false}],[{team:'blue',alive:false}],[{team:'red',alive:false},{team:'neutral',alive:true}]]){
 const player={team:'blue'},s={player,hitStop:0,slowMo:0,fovPunch:0,trauma:0},sim={units:[player,...units]};
 Confirm.call(s,sim);
 const initial={hitStop:s.hitStop,slowMo:s.slowMo,fovPunch:s.fovPunch,trauma:s.trauma};
 const times=[];
 for(const dt of [.016,.032,.016,.016,.016,.05,.12,.02,.3,.25,.016])times.push({dt,out:Step.call(s,dt),hitStop:s.hitStop,slowMo:s.slowMo});
 rows.push({units,initial,times});
}
console.log(JSON.stringify(rows));
"""
rows = json.loads(subprocess.check_output(['node', '-e', source], cwd=ROOT, text=True))
lua = LuaRuntime()


def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value


lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path")
lua.execute(r"""
local rows=...
local Impact=require 'combat.KillImpact'
local function equal(a,b) assert(math.abs(a-b)<1e-12,tostring(a)..' != '..tostring(b)) end
for _,row in ipairs(rows) do
 local player={team='blue'};local units={player}
 for _,unit in ipairs(row.units) do units[#units+1]=unit end
 local s={combat={player=player},world={units=units},hitStop=0,slowMo=0,fovPunch=0,trauma=0}
 Impact.Confirm(s,{spec={}})
 for key,value in pairs(row.initial) do equal(s[key],value) end
 for _,record in ipairs(row.times) do equal(Impact.Step(s,record.dt),record.out);equal(s.hitStop,record.hitStop);equal(s.slowMo,record.slowMo) end
end
local s={hitStop=.1,fovPunch=6,trauma=.9};Impact.Confirm(s,{spec={}})
equal(s.hitStop,.1);equal(s.fovPunch,6);equal(s.trauma,.9)
local untouched={};Impact.Confirm(untouched,{});assert(next(untouched)==nil)
print('[KillImpact] PASS six actual H5 enemy-list/clock goldens, repeated impact, non-vehicle exclusion')
""", convert(rows))

data = json.loads((ROOT / 'assets/Combat/FeedbackSounds.json').read_text(encoding='utf-8'))
baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
assert data['killFeedbackSource']['commit'] == baseline['commit']
for cue_id in ('score_tick', 'objective_gain'):
    cue = data['cues'][cue_id]
    actual = (ROOT / 'assets' / cue['path']).read_bytes()
    expected = (pathlib.Path(baseline['snapshot']) / cue['source']).read_bytes()
    assert actual == expected
    assert hashlib.sha256(actual).hexdigest() == cue['sha256']
    assert len(actual) == cue['bytes']
print('[KillFeedbackAssets] PASS both approved waveforms equal frozen H5 bytes and SHA-256 provenance')
lua.execute(r"""
local data=...
package.loaded['core.ResourceData']={Read=function()return data end}
package.loaded['audio.RecoveryMix']={New=function()return {amount=0,Reset=function()end,Consume=function()end}end}
local played={}
package.loaded['audio.AudioLevels']={Play=function(source,sound,frequency,gain,pan)
 source.playing=true;played[#played+1]={id=sound.id,gain=gain,pan=pan,frequency=frequency}
end,SetGain=function()end}
cache={GetResource=function(_,_,id)return {id=id,GetFrequency=function()return 48000 end}end}
input={focus=true,minimized=false}
local function node()return {CreateChild=function()return node()end,CreateComponent=function()
 return {playing=false,SetSoundType=function()end,StopImmediate=function(self)self.playing=false end}
end,Dispose=function()end}end
local Audio=require 'audio.CombatFeedbackAudio'
local a=Audio.New(node());a:SetActive(true)
local confirms=0
a.Play=function(self,id,amount,pan,rate)confirms=confirms+(id=='kill_confirm' and 1 or 0);return Audio.Play(self,id,amount,pan,rate)end
a:Kill(1)
assert(confirms==1 and #a.pending==1 and #played==1,'one confirm and delayed destroy')
assert(a.pending[1].gain==.7 and a.pending[1].pan==0,'source kill nonspatial strength')
a.time=.119;assert(#played==1,'destroy does not precede 120ms')
local camera={worldPosition={x=0,y=0,z=0},worldRotation=setmetatable({},{__mul=function()return {x=1,y=0,z=0}end})}
Vector3={RIGHT={}}
a:Update(.001,camera,false)
assert(#played==2 and played[2].id==data.cues.vehicle_destroy.path,'delayed source waveform')
assert(math.abs(played[2].gain-data.cues.vehicle_destroy.gain*.7*.71*.65)<1e-12,'source confirm duck')
a:ScoreTick();local count=#played;a:ScoreTick();assert(#played==count,'35ms score tick gap')
a.time=a.time+.036;a:ScoreTick();assert(#played==count+1,'next score tick resumes')
a.time=1;a:Kill(5)
assert(played[#played].id==data.cues.objective_gain.path,'streak objective sound')
assert(math.abs(played[#played].gain-data.cues.objective_gain.gain*.65)<1e-12,'source strength clamps at one')
a:SetActive(false);assert(#a.pending==0,'pause cancels delayed kill sounds')
a:SetActive(true);a.time=2;a:Destroy(.2,-.4);a:Destroy(.7,0);a:Update(.12,camera,false)
assert(played[#played].pan==-.4,'coincident timers preserve source FIFO before cue gap')
local event={type='unitKilled',pos={0,0,0}}
a.time=3;a:Consume({event,event});assert(#a.pending==1,'same event object is deduplicated')
a:Dispose();assert(#a.pending==0,'dispose cancels delayed kill sounds')
print('[KillFeedbackAudio] PASS confirm/destroy/streak/score tick/FIFO/dedup/pause/dispose')
""", convert(data))
lua.execute(r"""
for _,name in ipairs({'controls.ChaseCamera','controls.ChaseState','render.DriveView','controls.DriveInput','ui.DriveHud',
 'render.WeaponView','render.CombatEffects','render.CombatView','core.Coord','render.TargetFeedback'}) do package.loaded[name]={} end
package.loaded['urhox-libs/UI']={GetViewportSize=function()return 1280,720 end,GetFocus=function()end}
package.loaded['ui.DialogHost']={Update=function()end}
local Session=require 'app.TrialSession'
local captured
local s=setmetatable({app={},touch=true,pointer={captured=false,Poll=function()end},controls={Clear=function()end},
 PollKeys=function()end,Tick=function(_,dt)captured=dt end},Session)
s:ConfirmKill({spec={}});s:Update(.016)
assert(math.abs(captured-.016*.06)<1e-12 and s.realFrameDt==.016,'actual Update delivers source impact dt while retaining real audio clock')
s:Update(.1);assert(s.hitStop==0 and math.abs(captured-.1*.06)<1e-12,'last hitStop frame stays at source six percent')
s:Update(.02);assert(captured==.02,'simulation returns to real dt after impact')
s.hitStop=.08;s.intro={done=false,Update=function()end};input.GetKeyPress=function()return false end;s.drillSpeed={Clear=function()end}
s:Update(.02);assert(s.hitStop==.08,'intro does not consume kill impact clock')
s.intro=nil;s.endless={run={state='editing'},Update=function()end};s:Update(.02)
assert(s.hitStop==.08,'paused endless editor does not consume kill impact clock')
print('[KillImpactHost] PASS actual TrialSession Update real/scaled clocks, last frame, intro/editor gates')
""")

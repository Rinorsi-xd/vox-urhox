"""Exercise actual feedback and TrialSession audio boundaries with CPU adapters."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
os.chdir(ROOT)
OLD = ROOT / '.tmp/outgame-cached-1792128891583'
TRIAL = 'scripts/app/TrialSession.lua'
AUDIO = 'scripts/audio/CombatFeedbackAudio.lua'
SOURCE = '.tmp/outgame-source-2026-10-15T12-35-57-243Z/three/src/drive/testDrive.js'


def audio_boundary(text):
    start = text.index('    local speaking=', text.index('function M:Tick('))
    end = text.index('    -- Fixed 60 Hz', start)
    return 'return function(self,dt,command)\n' + text[start:end] + '\nend'


fixture = r'''
package.path='scripts/?.lua;'..package.path
local clock=0;Time={GetSystemTime=function()return clock*1000 end}
input={focus=true,minimized=false};Vector3={RIGHT={x=1,y=0,z=0}}
local data={cues={}}
for _,id in ipairs({'vehicle_destroy','hit_tick','kill_confirm','objective_gain','game_over','repair_loop'}) do
 data.cues[id]={path=id,gain=.5,gap=0,loop=id=='repair_loop'}
end
package.preload['core.ResourceData']=function()return {Read=function()return data end}end
cache={GetResource=function(_,_,path)return {length=.5,GetFrequency=function()return 48000 end}end}
local root={Dispose=function(self)self.disposed=true end}
root.CreateChild=function(self)return self end
root.CreateComponent=function()
 return {playing=false,SetSoundType=function(self,x)self.soundType=x end,
  Play=function(self,_,_,gain)self.playing=true;self.gain=gain end,
  StopImmediate=function(self)self.playing=false end}
end
local Levels=require 'audio.AudioLevels'
local Feedback=assert(load(AUDIO_CODE))()
local checks={}
local function Check(ok,name)assert(ok,name);checks[#checks+1]=name end
local function Device()
 return {SetActive=function(self,x)self.active=x end,Update=function(self,dt,vehicle)self.vehicle=vehicle end}
end
local camera={worldPosition={x=0,y=0,z=0},worldRotation=setmetatable({},{__mul=function()return Vector3.RIGHT end})}
local function Session()
 local a=Feedback.New(root);a.focus=function()return true end
 return {pointer={captured=true},weaponAudio=Device(),drivingAudio=Device(),feedbackAudio=a,
  camera={GetNode=function()return camera end},vehicle={},weapons={},
  combat={player={alive=true},entries={},rules={finished=false}}}
end
local tick=assert(load(TICK_CODE))()
local s=Session();tick(s,.01,{})
Check(s.weaponAudio.active and s.drivingAudio.active and s.feedbackAudio.active,'alive audio active')
s.feedbackAudio:Destroy(.8,0);s.combat.player.alive=false;tick(s,.06,{})
Check(s.feedbackAudio.active,'dead player keeps world feedback')
Check(not s.weaponAudio.active and not s.drivingAudio.active and s.drivingAudio.vehicle==nil,'dead player stops own driving and weapons')
Check(#s.feedbackAudio.pending==1,'death preserves pending explosion')
tick(s,.061,{})
Check(#s.feedbackAudio.pending==0 and s.feedbackAudio.counts.vehicle_destroy==1,'death delayed explosion actually plays once')
Check(s.feedbackAudio:Play('hit_tick'),'death accepts subsequent world feedback')
for _,state in ipairs({'pointer','match-prep','story-finished','salvage-wait','salvage-finished'}) do
 local other=Session();tick(other,.01,{});other.feedbackAudio:Destroy()
 if state=='pointer' then other.pointer.captured=false
 elseif state=='match-prep' then other.battle={rules={state='prep'}}
 elseif state=='story-finished' then other.story={rules={finished=true}};other.combat.rules.finished=true
 else other.salvage={begun=state=='salvage-finished',rules={finished=state=='salvage-finished'},audio=Device()} end
 tick(other,.2,{})
 Check(not other.feedbackAudio.active and #other.feedbackAudio.pending==0,state..' clears pending feedback')
 for _,v in ipairs(other.feedbackAudio.voices)do Check(not v.source.playing,state..' stops voices')end
end
s.feedbackAudio:Destroy();s.feedbackAudio:Dispose()
Check(s.feedbackAudio.disposed and #s.feedbackAudio.pending==0 and #s.feedbackAudio.voices==0,'return disposal clears all feedback')
local f=Session().feedbackAudio;f:SetActive(true)
for _,id in ipairs({'kill_confirm','hit_tick','vehicle_destroy','objective_gain','game_over'}) do
 Levels.Init(nil);f.time=f.time+2;Check(f:Play(id),id..' starts')
 Check(Levels.FeedbackActive()==(id=='kill_confirm' or id=='objective_gain' or id=='game_over'),id..' preserves source duck membership')
end
return checks
'''


def run(trial, audio):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().TICK_CODE = audio_boundary(trial)
    lua.globals().AUDIO_CODE = audio
    return list(lua.execute(fixture).values())


current_trial = (ROOT / TRIAL).read_text(encoding='utf-8')
current_audio = (ROOT / AUDIO).read_text(encoding='utf-8')
checks = run(current_trial, current_audio)
negative = {}
for label, trial, audio, expected in [
    ('bb6e-death-gate', (OLD / TRIAL).read_text(encoding='utf-8'), current_audio, 'dead player keeps world feedback'),
]:
    try:
        run(trial, audio)
    except Exception as error:
        assert expected in str(error), str(error)
        negative[label] = str(error)
    else:
        raise AssertionError(label + ' failed to reject old production')

source = (ROOT / SOURCE).read_text(encoding='utf-8')
assert 'sfx.stopDriving( true,' in source and source.count('sfx.consumeDamage(') >= 3
paths = [TRIAL, AUDIO, 'scripts/audio/AudioLevels.lua', 'scripts/audio/RecoveryMix.lua',
         'tools/migration/check-feedback-death-lifecycle.py']
report = {'result': 'PASS', 'checks': len(checks), 'cases': checks, 'negative': negative,
          'sourceCommit': 'b276064942ae09c0227ec28d4cfda1d5ff006455',
          'sourceHashes': {SOURCE: hashlib.sha256((ROOT / SOURCE).read_bytes()).hexdigest()},
          'inputs': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
          'boundary': 'Actual production TrialSession Tick audio prefix and CombatFeedbackAudio executed with engine sound/camera/cache doubles. Frozen H5 damage keepalive inspected; full cue duck membership separately checked against executed frozen JS. No native audible, GPU, gameplay shooting, Web performance or mobile acceptance.'}
output = ROOT / 'docs/migration/evidence/feedback-death-lifecycle-offline.json'
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'negative': len(negative), 'evidence': str(output)}))

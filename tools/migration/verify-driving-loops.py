"""Compare actual frozen uiSound controls to real Lua 5.4 DrivingAudio."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
source = json.loads(subprocess.check_output(['node', '--experimental-vm-modules', 'tools/migration/source-driving-loops.cjs'], text=True))
config = json.loads((ROOT / 'assets/Combat/DrivingSounds.json').read_text(encoding='utf-8'))
baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)


def table(value):
    if isinstance(value, dict):
        return lua.table_from({key: table(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(item) for item in value])
    return value


lua.globals().CONFIG = table(config)
lua.execute('''
package.path='scripts/?.lua;'..package.path
package.preload['core.ResourceData']=function() return {Read=function() return CONFIG end} end
input={focus=true,minimized=false};local clock=0;Time={GetSystemTime=function() return clock*1000 end}
local order=0
local function Source()
 return {playing=false,gain=0,frequency=48000,panning=0,SetSoundType=function(self,kind) self.soundType=kind end,
  Play=function(self,sound,frequency,gain,pan) order=order+1;self.order=order;self.playing=true;self.sound=sound;self.frequency=frequency;self.gain=gain;self.panning=pan or 0 end,
  StopImmediate=function(self) self.playing=false;self.sound=nil end}
end
local root={CreateComponent=function() return Source() end,Dispose=function() end};function root:CreateChild() return self end
cache={GetResource=function(_,_,path) return {name=path,length=100,GetFrequency=function() return 48000 end} end}
math.random=function() return .5 end
local Levels=require 'audio.AudioLevels';local Driving=require 'audio.DrivingAudio'
local driving;local active={}
function Reset(code)
 Levels.Init(nil);input.focus=true;order=0;active={}
 local Module=code and assert(load(code,'DrivingAudio control'))() or Driving
 driving=Module.New(root);driving:SetActive(true)
end
function Apply(action)
 if action.op=='loop' then
  driving:Loop(action.key,action.id,action.amount,action.rate or 1,action.pan or 0,0)
  if action.amount>.005 then active[action.key]=action else active[action.key]=nil end
 elseif action.op=='stop' or action.op=='pause' then driving:Stop();active={};if action.op=='pause' then input.focus=false end
 elseif action.op=='resume' then input.focus=true end
 local dt=action.dt;clock=clock+dt
 if action.op=='update' then
  Vector3={RIGHT={x=1,y=0,z=0}}
  local camera={worldPosition={x=0,y=0,z=0},worldRotation=setmetatable({},{__mul=function() return {x=1,y=0,z=0} end})}
  local vehicle={speed=action.speed,wheels=action.mixed and {{track=false},{track=true}} or {},spec={hovers=action.mixed and {{works=true}} or {}},thrusterOutputs={[1]=action.mixed and .64 or 0},telemetry={hoverForce=action.mixed and 10 or 0},body={translation=function() return {x=0,y=0,z=0} end}}
  local enemy={alive=true,vehicle={speed=6,wheels=vehicle.wheels,spec=vehicle.spec,thrusterOutputs=vehicle.thrusterOutputs,telemetry=vehicle.telemetry,body={translation=function() return {x=10,y=0,z=0} end}}}
  driving:Update(dt,vehicle,{throttle=action.throttle},camera,action.remote and {{unit=enemy}} or {})
 else
  driving.time=driving.time+dt
  if driving.UpdateLoopTails then driving:UpdateLoopTails(dt) end
  for _,args in pairs(active) do driving:Loop(args.key,args.id,args.amount,args.rate or 1,args.pan or 0,dt) end
 end
 local voices,keys={},{}
 for key,loop in pairs(driving.loops) do if not loop.released and loop.source.playing then keys[#keys+1]=key end end
 table.sort(keys)
 if driving.loopSources then
  for _,slot in ipairs(driving.loopSources) do local s=slot.source;if s.playing then voices[#voices+1]={id=slot.id,key=slot.key,order=s.order,gain=s.gain,rate=s.frequency/48000,pan=s.panning} end end
 else
  for key,loop in pairs(driving.loops) do local s=loop.source;if s.playing then voices[#voices+1]={id=key:gsub('^remote:',''),key=key,order=s.order,gain=s.gain,rate=s.frequency/48000,pan=s.panning} end end
 end
 table.sort(voices,function(a,b) return a.order<b.order end)
 return {voices=voices,active=keys,loopSources=driving.loopSources and #driving.loopSources or 0,tails=driving.loopTails and #driving.loopTails or 0}
end
function Lifecycle()
 driving:Loop('drive_idle','drive_idle',1,1.4,.8,.016);driving:Loop('drive_idle','drive_idle',0,1,0,0)
 driving:Loop('drive_idle','drive_idle',1,1.2,0,.01);driving:SetActive(false)
 for _,slot in ipairs(driving.loopSources) do assert(not slot.source.playing and slot.source.gain==0,'pause clears active and released voices') end
 assert(#driving.loopTails==0,'pause removes all tails')
 driving:SetActive(true);driving:Loop('drive_idle','drive_idle',1,1,0,.01);input.focus=false
 local camera={worldPosition={x=0,y=0,z=0},worldRotation=setmetatable({},{__mul=function() return {x=1,y=0,z=0} end})}
 driving:Update(.016,nil,{},camera,{})
 for _,slot in ipairs(driving.loopSources) do assert(not slot.source.playing,'focus clears all sources') end
 input.focus=true;driving:SetActive(true);driving:Loop('remote:drive_load','drive_load',1,1,0,.016)
 driving.volume=0;driving:Update(.016,nil,{},camera,{})
 for _,slot in ipairs(driving.loopSources) do assert(not slot.source.playing,'mute clears all sources') end
 driving:Dispose();assert(driving.disposed and next(driving.loops)==nil and #driving.loopSources==0 and #driving.loopTails==0,'dispose retires every source')
 return true
end
''')
checks = 0


def check(ok, message):
    global checks
    checks += 1
    assert ok, message


def compare(code=None):
    for scenario in source['scenarios']:
        lua.globals().Reset(code)
        for index, (action, expected) in enumerate(zip(scenario['actions'], scenario['samples'])):
            actual = lua.globals().Apply(table(action))
            label = f"{scenario['name']} / {index} / {action['op']}"
            observed = sorted(actual['voices'].values(), key=lambda item: (item['key'], item['order']))
            expected_voices = sorted(expected['voices'], key=lambda item: (item['key'], item['order']))
            check(list(actual['active'].values()) == expected['active'], label + ' active keys')
            check(len(observed) == len(expected['voices']), label + f" voice count {len(observed)} != {len(expected['voices'])}")
            for got, wanted in zip(observed, expected_voices):
                for key in ['id', 'key']:
                    check(got[key] == wanted[key], label + f" {key}: {got[key]} != {wanted[key]}")
                for key in ['gain', 'rate', 'pan']:
                    check(abs(got[key] - wanted[key]) < 1e-9, label + f" {key}: {got[key]} != {wanted[key]}")
            check(actual['loopSources'] <= 20, label + ' bounded reusable loop sources')


compare()
lua.globals().Reset()
check(lua.globals().Lifecycle(), 'real pause, focus, mute and disposal retire active and fading voices')
for cue_id, cue in config['cues'].items():
    expected = source['cues'][cue_id]
    check(abs(cue['gain'] - expected['gain']) < 1e-12, cue_id + ' original gain')
    check(cue['attack'] == expected['attack'] and cue['release'] == expected['release'], cue_id + ' original timing')
    check((ROOT / 'assets' / cue['path']).read_bytes() == (Path(baseline['snapshot']) / cue['source']).read_bytes(), cue_id + ' original audio bytes')

production = (ROOT / 'scripts/audio/DrivingAudio.lua').read_text(encoding='utf-8')
historical_path = 'docs/migration/evidence/history/DrivingAudio-before-source-loop-repair-20261016.lua'
historical = (ROOT / historical_path).read_text(encoding='utf-8')
check(hashlib.sha256(historical.encode()).hexdigest() == 'c81231ffa523b00743b6b6f4b9668a2a5bb962748155a0159fa423edf1bb6471', 'original pre-edit production bytes are pinned')
negatives = [('frozen previous production', historical),
             ('immediate initial rate', production.replace('gain=0,pitch=1,pan=0', 'gain=0,pitch=pitch,pan=0')),
             ('immediate initial pan', production.replace('gain=0,pitch=1,pan=0', 'gain=0,pitch=1,pan=pan')),
             ('early tail stop', production.replace('loop.release*5', 'loop.release*4')),
             ('late tail stop', production.replace('loop.release*5', 'loop.release*6')),
             ('resume old released voice', production.replace('not loop or loop.released or not loop.source.playing', 'not loop or not loop.source.playing')),
             ('no loop source bound', production.replace('#self.loopSources>=20', '#self.loopSources>=200'))]
rejected = []
for name, code in negatives:
    check(code != production, name + ' mutation applied')
    try:
        compare(code)
    except AssertionError as error:
        rejected.append({'name': name, 'reason': str(error), 'sha256': hashlib.sha256(code.encode()).hexdigest()})
    else:
        raise AssertionError('Negative control not rejected: ' + name)

paths = ['scripts/audio/DrivingAudio.lua', 'assets/Combat/DrivingSounds.json', 'tools/migration/source-driving-loops.cjs', 'tools/migration/verify-driving-loops.py', historical_path]
report = {'status': 'PASS', 'checks': checks, 'scenarios': len(source['scenarios']), 'samples': sum(len(item['actions']) for item in source['scenarios']),
          'sourceCommit': source['commit'], 'sourceHashes': source['hashes'], 'negativeControls': rejected,
          'productionHashes': {item: hashlib.sha256((ROOT / item).read_bytes()).hexdigest() for item in paths},
          'boundary': 'Actual frozen JS uiSound/drivingMix and actual production Lua 5.4, audio/cache/input adapters at frame boundaries. No native DSP, audible output, audio-clock automation, Web performance, GPU or mobile acceptance.'}
(ROOT / 'docs/migration/evidence/driving-loops-offline.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))

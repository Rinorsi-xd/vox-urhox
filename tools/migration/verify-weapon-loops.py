"""Execute frozen H5 uiSound and production Lua against identical audio actions."""
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
source = json.loads(subprocess.check_output(['node', '--experimental-vm-modules', 'tools/migration/source-weapon-loops.cjs'], text=True))
lua = LuaRuntime(unpack_returned_tuples=True)


def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value


config = json.loads((ROOT / 'assets/Combat/WeaponSounds.json').read_text(encoding='utf-8'))
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
local Levels=require 'audio.AudioLevels';local Weapon=require 'audio.WeaponAudio'
local active={};local weapons
function LegacyState(code)
 local Old=assert(load(code,'historical WeaponAudio'))();local old=Old.New(root);old:SetActive(true)
 old:Loop('mg_motor',1,1.4,.8,.016)
 return {rate=old.loops.mg_motor.source.frequency/48000,pan=old.loops.mg_motor.source.panning}
end
function Reset()
 Levels.Init(nil);order=0;weapons=Weapon.New(root);weapons:SetActive(true);active={}
end
function Apply(action)
 if action.op=='loop' then
  weapons:Loop(action.id,action.amount,action.rate or 1,action.pan or 0,0)
  if action.amount>.005 then active[action.id]=action else active[action.id]=nil end
 elseif action.op=='play' then weapons:Play(action.id,1,0)
 elseif action.op=='fire' then
  weapons:Consume({{type='shot',kind='sniper',pos={0,0,0}}},action.remote)
  if not action.remote then active.sniper_charge=nil end
 elseif action.op=='stop' or action.op=='pause' then weapons:SetActive(false);active={}
 elseif action.op=='resume' then weapons:SetActive(true) end
 if action.op=='stop' then weapons:SetActive(true) end
 local dt=action.dt;clock=clock+dt
 if action.op~='update' then weapons.time=weapons.time+dt end
 if action.op=='update' then
  Vector3={RIGHT={x=1,y=0,z=0}}
  local camera={worldPosition={x=0,y=0,z=0},worldRotation=setmetatable({},{__mul=function() return {x=1,y=0,z=0} end})}
  local system={groups={{weapons={{spin=action.spin}}}},projectiles={},Group=function() end,LockInfo=function() end}
  weapons:Update(dt,system,camera,{},false)
 else
  weapons:UpdateLoopTails(dt)
  for id,args in pairs(active) do weapons:Loop(id,args.amount,args.rate or 1,args.pan or 0,dt) end
 end
 local voices={};local ids={}
 for id,loop in pairs(weapons.loops) do if not loop.released and loop.source.playing then ids[#ids+1]=id end end
 table.sort(ids)
 for _,slot in ipairs(weapons.loopSources) do local s=slot.source;if s.playing then voices[#voices+1]={id=slot.id,loop=true,gain=s.gain,rate=s.frequency/48000,pan=s.panning,order=s.order} end end
 for i,s in ipairs(weapons.slots) do if s.playing then voices[#voices+1]={id=weapons.voiceIds[i],loop=false,gain=s.gain,rate=s.frequency/48000,pan=s.panning,order=s.order} end end
 table.sort(voices,function(a,b) return a.order<b.order end)
 return {voices=voices,active=ids,loopSources=#weapons.loopSources,oneShotSources=#weapons.slots,tails=#weapons.loopTails}
end
''')
checks = 0


def check(ok, message):
    global checks
    checks += 1
    assert ok, message


for scenario in source['scenarios']:
    lua.globals().Reset()
    for index, (action, expected) in enumerate(zip(scenario['actions'], scenario['samples'])):
        actual = lua.globals().Apply(table(action))
        label = f"{scenario['name']} / {index} / {action['op']}"
        actual_voices = list(actual['voices'].values())
        check(list(actual['active'].values()) == expected['active'], label + ' active keys')
        check(len(actual_voices) == len(expected['voices']), label + f" voice count {len(actual_voices)} != {len(expected['voices'])}")
        for observed, target in zip(actual_voices, expected['voices']):
            for key in ['id', 'loop', 'order']:
                check(observed[key] == target[key], label + f' {key}: {observed[key]} != {target[key]}')
            for key in ['gain', 'rate', 'pan']:
                check(abs(observed[key] - target[key]) < 1e-9, label + f' {key}: {observed[key]} != {target[key]}')
        check(actual['loopSources'] <= 20, label + ' twenty-loop source bound')
        check(actual['oneShotSources'] <= 10, label + ' ten-one-shot source bound')
for cue_id, cue in config['cues'].items():
    expected = source['cues'][cue_id]
    check(abs(cue['gain'] - expected['gain']) < 1e-12, cue_id + ' original gain')
    check(cue['attack'] == expected['attack'] and cue['release'] == expected['release'], cue_id + ' source time constants')
    data = (ROOT / 'assets' / cue['path']).read_bytes()
    frozen = (ROOT / '.tmp/outgame-source-2026-10-15T12-35-57-243Z' / cue['source']).read_bytes()
    check(data == frozen, cue_id + ' original sample bytes')
historical_ref = '9541dc59ef2f281cafa5126762a57550189e04dc:scripts/audio/WeaponAudio.lua'
historical = subprocess.check_output(['git', 'show', historical_ref], text=True, encoding='utf-8')
negative = lua.globals().LegacyState(historical)
first = source['scenarios'][0]['samples'][0]['voices'][0]
check(abs(negative['rate'] - first['rate']) > .1, 'historical immediate pitch is rejected by source .12 envelope')
check(abs(negative['pan'] - first['pan']) > .5, 'historical immediate pan is rejected by source .08 envelope')
paths = ['scripts/audio/WeaponAudio.lua', 'assets/Combat/WeaponSounds.json', 'tools/migration/import-weapon-audio.mjs', 'tools/migration/source-weapon-loops.cjs', 'tools/migration/verify-weapon-loops.py', 'tools/migration/check-missiles.lua']
report = {'status': 'PASS', 'checks': checks, 'scenarios': len(source['scenarios']), 'samples': sum(len(s['actions']) for s in source['scenarios']),
          'sourceCommit': source['commit'], 'sourceHashes': source['hashes'],
          'negativeControl': {'source': historical_ref, 'sha256': hashlib.sha256(historical.encode()).hexdigest(), 'status': 'REJECTED_AS_EXPECTED', 'oldRate': negative['rate'], 'sourceRate': first['rate'], 'oldPan': negative['pan'], 'sourcePan': first['pan']},
          'productionHashes': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
          'boundary': 'Real frozen uiSound and HeavyWeaponMix, real production Lua with source/input/cache adapters. Samples at frame boundaries; not native DSP, audible output, Web callback continuity, GPU or mobile performance.'}
(ROOT / 'docs/migration/evidence/weapon-loops-offline.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))

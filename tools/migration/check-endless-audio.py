"""Compare Endless sample routing with frozen H5 cues and master mixer, no GPU."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference = json.loads(subprocess.check_output(
    ['node', '--experimental-vm-modules', 'tools/migration/source-game-audio.cjs'], text=True))
config = json.loads((ROOT / 'assets/Endless/Sounds.json').read_text(encoding='utf-8'))
for cue in config['cues'].values():
    with wave.open(str(ROOT / 'assets' / cue['path']), 'rb') as wav:
        cue['length'] = wav.getnframes() / wav.getframerate()
lua = LuaRuntime(unpack_returned_tuples=True)


def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value


lua.globals().DATA = table(config)
lua.globals().SOURCE = table(reference)
result = lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local clock=0
Time={GetSystemTime=function()return clock*1000 end}
input={focus=true,minimized=false}
Vector3={RIGHT={x=1,y=0,z=0}}
package.preload['core.ResourceData']=function()return {Read=function()return DATA end}end
local sounds={}
for _,cue in pairs(DATA.cues)do sounds[cue.path]={length=cue.length}end
cache={GetResource=function(_,kind,path)return assert(sounds[path])end}
local created={}
local function Node()
 return {CreateChild=function()return Node()end,Dispose=function()end,
 CreateComponent=function()
  local source={playing=false,plays=0}
  function source:SetSoundType(kind)self.soundType=kind end
  function source:Play(sound,frequency,gain,pan)
   self.playing=true;self.plays=self.plays+1;self.gain=gain;self.panning=pan
  end
  function source:StopImmediate()self.playing=false end
  created[#created+1]=source;return source
 end}
end
local Audio=require 'endless.Audio';local Levels=require 'audio.AudioLevels'
local checks,failures=0,{}
local function Check(ok,message)
 checks=checks+1;if not ok then failures[#failures+1]=message end
end
local function Near(a,b)return math.abs(a-b)<1e-10 end
for id,cue in pairs(DATA.cues)do
 local expected=assert(SOURCE.cues[id])
 Check(Near(cue.gain,expected.gain),id..': frozen gain')
 Check(Near(cue.gap,expected.gap/1000),id..': frozen gap')
 for _,volume in ipairs({.1,.65,1})do
  Levels.Init();Levels.Set('sfx',volume);clock=clock+10
  local audio=Audio.New(Node());audio:Update(.01,{state='active'},nil,.65)
  Check(audio:Play(id),id..': plays')
  local source=created[#created]
  Check(Near(source.gain,expected.gain*volume*.65/.6),id..': original final gain at '..volume)
  Check(Levels.ContextSnapshot().buses.feedback~=nil,id..': feedback bus')
  Check(Levels.FeedbackActive()==expected.feedback,id..': flow context duck')
  audio:Dispose()
 end
end
-- Positional drops use the same attenuation/righthanded-to-left conversion.
Levels.Init();clock=clock+10
local audio=Audio.New(Node())
local camera={worldPosition={x=0,y=0,z=0},worldRotation=setmetatable({},{__mul=function()return Vector3.RIGHT end})}
for _,point in ipairs({{0,0,0},{24,0,0},{-48,0,0},{0,12,24}})do
 audio:Update(1,{state='active'},camera,.65)
 local distance=math.sqrt(point[1]^2+point[2]^2+point[3]^2)
 Check(audio:Play('loot_drop',point,camera),'drop plays at '..distance)
 local source=created[#created]
 Check(Near(source.gain,SOURCE.cues.loot_drop.gain*.65*.65/.6/(1+(distance/24)^2)),'drop attenuation')
 local pan=distance>0 and math.max(-.85,math.min(.85,-point[1]/distance))or 0
 Check(Near(source.panning,pan),'drop stereo')
end
audio:Update(1,{state='active'},camera,.65)
Check(not audio:Play('loot_drop',{240,0,0},camera),'240m cutoff')
local count=audio.counts.loot_pickup or 0
audio:Event({type='dropCollected',reason='overflow'},camera)
Check((audio.counts.loot_pickup or 0)==count,'overflow silent')
audio:Play('supply_open')
audio:Update(1,{state='active'},camera,0)
local active=false;for _,s in ipairs(audio.voices)do active=active or s.playing end
Check(not active,'muting stops existing voices')
Check(not audio:Play('game_over'),'muted cue rejected')
audio:Update(1,{state='active'},camera,.65)
Check(audio:Play('game_over'),'mute does not consume cue gap')
input.focus=false;audio:Update(1,{state='active'},camera,.65)
Check(not audio:Play('wave_start'),'unfocused silent');input.focus=true
audio:Dispose();audio:Dispose()
local played,result=pcall(function()return audio:Play('wave_start')end)
Check(played and not result,'disposed play rejected')
local ok=pcall(function()audio:Update(1,{state='countdown',countdown=3},camera,.65)end)
Check(ok,'disposed countdown safe')
return {checks=checks,failures=failures}
''')
failures = list(result['failures'].values())
evidence = {
    'checks': result['checks'], 'failures': failures,
    'sourceCommit': reference['commit'], 'sourceHashes': reference['hashes'],
    'productionHashes': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in
                         ['scripts/endless/Audio.lua', 'scripts/audio/AudioLevels.lua']},
    'scope': 'Actual Lua audio/mixer with native sound adapters; no listening or GPU acceptance',
}
name = sys.argv[1] if len(sys.argv) > 1 else 'endless-audio-offline.json'
(ROOT / 'docs/migration/evidence' / name).write_text(json.dumps(evidence, indent=2) + '\n', encoding='utf-8')
print(json.dumps(evidence, indent=2))
sys.exit(bool(failures))

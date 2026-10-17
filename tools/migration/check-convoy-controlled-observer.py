"""Exercise the actual isolated observer with real Lua rules/dispatch/audio queues."""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)


def to_lua(value):
    if isinstance(value, dict):
        return lua.table_from({key: to_lua(child) for key, child in value.items()})
    if isinstance(value, list):
        return lua.table_from([to_lua(child) for child in value])
    return value


def from_lua(value):
    if hasattr(value, 'keys'):
        keys = list(value.keys())
        if keys and all(isinstance(key, int) for key in keys):
            return [from_lua(value[key]) for key in sorted(keys)]
        return {key: from_lua(value[key]) for key in keys}
    return value


files = ['scripts/story/Mission.lua', 'scripts/story/MissionRules.lua',
         'scripts/story/ConvoyRules.lua', 'scripts/audio/StoryComms.lua',
         'scripts/audio/StoryRadio.lua', 'tools/migration/convoy-controlled-web-observer.lua']
code = {name: (ROOT / name).read_text(encoding='utf-8-sig') for name in files}
actual = {'story.Mission', 'story.MissionRules', 'story.ConvoyRules',
          'audio.StoryComms', 'audio.StoryRadio'}
deps = set()
for source in code.values():
    deps.update(re.findall(r'require\s*\(?\s*[\'\"]([^\'\"]+)', source))
lua.globals().DependencyNames = to_lua(sorted(deps - actual))
lua.globals().Level = to_lua(json.loads((ROOT / 'assets/Story/Mission/Level2.json').read_text(encoding='utf-8-sig'))['level'])
lua.globals().Nav = to_lua(json.loads((ROOT / 'assets/Crater/Layout.json').read_text(encoding='utf-8-sig'))['nav'])
lua.globals().RadioData = to_lua(json.loads((ROOT / 'assets/Story/Radio/Radio.json').read_text(encoding='utf-8-sig')))
logs = []
lua.globals().print = lambda value: logs.append(value)
lua.globals().cjson = lua.table_from({
    'encode': lambda value: json.dumps(from_lua(value), ensure_ascii=False, separators=(',', ':')),
    'decode': lambda value: to_lua(json.loads(value)),
})
lua.globals().ProjectScriptPath = str(ROOT / 'scripts/?.lua').replace('\\', '/')
lua.execute(r'''
package.path=ProjectScriptPath..';'..package.path
for _,name in ipairs(DependencyNames)do package.preload[name]=function()return{}end end
local function Source()return{playing=false,SetSoundType=function()end,StopImmediate=function(self)self.playing=false end}end
local function Node()return{CreateChild=function()return Node()end,CreateComponent=function()return Source()end,Dispose=function()end}end
Scene=function()return Node()end
input={focus=true,minimized=false};KEY_F7=7;KEY_F10=10
local pressed={};input.GetKeyPress=function(_,key)return pressed[key]==true end
function SetKey(key)pressed={};if key then pressed[key]=true end end
cache={GetResource=function()return{length=1}end}
package.preload['core.ResourceData']=function()return{Read=function()return RadioData end}end
package.preload['audio.AudioLevels']=function()return{Play=function(source)source.playing=true end,
 FeedbackFor=function()end,RawGain=function()return 1 end}end
package.preload['audio.StoryCommsCues']=function()return{New=function()return{Dispose=function()end,Update=function()end}end}end
package.preload['urhox-libs/UI']=function()return{GetViewportSize=function()return 1600,900 end,GetRoot=function()end,GetTopOverlay=function()end}end
package.preload['ui.GarageHud']=function()return{GetState=function()return{}end}end
local Mission=require 'story.Mission'
local Rules=require 'story.MissionRules'
local Convoy=require 'story.ConvoyRules'
local Comms=require 'audio.StoryComms'
local Radio=require 'audio.StoryRadio'
local escort;for _,step in ipairs(Level.steps)do if step.kind=='escort'then escort=step end end
local truck=Convoy.New(escort,Nav,function(_,_,hint)return hint end)
local rules=Rules.New(Level,truck);rules.begun=true;rules.index=1;rules.phase='go'
local position={1000,20,1000}
local player={alive=true,spec={bounds={min={-1,0,-4},max={3,4,0}}},SavePose=function(self)self.current={}end,
 Position=function()return position end}
player.vehicle={Place=function(_,pos)position={pos[1],pos[2],pos[3]}end}
local view={Objective=function()end,truck={}}
local world={time=0,disposed=false,visualGround={}}
local mission=setmetatable({rules=rules,level=Level,convoy=truck,world=world,player=player,
 voice=Comms.New(nil,{voices={}}),radio=Radio.New(),view=view,
 Spawn=function()end,ClearEnemies=function(self)self.entries={}end,entries={player}},{__index=Mission})
app={mode='trial',loadingFlow={active=false},trial={story=mission,world=world,pointer={captured=true},session=nil}}
mission.session=app.trial
function HandleUpdate()
 if not app.trial.story then return end
 world.time=world.time+1/60;mission.radio:Update(1,true)
 rules:Step(1/60,{alive=true,pos=position,enemyPositions={},talking=mission.voice:Talking(),enemies=0})
 mission:Events()
end
function HandlePostUpdate()end
''')
lua.execute(code['tools/migration/convoy-controlled-web-observer.lua'])
lua.execute("SetKey();HandleUpdate();HandlePostUpdate();SetKey(KEY_F10);HandleUpdate();HandlePostUpdate();SetKey();HandleUpdate();HandlePostUpdate();assert(app.trial.story.rules:StepSpec().id=='convoy')")
for checkpoint in (1, 2):
    lua.execute("SetKey(KEY_F10);HandleUpdate();HandlePostUpdate();SetKey();HandleUpdate();HandlePostUpdate()")
    assert lua.eval('app.trial.story.convoy.cp') == checkpoint

chunks = {}
states = []
for line in logs:
    prefix = 'CONVOY_CONTROLLED_CHUNK '
    if not line.startswith(prefix):
        continue
    item = json.loads(line[len(prefix):])
    group = chunks.setdefault(item['kind'], {})
    group[item['index']] = item['data']
    if len(group) == item['count']:
        text = ''.join(group[i] for i in range(1, item['count'] + 1))
        encoded = text.encode('utf-8')
        checksum = 2166136261
        for byte in encoded:
            checksum = ((checksum ^ byte) * 16777619) & 0xffffffff
        assert len(encoded) == item['bytes'] and checksum == item['checksum']
        states.append(json.loads(text))
assert states and len(states[-1]['checkpoints']) == 2
report = {
    'status': 'PASS', 'states': len(states), 'chunks': len(logs), 'lastState': states[-1],
    'hashes': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files},
    'boundary': 'Actual Lua observer, ConvoyRules, MissionRules.Step, Mission.Events/Banner/Place and actual StoryRadio/StoryComms.Say with native-free scene/audio/physics adapters. Explicit fixture placements; no rendered, audible, natural combat, actual menu/return or performance acceptance.'
}
out = ROOT / 'docs/migration/evidence/convoy-controlled-observer-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
subprocess.run(['node', '-e', "const fs=require('node:fs'),a=require('./tools/migration/convoy-controlled-web-acceptance.cjs');const s=JSON.parse(fs.readFileSync(process.argv[1])).lastState;console.log(JSON.stringify({checkpoints:a.checkpoints(s),preparations:a.preparations(s)}))", str(out)], cwd=ROOT, check=True)
print(json.dumps({'status': 'PASS', 'states': len(states), 'chunks': len(logs), 'out': str(out)}))

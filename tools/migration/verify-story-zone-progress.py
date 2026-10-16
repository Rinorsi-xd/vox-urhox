"""Compare frozen H5 zone state with actual Lua rules and complete view methods."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference = json.loads(subprocess.check_output(['node', 'tools/migration/story-zone-progress-source.cjs'], encoding='utf-8'))
data = json.loads((ROOT/'assets/Story/Mission/Level1.json').read_text(encoding='utf-8'))['view']
levels = {kind: json.loads((ROOT/f'assets/Story/Mission/Level{n}.json').read_text(encoding='utf-8'))['level']
          for kind, n in [('hold', 3), ('capture', 4)]}
checks = 0


def check(ok, message):
    global checks
    checks += 1
    assert ok, message


def runtime(path):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value

    lua.globals().ViewData = table(data)
    lua.globals().Nav = table(json.loads((ROOT/'assets/Crater/Layout.json').read_text(encoding='utf-8'))['nav'])
    lua.execute(r'''
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local vector={};vector.__index=vector
Vector3=setmetatable({UP={},RIGHT={},FORWARD={}},{__call=function(_,x,y,z) return setmetatable({x=x,y=y,z=z},vector) end})
local rotation={};rotation.__mul=function() return setmetatable({},rotation) end
Quaternion=function() return setmetatable({},rotation) end
Variant=function(v) return v end
package.loaded['story.MissionData']={view=ViewData}
function Node()
 return {enabled=false,GetChildren=function() return {} end,SetEnabledRecursive=function(self,on) self.enabled=on end}
end
function Material()
 return {values={uProgress=0},SetShaderParameter=function(self,name,v) self.values[name]=v end}
end
Rules=require('story.MissionRules')
''')
    lua.globals().View = lua.execute(path.read_text(encoding='utf-8'))
    lua.execute(r'''
function CreateView()
 local nodes={};for i=1,#ViewData.beacon.nodes do nodes[i]=Node() end
 return setmetatable({zone=Node(),zoneMaterial=Material(),time=0,objects={},sites={},intel={},collectors={},
   alarm={nodes={},lights={}},glow={mesh={}},beacon={root=Node(),nodes=nodes,materials={},born=0,fade=1}},View)
end
function Enter(step)
 if not V then V=CreateView() end
 R=Rules.New({steps={step},spawn={pos=step.pos}},nil);R:Go(1)
 V:Objective(step,step.pos)
 return V.zoneMaterial.values.uProgress
end
function Tick(input)
 if input.install then R.install=input.install
 elseif R.cap then
  local positions,tags={},{};for _,e in ipairs(input.enemies) do positions[#positions+1]=e.pos;tags[e.tag]=(tags[e.tag] or 0)+1 end
  R.stepT=input.stepT
  R.cap:Update(R,input.dt,{pos=input.pos,alive=input.alive,enemyPositions=positions,enemyTags=tags,interact=input.interact,nav=Nav})
 elseif R.hold then
  local positions={};for _,e in ipairs(input.enemies) do positions[#positions+1]=e.pos end
  R.stepT=input.stepT;R.hold:Update(R,input.dt,{pos=input.pos,alive=input.alive,enemyPositions=positions})
 end
 V:Update(input.dt or .016,R,nil)
 return V.zoneMaterial.values.uProgress
end
''')
    return lua, table


def run(path, negative=False):
    lua, table = runtime(path)
    failures = []
    for sample in reference['trace']:
        step, inp, exp = sample['step'], sample['input'], sample['expected']
        if inp.get('enter'):
            if step['kind'] in levels:
                target = next(s for s in levels[step['kind']]['steps'] if s['id'] == step['id'])
                for key in (['pos', 'healR', 'drainR', 'drain', 'heal', 'duration', 'delay'] if step['kind'] == 'hold'
                            else ['pos', 'r', 'trigger', 'capSec', 'guards', 'counter']):
                    check(target.get(key) == step.get(key), f'actual level parameter {key}')
                step = target
            actual = lua.globals().Enter(table(step))
        else:
            actual = lua.globals().Tick(table(inp))
        expected = min(1, exp['ring'])
        matches = actual is not None and abs(actual-expected) < 1e-9
        label = sample['kind'] + ':' + sample['label']
        if negative:
            if not matches:
                failures.append(label)
            continue
        check(matches, f'{label} ring: {actual} != {expected}')
        zone = lua.globals().V.zone
        check(zone.enabled == exp['visible'], label + ' visibility')
        for axis, value in zip(['x', 'y', 'z'], exp['position']):
            check(abs(zone.position[axis] - (-value if axis == 'x' else value)) < 1e-9, label + ' position')
        for axis, value in zip(['x', 'y', 'z'], exp['scale']):
            check(abs(zone.scale[axis]-value) < 1e-9, label + ' scale')
        if exp.get('hold'):
            for key in ['left', 'energy', 'healT']:
                check(abs(lua.globals().R.hold[key]-exp['hold'][key]) < 1e-9, label + ' actual hold ' + key)
        if exp.get('cap'):
            for key in ['p', 'scrub']:
                check(abs(lua.globals().R.cap[key]-exp['cap'][key]) < 1e-9, label + ' actual capture ' + key)
            check(lua.globals().R.cap.phase == exp['cap']['phase'], label + ' actual capture phase')
    return failures


run(ROOT/'scripts/render/MissionView.lua')
old = ROOT/'.tmp/outgame-cached-1792123715225/scripts/render/MissionView.lua'
old_identity = json.loads((old.parents[2]/'identity.json').read_text(encoding='utf-8'))
check(hashlib.sha256(old.read_bytes()).hexdigest() == old_identity['identity']['scripts']['render/MissionView.lua'],
      'negative fixture is actual frozen 6a payload')
negative = run(old, True)
for label in ['hold:hold-partial', 'capture:scrub-entry', 'capture:scrub-half', 'capture:site-A-restart-reset']:
    check(label in negative, 'actual 6a negative detects ' + label)
# Source and target shaders use the same full-arc saturation above one.
source_shader = (ROOT/json.loads((ROOT/'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))['snapshot']/'three/src/battle/storyView.js').read_text(encoding='utf-8')
target_shader = (ROOT/'assets/Shaders/BLGL/Story/MissionRing.shader').read_text(encoding='utf-8')
check('step( ang, uProgress )' in source_shader and 'step(ang, uProgress)' in target_shader, 'same arc comparison')
for progress in [0, .2, 1, 1.01, 1.2]:
    for index in range(101):
        angle = index/100
        check((angle <= progress) == (angle <= min(1, progress)), 'clamped value preserves visible full arc')
paths = ['scripts/render/MissionView.lua', 'scripts/render/NodeVisibility.lua', 'scripts/core/Coord.lua',
         'scripts/core/Rotations.lua', 'scripts/story/MissionRules.lua', 'scripts/story/HoldRules.lua',
         'scripts/story/CaptureRules.lua', 'assets/Story/Mission/Level1.json', 'assets/Story/Mission/Level3.json',
         'assets/Story/Mission/Level4.json', 'assets/Crater/Layout.json', 'assets/Shaders/BLGL/Story/MissionRing.shader']
sha = lambda p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
report = {'result': 'PASS', 'checks': checks, 'cases': len(reference['trace']),
          'reference': {k: v for k, v in reference.items() if k != 'trace'},
          'productionHashes': {p: sha(p) for p in paths},
          'testInputs': {p: sha(p) for p in ['tools/migration/verify-story-zone-progress.py', 'tools/migration/story-zone-progress-source.cjs']},
          'negativeFixture': {'path': old.relative_to(ROOT).as_posix(), 'sha256': sha(old)},
          'negativeControls': {'actual6aDifferingCases': len(negative), 'labels': sorted(set(negative))},
          'boundary': 'CPU actual frozen KINDS.hold/capture and StoryView zone methods; actual target MissionRules.Go, HoldRules/CaptureRules and complete MissionView.Objective/Update. Native vectors, rotations, scene nodes, materials and HUD are adapters. Install uses actual frozen setZoneProgress invocation. Above-one ring values compare visible saturation. No GPU pixels, natural S3/S4, audio, results or mobile acceptance. Candidate after 6a.'}
(ROOT/'docs/migration/evidence/story-zone-progress-offline.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k: v for k, v in report.items() if k != 'reference'}, ensure_ascii=False, indent=2))

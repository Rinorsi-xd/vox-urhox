"""Execute the opt-in Lua projection against actual full Web observations."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

helper = ROOT / 'tools/migration/story-route-observer.lua'
source = helper.read_text(encoding='utf-8')
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(source)
project = lua.globals().G0_StoryRouteState
same = lua.eval('function(a,b) return rawequal(a,b) or a==b end')
checks = []


def check(label, condition):
    assert condition, label
    checks.append(label)


def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value


required = {'mode', 'map', 'width', 'height', 'touch', 'loadingFlow', 'sceneVisible',
            'pointer', 'camera', 'vehicle', 'widgets', 'aimTargets', 'wing', 'story', 'weapons'}
memory = {'luaKiB', 'resourceBytes', 'api', 'desktop', 'modelBytes', 'arrayBytes',
          'texture2DBytes', 'imageBytes', 'materialBytes', 'xmlBytes', 'soundBytes',
          'jsonBytes', 'retiredTargets', 'batches', 'primitives', 'fixedSteps',
          'droppedSeconds', 'focus', 'minimized', 'ambience', 'lifecycle',
          'battleObjects', 'battleTiming'}
replayed = original_bytes = projected_bytes = 0
log = ROOT / 'docs/migration/evidence/story-natural-s4-manifest-279727d3-2026-10-16T08-35-25-117Z/runtime.log'
for index, line in enumerate(log.read_text(encoding='utf-8').splitlines()):
    if index % 13 or 'OUTGAME_STATE ' not in line:
        continue
    try:
        value = json.loads(line.split('OUTGAME_STATE ', 1)[1])
    except json.JSONDecodeError:
        continue
    if value.get('mode') != 'trial' or not value.get('story'):
        continue
    native = table(value)
    result = project(native)
    for key in required:
        check(f'Actual state {index} preserves exact route field {key}', same(result[key], native[key]))
    for key in memory:
        check(f'Actual state {index} preserves exact memory/timing field {key}', same(result.performance[key], native.performance[key]))
    if value['performance'].get('battleTiming', {}).get('enabled'):
        timing = value['performance'].get('updateTiming', {})
        check(f'Actual state {index} preserves every enabled battle timing label',
              set(result.performance.updateTiming.keys()) == {k for k in timing if k.startswith('battle.')})
        for label in result.performance.updateTiming.keys():
            check(f'Actual state {index} preserves timing {label}', same(result.performance.updateTiming[label], native.performance.updateTiming[label]))
    check(f'Actual state {index} excludes unrelated full UI audits',
          set(result.keys()) <= required | {'performance', 'observationMode'})
    projected = {k: value[k] for k in result.keys() if k not in {'performance', 'observationMode'}}
    projected['performance'] = {k: value['performance'][k] for k in result.performance.keys() if k != 'updateTiming'}
    if result.performance.updateTiming is not None:
        projected['performance']['updateTiming'] = {k: value['performance']['updateTiming'][k] for k in result.performance.updateTiming.keys()}
    projected['observationMode'] = result.observationMode
    original_bytes += len(json.dumps(value, ensure_ascii=False).encode())
    projected_bytes += len(json.dumps(projected, ensure_ascii=False).encode())
    replayed += 1
check('Replay includes more than 100 actual old full observations', replayed > 100)
check('Projection reduces actual serialized diagnostic bytes by at least 40%', projected_bytes < original_bytes * .6)
check('Projection tolerates no performance counters without inventing values', len(project(lua.table()).performance) == 0)
for name, before, after in [('target loss', "'widgets','aimTargets','wing','story'", "'widgets','wing','story'"),
                            ('weapon counters loss', 'out.weapons=data.weapons', 'out.weapons=nil'),
                            ('memory loss', "'texture2DBytes','imageBytes','materialBytes'", "'texture2DBytes','imageBytes'")]:
    mutated = LuaRuntime(unpack_returned_tuples=True)
    mutated.execute(source.replace(before, after))
    specimen = mutated.table_from({'aimTargets': 7, 'weapons': 23, 'performance': mutated.table_from({'materialBytes': 19})})
    result = mutated.globals().G0_StoryRouteState(specimen)
    check('Reject negative control ' + name, result.aimTargets != 7 or result.weapons != 23 or result.performance.materialBytes != 19)
probe = ROOT / 'tools/migration/probe-outgame-web.lua'
server = ROOT / 'tools/migration/serve-outgame.cjs'
runner = ROOT / 'tools/migration/check-story-natural-web.cjs'
check('Only explicit QA opt-in loads projection', "const storyRoute=qa&&process.argv.includes('--story-route');" in server.read_text(encoding='utf-8'))
check('Projection remains restricted to story trial dumps', 'if G0_StoryRouteState and data.story then data=G0_StoryRouteState(data,s) end' in probe.read_text(encoding='utf-8'))
check('Route mode stops automatic duplicate dumps but retains explicit full-history and object requests', 'frames%30==0 and not G0_StoryRouteState or input:GetKeyPress(KEY_F8) or pendingPresentationHistory or pendingSceneObjects' in probe.read_text(encoding='utf-8'))
files = [helper, Path(__file__), probe, server, runner]
report = {'result': 'PASS', 'checks': len(checks), 'negativeControls': 3,
          'replayedStates': replayed, 'originalBytes': original_bytes, 'projectedBytes': projected_bytes,
          'inputs': {str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
          'boundary': 'Actual Lua projection against historical full runtime states and three rejected mutations. Same story/camera/targets/control/memory references plus existing weapon counters, not gameplay or allocator changes. No GPU/OOM, complete UI audit or sustained performance acceptance.'}
out = ROOT / 'docs/migration/evidence/story-route-observer-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))

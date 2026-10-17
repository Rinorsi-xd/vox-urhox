"""Exercise the exact QA wall sampler; synthetic clocks are not FPS evidence."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

probe = ROOT / 'tools/migration/probe-outgame-web.lua'
source = probe.read_text(encoding='utf-8')
observer = ROOT / 'tools/migration/qa-frame-wall-observer.lua'
block = observer.read_text(encoding='utf-8')
lua = LuaRuntime(unpack_returned_tuples=True)
sampler = lua.execute(block + '\nreturn VOX_QA_FRAME_WALL')
checks = 0


def check(condition, message):
    global checks
    assert condition, message
    checks += 1


observe, drain = sampler['Observe'], sampler['Drain']
observe(100, 'crater', False)
check(drain() is None, 'First observation is a boundary, not a fabricated frame')
for stamp in (117, 291, 300):
    observe(stamp, 'crater', False)
window = drain()
check(window['count'] == 3 and window['totalMs'] == 200, 'All real intervals counted')
check(list(window['samplesMs'].values()) == [17, 174, 9], 'Temporal order and 174 ms stall retained')
check(window['p50'] == 17 and window['p95'] == 174 and window['max'] == 174, 'Unsmoothed percentiles')
check(window['lastClockMs'] - window['firstClockMs'] == 200, 'Clock span equals sum')
check(drain() is None, 'Draining does not duplicate prior intervals')
observe(335, 'crater', False)
window2 = drain()
check(window2['firstClockMs'] == window['lastClockMs'] and window2['totalMs'] == 35, 'Consecutive windows')
check(window['samplesMs'][2] == 174, 'Drain preserves previous returned samples')
observe(900, 'crater', True)
observe(1000, 'crater', False)
check(drain() is None, 'Loading edge interval excluded')
observe(1033, 'crater', False)
check(drain()['totalMs'] == 33, 'Sampling resumes after loading')
observe(1500, 'hangar', False)
check(drain() is None, 'Scene boundary excluded')
observe(10, 'hangar', False)
check(drain() is None, 'Clock reset/wrap restarts boundary')
observe(10, 'hangar', False)
check(drain()['totalMs'] == 0, 'Submillisecond zero interval retained without fabrication')
for i in range(1, 4099):
    observe(10 + i, 'hangar', False)
capped = drain()
check(capped['count'] == 4096 and capped['dropped'] == 2, 'Bounded QA buffer reports overflow')
check('not CPU' in capped['source'], 'Metric scope explicit')
lua.execute('assert(load(...))', source)
lua.execute('assert(load(...))', block + '\n' + source)
check(source.index('local updateWall=Time:GetSystemTime()') < source.index('original(et,ed)'), 'Clock read at Update entry')
check(source.count('framesWall=VOX_QA_FRAME_WALL.Drain()') == 2, 'Trial and hall emit independent wall windows')
report = {'result': 'PASS', 'checks': checks, 'probeSha256': hashlib.sha256(probe.read_bytes()).hexdigest(),
          'observerSha256': hashlib.sha256(observer.read_bytes()).hexdigest(),
          'boundary': 'Exact Lua QA sampler with synthetic clock inputs. No runtime or FPS acceptance.'}
out = ROOT / 'docs/migration/evidence/qa-frame-wall-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))

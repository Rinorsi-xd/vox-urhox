"""Compare authored page timeline with actual Lua Epilogue rendering and ownership."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
subprocess.run(['node', 'tools/migration/source-epilogue-pages.cjs'], check=True)
oracle = json.loads((ROOT / '.tmp/source-epilogue-pages.json').read_text(encoding='utf-8'))
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def ease(t):
    if t <= 0 or t >= 1:
        return max(0, min(1, t))
    x1, y1, x2, y2 = oracle['cssFadeEasing']
    lo, hi = 0, 1
    for _ in range(40):
        u = (lo + hi) / 2
        x = 3 * (1-u)**2 * u * x1 + 3 * (1-u) * u*u * x2 + u**3
        if x < t:
            lo = u
        else:
            hi = u
    u = (lo + hi) / 2
    return 3 * (1-u)**2 * u * y1 + 3 * (1-u) * u*u * y2 + u**3


def translation(animation, at, height):
    options = animation['options']
    t = (at-animation['at']-options['delay']) / options['duration']
    if t < 0 or t >= 1:
        return [0, 0]
    frames = [[float(v.removesuffix('vh')) for v in f['translate'].split()] for f in animation['frames']]
    part = t * (len(frames)-1)
    index = int(part)
    return [(frames[index][axis] + (frames[index+1][axis]-frames[index][axis])*(part-index))*height/100 for axis in range(2)]


expected = []
for snapshot in oracle['snapshots']:
    x, y = translation(oracle['shakes'][-1], snapshot['at'], 900)
    old_x, old_y = 0, 0
    for animation in oracle['shakes'][:2]:
        start = animation['at'] + animation['options']['delay']
        if start <= snapshot['at'] < start + animation['options']['duration']:
            old_x, old_y = translation(animation, snapshot['at'], 900)
    expected.append({**snapshot, 'alpha': 1-ease((snapshot['at']-200)/(oracle['cssFadeSeconds']*1000)), 'x': x, 'y': y, 'oldX': old_x, 'oldY': old_y})
motion = (ROOT / 'scripts/ui/EpilogueMotion.lua').read_text(encoding='utf-8')
epilogue = (ROOT / 'scripts/ui/Epilogue.lua').read_text(encoding='utf-8')
fixture = (ROOT / 'tools/migration/check-epilogue-pages.lua').read_text(encoding='utf-8')


def run(epilogue_source=epilogue, motion_source=motion):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value

    lua.globals().EPILOGUE_SOURCE = epilogue_source
    lua.globals().MOTION_SOURCE = motion_source
    lua.globals().EPILOGUE_EXPECTED = table(expected)
    return lua.execute(fixture)


checks = run()
negatives = []
for name, before, after in [
    ('immediate-old-page-removal', 'now>=page.outAt+.5', 'now>=page.outAt'),
    ('missing-shake', 'if not t then', 'if true then'),
    ('shake-without-delay', 'local start=now+.26', 'local start=now'),
    ('replaced-pending-shake', 'self.current.shakeStarts[#self.current.shakeStarts+1]=start', 'self.current.shakeStarts={start}'),
]:
    assert before in motion
    try:
        run(motion_source=motion.replace(before, after, 1))
    except Exception:
        negatives.append(name)
    else:
        raise AssertionError('Negative control escaped: ' + name)

old = subprocess.check_output(['git', 'show', 'HEAD:scripts/ui/Epilogue.lua'], text=True, encoding='utf-8')
try:
    run(epilogue_source=old)
except Exception as error:
    negatives.append('previous-committed-no-page-lifecycle')
    old_failure = str(error)
else:
    raise AssertionError('Previous committed version escaped')

hashes = lambda names: {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in names}
report = {'result': 'PASS', 'checks': checks, 'negativeControls': negatives, 'oldVersionFailure': old_failure,
          'sourceCommit': oracle['commit'], 'sourceHashes': oracle['sourceHashes'],
          'productionHashes': hashes(['scripts/ui/Epilogue.lua', 'scripts/ui/EpilogueMotion.lua', 'scripts/story/EpilogueRules.lua', 'assets/Story/Boss/Epilogue.json']),
          'inputs': hashes(['tools/migration/source-epilogue-pages.cjs', 'tools/migration/check-epilogue-pages.lua', 'tools/migration/check-epilogue-pages.py']),
          'boundary': 'Actual frozen JS DOM/timer/WAAPI recorder and actual Lua Epilogue update/render/Dispose with native drawing, images, voices and UI adapted. Compares source CSS ease, page ownership, draw opacity and shake; no GPU pixels, natural ending, listening or mobile performance acceptance.'}
output = ROOT / 'docs/migration/evidence/epilogue-pages-offline.json'
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))

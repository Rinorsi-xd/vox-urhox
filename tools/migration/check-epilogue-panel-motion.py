"""Execute frozen WAAPI recording and actual Lua epilogue drawing contracts."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
subprocess.run(['node', 'tools/migration/source-epilogue-panel-motion.cjs'], check=True)
oracle = json.loads((ROOT / '.tmp/source-epilogue-panel-motion.json').read_text(encoding='utf-8'))
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def easing(progress, text):
    p = max(0, min(1, progress))
    values = [float(v) for v in text.removeprefix('cubic-bezier(').removesuffix(')').split(',')]
    x1, y1, x2, y2 = values
    low, high = 0, 1
    for _ in range(45):
        t = (low+high)/2
        x = 3*(1-t)**2*t*x1 + 3*(1-t)*t*t*x2 + t**3
        if x < p:
            low = t
        else:
            high = t
    t = (low+high)/2
    return 3*(1-t)**2*t*y1 + 3*(1-t)*t*t*y2 + t**3


expected = []
for impact in oracle['impacts']:
    delay = impact['options']['delay']/1000
    for age in sorted({0, .001, .016, .05, .08, .16, .2, .26, .319, .32, .36, .4, .8, 1.2, 1.599, 1.6, 2,
                       delay-.001, delay, delay+.001, delay+.04, delay+.11, delay+.18, delay+.219, delay+.22}):
        panel = oracle['panels'][0]
        k = easing(age*1000/panel['options']['duration'], panel['options']['easing'])
        i = easing((age-delay)*1000/impact['options']['duration'], impact['options']['easing'])
        c = oracle['characters'][0]
        expected.append({'age': age, 'delay': delay,
                         'panel': {'eased': k, 'rotation': -4*(1-k), 'opacity': max(0, min(1, k))},
                         'impact': {'scale': 2.4-1.4*i, 'rotation': -23+12*i, 'opacity': max(0, min(1, i))},
                         'character': easing(age*1000/c['options']['duration'], c['options']['easing'])})

motion = (ROOT / 'scripts/ui/EpilogueMotion.lua').read_text(encoding='utf-8')
epilogue = (ROOT / 'scripts/ui/Epilogue.lua').read_text(encoding='utf-8')
fixture = (ROOT / 'tools/migration/check-epilogue-panel-motion.lua').read_text(encoding='utf-8')


def run(ep=epilogue, mo=motion):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value

    lua.globals().MOTION_SOURCE = mo
    lua.globals().EPILOGUE_SOURCE = ep
    lua.globals().EXPECTED = table(expected)
    return lua.execute(fixture)


checks = run()
negative = []
old_root = ROOT / '.tmp/outgame-cached-1792196884433'
old_identity = json.loads((old_root/'identity.json').read_text(encoding='utf-8'))
old_epilogue = (old_root/'scripts/ui/Epilogue.lua').read_bytes()
assert hashlib.sha256(old_epilogue).hexdigest() == old_identity['identity']['scripts']['ui/Epilogue.lua']
try:
    run(ep=old_epilogue.decode('utf-8-sig'))
except Exception as error:
    negative.append('actual-frozen-17ca-render')
    historical_failure = str(error)
else:
    raise AssertionError('Actual frozen renderer unexpectedly passed')
for label, target, before, after in [
    ('old-panel-easing', 'motion', 'Ease(age/.32,.2,.9,.3,1.05)', '1-(1-math.min(1,age/.32))^3'),
    ('fixed-impact-rotation', 'motion', '(rotation or -6)-12*(1-eased)', '(rotation or -6)'),
    ('opaque-impact', 'motion', 'math.max(0,math.min(1,eased))\nend\nfunction M.Character', '1\nend\nfunction M.Character'),
    ('linear-portrait-float', 'motion', 'Ease(age/1.6,.2,.8,.2,1)', 'math.min(1,age/1.6)'),
    ('missing-zoom-portrait-float', 'epilogue', '+Motion.Character(age,ph)', ''),
    ('wrong-portrait-container-height', 'epilogue', 'Motion.Character(age,ch)', 'Motion.Character(age,ph)'),
    ('top-left-panel-rotation', 'epilogue', 'nvgTranslate(vg,x+pw/2,y+ph/2);nvgRotate(vg,rotation*math.pi/180);nvgTranslate(vg,-pw/2,-ph/2)', 'nvgTranslate(vg,x,y);nvgRotate(vg,rotation*math.pi/180)'),
]:
    source = motion if target == 'motion' else epilogue
    assert before in source, label
    changed = source.replace(before, after, 1)
    try:
        run(mo=changed) if target == 'motion' else run(ep=changed)
    except Exception:
        negative.append(label)
    else:
        raise AssertionError('Negative control escaped: '+label)

names = ['scripts/ui/Epilogue.lua', 'scripts/ui/EpilogueMotion.lua',
         'tools/migration/source-epilogue-panel-motion.cjs', 'tools/migration/check-epilogue-panel-motion.lua',
         'tools/migration/check-epilogue-panel-motion.py']
report = {'status': 'PASS', 'checks': checks, 'samples': len(expected), 'negativeControls': negative,
          'historicalRendererFailure': historical_failure,
          'source': oracle['source'], 'sourceCommit': oracle['commit'],
          'hashes': {n: hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in names},
          'boundary': 'Actual frozen playEpilogue records animation options, independent cubic-bezier interpolation compared to actual Lua motion and Render affine matrices/opacity/portrait image placement. Drawing/UI/audio adapters; no GPU pixels, natural ending, audio or phone acceptance.'}
output = ROOT / 'docs/migration/evidence/epilogue-panel-motion-offline.json'
output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, indent=2))

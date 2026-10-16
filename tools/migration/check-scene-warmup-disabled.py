"""Exercise actual Lua module; reject historical no-filter and broken restoration."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

PRODUCTION = ROOT / 'scripts/render/SceneWarmup.lua'
FIXTURE = ROOT / 'tools/migration/check-scene-warmup-disabled.lua'
source = PRODUCTION.read_text(encoding='utf-8')
fixture = FIXTURE.read_text(encoding='utf-8')


def run(text, compare=False):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().COMPARE_BASELINE = compare
    runtime.execute('package.preload["render.SceneWarmup"]=assert(load(...))', text)
    return runtime.execute(fixture)


result = run(source)
baseline_path = ROOT / '.tmp/outgame-cached-1792113063203/scripts/render/SceneWarmup.lua'
baseline = baseline_path.read_text(encoding='utf-8')
before = run(baseline, compare=True)
after = run(source, compare=True)
assert before['sequence'] == after['sequence'], 'Enabled drawable submissions changed'
assert before['frames'] > after['frames'], 'Disabled-only work not reduced'
negatives = []
for label, candidate in [
    ('missing-filter', source.replace('drawable.enabledEffective==false', 'false')),
    ('missing-restoration', source.replace('item.drawable.viewMask=item.mask end\nend\nreturn M', 'item.drawable.viewMask=0 end\nend\nreturn M')),
]:
    assert candidate != source, label
    try:
        run(candidate)
    except Exception as error:
        negatives.append({'name': label, 'failure': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control passed: ' + label)

report = {'result': 'PASS', 'checks': result['checks'], 'negativeControls': negatives,
          'controlledFixture': {'disabled': result['disabled'], 'admitted': result['admitted'],
                                'batchesBefore': before['frames'], 'batchesAfter': after['frames'],
                                'enabledSubmissionSequenceEqual': True},
          'baseline': {'manifest': '5b8cf21c', 'sha256': hashlib.sha256(baseline_path.read_bytes()).hexdigest()},
          'productionHashes': {str(PRODUCTION.relative_to(ROOT)): hashlib.sha256(PRODUCTION.read_bytes()).hexdigest()},
          'toolHashes': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [FIXTURE, Path(__file__)]},
          'boundary': 'Actual Lua 5.4 SceneWarmup with controlled scene/frustum adapters. Exact masks and useful enabled submission coverage tested. Counts are controlled fixture only; no GPU, real runtime disabled count or performance claim.'}
out = ROOT / 'docs/migration/evidence/scene-warmup-disabled-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))

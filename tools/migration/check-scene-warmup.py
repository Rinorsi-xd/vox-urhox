"""Offline SceneWarmup grouping and ownership contract; no GPU acceptance."""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

files = ['tools/migration/experiments/SceneWarmupGrouping.lua']
fixture = root / 'tools/migration/check-scene-warmup.lua'
lua = LuaRuntime()
lua.execute('package.preload["render.SceneWarmup"]=assert(load(...))', (root / files[0]).read_text(encoding='utf-8'))
checks = lua.execute(fixture.read_text(encoding='utf-8'))
report = {
    'result': 'REJECTED',
    'offlineChecksResult': 'PASS',
    'checks': checks,
    'experimentHashes': {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files},
    'productionRestoredSha256': hashlib.sha256((root / 'scripts/render/SceneWarmup.lua').read_bytes()).hexdigest(),
    'fixtureHash': hashlib.sha256(fixture.read_bytes()).hexdigest(),
    'boundary': 'Lua 5.4 offline grouping, presented-phase sequencing and exact view-mask restoration only. No GPU, shader compile coverage, load-time or mobile performance acceptance.',
    'rejectionReason': 'Multiple exact groups may share model/material and re-instance in a batched single phase. The 679 offline checks do not prove native single-variant shader coverage. Candidate removed from production before GPU acceptance.',
    'guards': ['StaticModel only with enabledEffective=true', 'all active lights confirmed directional', 'confirmed nonnil zone',
               'same model resource and every material slot', 'all render-state fields known and equal',
               'no morph, outline or multiple LODs', 'more than eight exact duplicates',
               'four real representatives followed by one single presentation'],
    'runtimeRequired': ['current scene items and batches versus original',
                        'original and candidate shader compilation sets',
                        'actual serial match load timing and frame distribution'],
}
out = root / 'docs/migration/evidence/scene-warmup-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': checks}))

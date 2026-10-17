"""Actual equipment warmup lifecycle; drawing doubles, no GPU performance claim."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source = (ROOT / 'scripts/render/EquipmentWarmup.lua').read_text('utf8')
fixture = (ROOT / 'tools/migration/check-equipment-warmup.lua').read_text('utf8')


def run(code):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().EQUIPMENT_WARMUP_SOURCE = code
    lua.globals().print = lambda *args: None
    result = lua.execute(fixture)
    return {'result': result['result'], 'checks': result['checks']}


result = run(source)
negative = source.replace('        batch:Finish()', '        batch.mesh.enabled=false')
assert negative != source
try:
    run(negative)
except Exception as error:
    assert 'batch actually committed and visible' in str(error), str(error)
    result['negativeControl'] = str(error).split('\n')[0]
else:
    raise AssertionError('Allocation-only equipment probe incorrectly passed')

result['productionHashes'] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in [
    'scripts/render/CombatWarmup.lua', 'scripts/render/EquipmentWarmup.lua',
    'scripts/render/EquipmentEffects.lua', 'scripts/render/EquipmentResources.lua',
    'scripts/render/EffectBatch.lua']}
result['boundary'] = ('Real EquipmentEffects, EquipmentResources, EffectBatch and CombatWarmup; '
    'native draw API doubles. Actual Web shader variants, first-use stall removal, visuals '
    'and target-device sustained performance remain pending.')
output = ROOT / 'docs/migration/evidence/equipment-warmup-offline.json'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
print(json.dumps(result))

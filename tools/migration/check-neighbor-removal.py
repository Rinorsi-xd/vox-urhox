"""Verify reverse neighbor-cache cleanup against the frozen production Blueprint."""
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/lifecycle-python'))
from lupa.lua54 import LuaRuntime

REFERENCE = ROOT / '.tmp/outgame-cached-1792112558349/scripts/construction/Blueprint.lua'
PATH = ROOT / 'scripts/construction/Blueprint.lua'
SOURCE = PATH.read_text(encoding='utf-8-sig')


def run(source, full_equivalence=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    null = lua.table()

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({k: convert(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(v) for v in value])
        return null if value is None else value

    def read_resource(path):
        return convert(json.loads((ROOT / 'assets' / path).read_text(encoding='utf-8-sig')))

    lua.globals().read_resource = read_resource
    lua.globals().cjson = lua.table(null=null)
    lua.globals().neighbor_source = source
    lua.globals().neighbor_reference = REFERENCE.read_text(encoding='utf-8-sig')
    lua.globals().carunit_source = (ROOT / 'scripts/combat/CarUnit.lua').read_text(encoding='utf-8-sig')
    lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path; "
                "package.preload['core.ResourceData']=function() return {Read=function(path) return read_resource(path) end} end; "
                "package.preload['construction.Blueprint']=function() return assert(load(neighbor_source))() end")
    result = lua.execute((ROOT / 'tools/migration/check-neighbor-removal.lua').read_text(encoding='utf-8'))
    if full_equivalence:
        lua.globals().fixture = convert(json.loads((ROOT / 'tools/migration/source-vehicle-fixtures.json').read_text(encoding='utf-8')))
        modules = ['construction/Blueprint', 'construction/TurretRange', 'drive/VehicleSpec', 'combat/CarUnit']
        lua.globals().damage_before = convert({name: (REFERENCE if name == 'construction/Blueprint' else ROOT / 'scripts' / (name + '.lua')).read_text(encoding='utf-8-sig') for name in modules})
        full = lua.execute((ROOT / 'tools/migration/check-damage-rebuild.lua').read_text(encoding='utf-8'))
        result['full_damage_equivalence_checks'] = len(full)

    def plain(value):
        if hasattr(value, 'items'):
            return {str(k): plain(v) for k, v in value.items()}
        return value

    return plain(result)


result = run(SOURCE, full_equivalence=True)
controls = []
for name, needle, replacement in [
    ('missing incoming registration', 'owners[id]=true;self._neighborOwners[neighbor]=owners', 'self._neighborOwners[neighbor]=owners'),
    ('stale owner after row invalidation', 'owners[id]=nil', 'local omittedCleanup=true'),
]:
    assert SOURCE.count(needle) == 1, name + ' mutation target changed'
    try:
        run(SOURCE.replace(needle, replacement))
    except Exception as error:
        controls.append({'name': name, 'detected': True, 'failure': str(error).splitlines()[0]})
    else:
        raise AssertionError('negative control was not detected: ' + name)

report = {
    'result': 'PASS', 'runtime': 'Lua 5.4 / lupa',
    'boundary': 'Actual production Blueprint/CarUnit and prefab data. Native vehicle and debris factories are adapters. Operation counts only; no Web/native frame-time or mobile performance acceptance.',
    'reference': str(REFERENCE.relative_to(ROOT)),
    'reference_sha256': hashlib.sha256(REFERENCE.read_bytes()).hexdigest(),
    'sources': {p: hashlib.sha256((ROOT / 'scripts' / p).read_bytes()).hexdigest() for p in [
        'construction/Blueprint.lua', 'combat/CarUnit.lua', 'drive/VehicleSpec.lua']},
    'checks': result, 'negative_controls': controls,
}
stamp = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%S-%fZ')
output = ROOT / ('docs/migration/evidence/neighbor-removal-' + stamp + '.json')
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': result['checks'], 'negative_controls': len(controls),
                  'samples': result['samples'], 'evidence': str(output)}, ensure_ascii=False))

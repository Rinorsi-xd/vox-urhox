"""Run old/new real endless spawn consumers and actual spec builders without GPU."""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
null = lua.table()

def table(value):
    if value is None:
        return null
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value

def read_resource(name):
    return table(json.loads((root / 'assets' / name).read_text(encoding='utf-8-sig')))

reference = root / '.tmp/endless-spawn-cache-before-20261016.lua'
reference_hash = hashlib.sha256(reference.read_bytes()).hexdigest()
assert reference_hash == '4ed4d32b2ebd7443cde2865dead0ae2005a786ecbcf2b7d92ef04879d13273ee'
paths = ['scripts/app/EndlessSession.lua', 'scripts/drive/SpawnSpecCache.lua', 'scripts/combat/CarUnit.lua',
         'scripts/drive/VehicleSpec.lua', 'scripts/construction/Blueprint.lua', 'scripts/endless/Run.lua']
hashes = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
lua.globals().cjson = lua.table(null=null)
lua.globals().read_resource = read_resource
lua.globals().reference = reference.read_text(encoding='utf-8')
checks = lua.execute((root / 'tools/migration/check-endless-spawn-cache.lua').read_text(encoding='utf-8'))
assert hashes == {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
rows = [{key: value for key, value in row.items()} for row in lua.globals().spawn_cache_rows.values()]
report = {'result': 'PASS', 'checks': list(checks.values()), 'runtime': lua.lua_implementation,
          'referenceHash': reference_hash, 'productionHashes': hashes,
          'prefabs': rows, 'oldBuilds': sum(row['oldBuilds'] for row in rows),
          'newBuilds': sum(row['newBuilds'] for row in rows),
          'boundary': 'Actual pre-change/current EndlessSession Spawn/SpawnUnit/Dispose, real VehicleSpec.Build/Blueprint/CarUnit/WeaponSystem and actual endless prefab data. Native vehicle/body and drivers are adapters. Build call counts are measured, not Web frame-time or memory claims. No GPU, browser, natural gameplay, account or mobile acceptance.'}
out = root / 'docs/migration/evidence/endless-spawn-cache-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'prefabs': len(rows),
                  'oldBuilds': report['oldBuilds'], 'newBuilds': report['newBuilds'], 'evidence': str(out)}))

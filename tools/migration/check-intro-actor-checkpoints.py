"""Exercise real opening actors and blueprint/spec construction without a GPU."""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    null = lua.table()

    def table(value):
        if value is None:
            return null
        if isinstance(value, dict):
            return lua.table_from({key: table(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(item) for item in value])
        return value

    def read_resource(name):
        return table(json.loads((root / 'assets' / name).read_text(encoding='utf-8-sig')))

    lua.globals().cjson = lua.table(null=null)
    lua.globals().read_resource = read_resource
    return lua


paths = ['scripts/intro/IntroBattle.lua', 'scripts/intro/IntroMontagePool.lua',
         'scripts/combat/CarUnit.lua', 'scripts/drive/VehicleSpec.lua',
         'scripts/construction/Blueprint.lua']
hashes = {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in paths}
fixture = (root / 'tools/migration/check-intro-actor-checkpoints.lua').read_text(encoding='utf-8')
lua = runtime()
result = lua.execute(fixture)
assert hashes == {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in paths}
report = {key: value for key, value in result.items()}
mutations = [
    ('battle checkpoint removed', 'intro.IntroBattle', 'scripts/intro/IntroBattle.lua',
     "checkpoint and function(p)checkpoint((index-1+p)/9,'intro-actors')end", 'nil'),
    ('battle retained owner removed', 'intro.IntroBattle', 'scripts/intro/IntroBattle.lua',
     'entry.unit=unit;w.units[#w.units+1]=unit;self.entries[index]=entry', ''),
    ('montage checkpoint removed', 'intro.IntroMontagePool', 'scripts/intro/IntroMontagePool.lua',
     'checkpoint and function(p)checkpoint(p*.3)end', 'nil'),
    ('montage retained owner removed', 'intro.IntroMontagePool', 'scripts/intro/IntroMontagePool.lua',
     'function(unit)self.unit=unit end', 'nil'),
]
rejected = []
for name, module, path, old, new in mutations:
    text = (root / path).read_text(encoding='utf-8')
    assert text.count(old) == 1, name
    mutated = runtime()
    mutated.globals().mutation_source = text.replace(old, new)
    mutated.globals().mutation_module = module
    mutated.execute("package.preload[mutation_module]=assert(load(mutation_source,'@negative-mutation','t',_ENV))")
    try:
        mutated.execute(fixture)
    except Exception:
        rejected.append(name)
    else:
        raise AssertionError('Checker accepted negative mutation: '+name)
report['negativeMutationsRejected'] = rejected
report.update(result='PASS', runtime=lua.lua_implementation, productionHashes=hashes,
              boundary='Real IntroBattle, IntroMontagePool, CarUnit, Blueprint, VehicleSpec, WeaponSystem and original Intro.json. Native bodies, drivers and DriveView use ownership adapters. Full yielded traversal verifies ownership at every callback; selected phase boundaries verify actual cancellation and idempotent teardown. No GPU, native physics timing, browser playback, build or mobile performance acceptance.')
out = root / 'docs/migration/evidence/intro-actor-checkpoints-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))

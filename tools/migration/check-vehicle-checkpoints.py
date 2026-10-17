"""Run source fixtures and cooperative-loading equivalence in isolated Lua 5.4."""
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/lifecycle-python'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
null = lua.table()
def convert(value):
    if value is None:
        return null
    if isinstance(value, dict):
        return lua.table_from({k: convert(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(v) for v in value])
    return value

def read_resource(path):
    return convert(json.loads((root / 'assets' / path).read_text(encoding='utf-8-sig')))

lua.globals().read_resource = read_resource
lua.globals().cjson = lua.table(null=null)
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path; package.preload['core.ResourceData']=function() return {Read=function(path) return read_resource(path) end} end")
suite = 'damage-rebuild' if '--damage-rebuild' in sys.argv else 'scope-input' if '--scope-input' in sys.argv else 'spawn-cache' if '--spawn-cache' in sys.argv else 'vehicle-checkpoints'
if suite == 'vehicle-checkpoints':
    lua.globals().fixture = convert(json.loads((root / 'tools/migration/source-vehicle-fixtures.json').read_text(encoding='utf-8')))
    lua.globals().rotor_fixture = convert(json.loads((root / 'tools/migration/source-rotors-fixtures.json').read_text(encoding='utf-8')))
if suite == 'scope-input':
    lua.globals().scope_fixture = convert(json.loads((root / '.tmp/source-scope-input.json').read_text(encoding='utf-8')))
    lua.globals().camera_fixture = convert(json.loads((root / '.tmp/source-chase-camera.json').read_text(encoding='utf-8')))
if suite == 'damage-rebuild':
    lua.globals().damage_before = convert({name: (root / '.tmp/damage-before-2026-10-15' / (name.split('/')[-1] + '.lua')).read_text(encoding='utf-8-sig') for name in ['construction/Blueprint', 'construction/TurretRange', 'drive/VehicleSpec', 'combat/CarUnit']})
    lua.globals().fixture = convert(json.loads((root / 'tools/migration/source-vehicle-fixtures.json').read_text(encoding='utf-8')))
checks = lua.execute((root / 'tools/migration' / ('check-' + suite + '.lua')).read_text(encoding='utf-8'))
def plain(value):
    if hasattr(value, 'items'):
        return {str(k): plain(v) for k, v in value.items()}
    return value
sources = ['construction/Blueprint', 'construction/Rotors', 'construction/TurretRange', 'drive/VehicleSpec', 'combat/CarUnit', 'combat/BattleController']
if suite == 'spawn-cache':
    sources += ['drive/SpawnSpecCache', 'story/Mission']
if suite == 'scope-input':
    sources = ['controls/DrivePointer', 'controls/ChaseState', 'controls/ChaseCamera', 'controls/SpeedFov', 'app/TrialSession']
if suite == 'damage-rebuild':
    sources = ['construction/Blueprint', 'construction/TurretRange', 'drive/VehicleSpec', 'combat/CarUnit']
boundary = ('Actual production pointer, chase-state and FOV Lua against executable frozen H5 input and camera fixtures. '
            'Native Node/ScriptObject, input and timing APIs are stubbed; camera poses are source-space state output. '
            'No actual Web/native event bridge, rendered ThirdPersonCamera adapter or frame-time acceptance.') if suite == 'scope-input' else 'Actual production geometry/range/blueprint Lua and source JSON fixtures. Native vehicle creation is stubbed; no Web frame-time acceptance.'
if suite == 'spawn-cache':
    boundary += (' Actual Mission.PrepareSpawnSpecs, Spawn and Dispose run against real data/spec/CarUnit code. '
                 'Unused native presentation imports render.SpawnViewCache and ui.Epilogue are fail-fast boundaries; '
                 'visual preparation, UI, effects and actual native vehicle bodies are not tested.')
report = {'result': 'PASS', 'runtime': lua.lua_implementation,
          'source_fixture_differences': plain(lua.globals().checkpoint_source_differences),
          'sources': {name: hashlib.sha256((root / 'scripts' / (name + '.lua')).read_bytes()).hexdigest() for name in sources},
          'checks': [checks[i] for i in range(1, len(checks) + 1)],
          'isolated_benchmarks': plain(lua.globals().damage_benchmarks),
          'presentation_boundaries': plain(lua.globals().spawn_cache_presentation_boundaries) if suite == 'spawn-cache' else None,
          'reference_sources': {name: hashlib.sha256(source.encode('utf-8')).hexdigest() for name, source in lua.globals().damage_before.items()} if suite == 'damage-rebuild' else None,
          'boundary': boundary}
out = root / 'docs/migration/evidence' / (suite + '-' + datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%S-%fZ'))
out.mkdir(parents=True)
(out / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(report['checks']), 'evidence': str(out)}))

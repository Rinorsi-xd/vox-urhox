"""Compare actual old/new Lua navigation and source-authored AI consumers; CPU only."""
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    baseline = ROOT / (sys.argv[1] if len(sys.argv) > 1 else '.tmp/outgame-cached-1792139145715')
    module = ROOT / 'scripts/combat/EnemyDriverNav.lua'
    old_module = baseline / 'scripts/combat/EnemyDriverNav.lua'
    assert sha(old_module) == '4e07d4e3bc18f759748be25b61a8b3ba0cd93f4ee1b0c0145b0a2c4f1f1260ce', 'Unexpected immutable old implementation'
    started = datetime.now(timezone.utc)
    paths = ['assets/Crater/Layout.json', 'assets/EnginePit/Layout.json', 'assets/Salvage/Gameplay.json']
    production_paths = ['scripts/combat/' + name + '.lua' for name in ['EnemyDriverNav', 'EnemyDriver', 'EnemyDriverThink', 'EnemyDriverMotion', 'EnemyDriverTactics', 'EnemyDriverMath', 'MissileWeapons', 'WeaponDefs']]
    production_before = {path: sha(ROOT / path) for path in production_paths}
    source = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8-sig'))
    assert source['branch'] == '2026-10-15' and source['commit'] == 'b276064942ae09c0227ec28d4cfda1d5ff006455', 'Unexpected source baseline'
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value, runtime=lua, null=None):
        if isinstance(value, dict):
            return runtime.table_from({key: convert(item, runtime, null) for key, item in value.items()})
        if isinstance(value, list):
            return runtime.table_from([convert(item, runtime, null) for item in value])
        return null if value is None else value

    def plain(value):
        if hasattr(value, 'items'):
            keys = list(value.keys())
            if keys and all(isinstance(k, int) for k in keys):
                return [plain(value[i]) for i in range(1, len(keys) + 1)]
            return {k: plain(v) for k, v in value.items()}
        return value

    os.chdir(ROOT)
    lua.globals().NAV_CASES = convert([{'name': path, 'nav': json.loads((ROOT / path).read_text(encoding='utf-8-sig'))['nav']} for path in paths])
    lua.globals().NAV_BEFORE_MODULE = old_module.as_posix()
    result = plain(lua.execute((ROOT / 'tools/migration/check-nav-distance-work.lua').read_text(encoding='utf-8')))
    fixture_path = ROOT / 'tools/migration/source-enemy-fixtures.json'
    assert sha(fixture_path) == '3398dc2a5950d36dfa9a35cb9097abd068f154c71edad4ff427316efe5eb1431', 'Unexpected source AI fixture'
    fixtures = json.loads(fixture_path.read_text(encoding='utf-8'))
    source_driver = Path(source['snapshot']) / fixtures['source']['file']
    assert sha(source_driver) == fixtures['source']['sha256'], 'H5 golden source drifted'
    consumers = {}
    runtime = LuaRuntime(unpack_returned_tuples=True)
    null = runtime.table()
    runtime.globals().SOURCE_NULL = null
    runtime.globals().SOURCE_AI_DATA = convert(fixtures, runtime, null)
    runtime.globals().read_resource = lambda name: convert(json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8-sig')), runtime, null)
    runtime.execute("package.preload['core.ResourceData']=function() return {Read=function(path) return read_resource(path) end} end")
    for label, implementation in [('before', old_module), ('after', module)]:
        trace = hashlib.sha256()
        runtime.globals().NAV_CONSUMER_MODULE = implementation.as_posix()
        runtime.globals().NAV_TRACE = lambda value: trace.update(value.encode('utf-8'))
        consumer = plain(runtime.execute((ROOT / 'tools/migration/check-nav-driver-consumer.lua').read_text(encoding='utf-8')))
        consumer['traceSha256'] = trace.hexdigest()
        consumers[label] = consumer
    assert consumers['before'] == consumers['after'], ('Actual AI output, retained state or cast sequence differs', consumers)
    result['sourceAiConsumers'] = consumers
    result['sourceAiFixtureSha256'] = sha(fixture_path)
    assert production_before == {path: sha(ROOT / path) for path in production_paths}, 'Production changed during verification'
    result.update({'lua': lua.eval('_VERSION'), 'started': started.isoformat(), 'baseline': str(baseline),
                   'beforeModuleSha256': sha(old_module), 'productionModuleSha256': sha(module),
                   'sourceBaseline': {'branch': source['branch'], 'commit': source['commit'], 'driverSha256': sha(source_driver)},
                   'inputs': {path: sha(ROOT / path) for path in paths},
                   'production': production_before,
                   'resources': {'assets/Combat/Weapons.json': sha(ROOT / 'assets/Combat/Weapons.json')},
                   'testInputs': {path: sha(ROOT / path) for path in ['tools/migration/check-nav-distance-work.lua', 'tools/migration/check-nav-driver-consumer.lua', 'tools/migration/verify-nav-distance-work.py', 'tools/migration/check-enemy-driver.lua', 'tools/migration/source-enemy-fixtures.json']},
                   'durationSeconds': (datetime.now(timezone.utc) - started).total_seconds(),
                   'scope': 'Actual Lua algorithm equivalence and operation counts; no Web/GPU/Bullet/mobile/FPS acceptance.'})
    output = ROOT / 'docs/migration/evidence' / ('nav-distance-work-' + started.strftime('%Y-%m-%dT%H-%M-%S-%fZ'))
    output.mkdir(parents=True)
    (output / 'report.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    (ROOT / 'docs/migration/evidence/nav-distance-work-offline.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2), flush=True)
    print('Evidence: ' + str(output / 'report.json'), flush=True)


if __name__ == '__main__':
    main()

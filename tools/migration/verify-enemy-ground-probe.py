"""Actual Lua 5.4 differential and frozen H5 golden checks; no runtime window."""
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
sys.path.insert(0, str(ROOT / '.tmp/lifecycle-python'))
from lupa.lua54 import LuaRuntime


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    args = [arg for arg in sys.argv[1:] if not arg.startswith('--')]
    baseline = ROOT / (args[0] if args else '.tmp/outgame-cached-1792071037109')
    old = baseline / 'scripts/combat/EnemyDriver.lua'
    production = ROOT / 'scripts/combat/EnemyDriver.lua'
    baseline_config = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8-sig'))
    fixtures_path = ROOT / 'tools/migration/source-enemy-fixtures.json'
    data = json.loads(fixtures_path.read_text(encoding='utf-8-sig'))
    source_file = Path(baseline_config['snapshot']) / data['source']['file']
    assert sha(source_file) == data['source']['sha256'], 'Golden source must match active frozen H5 input'
    production_inputs = ['scripts/combat/' + name + '.lua' for name in [
        'EnemyDriver', 'EnemyDriverMath', 'EnemyDriverNav', 'EnemyDriverThink',
        'EnemyDriverMotion', 'EnemyDriverTactics', 'MissileWeapons', 'WeaponDefs']]
    production_inputs.append('assets/Combat/Weapons.json')
    before = {name: sha(ROOT / name) for name in production_inputs}
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

    lua.globals().ENEMY_DATA = convert(data)
    lua.globals().ENEMY_NULL = null
    lua.globals().ENEMY_BEFORE_MODULE = old.as_posix()
    if '--before-nav' in sys.argv:
        lua.globals().ENEMY_BEFORE_NAV = (baseline / 'scripts/combat/EnemyDriverNav.lua').as_posix()
    lua.globals().read_resource = lambda name: convert(json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8-sig')))
    lua.execute("package.preload['core.ResourceData']=function() return {Read=function(path) return read_resource(path) end} end")
    os.chdir(ROOT)
    started = datetime.now(timezone.utc)
    result = lua.execute((ROOT / 'tools/migration/check-enemy-ground-probe.lua').read_text(encoding='utf-8'))
    rows = [dict(row.items()) for _, row in result['rows'].items()]
    report = {
        'result': result['result'], 'lua': lua.eval('_VERSION'),
        'assertions': result['assertions'], 'goldenAssertions': result['goldenAssertions'],
        'steps': result['steps'], 'removedUnusedQueries': result['removedUnusedQueries'],
        'edgeCalls': dict(result['edgeCalls'].items()),
        'newUnusedQueries': result['newUnusedQueries'],
        'requiredProbeCallsIncludingGolden': result['requiredProbeCallsIncludingGolden'], 'rows': rows,
        'baselineBuild': str(baseline), 'beforeModuleSha256': sha(old),
        'isolatedBeforeNavigation': '--before-nav' in sys.argv,
        'beforeNavigationSha256': sha(baseline / 'scripts/combat/EnemyDriverNav.lua') if '--before-nav' in sys.argv else None,
        'productionModuleSha256': sha(production), 'sourceGolden': data['source'],
        'activeSource': {key: baseline_config[key] for key in ['branch', 'commit', 'snapshot']},
        'activeSourceDriverSha256': sha(source_file),
        'productionInputs': before,
        'fixtureSha256': sha(fixtures_path),
        'durationSeconds': (datetime.now(timezone.utc) - started).total_seconds(),
        'scope': 'Offline real Lua decision modules with query/body adapters. No native Bullet timing, Web GPU, mobile, M1 or FPS acceptance.'
    }
    assert before == {name: sha(ROOT / name) for name in production_inputs}, 'Production inputs changed during verification'
    output = ROOT / 'docs/migration/evidence' / ('enemy-ground-probe-' + started.strftime('%Y-%m-%dT%H-%M-%S-%fZ'))
    output.mkdir(parents=True, exist_ok=True)
    (output / 'report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'activeSource'}, indent=2, ensure_ascii=False))
    print('Evidence: ' + str(output / 'report.json'))


if __name__ == '__main__':
    main()

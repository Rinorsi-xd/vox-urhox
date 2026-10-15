"""Replay real source fixtures and exact before/after leg controller outputs."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def main():
    baseline = ROOT / (sys.argv[1] if len(sys.argv) > 1 else '.tmp/outgame-cached-1792065106063')
    os.chdir(ROOT)
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items() if item is not None})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value

    def plain(value):
        return {key: item for key, item in value.items()}

    fixture_path = ROOT / 'tools/migration/source-leg-drive-fixtures.json'
    fixture = json.loads(fixture_path.read_text(encoding='utf-8'))
    types = sorted({leg['type'] for case in fixture['cases'] for leg in case['spec']['legs']})
    rigs = {name: json.loads((ROOT / f'assets/Parts/Rigs/{name}.json').read_text(encoding='utf-8')) for name in types}
    lua.globals().LEG_BEFORE_ROOT = baseline.as_posix()
    lua.globals().LEG_CELL = json.loads((ROOT / 'assets/Parts/Catalog.json').read_text(encoding='utf-8'))['cell']
    lua.globals().LEG_RIGS = convert(rigs)
    lua.execute((ROOT / 'tools/migration/check-leg-cache-offline.lua').read_text(encoding='utf-8'))
    rows = []
    for case in fixture['cases']:
        result = plain(lua.globals().LEG_RUN_CASE(convert(case)))
        rows.append(result)
        print(json.dumps(result), flush=True)
        lua.eval('collectgarbage')('collect')
    rows.append(plain(lua.globals().LEG_RUN_MIXED(convert(fixture['cases'][0]))))
    boundaries = plain(lua.globals().LEG_RUN_BOUNDARIES(convert(fixture['cases'][0])))
    paths = ['scripts/drive/LegControl.lua', 'scripts/parts/LegIK.lua', 'scripts/drive/LegGait.lua']
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    report = {
        'result': 'PASSED', 'lua': lua.eval('_VERSION'), 'assertions': lua.globals().LEG_ASSERTIONS(),
        'baseline': str(baseline), 'fixtureSha256': digest(fixture_path), 'provenance': fixture['provenance'],
        'rows': rows, 'boundaries': boundaries,
        'beforeSolve': sum(row['beforeSolve'] for row in rows), 'afterSolve': sum(row['afterSolve'] for row in rows),
        'before': {path: digest(baseline / path) for path in paths},
        'production': {path: digest(ROOT / path) for path in paths},
        'rigs': {name: digest(ROOT / f'assets/Parts/Rigs/{name}.json') for name in types},
        'scope': 'Actual Lua controllers and real source replay, synthetic extra terrain; not native Bullet or Web timing.'
    }
    output = ROOT / 'docs/migration/evidence/leg-cache-offline.json'
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in report.items() if key not in ['rows', 'provenance']}, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()

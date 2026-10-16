"""Bit comparisons and actual controller replay; never opens an engine or GPU."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def main():
    baseline = ROOT / (sys.argv[1] if len(sys.argv) > 1 else '.tmp/outgame-cached-1792085173431')
    reference = baseline / 'scripts/core/Math3.lua'
    expected_reference = '3f03e043874780814bcc5cb399f7f01928a18e82a6794829df8c322712573d12'
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest(reference) == expected_reference, 'Unexpected scalar optimization reference'
    os.chdir(ROOT)
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items() if item is not None})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value

    def plain(value):
        if not hasattr(value, 'items'):
            return value
        entries = list(value.items())
        if all(isinstance(key, int) for key, _ in entries):
            return [plain(value[index]) for index in range(1, len(value) + 1)]
        return {key: plain(item) for key, item in entries}

    lua.execute("package.path='scripts/?.lua;'..package.path")
    lua.globals().MATH_REFERENCE = reference.as_posix()
    lua.execute("BASE_MATH=assert(loadfile(MATH_REFERENCE))();CAND_MATH=assert(loadfile('scripts/core/Math3.lua'))()")
    lua.execute((ROOT / 'tools/migration/check-math-scalar.lua').read_text(encoding='utf-8-sig'))

    # Python objects cross Lupa as userdata, so the production functions also see
    # userdata field/index access rather than only plain Lua tables.
    class Fields:
        def __init__(self):
            self.x, self.y, self.z, self.w = .2, -.3, .8, 1.5

        def __getitem__(self, key):
            if isinstance(key, str):
                return getattr(self, key)
            return (3.0, -2.0, 4.0)[key - 1]

    lua.globals().MATH_USERDATA = Fields()
    lua.execute("assert(type(MATH_USERDATA)=='userdata');for _,name in ipairs({'QMul','RotateUnit'})do local a=BASE_MATH[name](MATH_USERDATA,MATH_USERDATA);local b=CAND_MATH[name](MATH_USERDATA,MATH_USERDATA);for k,v in pairs(a)do assert(string.pack('d',v)==string.pack('d',b[k]),name..' userdata')end end")

    fixture_path = ROOT / 'tools/migration/source-leg-drive-fixtures.json'
    fixture = json.loads(fixture_path.read_text(encoding='utf-8-sig'))
    types = sorted({leg['type'] for case in fixture['cases'] for leg in case['spec']['legs']})
    lua.globals().LEG_BEFORE_ROOT = ROOT.as_posix()
    lua.globals().LEG_CELL = json.loads((ROOT / 'assets/Parts/Catalog.json').read_text(encoding='utf-8-sig'))['cell']
    lua.globals().LEG_RIGS = convert({name: json.loads((ROOT / f'assets/Parts/Rigs/{name}.json').read_text(encoding='utf-8-sig')) for name in types})
    suite = (ROOT / 'tools/migration/check-leg-cache-offline.lua').read_text(encoding='utf-8-sig')
    original = 'local function Modules(root)'
    assert suite.count(original) == 1
    suite = suite.replace(original, original + "\n    package.loaded['core.Math3']=root=='.' and CAND_MATH or BASE_MATH")
    lua.execute(suite)
    rows = [plain(lua.globals().LEG_RUN_CASE(convert(case))) for case in fixture['cases']]
    rows.append(plain(lua.globals().LEG_RUN_MIXED(convert(fixture['cases'][0]))))
    sources = ['scripts/core/Math3.lua', 'scripts/drive/LegControl.lua', 'scripts/drive/LegGait.lua', 'scripts/parts/LegIK.lua']
    report = {
        'result': 'PASS', 'runtime': lua.lua_implementation,
        'reference': str(reference), 'referenceSha256': digest(reference),
        'production': {path: digest(ROOT / path) for path in sources},
        'fixtureSha256': digest(fixture_path), 'provenance': fixture['provenance'],
        'scalarAssertions': lua.globals().MATH_SCALAR_CHECKS,
        'userdataInputs': 'PASS: Python attribute/index objects exposed by Lua as userdata; not native engine userdata',
        'controllerAssertions': lua.globals().LEG_ASSERTIONS(),
        'assertions': lua.globals().MATH_SCALAR_CHECKS + lua.globals().LEG_ASSERTIONS(),
        'controllerCases': rows, 'benchmarks': plain(lua.globals().MATH_SCALAR_BENCH),
        'temporaryTablesPerCall': {'QMul': {'before': 11, 'after': 0}, 'RotateUnit': {'before': 6, 'after': 0}},
        'boundary': 'Actual production Lua math and controllers, recorded H5 rays/forces and synthetic mixed terrain. Math finite outputs compared by packed double bits; NaN by classification. No native Bullet, engine userdata, Web, GPU or target-device performance acceptance. Isolated timings are not game speedups.'
    }
    output = ROOT / 'docs/migration/evidence/math-scalar-offline.json'
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: report[key] for key in ['result', 'scalarAssertions', 'controllerAssertions', 'userdataInputs', 'benchmarks']}, ensure_ascii=False))


if __name__ == '__main__':
    main()

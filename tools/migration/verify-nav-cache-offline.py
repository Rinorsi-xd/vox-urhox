"""Run the actual Lua navigation modules without an engine window."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    baseline = ROOT / (sys.argv[1] if len(sys.argv) > 1 else '.tmp/outgame-cached-1792063134142')
    lua = LuaRuntime(unpack_returned_tuples=True)

    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({key: to_lua(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([to_lua(item) for item in value])
        return value

    paths = ['assets/Crater/Layout.json', 'assets/EnginePit/Layout.json', 'assets/Salvage/Gameplay.json']
    maps = [{'name': path, 'nav': json.loads((ROOT / path).read_text(encoding='utf-8'))['nav']} for path in paths]
    old_module = baseline / 'scripts/combat/EnemyDriverNav.lua'
    lua.globals().NAV_CASES = to_lua(maps)
    lua.globals().NAV_BEFORE_MODULE = old_module.as_posix()
    import os
    os.chdir(ROOT)
    result = lua.execute((ROOT / 'tools/migration/check-nav-cache-offline.lua').read_text(encoding='utf-8'))
    report = {
        'result': result['result'], 'assertions': result['assertions'], 'lua': lua.eval('_VERSION'),
        'baseline': str(baseline), 'beforeModuleSha256': digest(old_module),
        'weakRelease': result['weakRelease'], 'tableReplacement': result['tableReplacement'],
        'maps': [dict(row.items()) for _, row in result['maps'].items()],
        'inputs': {path: digest(ROOT / path) for path in paths},
        'production': {path: digest(ROOT / path) for path in ['scripts/combat/EnemyDriverNav.lua', 'scripts/combat/EnemyDriverThink.lua']},
        'scope': 'Offline algorithm equivalence only; no runtime performance or browser acceptance claim.'
    }
    output = ROOT / 'docs/migration/evidence/nav-cache-offline.json'
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()

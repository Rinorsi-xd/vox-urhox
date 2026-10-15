"""Validate actual navigation layouts against the immutable production implementation."""
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
    baseline = ROOT / (sys.argv[1] if len(sys.argv) > 1 else '.tmp/outgame-cached-1792071037109')
    before_module = baseline / 'scripts/combat/EnemyDriverNav.lua'
    module = ROOT / 'scripts/combat/EnemyDriverNav.lua'
    original_sha = sha(module)
    paths = ['assets/Crater/Layout.json', 'assets/EnginePit/Layout.json', 'assets/Salvage/Gameplay.json']
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value

    lua.globals().NAV_CASES = convert([{'name': path, 'nav': json.loads((ROOT / path).read_text(encoding='utf-8-sig'))['nav']} for path in paths])
    lua.globals().NAV_BEFORE_MODULE = before_module.as_posix()
    os.chdir(ROOT)
    started = datetime.now(timezone.utc)
    result = lua.execute((ROOT / 'tools/migration/check-nav-edge-index.lua').read_text(encoding='utf-8'))
    report = {
        'result': result['result'], 'assertions': result['assertions'], 'lua': lua.eval('_VERSION'),
        'rows': [dict(row.items()) for _, row in result['rows'].items()],
        'weakRelease': result['weakRelease'], 'tableReplacement': result['tableReplacement'], 'duplicateOrder': result['duplicateOrder'],
        'beforeModuleSha256': sha(before_module), 'productionModuleSha256': original_sha,
        'inputs': {path: sha(ROOT / path) for path in paths},
        'durationSeconds': (datetime.now(timezone.utc) - started).total_seconds(),
        'scope': 'Actual Lua edge lookups and CPU-only offline microbenchmark. Not native Bullet, rendered Web, GPU, mobile or FPS acceptance.'
    }
    assert original_sha == sha(module), 'Production module changed during verification'
    output = ROOT / 'docs/migration/evidence' / ('nav-edge-index-' + started.strftime('%Y-%m-%dT%H-%M-%S-%fZ'))
    output.mkdir(parents=True)
    (output / 'report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2, ensure_ascii=False))
    print('Evidence: ' + str(output / 'report.json'))


if __name__ == '__main__':
    main()

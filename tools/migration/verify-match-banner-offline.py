"""Frozen H5 banner event golden checks and real Lua UI command/state checks."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def main():
    os.chdir(ROOT)
    source = json.loads(subprocess.check_output(['node', 'tools/migration/source-match-banner-golden.cjs'], cwd=ROOT, text=True, encoding='utf-8'))
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items() if item is not None})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value

    lua.globals().MATCH_BANNER_SOURCE_CASES = convert(source)
    result = lua.execute((ROOT / 'tools/migration/check-match-banner-offline.lua').read_text(encoding='utf-8'))
    baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
    paths = ['scripts/ui/MatchBanner.lua', 'scripts/ui/MatchHud.lua', 'scripts/ui/DriveHud.lua', 'scripts/ui/DriveControls.lua', 'scripts/combat/BattleController.lua']
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    report = {'result': 'PASSED', 'lua': lua.eval('_VERSION'), 'assertions': result['assertions'], 'sourceEventCases': len(source),
              'baseline': {'branch': baseline['branch'], 'commit': baseline['commit'], 'snapshot': baseline['snapshot']},
              'production': {path: digest(ROOT / path) for path in paths},
              'source': {path: digest(Path(baseline['snapshot']) / path) for path in ['three/src/battle/matchSession.js', 'shared/ui/matchHud.js', 'shared/ui/uiScale.js', 'shared/css/new-ui-utility.css']},
              'scope': 'Frozen source onEvent methods, actual Lua banner state/draw commands and DriveHud.Create; no engine rendering or Web performance claim.'}
    (ROOT / 'docs/migration/evidence/match-banner-offline.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()

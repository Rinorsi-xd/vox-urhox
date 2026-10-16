"""Source-golden competitive flow and spectator checks, without a GPU."""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

baseline = json.loads((root / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
sources = ['three/src/battle/matchSession.js', 'shared/ui/matchHud.js']
hashes = {}
for name in sources:
    hashes[name] = hashlib.sha256((Path(baseline['snapshot']) / name).read_bytes()).hexdigest()
    assert hashes[name] == baseline['files'][name]['sha256'], name
lua = LuaRuntime(unpack_returned_tuples=True)
checks = lua.execute((root / 'tools/migration/check-match-actions.lua').read_text(encoding='utf-8'))
production = ['combat/MatchActions.lua', 'ui/MatchHud.lua', 'ui/MatchSpectator.lua', 'ui/PauseMenu.lua',
              'app/TrialSession.lua', 'app/HangarApp.lua', 'controls/ChaseCamera.lua', 'ui/TouchDriveControls.lua']
for name in production:
    lua.execute('assert(loadfile(...))', str(root / 'scripts' / name))
report = {'result': 'PASS', 'sourceCommit': baseline['commit'], 'sourceHashes': hashes,
          'checks': list(checks.values()), 'runtime': lua.lua_implementation,
          'productionHashes': {n: hashlib.sha256((root / 'scripts' / n).read_bytes()).hexdigest() for n in production},
          'boundary': 'Actual MatchActions Lua with dialog/storage stubs, source spectator numeric formulas; syntax checked integration. Web input/rendering and natural death/rematch still require runtime verification.'}
out = root / 'docs/migration/evidence/match-actions-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'evidence': str(out)}))

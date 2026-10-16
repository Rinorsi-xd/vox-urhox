"""Execute frozen H5 callbacks and actual Lua extraction/toast consumers."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node', 'tools/migration/check-g5-extraction-source.cjs'], check=True)
fixtures = json.loads((root / '.tmp/source-g5-extraction-fixtures.json').read_text(encoding='utf-8'))
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)

def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value

files = ['scripts/app/EndlessSession.lua', 'scripts/ui/SourceToasts.lua', 'scripts/salvage/RunRules.lua',
         'scripts/salvage/Run.lua', 'scripts/salvage/Cinematics.lua', 'scripts/salvage/CineMotion.lua',
         'scripts/ui/SalvageRunHud.lua']
hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
lua.globals().resources = table({name: json.loads((root / 'assets' / name).read_text(encoding='utf-8'))
                               for name in ['UI/Outgame.json', 'Salvage/RunData.json']})
lua.globals().fixtures = table(fixtures)
checks = lua.execute((root / 'tools/migration/check-g5-extraction.lua').read_text(encoding='utf-8'))
assert hashes == {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
report = {'result': 'PASS', 'sourceCommit': fixtures['commit'], 'sourceHashes': fixtures['sourceHashes'],
          'productionHashes': hashes, 'runtime': lua.lua_implementation,
          'checks': [checks[i] for i in range(1, len(checks)+1)],
          'sourceCases': len(fixtures['cases']), 'sourceFrames': sum(len(c['frames']) for c in fixtures['cases']),
          'sourceShots': len(fixtures['shots']), 'sourceLayering': fixtures['layering'],
          'sourceRespawnEntries': len(fixtures['gates']),
          'boundary': 'Actual frozen JS Run.update/Cine.approach/_approachStep/Loot.onEvent versus production Lua rules/event consumers/cinematic motion/SourceToasts. Engine vectors, UI, FX, physics and audio are adapters. No GPU, natural extraction/death, account, visual or performance acceptance. Frozen source also layers toasts above endless banners; no relocation.'}
out = root / 'docs/migration/evidence/g5-extraction-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'evidence': str(out)}))

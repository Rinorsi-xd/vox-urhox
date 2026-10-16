"""Run frozen original editor sound branches and actual Lua command/UI consumers."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node', 'tools/migration/check-build-sounds-source.mjs'], check=True)
source = json.loads((root / '.tmp/build-sounds-source.json').read_text(encoding='utf-8'))
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)

def table(v):
    if isinstance(v, dict):
        return lua.table_from({k: table(i) for k, i in v.items()})
    if isinstance(v, list):
        return lua.table_from([table(i) for i in v])
    return v

resources = {}
def read_resource(name):
    if name not in resources:
        resources[name] = table(json.loads((root / 'assets' / name).read_text(encoding='utf-8-sig')))
    return resources[name]

def native(v):
    if hasattr(v, 'items'):
        items = dict(v.items())
        if all(isinstance(k, int) for k in items):
            return [native(items[k]) for k in sorted(items)]
        return {k: native(i) for k, i in items.items()}
    return v

lua.globals().READ_RESOURCE = read_resource
lua.globals().PY_ENCODE = lambda v: json.dumps(native(v), sort_keys=True, separators=(',', ':'))
lua.globals().PY_DECODE = lambda v: table(json.loads(v))
lua.execute('cjson={null={},encode=PY_ENCODE,decode=PY_DECODE}')
lua.globals().fixtures = table(source)
checks = lua.execute((root / 'tools/migration/check-build-sounds.lua').read_text(encoding='utf-8'))
files = ['scripts/audio/UiSound.lua', 'scripts/construction/BuildEditor.lua', 'scripts/construction/BuildStretch.lua',
         'scripts/construction/LiverySession.lua', 'scripts/ui/InventoryPanel.lua', 'scripts/app/BuildSession.lua',
         'scripts/ui/BlueprintLibrary.lua', 'scripts/app/HangarApp.lua', 'scripts/ui/LiveryPage.lua', 'assets/UI/Sounds.json']
config = json.loads((root / 'assets/UI/Sounds.json').read_text(encoding='utf-8'))
files += ['assets/'+v['path'] for v in config['cues'].values()]
report = {'result': 'PASS', 'checks': checks, 'sourceCommit': source['commit'], 'sourceHashes': source['sourceHashes'],
          'sourceCases': len(source['cases']), 'sourceSaves': len(source['saves']), 'sourceInventory': len(source['inventory']),
          'sourceLivery': len(source['livery']), 'productionHashes': {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in files},
          'boundary': 'Frozen actual JS Editor/Blueprint operation methods, Inventory.toggle, Livery place/remove, async Editor.save. Actual Lua BuildEditor/Blueprint/History/Stretch/Livery and InventoryPanel/BuildSession/BlueprintLibrary callbacks; UI, renderer, persistence and sound device adapted. No native/Web listening, visual or performance acceptance; increment after e31.'}
(root / 'docs/migration/evidence/build-sounds-offline.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))

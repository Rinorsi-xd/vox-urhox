"""Execute frozen original selection commands and actual Lua domain/UI consumers."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node', 'tools/migration/check-selection-bar-source.mjs'], check=True)
source = json.loads((root / '.tmp/selection-bar-source.json').read_text(encoding='utf-8'))
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)

def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value

resources = {}
def read_resource(name):
    if name not in resources:
        resources[name] = table(json.loads((root / 'assets' / name).read_text(encoding='utf-8-sig')))
    return resources[name]

lua.globals().READ_RESOURCE = read_resource
lua.globals().SOURCE = table(source)
checks = lua.execute((root / 'tools/migration/check-selection-bar.lua').read_text(encoding='utf-8'))
files = ['scripts/construction/BuildEditor.lua', 'scripts/app/BuildSession.lua', 'scripts/ui/BuildHud.lua',
         'scripts/ui/SourceSelectionBar.lua', 'scripts/ui/BuildHover.lua']
report = {'result': 'PASS', 'checks': checks, 'sourceCommit': source['commit'], 'sourceHashes': source['sourceHashes'],
          'sourcePaintCases': len(source['cases']), 'sourceActions': len(source['actions']), 'sourceVisibilityCases': len(source['bars']),
          'productionHashes': {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in files},
          'boundary': 'Frozen actual JS Editor.paintSelection/undo/redo and selectionAction executed; original UI._selBar executed with DOM edges adapted. Actual Lua Blueprint/History/Editor/PaintSelection, BuildSession actions, actual SourceSelectionBar tree/callback/visibility/layout/animation. Native UI layout/render and SourceFonts OS resolution adapted; no GPU/Web screenshot, visual 1:1, touch-runtime or performance acceptance.'}
(root / 'docs/migration/evidence/selection-bar-offline.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))

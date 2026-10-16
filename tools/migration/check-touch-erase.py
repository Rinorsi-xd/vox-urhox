"""Compare actual frozen H5 erase contact lifecycle with production Lua, no GPU."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node', 'tools/migration/check-touch-erase-source.mjs'], check=True)
source = json.loads((root / '.tmp/touch-erase-source.json').read_text(encoding='utf-8'))
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)

def table(value):
    if isinstance(value, dict):
        return lua.table_from({key: table(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(item) for item in value])
    return value

resources = {}
def read_resource(name):
    if name not in resources:
        resources[name] = table(json.loads((root / 'assets' / name).read_text(encoding='utf-8-sig')))
    return resources[name]

files = ['scripts/controls/BuildInput.lua', 'scripts/ui/TouchBuildControls.lua',
         'scripts/controls/TouchGestures.lua', 'scripts/ui/TouchEditorLayout.lua', 'scripts/construction/BuildEditor.lua', 'scripts/app/BuildSession.lua']
hashes = lambda: {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
before = hashes()
lua.globals().READ_RESOURCE = read_resource
lua.globals().SOURCE = table(source)
session_source = (root / 'scripts/app/BuildSession.lua').read_text(encoding='utf-8')
escape_body = session_source[session_source.index('function M:Escape()'):session_source.index('function M:Trace(')]
assert "not self.buildCamera.touch and (self.buildCamera.captured or self.buildCamera.pending)" in escape_body
lua.globals().OLD_ESCAPE_BODY = escape_body.replace('not self.buildCamera.touch and (self.buildCamera.captured or self.buildCamera.pending)', 'self.buildCamera.captured or self.buildCamera.pending')
checks = lua.execute((root / 'tools/migration/check-touch-erase.lua').read_text(encoding='utf-8'))
assert hashes() == before, 'Production changed during check'
report = {'result': 'PASS', 'checks': checks, 'sourceCommit': source['commit'], 'sourceHashes': source['sourceHashes'],
          'sourceCases': len(source['cases']), 'sourceEscapeCases': len(source['escapeCases']), 'oldTouchEscapeReproduced': True,
          'sourceLimits': source['sourceLimits'], 'productionHashes': before,
          'boundary': 'Actual H5 TouchControls.hold, Editor pointerdown/pointerup/remove/selection/history and _key Escape plus extracted hold update statements with shared controlled performance clock; drawing/device edges adapted. Actual Lua Blueprint/Editor/BuildInput, TouchBuildControls bound erase contacts, TouchGestures and BuildSession.Escape. Cancellation retains target no-mutation policy; no GPU/Web/phone visual or performance acceptance.'}
(root / 'docs/migration/evidence/touch-erase-offline.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))

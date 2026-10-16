"""Frozen source keyboard contract and actual Lua UI dispatcher/Hud.Update, no GPU."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
baseline = json.loads((root / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
source_files = ['shared/ui/home.js', 'shared/ui/shell.js']
source_hashes = {}
for name in source_files:
    source_hashes[name] = sha(Path(baseline['snapshot']) / name)
    assert source_hashes[name] == baseline['files'][name]['sha256']
source = json.loads(subprocess.check_output(['node', 'tools/migration/check-button-keyboard-source.cjs'], text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
widget = (root / 'urhox-libs/UI/Core/Widget.lua').read_text(encoding='utf-8')
ui = (root / 'urhox-libs/UI/Core/UI.lua').read_text(encoding='utf-8')
lua.globals().ENGINE_EXTEND = re.search(r'function Widget:Extend\(name\).*?\nend', widget, re.S).group()
lua.globals().ENGINE_NEW = re.search(r'function Widget:new\(props\).*?\nend', widget, re.S).group()
lua.globals().ENGINE_SETTERS = re.search(r'local function buildSetterMap\(class\).*?\nend', widget, re.S).group()
lua.globals().ENGINE_FOCUS = '\n'.join(re.search(r'function Widget:'+name+r'\(\).*?\nend', widget, re.S).group() for name in ['OnFocus', 'OnBlur'])
lua.globals().ENGINE_HANDLERS = '\n'.join(re.search(r'function UI\.'+name+r'\([^\n]*\).*?\nend', ui, re.S).group() for name in ['HandleKeyDown', 'HandleKeyUp', 'SetFocus', 'GetFocus', 'ClearFocus'])
fixture = (root / 'tools/migration/check-button-keyboard.lua').read_text(encoding='utf-8')
result = lua.execute(fixture)
old_lua = LuaRuntime(unpack_returned_tuples=True)
for key in ['ENGINE_EXTEND','ENGINE_NEW','ENGINE_SETTERS','ENGINE_FOCUS','ENGINE_HANDLERS']:
    old_lua.globals()[key] = lua.globals()[key]
old_lua.globals().TEST_ACTION_OVERRIDE = (root / '.tmp/outgame-cached-1792090565231/scripts/ui/ActionButton.lua').read_text(encoding='utf-8')
try:
    old_lua.execute(fixture)
    raise AssertionError('195 keyboard regression did not reproduce')
except Exception as error:
    assert 'Cross-frame consumed key must not start a match' in str(error), str(error)
    old_failure = 'Cross-frame consumed key must not start a match after focused button changes tab'
production = ['scripts/ui/ActionButton.lua', 'scripts/ui/GarageHud.lua']
engine = ['urhox-libs/UI/Core/Widget.lua', 'urhox-libs/UI/Core/UI.lua', 'urhox-libs/UI/Core/PointerEvent.lua', 'urhox-libs/UI/Widgets/Button.lua']
report = {'result': 'PASS', 'checks': result['checks']+source['checks'], 'luaChecks': result['checks'], 'sourceChecks': source['checks'],
          'old195CrossFrameFailureReproduced': old_failure,
          'sourceCommit': baseline['commit'], 'sourceHashes': source_hashes,
          'productionHashes': {name: sha(root / name) for name in production},
          'engineReferenceHashes': {name: sha(root / name) for name in engine},
          'boundary': 'Actual frozen home keydown listener and Shell._key executed in Node with explicit DOM default-activation adapter; actual complete engine Button and PointerEvent plus extracted real Widget.Extend/new/property routing/setter-map/OnFocus/OnBlur/UI key and focus dispatch; actual production ActionButton and GarageHud.Update executed. Test descendant only replaces native Init and Yoga allocation; layout, window focus notification and browser-generated key repeats are adapted; actual Web regression remains required. No GPU or performance acceptance.'}
out = root / 'docs/migration/evidence/button-keyboard-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': report['checks'], 'luaChecks': result['checks'], 'sourceChecks': source['checks']}, indent=2))

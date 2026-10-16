"""Check frozen JS UI hooks, original bytes and real Lua UI sound ownership."""
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node', 'tools/migration/check-ui-sounds-source.cjs'], check=True)
source = json.loads((root / '.tmp/ui-sounds-source.json').read_text(encoding='utf-8'))
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)

def table(v):
    if isinstance(v, dict):
        return lua.table_from({k: table(i) for k, i in v.items()})
    if isinstance(v, list):
        return lua.table_from([table(i) for i in v])
    return v

lua.globals().TEST_SOUND_DATA = table(json.loads((root / 'assets/UI/Sounds.json').read_text(encoding='utf-8')))
lua.globals().TEST_SOURCE = table(source)
widget_path = root / 'urhox-libs/UI/Core/Widget.lua'
widget = widget_path.read_text(encoding='utf-8')
lua.globals().ENGINE_EXTEND = re.search(r'function Widget:Extend\(name\).*?\nend', widget, re.S).group()
lua.globals().ENGINE_WIDGET_NEW = re.search(r'function Widget:new\(props\).*?\nend', widget, re.S).group()
checks = lua.execute((root / 'tools/migration/check-ui-sounds.lua').read_text(encoding='utf-8'))
files = ['scripts/audio/UiSound.lua', 'scripts/app/HangarApp.lua', 'scripts/story/Tutorial.lua',
         'scripts/ui/TutorialPage.lua', 'assets/UI/Sounds.json']
files += ['assets/'+v['path'] for v in json.loads((root / 'assets/UI/Sounds.json').read_text(encoding='utf-8'))['cues'].values()]
report = {'result': 'PASS', 'checks': checks, 'sourceCommit': source['commit'], 'sourceHashes': source['sourceHashes'],
          'engineReferenceHashes': {'urhox-libs/UI/Core/Widget.lua': hashlib.sha256(widget_path.read_bytes()).hexdigest()},
          'productionHashes': {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in files},
          'boundary': 'Actual frozen shell pointerdown/ Tutorial Advance and Update methods executed. Actual Lua UiSound and AudioLevels; scene, download/cache and hit-test edges adapted. Original WAV bytes verified. No runtime native/Web listening or mobile/performance acceptance.'}
(root / 'docs/migration/evidence/ui-sounds-offline.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))

"""Exercise actual Widget routing and production portrait ownership without a GPU."""
import hashlib
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
paths = ['scripts/ui/CommsPortrait.lua', 'scripts/ui/CommsCard.lua',
         'scripts/ui/IntroPage.lua', 'scripts/app/OpeningHost.lua',
         'scripts/audio/StoryComms.lua', 'scripts/story/Tutorial.lua',
         'scripts/app/ResourceGate.lua']
hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
lua = LuaRuntime(unpack_returned_tuples=True)
widget = (ROOT / 'urhox-libs/UI/Core/Widget.lua').read_text(encoding='utf-8')
for key, pattern in [('ENGINE_EXTEND', r'function Widget:Extend\(name\).*?\nend'),
                     ('ENGINE_NEW', r'function Widget:new\(props\).*?\nend'),
                     ('ENGINE_SETTERS', r'local function buildSetterMap\(class\).*?\nend')]:
    lua.globals()[key] = re.search(pattern, widget, re.S).group()
result = lua.execute((ROOT / 'tools/migration/check-intro-portrait-handoff.lua').read_text(encoding='utf-8'))
assert hashes == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
report = {'result': 'PASS', 'checks': result['count'], 'productionHashes': hashes,
          'cases': [result['checks'][i] for i in range(1, result['count'] + 1)],
          'boundary': 'Actual production portrait construction/prepare/draw/dispose, card adoption, page close, OpeningHost Begin/ownership guards, tutorial Prepare, ResourceGate and StoryComms Shutdown; actual engine Widget Extend/new/setter routing. Native graphics/download/resource boundaries are controlled doubles. No GPU rendering, memory peak, Web OOM, audio continuity or mobile performance acceptance.'}
out = ROOT / 'docs/migration/evidence/intro-portrait-handoff-offline.json'
out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': report['checks'], 'evidence': str(out)}))

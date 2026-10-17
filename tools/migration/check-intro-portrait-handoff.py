"""Exercise actual Widget routing and production portrait ownership without a GPU."""
import hashlib
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
try:
    from lupa.lua54 import LuaRuntime
except ImportError as error:
    raise SystemExit('Lua 5.4 test dependency missing. Install lupa==2.8 in this Python environment or provide it through PYTHONPATH.') from error

os.chdir(ROOT)
paths = ['scripts/ui/CommsPortrait.lua', 'scripts/ui/CommsCard.lua',
         'scripts/ui/IntroPage.lua', 'scripts/app/OpeningHost.lua',
         'scripts/audio/StoryComms.lua', 'scripts/story/Tutorial.lua',
         'scripts/app/ResourceGate.lua', 'scripts/core/ResourceData.lua',
         'scripts/story/MissionData.lua', 'scripts/Config.lua']
hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
widget = (ROOT / 'urhox-libs/UI/Core/Widget.lua').read_text(encoding='utf-8')
engine = {}
for key, pattern in [('ENGINE_EXTEND', r'function Widget:Extend\(name\).*?\nend'),
                     ('ENGINE_NEW', r'function Widget:new\(props\).*?\nend'),
                     ('ENGINE_SETTERS', r'local function buildSetterMap\(class\).*?\nend')]:
    engine[key] = re.search(pattern, widget, re.S).group()
fixture = (ROOT / 'tools/migration/check-intro-portrait-handoff.lua').read_text(encoding='utf-8')
resource_paths = set()


def read_resource(path):
    resource_paths.add(path)
    return (ROOT / 'assets' / path).read_text(encoding='utf-8')


def run(overrides=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    for key, source in engine.items():
        lua.globals()[key] = source
    lua.globals().PRODUCTION_OVERRIDES = lua.table_from(overrides or {})
    lua.globals().READ_RESOURCE = read_resource
    lua.globals().cjson = lua.table_from({'decode': lambda text: lua.table_from(json.loads(text), recursive=True)})
    lua.globals().print = lambda *args: None
    return lua.execute(fixture)


result = run()
card = (ROOT / 'scripts/ui/CommsCard.lua').read_text(encoding='utf-8')
host = (ROOT / 'scripts/app/OpeningHost.lua').read_text(encoding='utf-8')
page = (ROOT / 'scripts/ui/IntroPage.lua').read_text(encoding='utf-8')
controls = [
    ('missing adopted presentation reset', 'ui.CommsCard', card,
     '    portrait:ResetPresentation()\n    local previous=', '    local previous=', 'logical card dimensions restored'),
    ('unsigned opening accepts ownership', 'app.OpeningHost', host,
     'or not I.signed or I.failed', 'or I.failed', 'unsigned host/card explicitly refuses ownership'),
    ('transferred portrait disposed by page', 'ui.IntroPage', page,
     'if take and take(self.owner,self.portrait,Images.GetContext()) then self.portrait=nil',
     'if take and take(self.owner,self.portrait,Images.GetContext()) then self.portrait:Dispose();self.portrait=nil',
     'actual Widget page close transfers sole ownership'),
]
negative = []
for label, name, original, before, after, expected in controls:
    assert original.count(before) == 1, label
    try:
        run({name: original.replace(before, after)})
    except Exception as error:
        assert expected in str(error), f'{label} rejected for an unrelated reason: {error}'
        negative.append({'name': label, 'rejected': True, 'assertion': expected})
    else:
        raise AssertionError('Negative control survived: ' + label)
assert hashes == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
report = {'result': 'PASS', 'checks': result['count'], 'productionHashes': hashes,
          'negativeControls': negative,
          'engineWidgetSha256': hashlib.sha256(widget.encode('utf-8')).hexdigest(),
          'fixtureSha256': hashlib.sha256(fixture.encode('utf-8')).hexdigest(),
          'resourceHashes': {p: hashlib.sha256((ROOT / 'assets' / p).read_bytes()).hexdigest() for p in sorted(resource_paths)},
          'cases': [result['checks'][i] for i in range(1, result['count'] + 1)],
          'boundary': 'Actual production portrait construction/prepare/draw/dispose, card adoption, page close, OpeningHost Begin/ownership guards, tutorial Prepare, ResourceGate and StoryComms Shutdown; actual engine Widget Extend/new/setter routing. Native graphics/download/resource boundaries are controlled doubles. No GPU rendering, memory peak, Web OOM, audio continuity or mobile performance acceptance.'}
out = ROOT / 'docs/migration/evidence/intro-portrait-handoff-offline.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': report['checks'], 'negativeControls': len(negative), 'evidence': str(out)}))

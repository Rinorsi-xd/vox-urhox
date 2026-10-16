"""Exercise production Promo/Payslip/Film drawing order without a GPU."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

SOURCE = ROOT / '.tmp/outgame-source-2026-10-15T12-35-57-243Z'
css = (SOURCE / 'shared/css/intro.css').read_text(encoding='utf-8')
assert '#intro .ly { position: absolute; inset: 0; pointer-events: none; }' in css
assert '#intro .in-panels { background: transparent; }' in css
assert '#intro .lockon { position: absolute; z-index: 8;' in css
assert '#intro .zap { position: absolute;' in css and 'z-index: 9;' in css
lua = LuaRuntime(unpack_returned_tuples=True)

def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value

lua.globals().GLYPHS = convert(json.loads((ROOT / 'assets/Intro/Fonts/TitleGlyphs.json').read_text(encoding='utf-8')))
lua.execute('''
package.path='scripts/?.lua;'..package.path
EVENTS={};DEPTH=0
function Record(name,...) EVENTS[#EVENTS+1]={name=name,args={...}} end
package.loaded['core.ResourceData']={Read=function()return GLYPHS end}
package.loaded['ui.SourceDraw']={
 Color=function(c)return c end,
 Width=function(_,text,size,_,spacing)return utf8.len(text)*(size*.6+(spacing or 0))end,
 Text=function(...)Record('text',...)end,Rect=function(...)Record('rect',...)end,
 Line=function(...)Record('line',...)end,Path=function()end,Gradient=function()end}
package.loaded['ui.SourceParagraph']={New=function()return {
 Measure=function()return {height=20}end,Draw=function()Record('caption')end}end}
package.loaded['ui.IntroTypography']={face='game',Begin=function()end}
package.loaded['ui.IntroPage']={Image=function()end}
NVG_SOLID=1;NVG_HOLE=2;NVG_IMAGE_REPEATX=1;NVG_IMAGE_REPEATY=2
NVG_ALIGN_RIGHT=2
for _,name in ipairs({'nvgBeginPath','nvgRect','nvgCircle','nvgPathWinding','nvgFillColor','nvgFillPaint','nvgFill','nvgRoundedRect','nvgIntersectScissor','nvgRotate','nvgScale','nvgGlobalAlpha','nvgMoveTo','nvgLineTo','nvgBezierTo','nvgClosePath','nvgStrokeColor','nvgStrokeWidth','nvgStroke'})do
 _G[name]=function()end
end
function nvgTranslate(...)Record('translate',...)end
function nvgSave()DEPTH=DEPTH+1 end
function nvgRestore()DEPTH=DEPTH-1;assert(DEPTH>=0)end
function nvgRGBA(...)return {...}end
function nvgRadialGradient()return {}end
function nvgLinearGradient()return {}end
function nvgImagePatternTinted()return {}end
function nvgCreateImage()return 1 end
PROMO=require 'ui.IntroPromo'
PAYSLIP=require 'ui.IntroPayslip'
''')

def draw(module, width, height, age, wrecked):
    owner = convert({'shot': 'payslip', 'age': age, 'time': 100 + age,
                     'voiceDuration': 5.86, 'wrecked': wrecked,
                     'data': {'images': {}}, 'caption': 'approved caption',
                     'log': [{'shot': 'idyll', 't': 0}, {'shot': 'galaxy', 't': 1}]})
    lua.execute('EVENTS={};DEPTH=0')
    module.Draw(convert({'owner': owner, 'k': 1}), 0, width, height, height / 100)
    assert lua.globals().DEPTH == 0
    return list(lua.globals().EVENTS.values())

def inspect(events, width, height):
    bars, labels, lasers = [], [], []
    for index, event in enumerate(events):
        args = event['args']
        if event['name'] == 'rect' and args[2] == 0 and args[4] == width and abs(args[5] - height * .085) < 1e-6:
            bars.append(index)
        if event['name'] == 'text' and str(args[2]).startswith(('锁定中 ', '已锁定 ·')):
            labels.append(index)
        if event['name'] == 'translate' and args[2] == width + 40:
            lasers.append(index)
    return bars, labels, lasers

old_root = ROOT / '.tmp/outgame-cached-1792106681145/scripts/ui'
old_payslip = lua.execute((old_root / 'IntroPayslip.lua').read_text(encoding='utf-8'))
old_promo = lua.execute((old_root / 'IntroPromo.lua').read_text(encoding='utf-8'))
lua.globals().package.loaded['ui.IntroPayslip'] = old_payslip
old_events = draw(old_promo, 1600, 900, 2, True)
old_bars, old_labels, _ = inspect(old_events, 1600, 900)
assert len(old_bars) == 2 and len(old_labels) == 1 and old_labels[0] < old_bars[0]
lua.globals().package.loaded['ui.IntroPayslip'] = lua.globals().PAYSLIP

checks = 5
cases = []
for width, height in [(1600, 900), (2400, 1080), (1440, 1080)]:
    for wrecked in [False, True]:
        for age in [.8, 2, 4.2, 4.6, 4.66, 5]:
            events = draw(lua.globals().PROMO, width, height, age, wrecked)
            bars, labels, lasers = inspect(events, width, height)
            assert len(bars) == 2
            assert len(labels) == (1 if age < 4.65 else 0)
            assert all(index > max(bars) for index in labels)
            assert len(lasers) == (1 if 4.56 <= age < 4.98 else 0)
            assert all(index > max(bars) for index in lasers)
            assert not (labels and lasers) or lasers[0] > labels[0]
            assert sum(event['name'] == 'caption' for event in events) == 1
            checks += 8
            cases.append({'viewport': [width, height], 'wrecked': wrecked, 'age': age,
                          'bars': bars, 'lockText': labels, 'laser': lasers})

paths = ['scripts/ui/IntroPayslip.lua', 'scripts/ui/IntroPromo.lua', 'scripts/ui/IntroFilm.lua',
         'tools/migration/check-intro-payslip-layers.py']
report = {'result': 'PASS', 'checks': checks, 'cases': cases,
          'sourceCommit': 'b276064942ae09c0227ec28d4cfda1d5ff006455',
          'old749ReproducedLabelBeforeBars': True,
          'productionHashes': {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in paths},
          'boundary': 'Actual production Promo/Payslip/Film Lua calls with drawing adapters; old package negative control. No GPU, browser visual parity, frame timing or audio acceptance.'}
output = ROOT / 'docs/migration/evidence/intro-payslip-layers-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': checks, 'cases': len(cases),
                  'productionHashes': report['productionHashes']}, indent=2))

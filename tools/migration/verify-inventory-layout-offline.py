"""Real Lua layout with imported font advances; frozen CSS and viewport fixtures."""
import hashlib
import json
import math
import os
from pathlib import Path
import sys
import subprocess

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
sys.path.insert(0, str(ROOT / '.tmp/font-tooling'))
from lupa.lua54 import LuaRuntime
from fontTools.ttLib import TTFont

os.chdir(ROOT)
baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
source = ROOT / '.tmp/outgame-source-2026-10-15T12-35-57-243Z'
css = (source / 'shared/css/new-ui-inventory.css').read_text(encoding='utf-8')
home = (source / 'shared/ui/homeScale.js').read_text(encoding='utf-8')
assert 'grid-template-columns: 15px minmax(54px, 1fr) minmax(0, 1.6fr)' in css
assert 'export const COMPACT_H = 600;' in home
assert "'(pointer: coarse)'" in home and 'navigator.maxTouchPoints > 0' in home
assert 'Math.min( screen.width, screen.height ) <= 600' in home

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items() if item is not None})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value

font = TTFont(ROOT / 'assets/Fonts/VoxIndustrial-Bold.otf')
units = font['head'].unitsPerEm
cmap = font.getBestCmap()
lua.globals().BODY_ADVANCES = convert({chr(cp): font['hmtx'][glyph][0] / units for cp, glyph in cmap.items()})
lua.globals().BODY_ASCENT = font['hhea'].ascent / units
lua.globals().BODY_DESCENT = -font['hhea'].descent / units
lua.globals().FONT_DATA = convert(json.loads((ROOT / 'assets/UI/SourceFontMetrics.json').read_text(encoding='utf-8')))
lua.execute('''
package.preload['core.ResourceData']=function() return {Read=function() return FONT_DATA end} end
package.preload['ui.SourceFonts']=function() return {GetBodyFace=function() return {
    fractional=true,ascent=BODY_ASCENT,descent=BODY_DESCENT,units=1,kern={},
    GetAdvance=function(_,char) return BODY_ADVANCES[char] end,
} end} end
local Typography=require 'ui.SourceTextLayout'
DRAW={}
package.preload['ui.SourceDraw']=function() return {
    white={237,246,255,255},HasBodyAdvances=function() return true end,
    Advance=function(_,text,size,font,spacing)
        local layout=assert(Typography.Get(text,font),'fixture missing font glyph '..text)
        return Typography.Advance(layout,size,spacing)
    end,
    FontMetrics=function(_,size,font) return Typography.Metrics(font,size) end,
    Text=function(_,text,x,y,size,color,font,align,spacing,baseline)
        DRAW[#DRAW+1]={text=text,x=x,y=y,size=size,font=font,baseline=baseline}
    end,
} end
LAYOUT=require 'ui.InventoryDetailLayout'
''')
checks = 4
fixtures = []
for width, expected_label, expected_value in [(272, 92.6875, 148.3125), (201, 65.375, 104.625)]:
    row = lua.globals().LAYOUT.Row(0, convert(['bolt', '满蓄力全段基础伤害', '800 × 6 段 = 4800']), width)
    assert row['labelWidth'] == expected_label
    assert row['valueWidth'] == expected_value
    assert len(row['label']['lines']) == 2
    assert row['label']['height'] == 28
    assert row['height'] == max(15, row['label']['height'], row['value']['height']) + 19
    checks += 5
    lua.globals().DRAW = lua.table()
    lua.globals().LAYOUT.Draw(0, row['value'], 31 + expected_label, 9, expected_value, True)
    for _, command in lua.globals().DRAW.items():
        assert command['baseline'] is True
        text_layout = lua.eval("require('ui.SourceTextLayout').Get")(command['text'], command['font'])
        advance = lua.eval("require('ui.SourceTextLayout').Advance")(text_layout, command['size'], 0)
        assert command['x'] + advance <= width + 1e-8
        checks += 2
    description = lua.globals().LAYOUT.Description(0, '测试 English words together，不应拆开单词。', width)
    assert description['height'] == len(description['lines']) * 20.390625
    checks += 1
    fixtures.append({'width': width, 'labelWidth': row['labelWidth'], 'valueWidth': row['valueWidth'],
                     'labelLines': len(row['label']['lines']), 'valueLines': len(row['value']['lines']), 'height': row['height']})
    long_row = lua.globals().LAYOUT.Row(0, convert(['bolt', '持续钻削伤害', '连续命中 999999999999999999999999999999999999999999999999 点伤害']), width)
    assert len(long_row['value']['lines']) > 1
    for _, line in long_row['value']['lines'].items():
        assert line['width'] <= long_row['valueWidth']
        checks += 1
    assert long_row['height'] == max(long_row['label']['height'], long_row['value']['height'], 15) + 19
    checks += 2

# Execute the production policy in a fresh module for every device. Resize must
# change scale but retain the boot-time compact classification, like the source.
lua.execute('''
CASE={};SCALE_CALLS=0
graphics={GetWidth=function() return CASE.w end,GetHeight=function() return CASE.h end,GetDPR=function() return CASE.dpr end}
input={GetNumTouches=function() return CASE.touches or 0 end}
GetPlatform=function() return CASE.platform end
GetNativePlatform=function() return CASE.native or CASE.platform end
GetArguments=function() return CASE.args or {} end
package.preload['urhox-libs.Platform.PlatformUtils']=function() return {
    IsMobilePlatform=function() return CASE.platform=='Android' or CASE.platform=='iOS' or CASE.platform=='HarmonyOS' end,
} end
package.preload['urhox-libs/UI']=function() return {Scale={
    DPR=function() return CASE.dpr end,
    DESIGN_RESOLUTION=function(w,h) return function() return math.min(CASE.w/w,CASE.h/h) end end,
},SetScale=function(fn) SCALE_CALLS=SCALE_CALLS+1;CURRENT_SCALE=fn() end} end
function Device(case)
    CASE=case;input.touchEmulation=case.emulation or false
    package.loaded['controls.TouchMode']=nil
    local policy=require 'controls.TouchMode';return policy
end
''')
devices = [
    ('pc1920', 1920, 1080, 1, 'Windows', None, False, [], 1080),
    ('pc1440', 1440, 810, 1, 'Windows', None, False, [], 1080),
    ('pc-small-web', 840, 378, 3, 'Web', 'Windows', False, [], 1080),
    ('touch20x9', 840, 378, 3, 'Web', 'Android', False, [], 600),
    ('emulated20x9', 840, 378, 3, 'Web', 'Windows', True, [], 600),
    ('native-touch', 840, 378, 3, 'Android', None, False, [], 600),
    ('large-tablet', 1280, 800, 2, 'Web', 'Android', False, [], 1080),
    ('forced-compact', 1920, 1080, 1, 'Windows', None, False, ['-compact=1'], 600),
    ('forced-desktop', 840, 378, 3, 'Web', 'Android', False, ['-compact=0'], 1080),
    ('touch-debug', 840, 378, 3, 'Windows', None, False, ['-touch'], 600),
]
device_report = []
old_policy = subprocess.check_output(['git','show','HEAD:scripts/controls/TouchMode.lua'],encoding='utf-8')
lua.globals().OLD_POLICY = old_policy
for name, w, h, dpr, platform, native, emulation, args, reference in devices:
    case = convert({'w':w*dpr, 'h':h*dpr, 'dpr':dpr, 'platform':platform, 'native':native, 'emulation':emulation, 'args':args})
    policy = lua.globals().Device(case)
    old = lua.execute('return assert(load(OLD_POLICY))()')
    assert policy.Scale('drive')() == old.Scale('drive')()
    checks += 1
    assert policy.Compact() is (reference == 600)
    for surface in ['home', 'build']:
        scale = policy.Scale(surface)()
        expected = min(w / (reference * 16/9), h / reference) * dpr
        assert math.isclose(scale, expected)
        checks += 1
    policy.Apply('build')
    before = lua.globals().SCALE_CALLS
    policy.Update('build')
    assert lua.globals().SCALE_CALLS == before
    checks += 2
    case['w'], case['h'] = 1650, 930
    policy.Update('build')
    assert policy.Compact() is (reference == 600)
    assert lua.globals().SCALE_CALLS == before + 1
    checks += 2
    device_report.append({'case':name,'referenceHeight':reference,'initialPhysicalScale':expected})

paths = ['scripts/controls/TouchMode.lua', 'scripts/ui/InventoryDetail.lua', 'scripts/ui/InventoryDetailLayout.lua',
         'scripts/ui/InventoryPanel.lua', 'scripts/ui/InventoryChrome.lua']
for path in paths:
    lua.execute('assert(loadfile(...))', str(ROOT / path))
    checks += 1
report = {'result':'PASSED', 'assertions':checks, 'baseline':baseline['commit'], 'lua':lua.eval('_VERSION'),
          'rows':fixtures,'devices':device_report,
          'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
          'source':{p:hashlib.sha256((source/p).read_bytes()).hexdigest() for p in ['shared/ui/homeScale.js','shared/css/new-ui-inventory.css','shared/css/new-ui-responsive.css']},
          'boundary':'Actual Lua layout and scale with real bundled source font advances. No GPU/browser/native/real-phone acceptance. Web uses GetNativePlatform/touchEmulation and initial CSS viewport because screen/pointer media queries are not exposed; screen-versus-viewport device classification needs runtime verification.'}
output = ROOT / 'docs/migration/evidence/inventory-layout-offline.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))

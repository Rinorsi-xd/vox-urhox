"""Execute production Lua draw branches against current frozen source CSS."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
import tinycss2

baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
assert baseline['commit'] == 'b276064942ae09c0227ec28d4cfda1d5ff006455'
css_name = 'shared/css/mobile-editor.css'
css_bytes = (Path(baseline['snapshot']) / css_name).read_bytes()
assert hashlib.sha256(css_bytes).hexdigest() == baseline['files'][css_name]['sha256']
rules = {}
for rule in tinycss2.parse_stylesheet(css_bytes.decode('utf-8'), skip_whitespace=True, skip_comments=True):
    if rule.type == 'qualified-rule':
        selector = tinycss2.serialize(rule.prelude).strip()
        rules[selector] = {decl.name: decl.value for decl in tinycss2.parse_declaration_list(rule.content)
                           if decl.type == 'declaration'}


def pixels(tokens):
    out = []
    for token in tokens:
        if token.type == 'dimension' and token.lower_unit == 'px':
            out.append(token.value)
        elif token.type == 'function':
            out.extend(pixels(token.arguments))
    return out


def px(selector, property_name):
    values = pixels(rules[selector][property_name])
    assert len(values) == 1, (selector, property_name, values)
    return values[0]


label_selector = '.me-split .lb'
split_selector = '#touch-controls .me .me-split button'
row_selector = '#touch-controls .me .me-b.row'
source = {
    'labelSize': px(label_selector, 'font-size'),
    'labelPadding': px(label_selector, 'padding'),
    'labelTracking': px(label_selector, 'letter-spacing'),
    'splitSize': px(split_selector, 'font'),
    'splitIcon': px('#touch-controls .me .me-split .ic', 'width'),
    'splitGap': px(split_selector, 'gap'),
    'rowSize': px(row_selector, 'font'),
    'rowIcon': px('#touch-controls .me .ic', 'width'),
    'rowGap': px(row_selector, 'gap'),
}
assert tinycss2.serialize(rules[label_selector]['align-items']).strip() == 'center'

filename = ROOT / 'scripts/ui/TouchEditorWidgets.lua'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
calls={}
local D={}
function D.Text(vg,text,x,y,size,color,font,align,spacing)
    calls.text={text=text,x=x,y=y,size=size,font=font,spacing=spacing}
end
function D.Icon(vg,icon,x,y,size) calls.icon={icon=icon,x=x,y=y,size=size} end
function D.Width(vg,text,size) return utf8.len(text)*size end
setmetatable(D,{__index=function() return function() end end})
local class={Extend=function() return {} end}
local modules={['ui.VoxTheme']={},['urhox-libs/UI']={Panel=class},
    ['ui.SourceDraw']=D,['ui.SourceRelief']={Draw=function() end},['ui.ActionButton']=class}
function require(name) assert(modules[name],name);return modules[name] end
setmetatable(_G,{__index=function(_,name)
    if name:sub(1,3)=='nvg' then return function() end end
end})
function widget(props,rect)
    return {props=props,rect=rect,state={},GetAbsoluteLayout=function(self) return self.rect end}
end
""")
module = lua.execute(filename.read_text(encoding='utf-8'))
layout = lua.execute((ROOT / 'scripts/ui/TouchEditorLayout.lua').read_text(encoding='utf-8'))
checks = 0
samples = []
button_samples = []


def equal(actual, expected):
    global checks
    assert abs(actual - expected) < 1e-7, (actual, expected)
    checks += 1


for scale in [.78, 1, 2.4, 3]:
    rect = lua.table_from({'x': 37, 'y': 19, 'w': 40*scale, 'h': 40*scale})
    props = lua.table_from({'kind': 'label', 'sourceScale': scale, 'text': '\u8f66\u9ad8'})
    module.Surface.Render(lua.globals().widget(props, rect), 42)
    text = lua.globals().calls.text
    equal(text.x, rect.x + source['labelPadding']*scale)
    equal(text.y, rect.y + (rect.h-source['labelSize']*scale)/2)
    equal(text.size, source['labelSize']*scale)
    equal(text.spacing, source['labelTracking']*scale)
    samples.append({'scale': scale, 'label': {'x': text.x, 'y': text.y, 'size': text.size}})
    for icon in ['liftUp', 'liftDown', 'back', 'wheel', 'save']:
        split = icon.startswith('lift')
        font_size = source['splitSize' if split else 'rowSize']
        icon_size = source['splitIcon' if split else 'rowIcon']
        gap = source['splitGap' if split else 'rowGap']
        for narrow in [False, True]:
            # Only back/test/save hide their labels on the source narrow layout.
            hide_label = narrow and not split
            rect = lua.table_from({'x': 0, 'y': 0, 'w': 81*scale, 'h': 40*scale})
            props = lua.table_from({'kind': 'action', 'row': True, 'sourceScale': scale,
                                   'icon': icon, 'text': 'AB', 'narrow': hide_label})
            lua.globals().calls = lua.table()
            module.Button.Render(lua.globals().widget(props, rect), 42)
            drawn = lua.globals().calls
            if scale == 1 and not narrow:
                button_samples.append({'icon': icon, 'iconSize': drawn.icon.size,
                                       'iconX': drawn.icon.x, 'iconY': drawn.icon.y,
                                       'textSize': drawn.text.size, 'textX': drawn.text.x,
                                       'textY': drawn.text.y})
            equal(drawn.icon.size, icon_size)
            equal(drawn.icon.y, (40-icon_size)/2)
            if hide_label:
                assert drawn.text is None
                checks += 1
                equal(drawn.icon.x, (81-icon_size)/2)
            else:
                equal(drawn.text.size, font_size)
                equal(drawn.text.y, (40-font_size)/2)
                equal(drawn.text.x-drawn.icon.x-drawn.icon.size, gap)
                equal((drawn.icon.x+drawn.text.x+2*font_size)/2, 81/2)

for width, height in [(840, 378), (800, 450), (1024, 768), (640, 320)]:
    actual = layout.Calculate(width, height, width, height, lua.table(), 1, False, None)
    if width <= 760:
        assert actual.liftLabel is None
        checks += 1
    else:
        equal(actual.liftLabel.height, 40*actual.s)
        equal(actual.liftLabel.top, actual.buttons['me-liftUp'].top)
    equal(actual.buttons['me-liftUp'].height, 40*actual.s)
    equal(actual.buttons['me-liftDown'].height, 40*actual.s)

negative_controls = []
production_code = filename.read_text(encoding='utf-8')
for name, old, restored in [
    ('old-top-left-label', 'r.x+8*s,r.y+(r.h-10*s)/2', 'r.x,r.y'),
    ('old-generic-lift-metrics', "local split=p.icon=='liftUp' or p.icon=='liftDown'", 'local split=false'),
]:
    assert production_code.count(old) == 1
    candidate = lua.execute(production_code.replace(old, restored))
    lua.globals().calls = lua.table()
    rect = lua.table_from({'x': 37, 'y': 19, 'w': 81, 'h': 40})
    if name == 'old-top-left-label':
        props = lua.table_from({'kind': 'label', 'sourceScale': 1, 'text': 'label'})
        candidate.Surface.Render(lua.globals().widget(props, rect), 42)
        actual = lua.globals().calls.text
        rejected = actual.x != 37+source['labelPadding'] or actual.y != 19+(40-source['labelSize'])/2
    else:
        props = lua.table_from({'kind': 'action', 'row': True, 'sourceScale': 1, 'icon': 'liftUp', 'text': 'AB'})
        candidate.Button.Render(lua.globals().widget(props, rect), 42)
        actual = lua.globals().calls
        rejected = actual.text.size != source['splitSize'] or actual.icon.size != source['splitIcon']
    assert rejected, 'Old behavior incorrectly accepted: '+name
    negative_controls.append({'name': name, 'rejected': True})

report = {'result': 'PASS', 'checks': checks, 'baseline': baseline['commit'],
          'sourceCssSha256': hashlib.sha256(css_bytes).hexdigest(), 'sourceValues': source,
          'productionSha256': hashlib.sha256(filename.read_bytes()).hexdigest(), 'samples': samples,
          'buttonDrawCapture': button_samples, 'negativeControls': negative_controls,
          'boundary': 'Full production Lua Render branches executed with draw-call spies and parsed current source CSS. No engine, browser, font rasterization or new-package visual acceptance.'}
output = ROOT / 'docs/migration/evidence/touch-actionbar-20261017.json'
output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': checks, 'productionSha256': report['productionSha256']}))

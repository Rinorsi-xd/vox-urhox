"""Execute the production detail scroller and real base ScrollView methods."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
source = ROOT / '.tmp/outgame-source-2026-10-15T12-35-57-243Z'
css_paths = ['shared/css/new-ui-inventory.css', 'shared/css/new-ui-responsive.css']
sources = {}
for relative in css_paths:
    raw = (source / relative).read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    assert digest == baseline['files'][relative]['sha256'], relative
    sources[relative] = digest
css = (source / css_paths[0]).read_text(encoding='utf-8')
compact = (source / css_paths[1]).read_text(encoding='utf-8')
assert re.search(r'\.inv-detail\s*\{\s*padding:\s*18px 3px 16px 24px;', css)
assert re.search(r'\.inv-detail\s*\{\s*padding:\s*8px 6px 12px 12px;', compact)

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;?.lua;'..package.path")
lua.execute('''
local Widget={}
function Widget:Extend()
    local cls={};cls.__index=cls
    return setmetatable(cls,{__index=self})
end
package.preload['urhox-libs/UI/Core/Widget']=function() return Widget end
for _,name in ipairs({'Theme','Style','UI','PointerEvent'}) do
    package.preload['urhox-libs/UI/Core/'..name]=function() return {} end
end
BASE=require 'urhox-libs/UI/Widgets/ScrollView'
SCROLL=require 'ui.InventoryDetailScroll'
function Fixture(cls,viewport,top,bottom,height)
    local child={props={},children={}}
    function child:GetLayout() return {x=25,y=top,w=272,h=height} end
    local self=setmetatable({props={bounces=false,scrollY=true,paddingTop=top,paddingBottom=bottom},
        state={scrollX=0,scrollY=0},children={child}},cls)
    function self:GetLayout() return {x=0,y=0,w=310,h=viewport} end
    return self,child
end
''')

checks = 4
cases = []
before = []
for name, viewport, top, bottom in [('pc', 697, 18, 16), ('20x9', 392, 8, 12)]:
    for height in [0, 76, viewport-top-bottom, viewport-top-bottom+1, 1069-top-bottom, 1800.375]:
        expected = max(0, top+height+bottom-viewport)
        old, _ = lua.globals().Fixture(lua.globals().BASE, viewport, top, bottom, height)
        old.UpdateContentSize(old)
        old.ScrollToBottom(old)
        if expected > 0:
            before.append({'case': name, 'height': height, 'old': old.state.scrollY, 'expected': expected,
                           'pass': old.state.scrollY == expected})
            assert old.state.scrollY != expected
            checks += 1
        scroller, child = lua.globals().Fixture(lua.globals().SCROLL, viewport, top, bottom, height)
        for iteration in range(3):
            scroller.UpdateContentSize(scroller)
            assert scroller.contentHeight_ == top+height+bottom
            scroller.ScrollToBottom(scroller)
            assert scroller.state.scrollY == expected
            checks += 2
        # Real inherited wheel/touch/public clamp consumes the corrected extent.
        scroller.SetScroll(scroller, 9999, 9999)
        assert scroller.state.scrollY == expected
        scroller.ScrollBy(scroller, 0, -17)
        assert scroller.state.scrollY == max(0, expected-17)
        scroller.ScrollToTop(scroller)
        assert scroller.state.scrollY == 0
        scroller.SetScroll(scroller, 0, -100)
        assert scroller.state.scrollY == 0
        checks += 4
        cases.append({'case': name, 'viewport': viewport, 'childHeight': height, 'top': top, 'bottom': bottom,
                      'scrollHeight': scroller.contentHeight_, 'maxScroll': expected})

# Verify the actual InventoryPanel restore statements call the corrected extent.
panel = (ROOT / 'scripts/ui/InventoryPanel.lua').read_text(encoding='utf-8')
assert "self.detailScroll=require('ui.InventoryDetailScroll'){" in panel
match = re.search(r'local extent=self.detail.props.height[^\n]+\n\s*self.detailScroll:SetScrollDirect\([^\n]+', panel)
assert match
scroller, _ = lua.globals().Fixture(lua.globals().SCROLL, 392, 8, 12, 1200)
lua.globals().PANEL_SELF = lua.table_from({'detailScroll': scroller, 'centerHeight': 392,
    'detail': lua.table_from({'props': lua.table_from({'height': 1200})})})
for requested in [0, 312, 828, 9999]:
    lua.globals().RESTORE = requested
    lua.execute('local self,state=PANEL_SELF,{detailY=RESTORE};'+match.group(0))
    assert scroller.state.scrollY == min(828, requested)
    checks += 1
# Modal restoration must avoid the transient Yoga viewport (possibly NaN).
lua.execute('PANEL_SELF.detailScroll.GetLayout=function() return {w=0/0,h=0/0} end')
lua.globals().RESTORE = 9999
lua.execute('local self,state=PANEL_SELF,{detailY=RESTORE};'+match.group(0))
assert scroller.state.scrollY == 828
checks += 3
paths = ['scripts/ui/InventoryDetailScroll.lua', 'scripts/ui/InventoryPanel.lua']
for relative in paths:
    lua.execute('assert(loadfile(...))', str(ROOT / relative))
    checks += 1
boundary = ('Actual production detail subclass, complete engine ScrollView module and actual panel restore statements; '
            'widget layout rectangles are measured-coordinate fixtures, no Yoga/NanoVG/browser/GPU execution. '
            'Frozen source CSS values verified by SHA. This closes missing scroll extent only, not full raster/font/wrap parity.')
report = {'result': 'PASS', 'checks': checks, 'baseline': baseline['commit'], 'cases': cases,
          'production': {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
          'source': sources, 'boundary': boundary}
evidence = ROOT / 'docs/migration/evidence'
(evidence / 'inventory-scroll-before.json').write_text(json.dumps({'result': 'FAIL', 'cases': before,
    'boundary': boundary}, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
(evidence / 'inventory-scroll-offline.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))

"""Actual terminal geometry and pointer strokes across landscape viewport changes."""
import hashlib
import json
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
layout = lua.execute((ROOT / 'scripts/ui/IntroContractLayout.lua').read_text(encoding='utf-8'))
checks = []
def check(ok, label):
    assert ok, label
    checks.append(label)

for width, height in [(1920,1080),(1024,768),(1280,800),(840,378),(2560,1080),(1605,388)]:
    p = layout.Plan(width, height)
    u, terminal, pad = p['unit'], p['terminal'], p['pad']
    check(terminal['w'] >= 69.99*u, f'{width}: full readable terminal width')
    for name, box in [('terminal',terminal),('pad',pad)]:
        check(box['x'] >= 0 and box['y'] >= 0 and box['x']+box['w'] <= width and box['y']+box['h'] <= height,
              f'{width}: {name} entirely inside viewport')
    check(pad['x']+3*u >= terminal['x']+terminal['w']-3*u, f'{width}: signature clear of terms')
    check(pad['x']+pad['w'] <= width*.96-48*u, f'{width}: pad clear of communications portrait')
check(abs(layout.Unit(1920,1080)-10.8)<1e-9, '16:9 original scale unchanged')
check(abs(layout.Unit(840,378)-3.78)<1e-9, '20:9 original scale unchanged')

widget=(ROOT/'urhox-libs/UI/Core/Widget.lua').read_text(encoding='utf-8')
for key,pattern in [('ENGINE_EXTEND',r'function Widget:Extend\(name\).*?\nend'),('ENGINE_NEW',r'function Widget:new\(props\).*?\nend'),('ENGINE_SETTERS',r'local function buildSetterMap\(class\).*?\nend')]:
    lua.globals()[key]=re.search(pattern,widget,re.S).group()
lua.execute('''
local Widget={};Widget.__index=Widget
assert(load('local Widget=...;'..ENGINE_EXTEND..';return Widget'))(Widget)
YGNodeNew=function()return {}end
assert(load('local Widget=...;local Style={NormalizeColorProps=function()end};local SCROLL_UPGRADEABLE_={};'..ENGINE_SETTERS..';'..ENGINE_NEW))(Widget)
UI={Widget=Widget}
function UI.GetScale()return .35 end
graphics={GetDPR=function()return 1 end}
package.loaded['urhox-libs/UI']=UI
for _,name in ipairs({'ui.SourceDraw','ui.IntroFrame','ui.SourceParagraph','ui.WorkshopPaint','urhox-libs/UI/Core/ImageCache'}) do package.loaded[name]={} end
local Extend=Widget.Extend
function Widget:Extend(name) capturedPage=Extend(self,name);return capturedPage end
require('ui.IntroPage')
function capturedPage:Init()end
''')
lua.execute('''
owner={shot='contract',strokes={},ink=0,audio={Sfx=function()return {StopImmediate=function()end},1 end,StopSfx=function()end}}
page=capturedPage:new({})
page.owner=owner;page.k=.75;page.buttons={};page.pointers={}
page:UpdateSignatureBounds({x=200,y=300,w=300,h=180})
page:OnPointerDown({pointerId=1,pointerType='touch',x=230,y=336})
page:OnPointerMove({pointerId=1,x=350,y=390})
page:OnPointerMove({pointerId=1,x=900,y=1000})
page:OnPointerUp({pointerId=1})
''')
stroke = lua.globals().owner['strokes'][1]
check(abs(stroke[1][1]-.1)<1e-9 and abs(stroke[1][2]-.2)<1e-9, 'pointer down stored relative to pad')
check(abs(stroke[2][1]-.5)<1e-9 and abs(stroke[2][2]-.5)<1e-9, 'pointer move stored relative to pad')
check(stroke[3][1] == 1 and stroke[3][2] == 1, 'outside contact clipped to pad')
check(lua.globals().owner['ink']>30, 'real pointer movement keeps submit threshold')
check(lua.globals().page['signPointer'] is None, 'pointer release terminates drawing')
check(lua.globals().page['signatureRect']['w']==300, 'actual Widget property routing stores signature bounds without setter recursion')
lua.execute('''
owner.ink=0
page:OnPointerDown({pointerId=2,pointerType='touch',x=230,y=336})
page:OnPointerMove({pointerId=2,x=240,y=336})
''')
check(abs(lua.globals().owner['ink']-3.5)<1e-9, 'short phone stroke measured in CSS pixels, not design coordinates')
lua.execute('''
page:UpdateSignatureBounds({x=400,y=600,w=600,h=360})
page:OnPointerMove({pointerId=2,x=240,y=336})
''')
check(lua.globals().page['signPointer'] is None and lua.globals().page['scribble'] is None, 'resize ends held stroke and sound')
check(abs(lua.globals().owner['ink']-3.5)<1e-9, 'resize does not create imaginary ink')
for width,height in [(1024,768),(1280,800),(1920,1080),(840,378)]:
    p=layout.Plan(width,height);u=p['unit'];pad=p['pad']
    x,y,w,h=pad['x']+3*u,pad['y']+15.1*u,pad['w']-6*u,max(10*u,pad['h']-23*u)
    for point in stroke.values():
        check(x<=x+point[1]*w<=x+w and y<=y+point[2]*h<=y+h, f'{width}: existing ink remains in resized signature')

inputs={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['scripts/ui/IntroPage.lua','scripts/ui/IntroContractLayout.lua']}
report={'result':'PASS','checks':len(checks),'inputs':inputs,'cases':checks,'boundary':'CPU layout and actual pointer handlers; rendered Web, font and touch-device acceptance separate'}
(ROOT/'docs/migration/evidence/intro-contract-offline.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'result':'PASS','checks':len(checks)}))

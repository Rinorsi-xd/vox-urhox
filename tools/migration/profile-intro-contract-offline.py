"""Compare actual contract draw output and allocation, with no native renderer."""
import hashlib
import json
import os
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

OLD = ROOT / '.tmp/outgame-cached-1792098352922/scripts/ui/IntroPage.lua'
CURRENT = ROOT / 'scripts/ui/IntroPage.lua'
data = json.loads((ROOT / 'assets/Intro/Intro.json').read_text(encoding='utf-8'))
metrics = json.loads((ROOT / 'assets/UI/SourceFontMetrics.json').read_text(encoding='utf-8'))


def runtime(source):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({k: convert(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(v) for v in value])
        return value

    lua.globals().DATA = convert(data)
    lua.globals().METRICS = convert(metrics)
    lua.globals().ICONS = convert(json.loads((ROOT/'assets/UI/SourceIcons.json').read_text(encoding='utf-8')))
    lua.execute('''
package.path='scripts/?.lua;'..package.path
local Widget={}
function Widget:Extend() capturedPage={};capturedPage.__index=capturedPage;return capturedPage end
package.loaded['urhox-libs/UI']={Widget=Widget}
package.loaded['ui.SourceFonts']={GetBodyFace=function()end,Resolve=function()return {body='body',code='code'}end}
package.loaded['core.ResourceData']={Read=function(path)if path=='UI/SourceIcons.json'then return ICONS end;assert(path=='UI/SourceFontMetrics.json');return METRICS end}
package.loaded['ui.WorkshopPaint']={}
package.loaded['urhox-libs/UI/Core/ImageCache']={Get=function()return 1 end,GetSize=function()return 128,128 end}
NVG_ALIGN_CENTER=1;NVG_ALIGN_RIGHT=2;NVG_ALIGN_LEFT=4;NVG_ALIGN_TOP=8;NVG_ALIGN_BASELINE=16
CALLS={};TRACE={};RECORD=false;DEPTH=0
local function Native(name,...)
 CALLS[name]=(CALLS[name]or 0)+1
 if RECORD then local row={name};for _,v in ipairs({...})do row[#row+1]=v end;TRACE[#TRACE+1]=row end
 return 1
end
for _,name in ipairs({'nvgBeginPath','nvgMoveTo','nvgLineTo','nvgClosePath','nvgFillColor','nvgFill','nvgStrokeWidth','nvgStrokeColor','nvgStroke','nvgTranslate','nvgScale','nvgGlobalAlpha','nvgRect','nvgCircle','nvgEllipse','nvgIntersectScissor','nvgFillPaint','nvgLinearGradient','nvgRadialGradient','nvgImagePattern','nvgFontSize','nvgFontFace','nvgTextLetterSpacing','nvgTextAlign','nvgText','nvgFontBlur','nvgAddFallbackFontId'})do _G[name]=function(...)return Native(name,...)end end
function nvgSave()DEPTH=DEPTH+1;Native('nvgSave')end
function nvgRestore()DEPTH=DEPTH-1;assert(DEPTH>=0);Native('nvgRestore')end
function nvgRGBA(r,g,b,a)return r*16777216+g*65536+b*256+a end
function nvgCreateFont()return 1 end
function nvgTextBounds(_,_,_,text)Native('nvgTextBounds',text);return utf8.len(text)*10 end
local D=require 'ui.SourceDraw';D.Begin(1)
local Rich=require 'ui.SourceRichText';local Layout=Rich.Layout
LAYOUTS=0
Rich.Layout=function(...)LAYOUTS=LAYOUTS+1;return Layout(...)end
''')
    lua.execute(source.read_text(encoding='utf-8'))
    lua.execute('''
function MakePage(w,h,read)
 local p=setmetatable({k=1,termScroll=0,buttons={},pointers={},readTerms=read},capturedPage)
 p.owner={data=DATA,downloaded=true,age=2,time=100,strokes={},name='',error='',audio={Sfx=function()end}}
 p.terms=require('ui.SourceParagraph').New(15.12,27.972)
 p.paragraph=require('ui.SourceParagraph').New(28.08,47.736)
 p.inputClip={SetStyle=function()end}
 p.nameField={SetStyle=function()end,SetVisible=function()end,SetOpacity=function()end}
 return p
end
function Draw(page,w,h)
 page.buttons={};page:Contract(1,w,h,h/100);assert(DEPTH==0)
end
Vector2=function(...)return {...}end;Variant=function(v)return v end
function DrawComms(page,w,h,age)
 page.owner.shot='comms';page.owner.line='v01';page.owner.lineAge=age;page.owner.typing=1
 page.owner.voiceDuration=10;page.owner.finishedTyping=age>=1;page.owner.face='smile';page.owner.age=2
 page.portrait={materials={},Prepare=function()end,Queue=function()end,Draw=function()end}
 page:Comms(1,w,h,require('ui.IntroContractLayout').Unit(w,h));assert(DEPTH==0)
end
function Alloc(page,w,h,frames)
 Draw(page,w,h)
 collectgarbage('collect');collectgarbage('stop')
 local before=collectgarbage('count');local layouts=LAYOUTS;local started=os.clock()
 for i=1,frames do Draw(page,w,h)end
 local elapsed=os.clock()-started;local growth=collectgarbage('count')-before
 collectgarbage('restart')
 return {frames=frames,allocationKiB=growth,layoutBuilds=LAYOUTS-layouts,cpuSeconds=elapsed}
end
''')
    return lua


def plain(table):
    if hasattr(table, 'items'):
        keys = list(table.keys())
        if keys and all(isinstance(k, int) for k in keys):
            return [plain(table[k]) for k in sorted(keys)]
        return {k: plain(v) for k, v in table.items()}
    return table


def drawing(trace):
    trace = [row for row in trace if row[0] != 'nvgTextBounds']
    result = []
    i = 0
    scan_color = 214*16777216+240*65536+255*256+6
    while i < len(trace):
        end = i+1
        if trace[i][0] == 'nvgBeginPath':
            while end < len(trace) and trace[end][0] in ['nvgMoveTo','nvgLineTo']:
                end += 1
            points = trace[i+1:end]
            if (points and len(points)%2 == 0 and end+2 < len(trace)
                and trace[end] == ['nvgStrokeWidth',1,1]
                and trace[end+1] == ['nvgStrokeColor',1,scan_color]
                and trace[end+2] == ['nvgStroke',1]
                and all(points[k][0]=='nvgMoveTo' and points[k+1][0]=='nvgLineTo'
                        and points[k][3]==points[k+1][3] for k in range(0,len(points),2))):
                for k in range(0,len(points),2):
                    result.append(['scanline',*points[k][2:],*points[k+1][2:],1,scan_color])
                i = end+3
                continue
        result.append(trace[i])
        i += 1
    return result


old, current = runtime(OLD), runtime(CURRENT)
checks = 0
cases = []
for w, h in [(1920,1080), (1440,1080), (1728,1080), (2400,1080)]:
    for read in [False, True]:
        traces, pages = [], []
        for lua in [old, current]:
            p = lua.globals().MakePage(w,h,read)
            lua.execute('CALLS={};TRACE={};RECORD=true')
            lua.globals().Draw(p,w,h)
            traces.append(plain(lua.globals().TRACE))
            pages.append(p)
            lua.execute('RECORD=false')
        # Width/metrics native queries may vanish with cache reuse; emitted drawing remains identical.
        assert drawing(traces[0]) == drawing(traces[1]), (w,h,read,'draw trajectory changed')
        checks += 1
        for name in ['termRect','signatureRect','buttons']:
            assert plain(pages[0][name]) == plain(pages[1][name]), (w,h,read,name)
            checks += 1
        before = plain(old.globals().Alloc(pages[0],w,h,120))
        after = plain(current.globals().Alloc(pages[1],w,h,120))
        assert before['layoutBuilds'] == len(data['employeeFields'])//2*120
        assert after['layoutBuilds'] == 0
        assert after['allocationKiB'] < before['allocationKiB']
        checks += 3
        # Text changes and resize must invalidate the owning field's cached layout.
        built = current.globals().LAYOUTS
        current.globals().Draw(pages[1],w*.98,h*.98)
        assert current.globals().LAYOUTS > built
        checks += 1
        built = current.globals().LAYOUTS
        original = current.globals().DATA['employeeFields'][2]
        current.globals().DATA['employeeFields'][2] = original + 'X'
        current.globals().Draw(pages[1],w*.98,h*.98)
        assert current.globals().LAYOUTS == built+1
        current.globals().DATA['employeeFields'][2] = original
        checks += 1
        cases.append({'viewport':[w,h],'readTerms':read,'equivalentDrawingOperations':len(drawing(traces[1])),
                      'beforeCommands':len(traces[0]),'afterCommands':len(traces[1]),
                      'beforeNativeCalls':dict(Counter(row[0] for row in traces[0])),
                      'afterNativeCalls':dict(Counter(row[0] for row in traces[1])),
                      'before':before,'after':after})

comms=[]
for w,h in [(1920,1080),(1440,1080),(1728,1080),(2400,1080)]:
    for age in [.1,.5,1.5]:
        traces=[]
        for lua in [old,current]:
            p=lua.globals().MakePage(w,h,False)
            lua.execute('CALLS={};TRACE={};RECORD=true')
            lua.globals().DrawComms(p,w,h,age)
            traces.append(plain(lua.globals().TRACE))
            lua.execute('RECORD=false')
        assert drawing(traces[0])==drawing(traces[1]), (w,h,age,'comms scanlines changed')
        checks+=1
        comms.append({'viewport':[w,h],'lineAge':age,'beforeCommands':len(traces[0]),'afterCommands':len(traces[1])})

paths=['scripts/ui/IntroPage.lua','scripts/ui/SourceParagraph.lua','scripts/ui/SourceRichText.lua',
       'scripts/ui/SourceDraw.lua','scripts/ui/SourceTextLayout.lua','scripts/ui/IntroFrame.lua',
       'assets/Intro/Intro.json','assets/UI/SourceFontMetrics.json','assets/UI/SourceIcons.json']
report={'result':'PASS','checks':checks,'cases':cases,'commsCases':comms,'failedPackage':'manifest-3ba43bd8.json',
        'originalPageSha256':hashlib.sha256(OLD.read_bytes()).hexdigest(),
        'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
        'boundary':'Actual Page.Contract/Comms, SourceParagraph, SourceRichText, SourceDraw, font metrics, IntroTerminalFx and IntroFrame executed in Lua 5.4; portrait native surface is doubled. Full drawing trajectory and interactive geometry compared to frozen package, expanding each batched scanline back to its exact independent segment/color/width. GC disabled only inside offline 120-frame allocation samples. CPU times are native-free harness values, not Web/GPU/frame-time or GC-pause attribution. No approved subtitle changes.'}
out=ROOT/'docs/migration/evidence/intro-contract-cost-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))

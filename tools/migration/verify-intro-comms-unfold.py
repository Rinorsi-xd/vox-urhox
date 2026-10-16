"""Compare frozen IntroStory _unfold with actual Page.Comms drawing state (CPU)."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

oracle = r'''
const fs=require('fs'),vm=require('vm'),crypto=require('crypto');
const b=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const hashes={};function read(p){const v=fs.readFileSync(b.snapshot+'/'+p),h=crypto.createHash('sha256').update(v).digest('hex');if(h!==b.files[p].sha256)throw Error(p);hashes[p]=h;return v.toString('utf8');}
const story=read('three/src/intro/introStory.js'),css=read('shared/css/intro.css');
const method=story.slice(story.indexOf('\t_unfold( el,'),story.indexOf('\n\t_out( el,'));
const calls=story.slice(story.indexOf('\tasync actComms('),story.indexOf('\n\t// 诺诺说一句')).match(/this\._unfold\( this\.vv\.(?:root|tag|dlg),[^\n]+/g);
if(calls.length!==3)throw Error('source invocation drift');
const animations=[];function el(name){return{name,isConnected:true,style:{},animate(frames,options){animations.push({name,frames,options});return{finished:Promise.resolve()};},remove(){}};}
const c=vm.createContext({h:()=>el('scan')});vm.runInContext('globalThis.Host=class{'+method+'}',c);
const host=new c.Host();host.vv={root:el('comms'),tag:el('tag'),dlg:el('dialog')};
vm.runInContext('globalThis.invoke=function(){'+calls.join('\n')+'}',c);c.invoke.call(host);
const block=css.match(/#intro \.comms \{([^}]+)\}/)[1];
const dims=[...block.matchAll(/(?:width|height): calc\(var\(--ui-vh, 1vh\) \* ([\d.]+)\)/g)].map(m=>+m[1]);
process.stdout.write(JSON.stringify({baseline:{commit:b.commit,branch:b.branch},hashes,animations,dims}));
'''
reference = json.loads(subprocess.check_output(['node', '-e', oracle], encoding='utf-8'))
animations = {a['name']: a for a in reference['animations'] if a['name'] != 'scan'}
assert reference['dims'] == [48, 84]
data = json.loads((ROOT / 'assets/Intro/Intro.json').read_text(encoding='utf-8'))
checks = 0


def check(ok, label):
    global checks
    checks += 1
    assert ok, label


def near(a, b, label):
    check(abs(a-b) < 0.0002, f'{label}: {a} != {b}')


def ease(x, x1, y1, x2, y2):
    if x <= 0 or x >= 1:
        return max(0, min(1, x))
    def bez(t, a, b):
        return 3*(1-t)**2*t*a+3*(1-t)*t*t*b+t**3
    low, high = 0., 1.
    for _ in range(48):
        t = (low+high)/2
        if bez(t, x1, x2) < x:
            low = t
        else:
            high = t
    return bez((low+high)/2, y1, y2)


def expected(name, age, box, pixel):
    a = animations[name]
    f = a['frames']
    check(f[0]['clipPath'] == 'inset(calc(50% - 1px) 50%)' and
          f[2]['clipPath'] == 'inset(calc(50% - 1px) -60px)' and
          f[-1]['clipPath'] == 'inset(-60px)', 'actual frozen clip keyframes')
    check(a['options']['fill'] == 'backwards', 'actual source removes clip after completion')
    p = max(0, min(1, (age-a['options']['delay']/1000)/(a['options']['duration']/1000)))
    x, y, w, h = box
    if p < f[2]['offset']:
        q = ease(p/f[2]['offset'], .3, 0, .2, 1)
        left = w/2+(-60*pixel-w/2)*q
        top = h/2-pixel
    else:
        q = ease((p-f[2]['offset'])/(1-f[2]['offset']), .1, .9, .2, 1)
        left = -60*pixel
        top = h/2-pixel+(-60*pixel-h/2+pixel)*q
    alpha = ease(p/.1, .3, 0, .2, 1) if p < .1 else 1 if p < .7 else 1-(p-.7)*5 if p < .8 else .5+(p-.8)*5 if p < .9 else 1
    return alpha, None if p >= 1 else (x+left, y+top, max(0, w-2*left), max(0, h-2*top))


def runtime(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    def table(v):
        if isinstance(v, dict):
            return lua.table_from({k: table(x) for k, x in v.items()})
        if isinstance(v, list):
            return lua.table_from([table(x) for x in v])
        return v
    lua.globals().DATA = table(data)
    lua.globals().PAGE_PATH = path.as_posix()
    lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local noop=function()end
local Methods={AddChild=noop,SetVisible=noop}
local function New(props)return setmetatable(props or {},{__index=Methods})end
local UI={Widget={Extend=function()PAGE=setmetatable({},{__index=Methods,__call=function(_,p)return setmetatable(p,{__index=PAGE})end});return PAGE end},TextField=New,Panel=New}
package.loaded['urhox-libs/UI']=UI
package.loaded['ui.IntroImageWarmup']={New=function()return {}end}
package.loaded['ui.WorkshopPaint']={};package.loaded['urhox-libs/UI/Core/ImageCache']={}
local state={alpha=1};local stack={};EVENTS={}
local function emit(kind,extra) local r={kind=kind,alpha=state.alpha,clip=state.clip};for k,v in pairs(extra or {})do r[k]=v end;EVENTS[#EVENTS+1]=r end
function nvgSave()stack[#stack+1]={alpha=state.alpha,clip=state.clip}end
function nvgRestore()state=assert(table.remove(stack),'unbalanced native stack')end
function nvgGlobalAlpha(_,a)state.alpha=a end
function nvgIntersectScissor(_,x,y,w,h)
 local c=state.clip
 if c then local xx,yy=math.max(x,c[1]),math.max(y,c[2]);w=math.max(0,math.min(x+w,c[1]+c[3])-xx);h=math.max(0,math.min(y+h,c[2]+c[4])-yy);x,y=xx,yy end
 state.clip={x,y,w,h}
end
for _,n in ipairs({'nvgBeginPath','nvgRect','nvgFillColor','nvgFill','nvgStrokeWidth','nvgStrokeColor','nvgStroke','nvgFillPaint','nvgTranslate','nvgScale','nvgCircle','nvgEllipse','nvgMoveTo','nvgLineTo'})do _G[n]=noop end
function nvgRGBA(...)return {...}end
nvgLinearGradient=noop;nvgRadialGradient=noop
package.loaded['ui.IntroFrame']={Shape=noop,Draw=function(_,w,h,_,kind)emit(kind,{w=w,h=h})end}
package.loaded['ui.SourceDraw']={Color=function(v)return v end,Width=function(_,s,z,_,sp)return utf8.len(tostring(s))*(z*.6+(sp or 0))end,
 Advance=function(_,s,z,_,sp)return utf8.len(tostring(s))*(z*.6+(sp or 0))end,
 FontMetrics=function(_,z)return z*.8,z*.2 end,HasBodyAdvances=function()return false end,
 Text=function(_,text)emit('text',{text=text})end,Rect=noop,Line=noop,Path=noop,Gradient=noop}
NVG_ALIGN_RIGHT=2
local Page=assert(loadfile(PAGE_PATH))()
local Opacity=require 'ui.IntroOpacity'
function Draw(age,w,h,pixel,line,parent,shot,inheritedClip)
 EVENTS={};local I={data=DATA,age=age,time=age,shot=shot or 'comms',line=line,lineAge=age,voiceDuration=5,typing=4,finishedTyping=true}
 local page=Page.New(I);page.k=.75;page.cssPixel=pixel;page.buttons={}
 page.portrait={materials={},Prepare=noop,Queue=noop,Draw=function()emit('portrait')end}
 if inheritedClip then nvgSave(1);nvgIntersectScissor(1,-100,-100,4000,4000)end
 Opacity.Push(1,parent);page:Comms(1,w,h,h/100);Opacity.Pop(1)
 if inheritedClip then
  assert(state.clip[1]==-100 and state.clip[2]==-100 and state.clip[3]==4000 and state.clip[4]==4000,'inherited scissor changed')
  nvgRestore(1)
 end
 assert(#stack==0 and state.alpha==1 and state.clip==nil,'drawing state leaks')
 return EVENTS,page.dialogRect
end
''')
    return lua


current = runtime(ROOT / 'scripts/ui/IntroPage.lua')
samples = 0
for w, h in [(1440, 1080), (1728, 1080), (2400, 1080)]:
    for pixel in [.5, 1, 2]:
        for line in ['v01', 'v03']:
            for age in [0, .007, .024, .0528, .07, .09, .12, .168, .18, .192, .204, .216, .239, .24, .249, .25, .26, .269, .27, .4, 2]:
                events, rect = current.globals().Draw(age, w, h, pixel, line, .6, 'comms')
                rows = list(events.values())
                u = h/100
                for name, box in [('comms', (w*.96-48*u, h-84*u, 48*u, 84*u)),
                                  ('dialog', (rect['x']/.75, rect['y']/.75, rect['w']/.75, rect['h']/.75))]:
                    row = next(r for r in rows if r['kind'] == name)
                    alpha, clip = expected(name, age, box, pixel)
                    near(row['alpha'], alpha*.6, 'actual draw parent-composed opacity')
                    check((row['clip'] is None) == (clip is None), 'actual clip retires at source completion')
                    if clip:
                        for index, value in enumerate(clip, 1):
                            near(row['clip'][index], value, 'actual main panel clip')
                    if name == 'comms':
                        portrait = next(r for r in rows if r['kind'] == 'portrait')
                        near(portrait['alpha'], row['alpha'], 'portrait inherits parent reveal')
                        check((portrait['clip'] is None) == (clip is None), 'portrait inherits/clears source clip')
                check(any(r['kind'] == 'text' and r['text'] == 'INCOMING · 诺诺' for r in rows), 'existing dialog header remains')
                samples += 1
for shot in ['contract', 'stamp', 'gate']:
    events, _ = current.globals().Draw(0, 1920, 1080, 1, 'v03', .4, shot)
    rows = list(events.values())
    near(rows[0]['alpha'], .4, 'later stages do not replay opening')
    check(rows[0]['clip'] is None and not any(r['kind'] == 'dialog' for r in rows), 'later stages retain established portrait without dialogue')
for age in [0, .12, .24, .4]:
    current.globals().Draw(age, 1920, 1080, 1, 'v03', .4, 'comms', True)
    check(True, 'actual draw restores inherited native scissor and alpha')

old_path = ROOT / '.tmp/outgame-cached-1792122576512/scripts/ui/IntroPage.lua'
old_text = old_path.read_text(encoding='utf-8')
new_text = (ROOT/'scripts/ui/IntroPage.lua').read_text(encoding='utf-8')
check(old_text.split('function Page:Comms(')[0] == new_text.split('function Page:Comms(')[0], 'all preceding code including actual subtitle text layout unchanged')
terminal_overlay=" Impact.Flash(vg,I,w,h)\n"
check(new_text.count(terminal_overlay)==1,'terminal impact has one separately validated late draw hook')
check(old_text.split('function Page:Contract(')[1] == new_text.replace(terminal_overlay,'',1).split('function Page:Contract(')[1], 'contract/render/subtitle code unchanged apart from separately validated terminal flash hook')
def dialogue_body(text):
    return text.split(" local header='INCOMING")[1].split("  if I.choosing")[0].rsplit('\n', 2)[0]
check(dialogue_body(old_text) == dialogue_body(new_text), 'dialog text drawing and waiting arrow remain byte-identical')
old = runtime(old_path)
negative = []
for age, label in [(.024, 'source easing and transparency'), (.12, '84vh main clip'), (.2, 'continuous flicker'), (.4, 'completed scissor removal')]:
    events, _ = old.globals().Draw(age, 1920, 1080, 1, 'v03', .6, 'comms')
    row = next(r for r in events.values() if r['kind'] == 'comms')
    alpha, clip = expected('comms', age, (1324.8, 172.8, 518.4, 907.2), 1)
    differs = abs(row['alpha']-alpha*.6) > .001 or (row['clip'] is None) != (clip is None)
    if clip and row['clip']:
        differs |= any(abs(row['clip'][i]-v) > .001 for i, v in enumerate(clip, 1))
    check(differs, 'actual 45f negative: '+label)
    negative.append(label)

paths = ['scripts/ui/IntroPage.lua', 'scripts/ui/IntroContractMotion.lua', 'scripts/ui/IntroGateMotion.lua', 'scripts/ui/IntroOpacity.lua']
sha = lambda p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
result = {'result': 'PASS', 'checks': checks, 'drawCases': samples+7, 'reference': reference,
          'productionHashes': {p: sha(p) for p in paths},
          'testInputs': {'tools/migration/verify-intro-comms-unfold.py': sha('tools/migration/verify-intro-comms-unfold.py')},
          'negativeFixture': {'path': old_path.relative_to(ROOT).as_posix(), 'sha256': sha(old_path)},
          'negativeControls': negative,
          'boundary': 'CPU actual Page.New/Comms, real rich-text layout and shared unfold/opacity, with native UI/NanoVG/font/portrait adapters. Source _unfold and original actComms invocation statements execute after SHA verification. No GPU pixels, glow, natural narration, audio or mobile performance acceptance. Next candidate, not manifest45f.'}
(ROOT/'docs/migration/evidence/intro-comms-unfold-offline.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k: v for k, v in result.items() if k != 'reference'}, ensure_ascii=False, indent=2))

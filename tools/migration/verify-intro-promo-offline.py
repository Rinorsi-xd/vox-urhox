"""Actual Promo.Draw + SortieUi.Draw regression; no GPU or native presentation."""
import hashlib,json,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
def table(value):
 if isinstance(value,dict):return lua.table_from({k:table(v)for k,v in value.items()})
 if isinstance(value,list):return lua.table_from([table(v)for v in value])
 return value
lua.globals().GLYPHS=table(json.loads((ROOT/'assets/Intro/Fonts/TitleGlyphs.json').read_text(encoding='utf-8')))
lua.execute('''
package.path='scripts/?.lua;'..package.path
DEPTH=0;COUNTS={};TEXTS={}
local function Count(key)COUNTS[key]=(COUNTS[key]or 0)+1 end
package.loaded['core.ResourceData']={Read=function()return GLYPHS end}
package.loaded['core.Coord']={Vec=function()return {}end}
package.loaded['ui.SourceDraw']={
 Width=function(_,text,size,_,spacing)return utf8.len(text)*(size*.6+(spacing or 0))end,
 Text=function(_,text,...)TEXTS[#TEXTS+1]=text;Count('text')end,
 Color=function(c)return c end,Rect=function()Count('rect')end,
 Line=function()end,Path=function()end,Gradient=function()end}
package.loaded['ui.SourceParagraph']={New=function()return {
 Measure=function()return {height=20}end,Draw=function()Count('caption')end}end}
package.loaded['ui.IntroTypography']={face='game',Begin=function()end}
package.loaded['ui.IntroPage']={Image=function()end}
NVG_ALIGN_CENTER=1;NVG_ALIGN_RIGHT=2;NVG_CW=1;NVG_SOLID=1;NVG_HOLE=2
for _,name in ipairs({'nvgBeginPath','nvgMoveTo','nvgLineTo','nvgBezierTo','nvgClosePath','nvgPathWinding','nvgFillColor','nvgFill','nvgStrokeWidth','nvgStrokeColor','nvgStroke','nvgTranslate','nvgScale','nvgRotate','nvgGlobalAlpha','nvgRect','nvgRoundedRect','nvgIntersectScissor','nvgCircle','nvgFillPaint','nvgArc'})do _G[name]=function(...)for _,v in ipairs({...})do if type(v)=='number'then assert(v==v and math.abs(v)<math.huge,'finite draw value')end end end end
function nvgSave()DEPTH=DEPTH+1 end
function nvgRestore()DEPTH=DEPTH-1;assert(DEPTH>=0,'state underflow')end
function nvgRGBA(...)return {...}end
function nvgRadialGradient()return {}end
function nvgBoxGradient()return {}end
function nvgGaussianBlur()end
function nvgTransform()end
local SortieUi=require 'ui.IntroSortieUi'
local visual=setmetatable({session={combat={easy={alive=true,Position=function()return {0,0,0}end},player={Position=function()return {0,0,0}end}}},
 reticle={Render=function()Count('reticle')end},overlay={layer={Render=function()Count('overlay')end}}},SortieUi)
visual.Project=function(_,_,_,w,h)Count('project');return w*.5,h*.35 end
function Page(step,controlling,pending,capture,stamped,caption)
 return {k=1,owner={shot='sortie-play',age=1.1,time=100,playing=true,capturePending=capture,
  caption=caption and '源字幕' or '',data={images={}},log={},
  sortie={step=step,elapsed=1.1,controlling=controlling,pending=pending,left=8,killAt=step==3 and 99.9 or nil,mine=true,stamped=stamped,reason='测试原因'},
  host={state={sortieUi=visual}}}}
end
PROMO=require 'ui.IntroPromo'
''')
oldpath=ROOT/'.tmp/outgame-cached-1792097529664/scripts/ui/IntroPromo.lua'
old=lua.execute(oldpath.read_text(encoding='utf-8'))
reproduced=None
try:old.Draw(lua.globals().Page(1,False,False,False,False,False),0,1920,1080,10.8)
except Exception as error:reproduced=str(error)
assert reproduced and "global 's'" in reproduced,reproduced
lua.execute('DEPTH=0')
checks=1;cases=0
for w,h in [(1920,1080),(2400,1080),(1440,1080)]:
 for step in [1,2,3,4,5]:
  for controlling in [False,True]:
   for pending in [False,True]:
    for capture in [False,True]:
     for stamped in ([False,True]if step==5 else [False]):
      lua.execute('COUNTS={};TEXTS={}')
      page=lua.globals().Page(step,controlling,pending,capture,stamped,True)
      lua.globals().PROMO.Draw(page,0,w,h,h/100)
      counts=lua.globals().COUNTS;texts=list(lua.globals().TEXTS.values())
      assert lua.globals().DEPTH==0;checks+=1
      assert (counts['overlay']or 0)==(0 if capture else 1);checks+=1
      assert (counts['reticle']or 0)==(1 if controlling and step<5 and not capture else 0);checks+=1
      assert any(t=='点击画面 · 接管战车'for t in texts)==(not controlling and step<5 and not capture);checks+=1
      assert any(t=='已损毁'for t in texts)==(step==5 and stamped);checks+=1
      assert (counts['caption']or 0)==1;checks+=1
      cases+=1
for step in [1,2]:
 for controlling in [False,True]:
  page=lua.globals().Page(step,controlling,False,False,False,False)
  page['owner']['sortie']['elapsed']=7.5
  lua.globals().PROMO.Draw(page,0,1920,1080,10.8)
  assert lua.globals().DEPTH==0;checks+=1;cases+=1
for age in [0,1.5,2.2,2.5,4]:
 page=lua.globals().Page(0,False,False,False,False,False)
 page['owner']['shot']='sortie-brief';page['owner']['age']=age;page['owner']['playing']=False
 lua.globals().PROMO.Draw(page,0,1920,1080,10.8)
 assert lua.globals().DEPTH==0;checks+=1;cases+=1
paths=['scripts/ui/IntroPromo.lua','scripts/ui/IntroPromoMotion.lua','scripts/ui/IntroOpacity.lua','scripts/ui/IntroSortieUi.lua','scripts/ui/IntroSortieFx.lua','scripts/ui/IntroSortieKill.lua','scripts/ui/IntroFilm.lua']
result={'result':'PASS','checks':checks,'cases':cases,'reproduced8581':reproduced,
 'failedPackage':{'manifest':'manifest-8581d52a.json','scriptFingerprint':'724e60566de0c4e649b9de68022d66951db20547d61abfc0ee49e6e17b35ed14','promoSha256':hashlib.sha256(oldpath.read_bytes()).hexdigest()},
 'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
 'boundary':'Actual production IntroPromo.Draw calls actual IntroSortieUi.Draw/Brief/Chrome/Stamp, IntroSortieFx, IntroSortieKill and IntroFilm with strict native/vector/draw adapters. Steps 1-5, controlling/unlocked, pending/not pending, capture/non-capture, stamp branches, briefing and caption reachability. Reproduces original packaged nil s failure. No GPU, natural input, native physics, rendered parity or audio acceptance.'}
out=ROOT/'docs/migration/evidence/intro-promo-offline.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))

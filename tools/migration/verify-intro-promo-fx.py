"""Frozen JS effects against actual Lua Promo.Draw, without GPU."""
import hashlib,json,math,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
ref=json.loads(subprocess.check_output(['node','tools/migration/source-intro-promo-fx.mjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
package.path='scripts/?.lua;'..package.path
EVENTS={};DEPTH=0;ALPHA=1;STACK={}
local function E(kind,data)data=data or {};data.kind=kind;data.alpha=ALPHA;EVENTS[#EVENTS+1]=data end
package.loaded['ui.SourceDraw']={Rect=function(_,x,y,w,h,color)E('rect',{x=x,y=y,w=w,h=h,color=color})end,Text=function()end}
package.loaded['ui.SourceParagraph']={New=function()return {Measure=function()return {height=20}end,Draw=function()E('caption')end}end}
package.loaded['ui.IntroTypography']={face='title',Begin=function()end}
package.loaded['ui.IntroFilm']={Under=function()E('under')end,Over=function()E('over')end}
package.loaded['ui.IntroTitleCard']={Plan=function()return {}end,Draw=function()E('title')end}
package.loaded['ui.IntroMotto']={Draw=function()E('motto')end}
package.loaded['ui.IntroPromoMotion']={Salvage=function()return false end,Motto=function()return 1,1,1 end}
package.loaded['ui.IntroDecisionFx']={Below=function()return {brightness=1}end,Hero=function(_,_,name,x,y,w,h)E('image',{name=name,x=x,y=y,w=w,h=h})end}
for _,name in ipairs({'IntroBrand','IntroComic','IntroComicBurst','IntroComicText','IntroFamiliar','IntroGalaxyText','IntroSortieUi'})do package.loaded['ui.'..name]={}end
package.loaded['ui.IntroPage']={Image=function(_,_,name,x,y,w,h)E('image',{name=name,x=x,y=y,w=w,h=h})end}
package.loaded['urhox-libs/UI/Core/ImageCache']={Get=function()return 0 end}
function nvgSave()DEPTH=DEPTH+1;STACK[DEPTH]=ALPHA end
function nvgRestore()ALPHA=STACK[DEPTH];STACK[DEPTH]=nil;DEPTH=DEPTH-1;assert(DEPTH>=0)end
function nvgGlobalAlpha(_,a)ALPHA=a end
function nvgTranslate(_,x,y)E('translate',{x=x,y=y})end
function nvgScale(_,x,y)E('scale',{x=x,y=y})end
for _,name in ipairs({'nvgRotate','nvgBeginPath','nvgRect','nvgCircle','nvgClosePath','nvgFillColor','nvgFill','nvgStrokeColor','nvgStrokeWidth','nvgStroke','nvgFillPaint','nvgIntersectScissor'})do _G[name]=function()end end
function nvgImagePattern(...)return {...}end
function nvgRGBA(...)return {...}end
NVG_ALIGN_CENTER=1
FX=require 'ui.IntroPromoFx';PROMO=require 'ui.IntroPromo';OPACITY=require 'ui.IntroOpacity'
function Draw(id,age,w,h,rootAlpha,module)
 EVENTS={};ALPHA=1;DEPTH=0;STACK={}
 local I={shot=id,age=age,time=30+age,caption='保留字幕',big='标题',log={{shot='motto',t=30}},data={images={},durations={vo_n16=8.87}}}
 OPACITY.Push(1,rootAlpha);(module or PROMO).Draw({owner=I,k=1},1,w,h,h/100);OPACITY.Pop(1)
 assert(DEPTH==0 and ALPHA==1,'render state leak');return EVENTS,I
end
''')
checks=0;cases=0
def check(ok,message):
 global checks
 checks+=1
 assert ok,message
def unpack(t):return [t[i]for i in range(1,len(t)+1)]
def bezier(t,a,b):return 3*(1-t)**2*t*a+3*(1-t)*t*t*b+t**3
def ease(t,points):
 if t<=0:return 0
 if t>=1:return 1
 lo,hi=0,1
 for _ in range(50):
  mid=(lo+hi)/2
  if bezier(mid,points[0],points[2])<t:lo=mid
  else:hi=mid
 return bezier((lo+hi)/2,points[1],points[3])
specs={k:ref[k][0]for k in ['cut','mechanic','wages']}
specs['decided']=next(e for e in ref['decided']if e['name']=='flash')
hero=next(e for e in ref['decided']if e['name']=='chr')
for shot,key in [('m-build','cut'),('m-drive','cut'),('m-missile','cut'),('m-salvage','cut'),('decided','decided'),('mechanic','mechanic')]:
 spec=specs[key];duration=spec['options']['duration']/1000;peak=spec['frames'][0]['opacity']
 for age in [0,.001,duration*.25,duration*.5,duration-.001,duration,duration+.001]:
  for w,h in [(1600,900),(1200,900),(1950,900)]:
   for alpha in [1,.37]:
    events,owner=lua.globals().Draw(shot,age,w,h,alpha);events=unpack(events);cases+=1
    expected=peak*(1-ease(age/duration,[0,0,.58,1]))
    plan=lua.globals().FX.Plan(owner)
    check(abs(plan['flash']-expected)<1e-6,'actual plan source flash curve')
    flashes=[e for e in events if e['kind']=='rect'and e['w']==w and e['h']==h and e['color'][1]>0]
    check(len(flashes)==(1 if expected>0 else 0),'actual draw flash lifetime')
    if flashes:
     color={'#fff':[255,255,255],'#ffd36a':[255,211,106]}[spec['color']]
     check([flashes[0]['color'][i]for i in range(1,4)]==color,'actual flash source color')
     check(flashes[0]['color'][4]==math.floor(expected*255),'source flash opacity')
     check(abs(flashes[0]['alpha']-alpha)<1e-9,'flash honors root fade')
     check(events[-1]['kind']=='rect','flash overlays caption and cinema bars')
    check(sum(e['kind']=='caption'for e in events)==1,'caption retained')
    if shot=='decided':
     expected_scale=1.25-.23*ease(age/.42,[.2,.9,.3,1])
     check(abs(plan['heroScale']-expected_scale)<1e-6,'actual hero source scale')
     scale=next(e for e in events if e['kind']=='scale');check(abs(scale['x']-expected_scale)<1e-6,'hero scale reaches actual draw')
     moves=[e for e in events if e['kind']=='translate']
     check(abs(moves[0]['x']-(w/2-10.15*h/100))<1e-6 and abs(moves[0]['y']-h*.68)<1e-6,'source hero box center')
     check(moves[0]['x']==-moves[1]['x']and moves[0]['y']==-moves[1]['y'],'hero scaling centered without image-box drift')
     image=next(e for e in events if e['kind']=='image');check(image['name']=='machinist_hero'and abs(image['alpha']-alpha)<1e-9,'hero replaces dim idle at full opacity')
check(hero['frames']==[{'scale':1.25},{'scale':1.02}]and hero['options']['duration']==420,'frozen hero animation')
negative_path=ROOT/'.tmp/outgame-cached-1792104742555/scripts/ui/IntroPromo.lua'
old=lua.execute(negative_path.read_text(encoding='utf-8'))
negative=[]
for shot in ['m-build','m-drive','m-missile','m-salvage','decided','mechanic']:
 events,_=lua.globals().Draw(shot,.05,1600,900,1,old);events=unpack(events)
 flashes=[e for e in events if e['kind']=='rect'and e['w']==1600 and e['h']==900 and e['color'][1]>0]
 check(not flashes,'actual previous frozen Promo reproduces omitted flash');negative.append(shot)
events,_=lua.globals().Draw('decided',.05,1600,900,1,old);events=unpack(events)
check(not any(e['kind']=='scale'for e in events),'actual previous frozen Promo lacks hero scale')
check(next(e for e in events if e['kind']=='image')['alpha']==.98,'actual previous hero retains idle brightness')
for age in [0,.001,.125,.25,.499,.5,1]:
 for shot in ['motto','disclaimer']:
  I=lua.table_from({'shot':shot,'age':age if shot=='motto'else .01,'time':30+age,'log':lua.table_from([lua.table_from({'shot':'motto','t':30})])})
  check(abs(lua.globals().FX.MottoBlack(I)-.7*ease(age/.5,[.42,0,.58,1]))<1e-6,'motto black fade persists into disclaimer')
paths=['scripts/ui/IntroPromo.lua','scripts/ui/IntroPromoFx.lua','scripts/ui/IntroPayslip.lua','tools/migration/verify-intro-promo-fx.py','tools/migration/source-intro-promo-fx.mjs']
result={'result':'PASS','checks':checks,'drawCases':cases,'source':ref,'negativeControl':{'path':str(negative_path),'sha256':hashlib.sha256(negative_path.read_bytes()).hexdigest(),'missingFlashes':negative,'missingHeroScale':True,'heroOpacity':.98},'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},'boundary':'Executes frozen JS flash/cut/decided/mechanic statements and actual Lua IntroPromo.Draw/IntroPromoFx with NanoVG adapters. Source timings/easing/hero center/root opacity/retained captions; actual previous immutable Promo negative control. No GPU/build, raster parity, full-root shake, camera trauma, native audio or device acceptance.'}
(ROOT/'docs/migration/evidence/intro-promo-fx-offline.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items()if k!='source'},indent=2))

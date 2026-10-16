"""Execute frozen JS animation blocks and actual Lua Promo.Draw; no GPU."""
import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference=json.loads(subprocess.check_output(['node','tools/migration/source-intro-promo-motion.mjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
package.path='scripts/?.lua;'..package.path
EVENTS={};STATE={alpha=1};STACK={}
local function Event(kind,values)values=values or {};values.kind=kind;values.alpha=STATE.alpha;EVENTS[#EVENTS+1]=values end
package.loaded['ui.SourceDraw']={
 Width=function(_,text,size)return utf8.len(text)*size*.6 end,
 FontMetrics=function(_,size)return size*.8,size*.2 end,
 Text=function(_,text,x,y,size,color,font,align)Event('text',{text=text,x=x,y=y,size=size,font=font,align=align})end,
 Rect=function(_,x,y,w,h,color)Event('rect',{x=x,y=y,w=w,h=h,color=color})end,
 Path=function(_,points)Event('path',{points=points})end,
 Line=function()end}
package.loaded['ui.SourceParagraph']={New=function()return {
 Measure=function()return {height=20}end,Draw=function()Event('caption')end}end}
package.loaded['ui.IntroTypography']={face='game',Begin=function()end}
package.loaded['ui.IntroFilm']={Under=function()Event('under')end,Over=function()Event('over')end}
package.loaded['ui.IntroTitleCard']={Plan=function(id,text)return {id=id,text=text}end,
 Draw=function()Event('title')end}
package.loaded['urhox-libs/UI/Core/ImageCache']={Get=function()return 1 end,GetSize=function()return 800,1200 end}
package.loaded['ui.IntroPage']={Image=function(_,owner,name,x,y,w,h)
 local opacity=require 'ui.IntroOpacity';nvgSave(1);opacity.Set(1,1)
 Event('image',{name=name,x=x,y=y,w=w,h=h});nvgRestore(1)
end}
NVG_ALIGN_CENTER=1;NVG_ALIGN_RIGHT=2
function nvgSave()STACK[#STACK+1]={alpha=STATE.alpha}end
function nvgRestore()assert(#STACK>0,'state underflow');STATE=table.remove(STACK)end
function nvgGlobalAlpha(_,alpha)assert(alpha>=0 and alpha<=1);STATE.alpha=alpha end
function nvgIntersectScissor(_,x,y,w,h)Event('scissor',{x=x,y=y,w=w,h=h})end
function nvgTranslate(_,x,y)Event('translate',{x=x,y=y})end
function nvgScale(_,x,y)Event('scale',{x=x,y=y})end
for _,name in ipairs({'nvgFillColor','nvgFill','nvgStrokeWidth','nvgStrokeColor','nvgStroke','nvgFillPaint'})do _G[name]=function()end end
function nvgRGBA(...)return {...}end
function nvgImagePattern(...)return {...}end
PROMO=require 'ui.IntroPromo';MOTION=require 'ui.IntroPromoMotion';OPACITY=require 'ui.IntroOpacity'
function DrawCase(id,age,time,duration,withLog,rootAlpha)
 EVENTS={};STATE={alpha=1};STACK={}
 local log={}
 if withLog then
  if id=='motto' or id=='disclaimer' then log={{t=30,shot='motto'},{t=30,vo='n16',dur=2}}
  else log={{t=20,shot='m-salvage'},{t=20,vo='n11',dur=4.96},{t=25.16,shot='recruit'}}end
 end
 local I={shot=id,age=age,time=time,caption='源字幕',big='加入星际前途',log=log,
 data={images={machinist_hero='hero'},durations={vo_n16=8.87}},audio={Duration=function()return duration end}}
 if rootAlpha then OPACITY.Push(1,rootAlpha)end
 PROMO.Draw({owner=I,k=1},1,WIDTH,HEIGHT,HEIGHT/100)
 if rootAlpha then OPACITY.Pop(1)end
 assert(#STACK==0,'unbalanced NanoVG state')
 assert(STATE.alpha==1,'alpha leak')
 return EVENTS,I
end
''')

checks=0;draw_cases=0
def check(condition,message):
 global checks
 checks+=1
 assert condition,message

def near(actual,expected,message):check(abs(actual-expected)<.001,message+f': {actual} != {expected}')
def unpack(value):
 if hasattr(value,'items'):
  keys=list(value.keys())
  return [unpack(value[i])for i in range(1,len(keys)+1)]if keys and all(isinstance(k,int)for k in keys)else {k:unpack(v)for k,v in value.items()}
 return value

def ease(fraction,name):
 if fraction<=0:return 0
 if fraction>=1:return 1
 if name=='ease-in':values=[.42,0,1,1]
 else:values=[float(x)for x in name.split('(',1)[1].rstrip(')').split(',')]
 x1,y1,x2,y2=values
 def bezier(t,a,b):return 3*(1-t)**2*t*a+3*(1-t)*t*t*b+t**3
 left,right=0.,1.
 for _ in range(48):
  middle=(left+right)/2
  if bezier(middle,x1,x2)<fraction:left=middle
  else:right=middle
 return bezier((left+right)/2,y1,y2)

def animation(events,name,index=0):return [e for e in events if e['kind']=='animation'and e['name']==name][index]
def by_kind(events,kind):return [e for e in events if e['kind']==kind]
def draw(w,h,id,age,time,duration,with_log=True,root_alpha=None):
 global draw_cases
 lua.globals().WIDTH=w;lua.globals().HEIGHT=h
 events,owner=lua.globals().DrawCase(id,age,time,duration,with_log,root_alpha)
 draw_cases+=1;events=unpack(events)
 check(events[0]['kind']=='under'and any(e['kind']=='over'for e in events),'original film layer order')
 over=next(i for i,e in enumerate(events)if e['kind']=='over')
 check(all(e['kind']=='rect'for e in events[over+1:]),'only source full-screen flash overlays cinema bars')
 check(len(by_kind(events,'caption'))==1,'caption remains drawn')
 check(lua.globals().STATE['alpha']==1,'draw alpha restored')
 return events,owner

for case in reference['cases']:
 duration=case['duration'];card=animation(case['motto'],'motto-card')
 first=animation(case['motto'],'line1');second=animation(case['motto'],'line2')
 check(card['options']['duration']==400,'frozen card duration')
 check(first['options']['duration']==second['options']['duration']==900,'frozen line duration')
 check(first['frames']==second['frames']==[{'clipPath':'inset(0 100% 0 0)'},{'clipPath':'inset(0 0 0 0)'}],'source horizontal reveal')
 delay=second['at']/1000
 check(delay==(duration or 8)*.48,'captured source audio delay')
 ages=sorted(set([0,.05,.2,.399,.4,.899,.9,delay-.001,delay,delay+.05,delay+.45,delay+.899,delay+.9]))
 for w,h in [(1920,1080),(2400,1080),(1440,1080)]:
  for root_alpha in [1,.37]:
   for age in ages:
    events,_=draw(w,h,'motto',age,30+age,duration,root_alpha=root_alpha)
    elapsed=(30+age)-30
    alpha=ease(elapsed/(card['options']['duration']/1000),card['options']['easing'])*root_alpha
    texts=by_kind(events,'text');images=by_kind(events,'image');scissors=by_kind(events,'scissor')
    near(images[0]['alpha'],alpha,'emblem respects both card/root opacity')
    fine=[e for e in texts if e['text']=='*最终解释权归公司所有']
    check(len(fine)==1,'fineprint stays on the card before disclaimer')
    near(fine[0]['alpha'],alpha,'fineprint card opacity')
    unit=h/100
    text_height=2*6.6*unit+4*unit+2
    top=(h-(16*unit+4.8*unit+text_height+1.3*unit))/2
    text_y=top+18.4*unit
    near(fine[0]['x'],w/2,'source fineprint centered');near(fine[0]['y'],text_y+text_height+2.4*unit,'source flex fineprint y')
    near(fine[0]['size'],1.3*unit,'source fineprint size')
    rules=[e for e in by_kind(events,'rect')if e['h']==1]
    check(len(rules)==2,'source top and bottom motto rules')
    near(rules[0]['y'],text_y,'top motto rule');near(rules[1]['y'],text_y+text_height-1,'bottom motto rule')
    visible=0
    for text,start,anim,y in [('以发展之眼光，促螺旋之上升。',0,first,text_y+1+2*unit),('为星系予和平，许员工以价值。',delay,second,text_y+1+8.6*unit)]:
     progress=ease((elapsed-start)/(anim['options']['duration']/1000),anim['options']['easing'])
     items=[e for e in texts if e['text']==text]
     check(len(items)==(1 if progress>0 else 0),'hidden line has no draw before reveal')
     if not items:continue
     item=items[0];clip=scissors[visible];visible+=1
     width=len(text)*(h*.044)*.6
     near(clip['x'],(w-width)/2,'clip centered left origin')
     near(clip['w'],width*progress,'clip width follows frozen bezier')
     near(clip['y'],0,'clip top');near(clip['h'],h,'clip height')
     near(item['alpha'],alpha,'line alpha');near(item['x'],w/2,'line x unchanged')
     near(item['y'],y,'source line box y');near(item['size'],h*.044,'source line font size')
     check(item['font']=='vox-title'and item['align']==1,'line font/alignment retained')
    check(len(scissors)==visible,'no extra card clip')
   elapsed=(duration or 8)+.1+.05
   motto_events,_=draw(w,h,'motto',elapsed,30+elapsed,duration,root_alpha=root_alpha)
   disclaimer_events,_=draw(w,h,'disclaimer',.05,30+elapsed,duration,root_alpha=root_alpha)
   check(motto_events==disclaimer_events,'disclaimer age reset cannot restart motto')

source=reference['cases'][0]['salvage'];entrance=animation(source,'pn');exit=animation(source,'pn',1)
check(entrance['options']['duration']==280 and exit['options']['duration']==200,'captured salvage durations')
check('45)'in entrance['frames'][0]['translate']and '-20)'in entrance['frames'][0]['translate'],'source entrance vector')
check('45)'in exit['frames'][1]['translate']and '* 20)'in exit['frames'][1]['translate'],'source exit vector')
for w,h in [(1920,1080),(2400,1080),(1440,1080)]:
 for age in [0,.05,.14,.279,.28,.5]:
  events,_=draw(w,h,'m-salvage',age,20+age,8.87,root_alpha=.37)
  translation=by_kind(events,'translate')[0]
  remaining=1-ease(age/.28,entrance['options']['easing'])
  near(translation['x'],w*.45*remaining,'source salvage entrance x')
  near(translation['y'],-h*.2*remaining,'source salvage entrance y')
  check(by_kind(events,'path')[0]['alpha']==.37,'salvage inherits overall root alpha')
 for age in [0,.025,.05,.1,.15,.199,.2,.21,.4]:
  events,_=draw(w,h,'recruit',age,25.16+age,8.87,root_alpha=.37)
  translations=by_kind(events,'translate')
  panel_clips=by_kind(events,'scissor')
  elapsed=(25.16+age)-25.16
  check(len(panel_clips)==(1 if elapsed<exit['options']['duration']/1000 else 0),'panel disappears exactly at exit end')
  if panel_clips:
   progress=ease(age/.2,exit['options']['easing'])
   near(translations[0]['x'],w*.45*progress,'source salvage exit x')
   near(translations[0]['y'],h*.2*progress,'source salvage exit y')
   check(next(i for i,e in enumerate(events)if e['kind']=='path')<next(i for i,e in enumerate(events)if e['kind']=='title'),'departing panel remains behind recruit title')
 for id in ['tvcut','m-build','m-drive']:
  # Test the motion gate alone for skipped shots; those draw branches have independent tests.
  owner=lua.table_from({'shot':id,'age':.05,'time':25.21,'log':lua.table_from([lua.table_from({'shot':'m-salvage','t':20}),lua.table_from({'shot':'recruit','t':25.16})])})
  check(lua.globals().MOTION.Salvage(owner,w,h)is False,'skip cannot carry stale panel into next scene')

# No timeline log: retain useful editor-preview behavior; real runtime uses canonical marks.
events,_=draw(1920,1080,'disclaimer',.1,100,8.87,with_log=False)
check(len(by_kind(events,'scissor'))==2,'standalone disclaimer preview remains fully revealed')
owner=lua.table_from({'shot':'motto','age':4.5,'time':4.5,'data':lua.table_from({'durations':lua.table_from({'vo_n16':8.87})})})
_,_,second=lua.globals().MOTION.Motto(owner)
check(second>0,'editor preview uses imported duration when audio object absent')

paths=['scripts/ui/IntroPromo.lua','scripts/ui/IntroPromoMotion.lua','scripts/ui/IntroPromoFx.lua','scripts/ui/IntroOpacity.lua','scripts/ui/IntroMotto.lua']
result={'result':'PASS','checks':checks,'drawCases':draw_cases,'baseline':reference['baseline'],'sourceHashes':reference['sourceHashes'],
 'sourceAnimations':reference['cases'],'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
 'boundary':'Executes exact frozen intro.js motto and salvage blocks plus exact IntroStory _in/_out; validates actual IntroPromo.Draw and IntroPromoMotion under Lua 5.4 with NanoVG/text/image adapters. Three aspect ratios, actual duration/fallback, disclaimer continuity, nested overall opacity, source easing/timing/layer order. No GPU, raster/style parity, natural input, sound continuity or target-device acceptance.'}
out=ROOT/'docs/migration/evidence/intro-promo-motion-current-style-offline.json'
out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items()if k!='sourceAnimations'},ensure_ascii=False,indent=2))

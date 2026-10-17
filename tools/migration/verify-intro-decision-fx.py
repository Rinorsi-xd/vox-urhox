"""Run frozen actDecide and actual production decision draw without hardware."""
import json,math,os,subprocess,sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
ref=json.loads(subprocess.check_output(['node','tools/migration/source-intro-decision-fx.mjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
package.path='scripts/?.lua;'..package.path
EVENTS={};ALPHA=1;STACK={}
local function E(kind,data)data=data or {};data.kind=kind;data.alpha=ALPHA;EVENTS[#EVENTS+1]=data end
package.loaded['ui.SourceDraw']={Path=function(_,points)E('path',{points=points})end,Rect=function(...)E('background')end,
 Text=function(_,text,x,y,size,color,font,align,spacing,baseline,lineHeight)E('text',{text=text,x=x,y=y,size=size,font=font,spacing=spacing or 0,baseline=baseline or false,lineHeight=lineHeight})end}
package.loaded['urhox-libs/UI/Core/ImageCache']={Get=function()return 7 end,GetSize=function()return 600,900 end}
function nvgSave()STACK[#STACK+1]=ALPHA end
function nvgRestore()ALPHA=table.remove(STACK);assert(ALPHA)end
function nvgGlobalAlpha(_,a)ALPHA=a end
function nvgFillColor(_,color)E('color',{color=color})end
function nvgFillPaint(_,paint)E('paint',{paint=paint})end
function nvgRGBA(...)return {...}end
function nvgLinearGradient(...)return {type='gradient',args={...}}end
function nvgImagePatternTinted(...)return {type='image',args={...}}end
function nvgTranslate(_,x,y)E('translate',{x=x,y=y})end
function nvgScale()end
function nvgRotate(_,angle)E('rotation',{angle=angle})end
function nvgIntersectScissor(...)E('clip',{args={...}})end
function nvgRect(...)E('rect',{args={...}})end
function nvgCircle(_,x,y,r)E('circle',{x=x,y=y,r=r})end
function nvgArc(_,x,y,r,a,b)E('arc',{x=x,y=y,r=r,a=a,b=b})end
function nvgStrokeColor()end
function nvgStrokeWidth(_,width)E('strokeWidth',{width=width})end
function nvgStroke()end
function nvgLineCap()end
NVG_CW=1;NVG_ROUND=1;NVG_ALIGN_CENTER=2
function nvgBeginPath()end
function nvgFill()E('fill')end
FX=require 'ui.IntroDecisionFx';OPACITY=require 'ui.IntroOpacity'
package.loaded['ui.SourceParagraph']={New=function()return {Measure=function(self)return {height=self.lineHeight}end,Draw=function(self,_,_,x,y)E('caption',{x=x,y=y,size=self.size,lineHeight=self.lineHeight,font=self.font})end}end}
package.loaded['ui.IntroTypography']={}
package.loaded['ui.IntroFilm']={Under=function()E('under')end,Over=function()E('over')end}
package.loaded['ui.IntroRecruitTitles']={Draw=function()end,Handles=function()return false end}
package.loaded['ui.IntroPromoMotion']={Salvage=function()return false end}
for _,name in ipairs({'IntroTitleCard','IntroBrand','IntroComic','IntroComicBurst','IntroComicText','IntroFamiliar','IntroGalaxyText','IntroSortieUi'})do package.loaded['ui.'..name]={}end
PROMO=require 'ui.IntroPromo'
function Draw(id,q,age,w,h,rootAlpha)
 EVENTS={};ALPHA=1;STACK={}
 local I={shot=id,holdProgress=q,deciding=id=='decide',age=age,time=30+age,caption='preserved',log={{shot='decide',t=20}},downloaded=true,data={images={machinist_idle='idle',machinist_hero='hero'}}}
 OPACITY.Push(1,rootAlpha)
 local plan=FX.Plan(I);PROMO.Draw({owner=I,k=1},1,w,h,h/100)
 OPACITY.Pop(1);assert(#STACK==0 and ALPHA==1,'draw state leak')
 return plan,EVENTS
end
''')
checks=0
def check(ok,message):
 global checks
 checks+=1
 assert ok,message
def seq(table):return [table[i]for i in range(1,len(table)+1)]
for case in ref['cases']:
 q=case['progress']
 for shot,key in [('decide','hold'),('decided','decided')]:
  source=case[key];cone=float(source['.beam-cone'].get('opacity',0));brightness=1 if shot=='decided'else float(source['idle']['filter'][11:-1]);speed=float(source['.speed'].get('opacity',0))
  for w,h in [(1600,900),(1200,900),(2000,900)]:
   for alpha in [1,.37]:
    plan,events=lua.globals().Draw(shot,q,.73,w,h,alpha);events=seq(events)
    check(abs(plan['cone']-cone)<.0051,'source hold cone opacity rounding')
    check(abs(plan['brightness']-brightness)<1e-9,'source image brightness')
    check(abs(plan['speed']-speed)<1e-9,'source speed opacity')
    check(abs(plan['spot']-float(source['decide']['--spot'].strip('%'))/100)<1e-9,'source spotlight progress')
    check(abs(plan['rotation']-(10.73/7*math.pi*2))<1e-9,'continuous seven-second source rotation across mark')
    paths=[e for e in events if e['kind']=='path'];check(len(paths)==(48 if cone>0 else 0)+(120 if speed>0 else 0),'bounded cone and speed draw count')
    image=next(e for e in events if e['kind']=='paint'and e['paint']['type']=='image');tint=image['paint']['args'][8]
    check(tint[1]==math.floor(brightness*255+.5)and tint[4]==255,'brightness multiplies RGB without making hero transparent')
    check(image['alpha']==alpha,'hero obeys retained root fade')
    check(sum(e['kind']=='caption'for e in events)==1,'actual production Promo retains caption once')
    caption=next(e for e in events if e['kind']=='caption')
    check(caption['font']=='vox-title'and abs(caption['size']-h*.033)<1e-9 and abs(caption['lineHeight']-h*.048)<1e-9,'existing subtitle font, size and line-height preserved')
    check(abs(caption['y']-h*(.9-.048))<1e-9,'existing subtitle vertical anchor preserved')
    if shot=='decide':
     # Source bottom-anchored flex stack: SVG 11vh + gap 1.6vh + text 2.6vh.
     check('bottom: calc(var(--ui-vh, 1vh) * 16)'in ref['css']['hold'],'frozen CSS bottom anchor')
     u=h/100;svg=11*u;top=h-16*u-svg-1.6*u-2.6*u
     ring=next(e for e in events if e['kind']=='circle');arc=next(e for e in events if e['kind']=='arc')
     check(abs(ring['x']-w/2)<1e-9 and abs(ring['y']-(top+svg*.5))<1e-9 and abs(ring['r']-svg*.44)<1e-9,'source SVG viewport/44-unit circle scales into actual draw')
     check(abs(arc['b']-(-math.pi/2+q*math.pi*2))<1e-9,'source progress reaches actual arc')
     label=next(e for e in events if e['kind']=='text'and e['text']=='按住')
     hint=next(e for e in events if e['kind']=='text'and e['text'].startswith('按住 鼠标'))
     check(abs(label['y']-(top+svg*.58))<1e-9 and label['baseline']and abs(label['size']-svg*.22)<1e-9,'source SVG text 58 baseline and 22-unit font scaling')
     check(abs(hint['y']-(top+svg+1.6*u))<1e-9 and abs(hint['size']-2.6*u)<1e-9 and abs(hint['lineHeight']-2.6*u)<1e-9 and abs(hint['spacing']-2.6*u*.14)<1e-9,'source instruction line box and .14em tracking')
     check(hint['y']+hint['lineHeight']<=caption['y']-u+1e-9,'actual hint line box clears unchanged subtitle background')
    else:check(not any(e['kind']=='text'and e['text'].startswith('按住')for e in events),'source decided state removes complete hold stack')
    if cone>0:check(abs(paths[0]['alpha']-alpha*cone)<.0051,'cone obeys root opacity')
    clips=[e['args']for e in events if e['kind']=='clip']
    if cone>0:check(abs(clips[0][2]-(w/2-h*.4))<1e-9 and clips[0][3]==-h*.1 and clips[0][4]==h*.8 and clips[0][5]==h*1.2,'actual source cone box clipping')
    if speed>0:
     rotate=next(e for e in events if e['kind']=='rotation');check(rotate['angle']==plan['rotation'],'continuous clock reaches actual draw')
     check(all(abs(e['alpha']-alpha*.75)<1e-9 for e in paths[-120:]),'speed layer source .75 and root fade')
promo=(ROOT/'scripts/ui/IntroPromo.lua').read_text(encoding='utf-8')
start=promo.index("elseif id=='decide' or id=='decided'");end=promo.index("elseif id=='sortie-countdown'",start);decision=promo[start:end]
check(decision.index('Decision.Below')<decision.index('Decision.Hero'),'production cone/speed precede opaque character')
check('page.caption:Draw' in promo,'existing subtitle draw preserved')
check("local q=id=='decided' and 1 or I.holdProgress or 0"in decision,'existing hold ring source progress retained')
old=ROOT/'.tmp/outgame-cached-1792191490122/scripts/ui/IntroPromo.lua'
old_bytes=old.read_bytes();old_sha=hashlib.sha256(old_bytes).hexdigest()
check(old_sha=='5263b18abd2f76137aa3aad93e4a461ec83c5a4e11c2e9d63e26f23cd83e51f5','immutable b-package negative control')
lua.globals().PROMO=lua.execute(old_bytes.decode('utf-8'))
_,before=lua.globals().Draw('decide',.5,1.85,1600,900,1);before=seq(before)
old_hint=next(e for e in before if e['kind']=='text'and e['text'].startswith('按住 鼠标'))
old_caption=next(e for e in before if e['kind']=='caption')
check(abs(old_hint['y']-900*.84)<1e-9,'old actual draw reproduces 84vh instruction')
check(old_hint['y']+old_hint['size']>old_caption['y']-9,'old actual draw overlaps retained subtitle background')
result={'result':'PASS','checks':checks,'source':ref,'negativeControl':{'path':str(old),'sha256':old_sha,'hintTop':old_hint['y'],'subtitleBackgroundTop':old_caption['y']-9,'overlapReproduced':True},'sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in ['scripts/ui/IntroPromo.lua','scripts/ui/IntroDecisionFx.lua']},'boundary':'Executes frozen actDecide in VM and actual Lua layer drawing through NanoVG adapters. Source opacity, brightness, progress, continuous seven-second clock, geometry bounds, source hold stack, label baseline, spacing, layer order, root fade and preserved captions verified. Previous actual Promo reproduces the overlap as a negative control. Conic gradients are tessellated in NanoVG; real source DOM checks are prepared in the browser runner; raster/GPU visual parity and full natural playback remain unverified.'}
out=ROOT/'docs/migration/evidence/intro-decision-fx-offline.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items()if k!='source'},indent=2))

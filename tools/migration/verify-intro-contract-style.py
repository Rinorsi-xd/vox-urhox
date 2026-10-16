"""Frozen-source animation extraction + actual Page calls, without a GPU."""
import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
reference=json.loads(subprocess.check_output(['node','tools/migration/source-intro-contract-style.mjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
def table(value):
 if isinstance(value,dict):return lua.table_from({k:table(v)for k,v in value.items()})
 if isinstance(value,list):return lua.table_from([table(v)for v in value])
 return value
lua.globals().DATA=table(json.loads((ROOT/'assets/Intro/Intro.json').read_text(encoding='utf-8')))
lua.execute('''
package.path='scripts/?.lua;'..package.path
EVENTS={};STACK={};ALPHA=1;FOCUS_COUNT=0
local function Event(kind,row)row=row or {};row.kind=kind;row.alpha=ALPHA;EVENTS[#EVENTS+1]=row end
local Methods={}
function Methods:SetStyle(style)self.style=style end
function Methods:SetVisible(value)self.visible=value end
function Methods:SetOpacity(value)self.opacity=value end
function Methods:AddChild(child)self.children=self.children or {};self.children[#self.children+1]=child;child.parent=self end
local function New(props)return setmetatable(props or {},{__index=Methods})end
local Widget={Extend=function()PAGE=setmetatable({},{__index=Methods,__call=function(_,props)return setmetatable(props,{__index=PAGE})end});return PAGE end}
UI={Widget=Widget,TextField=New,Panel=New,GetFocus=function()return FOCUS end,ClearFocus=function()FOCUS=nil end,
 SetFocus=function(field)FOCUS=field;FOCUS_COUNT=FOCUS_COUNT+1 end}
package.loaded['urhox-libs/UI']=UI
package.loaded['ui.IntroImageWarmup']={New=function()return {}end}
package.loaded['ui.SourceDraw']={Begin=function()end,Color=function(c)return c end,
 Width=function(_,text,size,_,spacing)return utf8.len(tostring(text))*(size*.6+(spacing or 0))end,
 Advance=function(_,text,size,_,spacing)return utf8.len(tostring(text))*(size*.6+(spacing or 0))end,
 FontMetrics=function(_,size)return size*.8,size*.2 end,HasBodyAdvances=function()return false end,
 Text=function(_,text,x,y,size,color,font)Event('text',{text=text,x=x,y=y,size=size,color=color,font=font})end,
 Rect=function(_,x,y,w,h,color)Event('rect',{x=x,y=y,w=w,h=h,color=color})end,
 Line=function(_,x,y,xx,yy,color)Event('line',{x=x,y=y,xx=xx,yy=yy,color=color})end,
 Path=function()end,Gradient=function()end}
package.loaded['ui.IntroFrame']={Shape=function()end,Draw=function()end}
package.loaded['ui.WorkshopPaint']={}
package.loaded['urhox-libs/UI/Core/ImageCache']={}
NVG_ALIGN_CENTER=1;NVG_ALIGN_RIGHT=2
function nvgSave()STACK[#STACK+1]=ALPHA end
function nvgRestore()assert(#STACK>0);ALPHA=table.remove(STACK)end
function nvgGlobalAlpha(_,a)ALPHA=a end
function nvgIntersectScissor(_,x,y,w,h)Event('clip',{x=x,y=y,w=w,h=h})end
for _,name in ipairs({'nvgBeginPath','nvgRect','nvgMoveTo','nvgLineTo','nvgFillColor','nvgFill','nvgStrokeWidth','nvgStrokeColor','nvgStroke','nvgFillPaint','nvgTranslate','nvgScale','nvgCircle','nvgEllipse'})do _G[name]=function()end end
function nvgRGBA(...)return {...}end
function nvgRadialGradient()return {}end
function nvgLinearGradient()return {}end
local Page=require 'ui.IntroPage'
function NewPage()
 local p=Page.New({data=DATA,age=0,time=0,shot='contract',strokes={},name='',audio={Sfx=function()end}})
 p.k=.75;p.cssPixel=2;p:ShowContract(true);return p
end
function Draw(page,age,w,h)
 EVENTS={};page.buttons={};page.owner.age=age;page.owner.time=age
 page:Contract(1,w,h,h/100);assert(#STACK==0 and ALPHA==1);return EVENTS
end
function Comms(page,choice,elapsed,waiting)
 EVENTS={};page.buttons={};page.owner.shot='comms';page.owner.choosing=true;page.owner.choice=choice
 page.owner.choiceAt=choice and 10 or nil;page.owner.time=10+elapsed;page.owner.age=2;page.owner.waitingAdvance=waiting
 page.portrait={materials={},Prepare=function()end,Queue=function()end,Draw=function()end}
 page:Comms(1,1920,1080,10.8);assert(#STACK==0 and ALPHA==1);return EVENTS
end
MOTION=require 'ui.IntroContractMotion';TEXT=require 'ui.IntroContractText';LAYOUT=require 'ui.IntroContractLayout'
package.loaded['urhox-libs/UI/Core/Widget']={Extend=function()return {}end}
package.loaded['urhox-libs/UI/Core/Style']={}
package.loaded['urhox-libs/UI/Widgets/EditMenu']={}
local ActualField=require 'urhox-libs/UI/Widgets/TextField'
NVG_ALIGN_LEFT=4;NVG_ALIGN_MIDDLE=8
function nvgFontSize(_,size)FIELD_FONT=size end
function nvgFontFace()end
function nvgTextAlign()end
function nvgTextBounds(_,_,_,text)return utf8.len(text)*FIELD_FONT*.6 end
function nvgText(_,x,y,text)Event('fieldtext',{text=text,size=FIELD_FONT})end
function FieldRender(page,value)
 local props={};for key,item in pairs(page.nameField)do props[key]=item end
 for key,item in pairs(page.nameField.style)do props[key]=item end
 props.value=value;props.fontFamily='vox-title'
 local field=setmetatable({props=props,state={cursorPos=utf8.len(value)},GetAbsoluteLayout=function()return {x=0,y=0,w=props.width,h=props.height}end,
 GetShapeGeometry=function()return {}end,CreateShapePath=function()end},{__index=ActualField})
 ActualField.Render(field,1);return FIELD_FONT
end
''')
checks=0;cases=0
def check(value,label):
 global checks
 checks+=1
 assert value,label
def near(a,b,label):check(abs(a-b)<.0001,label)
def rows(value):return list(value.values())
def ease(x,a,b,c,d):
 if x<=0:return 0
 if x>=1:return 1
 def bez(t,p,q):return 3*(1-t)**2*t*p+3*(1-t)*t*t*q+t**3
 lo,hi=0.,1.
 for _ in range(48):
  mid=(lo+hi)/2
  if bez(mid,a,c)<x:lo=mid
  else:hi=mid
 return bez((lo+hi)/2,b,d)
animations=[a for a in reference['unfold']if a['name']in ['terminal','pad']]
check([(a['options']['duration'],a['options']['delay'])for a in animations]==[(240,0),(200,250)],'executed frozen unfold timing')
check(animations[0]['frames'][0]['clipPath']=='inset(calc(50% - 1px) 50%)','executed frozen initial clip')
check(animations[0]['frames'][-1]['clipPath']=='inset(-60px)','executed frozen final clip')
for animation in animations:
 duration=animation['options']['duration']/1000;delay=animation['options']['delay']/1000
 for fraction in [0,.05,.1,.15,.22,.5,.7,.75,.8,.85,.9,1]:
  rect=lua.globals().MOTION.Unfold(delay+duration*fraction,duration,delay,100,80,600,800,2)
  if fraction<.22:left=300+(-120-300)*ease(fraction/.22,.3,0,.2,1);top=398
  else:left=-120;top=398+(-120-398)*ease((fraction-.22)/.78,.1,.9,.2,1)
  alpha=ease(fraction/.1,.3,0,.2,1)if fraction<.1 else 1 if fraction<.7 else 1-(fraction-.7)*5 if fraction<.8 else .5+(fraction-.8)*5 if fraction<.9 else 1
  near(rect['x'],100+left,'unfold source horizontal keyframe interpolation');near(rect['y'],80+top,'unfold source vertical keyframe interpolation')
  near(rect['w'],600-2*left,'unfold source width');near(rect['h'],800-2*top,'unfold source height');near(rect['alpha'],alpha,'unfold source flicker opacity')
exits=[a for a in reference['choices']if a['options']['fill']=='forwards']
check([a['options']['duration']for a in exits]==[240,280,320],'executed frozen option exit durations')
check(reference['chooseResolveMs']==260,'narrative remains at 260ms')
check(reference['focusMs']==700,'frozen focus timer extracted without fallback')
for a in exits:check(a['options']['easing']=='ease-in','source choice easing')
for index in [1,2,3]:
 for age in [0,.05,.12,.24,.26,.28,.31,.32]:
  result=lua.globals().MOTION.Choice(index,2,age,1920)
  p=min(1,age/(exits[index-1]['options']['duration']/1000));e=ease(p,.42,0,1,1)
  near(result['alpha'],1-e,'choice alpha matches source');near(result['x'],(38.4 if index==2 else -192)*e,'choice translate matches source')
for w,h in [(1920,1080),(1440,1080),(2400,1080)]:
 p=lua.globals().NewPage()
 check(lua.eval('rawequal')(p['nameField']['parent'],p['inputClip']),'field is child of clipping panel')
 check(p['inputClip']['overflow']=='hidden','UI panel requests actual library overflow clipping')
 for age in [0,.01,.0528,.12,.18,.192,.216,.24,.249,.25,.26,.294,.35,.41,.45,.699,.7,.71]:
  events=rows(lua.globals().Draw(p,age,w,h));cases+=1
  terminal,pad=lua.globals().MOTION.Contract(p['owner'],lua.globals().LAYOUT.Plan(w,h),2)
  if age<.25:check(not p['nameField']['visible'],'pad delay hides native child input')
  if age<.7:check(lua.globals().FOCUS is None,'no premature input focus')
  if age>=.7:check(lua.eval('rawequal')(lua.globals().FOCUS,p['nameField']),'focus at frozen 700ms')
  near(p['nameField']['opacity'],pad['alpha'],'field alpha follows independent pad')
  if age>=.45:check(p['signatureHitRect']is None,'completed pad removes persistent clip')
  for row in rows(p['termParagraphs']):
   style=row['style']
   if row['fine']:near(style['size'],1.12*lua.globals().LAYOUT.Unit(w,h),'fine terms use source 1.12vh')
  check(any(e['kind']=='text'and e['text']=='特别安保部 · 战地人员登记终端'for e in events),'actual contract header drawn')
 check(lua.globals().FOCUS_COUNT==1,'contract focuses once');lua.execute('FOCUS=nil;FOCUS_COUNT=0')
 field=next(r for r in p['fieldRuns'].values()if not isinstance(r['content'],str))
 content=field['content'];check(''.join(r['text']for r in content.values())==field['text'],'rich field preserves imported words')
 near(content[2]['size']/content[1]['size'],1.25/1.65,'benefit em uses source size ratio');check(content[2]['color'][4]==140,'benefit em uses source alpha')
 for value in ['', '自然验收']:
  near(lua.globals().FieldRender(p,value),2.6*lua.globals().LAYOUT.Unit(w,h)*p['k'],'actual TextField.Render uses exact CSS pixel size')
 events=rows(lua.globals().Draw(p,.71,w,h))
 check(sum(e['kind']=='rect'and abs(e['w']-.6*lua.globals().LAYOUT.Unit(w,h))<1e-6 and abs(e['h']-e['w'])<1e-6 for e in events)==2,'source square markers on both labels')
 check(any(e['kind']=='rect'and e['color'][4]==217 for e in events),'SIGN source scrim background')
 check(sum(e['kind']=='line'and e['color'][4]==82 for e in events)>20,'signature source dashed border emitted')
 # Hit testing invokes the actual pointer handler against a visibly clipped pad.
 lua.globals().Draw(p,.25,w,h)
 r=p['signatureRect'];p.OnPointerDown(p,table({'pointerId':1,'pointerType':'touch','x':r['x']+1,'y':r['y']+1}))
 check(len(p['owner']['strokes'])==0,'signature cannot start outside animated clip')
 p.ShowContract(p,False);check(not p['nameField']['visible'],'contract hide immediately hides child')
 # Actual terminal backdrop owns the corner rule, including signed/gate caller flag.
 lua.execute("FX=require 'ui.IntroTerminalFx';EVENTS={};FX.Backdrop(1,1920,1080,10.8,1,true)")
 text=[e['text']for e in rows(lua.globals().EVENTS)if e['kind']=='text']
 check('SS-07 · FIELD TERMINAL'not in text and 'HANGAR 07 · 坠舰陨坑'not in text,'contract hides both left corner labels')
 check('SECURE LINK · AES-7'in text,'unaffected right corner stays')
p=lua.globals().NewPage()
for waiting in [False,True]:
 events=rows(lua.globals().Comms(p,None,0,waiting));cases+=1
 check(any(e['kind']=='text'and e['text']=='▼'for e in events)==waiting,'actual Comms arrow follows wait state')
 check(len(p['buttons'])==3,'unselected choices register three actual targets')
for elapsed in [0,.12,.24,.26,.28,.3,.32,.4]:
 events=rows(lua.globals().Comms(p,2,elapsed,False));cases+=1
 choices=[e for e in events if e['kind']=='text'and e['text']in list(lua.globals().DATA['choices'].values())]
 expected=sum((10+elapsed)-10<duration for duration in [.24,.28,.32])
 check(len(choices)==expected,'actual Comms retains each choice through its own exit clock')
 check(len(p['buttons'])==0,'exiting choices never register input targets')
old=lua.execute((ROOT/'.tmp/outgame-cached-1792102529909/scripts/ui/IntroPage.lua').read_text(encoding='utf-8'))
old_page=old.New(table({'data':json.loads((ROOT/'assets/Intro/Intro.json').read_text(encoding='utf-8'))}))
check(old_page['inputClip']is None,'negative control: immutable82 lacks new input clipping path')
panel=(ROOT/'urhox-libs/UI/Widgets/Panel.lua').read_text(encoding='utf-8')
check('CustomRenderChildren'in panel and 'IntersectScissor'in panel,'real panel implements render clipping')
page=(ROOT/'scripts/ui/IntroPage.lua').read_text(encoding='utf-8')
check("if I.waitingAdvance then"in page,'arrow consumes actual voice completion flag')
check("id=='contract' or id=='stamp' or id=='gate' and I.contractExitAt~=nil"in page,'corner flag persists through stamp and gate exit')
paths=['scripts/ui/IntroPage.lua','scripts/ui/IntroPromo.lua','scripts/ui/IntroTerminalFx.lua','scripts/ui/IntroContractMotion.lua','scripts/ui/IntroContractText.lua','scripts/ui/IntroMotto.lua']
result={'result':'PASS','checks':checks,'drawCases':cases,'reference':reference,'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},'boundary':'CPU actual Page.New/Contract/pointer/Backdrop calls with NanoVG/UI adapters and real SourceParagraph/SourceRichText. Frozen JS methods execute for unfolding/choice exit. No GPU, natural gameplay, audio-driven mouth, parallax or raster/style acceptance.'}
(ROOT/'docs/migration/evidence/intro-contract-current-style-offline.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items()if k!='reference'},ensure_ascii=False,indent=2))

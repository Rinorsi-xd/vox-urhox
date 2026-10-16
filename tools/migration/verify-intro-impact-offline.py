"""Execute original WAAPI oracle and real Lua impact/title draws, CPU only."""
import hashlib,json,math,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'.tmp/nav-python-deps'),str(ROOT/'.tmp/font-tooling')]
from lupa.lua54 import LuaRuntime
from fontTools.ttLib import TTFont
oracle=json.loads(subprocess.check_output(['node','tools/migration/source-intro-impact-style.mjs'],cwd=ROOT,text=True,encoding='utf-8'))
baseline=json.loads((ROOT/'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
source=Path(baseline['snapshot'])
data=json.loads((ROOT/'assets/Intro/Fonts/TitleGlyphs.json').read_text(encoding='utf-8'))
font=TTFont(source/'shared/fonts/ZCOOLQingKeHuangYou-Regular.ttf')
display=TTFont(source/'shared/fonts/BarlowCondensed-BoldItalic.ttf')
tabular=TTFont(ROOT/'assets/Fonts/VoxDisplayTabular-BoldItalic.ttf')
def advance(f,char):return f['hmtx'][f.getBestCmap()[ord(char)]][0]/f['head'].unitsPerEm
assert data['glyphs']['!']['advance']==advance(font,'!')==.196
assert data['glyphs']['！']['advance']==advance(font,'！')==.765
assert data['glyphs']['!']['contours']!=data['glyphs']['！']['contours']
assert (ROOT/'assets/Fonts/BarlowCondensed-BoldItalic.ttf').read_bytes()==(source/'shared/fonts/BarlowCondensed-BoldItalic.ttf').read_bytes()
lua=LuaRuntime(unpack_returned_tuples=True)
def convert(v):
 if isinstance(v,dict):return lua.table_from({k:convert(x)for k,x in v.items()})
 if isinstance(v,list):return lua.table_from([convert(x)for x in v])
 return v
def width(text,size,face,spacing):
 f=display if face=='vox-display' else tabular
 return sum(advance(f,c)*size+spacing for c in text)
lua.globals().GLYPHS=convert(data);lua.globals().WIDTH=width
lua.execute('''
package.path='scripts/?.lua;'..package.path
TRACE={};GLYPH_TRACE={};DEPTH=0
local function rec(name,...)TRACE[#TRACE+1]={name=name,args={...}}end
package.loaded['core.ResourceData']={Read=function()return GLYPHS end}
package.loaded['ui.SourceDraw']={Color=function(c)return c end,Width=function(_,text,size,font,spacing)rec('width',text,size,font,spacing);return WIDTH(text,size,font,spacing or 0)end,
Text=function(...)rec('text',...)end,Rect=function(...)rec('rect',...)end,Path=function()end,Gradient=function()end}
for _,name in ipairs({'nvgTranslate','nvgScale','nvgRotate','nvgGlobalAlpha','nvgSkewX','nvgBeginPath','nvgFillColor','nvgFill','nvgMoveTo','nvgLineTo','nvgClosePath','nvgStrokeColor','nvgStrokeWidth','nvgStroke','nvgCircle'})do _G[name]=function(...)rec(name,...)end end
function nvgRGBA(...)return {...}end
function nvgSave()DEPTH=DEPTH+1 end
function nvgRestore()DEPTH=DEPTH-1;assert(DEPTH>=0)end
G=require 'ui.IntroGlyphs'
function G.Draw(_,char,x,y,size,fill,stroke,thickness)GLYPH_TRACE[#GLYPH_TRACE+1]={char=char,x=x,y=y,size=size,fill=fill,stroke=stroke,thickness=thickness}end
COMIC=require 'ui.IntroComicText';TITLE=require 'ui.IntroTitleCard'
''')
checks=4;fixtures=[]
def ease(t,values):
 if t<=0:return 0
 if t>=1:return 1
 a,b,c,d=values;lo,hi=0.,1.
 def cubic(q,v,w):return 3*(1-q)**2*q*v+3*(1-q)*q*q*w+q**3
 for _ in range(22):
  p=(lo+hi)/2
  if cubic(p,a,c)<t:lo=p
  else:hi=p
 return cubic((lo+hi)/2,b,d)
def close(a,b):assert math.isclose(a,b,abs_tol=1e-7), (a,b)
def animation(event,age):
 duration=event['options']['duration']/1000
 curve=[float(v)for v in re.search(r'\(([^)]+)\)',event['options']['easing'])[1].split(',')]
 t=ease(age/duration,curve);frames=event['frames'];offsets=[f.get('offset',i/(len(frames)-1))for i,f in enumerate(frames)]
 segment=next((i for i in range(len(frames)-1)if t<offsets[i+1]),len(frames)-2)
 q=(t-offsets[segment])/(offsets[segment+1]-offsets[segment]);a,b=frames[segment:segment+2]
 def key(k):return float(str(a[k]).replace('deg',''))+(float(str(b[k]).replace('deg',''))-float(str(a[k]).replace('deg','')))*q
 return key('scale'),key('rotate'),max(0,min(1,key('opacity')))
def verify(module,which,w,h,age):
 global checks
 lua.execute('TRACE={};GLYPH_TRACE={}')
 u=h/100;size=u*(34 if which=='No' else 13);text=oracle['no']['text']if which=='No' else oracle['bang']['text']
 spacing=size*.02 if which=='No' else 0
 actual_width=sum(advance(font,c)*size+spacing for c in text)
 x,y=((w-actual_width)/2,(h-size)/2)if which=='No' else (w*.75+110-h*.2,h*.1+109.2+h*.08)
 if which=='No':module.No(0,w,h,u,age)
 else:module.Bang(0,x,y,u,age)
 trace=list(lua.globals().TRACE.values());glyphs=list(lua.globals().GLYPH_TRACE.values())
 translate=next(c['args']for c in trace if c['name']=='nvgTranslate')
 close(translate[2],x+actual_width/2);close(translate[3],y+size/2);checks+=2
 event=next(e for e in oracle['events']if e['className']==('slam huge'if which=='No'else'sfx red'))
 scale,rotation,alpha=animation(event,age)
 close(next(c['args'][2]for c in trace if c['name']=='nvgScale'),scale)
 close(next(c['args'][2]for c in trace if c['name']=='nvgRotate'),rotation*math.pi/180)
 close(next(c['args'][2]for c in trace if c['name']=='nvgGlobalAlpha'),alpha);checks+=3
 shadow_source=oracle['styles']['.slam'][-1]if which=='No'else oracle['styles']['.sfx.red'][0]
 offsets=[float(v)for v in re.findall(r'([.\d]+)em [\.\d]+em 0',shadow_source)][::-1]
 assert len(glyphs)==len(text)*(len(offsets)+1);checks+=1
 color=[255,45,31,255]if which=='No'else[255,59,48,255]
 border=[255,255,255,255]if which=='No'else[11,11,13,255]
 stroke=float(re.search(r'text-stroke: ([.\d]+)em',oracle['styles']['.slam'][-1]if which=='No'else oracle['styles']['.sfx'][0])[1])
 left=0
 for i,char in enumerate(text):
  group=[glyphs[layer*len(text)+i]for layer in range(len(offsets)+1)]
  for glyph,offset in zip(group,offsets):
   close(glyph['x'],left+offset*size);close(glyph['y'],size*.88+offset*size)
   close(glyph['thickness'],stroke*size);checks+=3
  main=group[-1];assert main['char']==char;close(main['x'],left);close(main['size'],size)
  assert list(main['fill'].values())==color and list(main['stroke'].values())==border;checks+=4
  left+=advance(font,char)*size+spacing
 assert lua.globals().DEPTH==0;checks+=1
 return {'viewport':[w,h],'kind':which,'age':age,'fontPx':size,'widthPx':actual_width,'anchor':[x,y],'scale':scale,'rotation':rotation,'alpha':alpha,'shadowPx':[o*size for o in offsets]}
for w,h in [(1920,1080),(2400,1080),(1440,1080),(1333,600)]:
 for age in [0,.03,.1,.14,.2,.24,.4]:
  for which in ['No','Bang']:fixtures.append(verify(lua.globals().COMIC,which,w,h,age))
 for id in ['prosper','order','leave']:
  lua.execute('TRACE={};GLYPH_TRACE={}')
  plan=lua.globals().TITLE.Plan(id,None)
  lua.globals().TITLE.Draw(0,w,h,h/100,2,plan,None)
  trace=list(lua.globals().TRACE.values());calls=[c for c in trace if c['name']=='width']
  assert len(calls)==2 and all(c['args'][3]=='vox-display'for c in calls);checks+=1
  fs=2.2*h/100;expected=width(plan['idx'],fs,'vox-display',fs*.05)+fs*1.2
  rects=[c['args']for c in trace if c['name']=='rect'];close(rects[-2][4],expected);checks+=1
  texts=[c['args']for c in trace if c['name']=='text'];assert texts[-2][7]=='vox-display'and texts[-1][7]=='vox-display';checks+=1
  fixtures.append({'viewport':[w,h],'tag':plan['idx'],'actualSourceFont':'vox-display','idxBoxPx':expected,'oldTabularExcessPx':width(plan['idx'],fs,'vox-tabular',fs*.05)-width(plan['idx'],fs,'vox-display',fs*.05)})
negative=[]
code=(ROOT/'scripts/ui/IntroComicText.lua').read_text(encoding='utf-8')
for name,before,after in [('missing-stroke','size*.12,','0,'),('fixed-pixel-shadow','left+size*shadow[1]','left+4'),('wrong-bang-anchor',"Impact(vg,'砰——！',x,y", "Impact(vg,'砰——！',x-G.Width('砰——！',size,0)/2,y")]:
 assert before in code
 mutant=lua.execute(code.replace(before,after,1))
 try:verify(mutant,'Bang'if name=='wrong-bang-anchor'else'No',1920,1080,.24)
 except AssertionError:negative.append({'name':name,'status':'REJECTED'})
 else:raise AssertionError('Escaped negative '+name)
title=(ROOT/'scripts/ui/IntroTitleCard.lua').read_text(encoding='utf-8')
assert title.count("'vox-display'")==4 and "'vox-tabular'"not in title;negative.append({'name':'old-tabular-tag','status':'REJECTED','widthExcess1080px':width('01',23.76,'vox-tabular',0)-width('01',23.76,'vox-display',0)})
promo=(ROOT/'scripts/ui/IntroPromo.lua').read_text(encoding='utf-8')
assert "IntroComicText').Bang(vg,tx-h*.2,ty+h*.08,u,t-.5)"in promo
assert "IntroComicText').No(vg,w,h,u,t-.5)"in promo
assert "Big(vg,'NO!'"not in promo and "Big(vg,'砰——！'"not in promo
negative.append({'name':'old-big-wiring','status':'REJECTED'})
paths=['scripts/ui/IntroComicText.lua','scripts/ui/IntroTitleCard.lua','scripts/ui/IntroPromo.lua','assets/Intro/Fonts/TitleGlyphs.json','tools/migration/import-intro-title-glyphs.py']
report={'status':'PASS','checks':checks,'negativeControls':negative,'oracle':oracle,'fixtures':fixtures,'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},'boundary':'Actual source methods/CSS and actual Lua outer transform/glyph draw arguments at four viewports. Glyph emitter intercepted after original exact-font contour data load. No GPU, browser computed styles, raster equality, native timing or whole opening acceptance.'}
out=ROOT/'docs/migration/evidence/intro-comic-impact-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':'PASS','checks':checks,'negativeControls':negative,'production':report['production']},indent=2))

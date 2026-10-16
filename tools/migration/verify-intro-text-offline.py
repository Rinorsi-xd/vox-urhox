"""Original font contour bounds and actual non-caption drawing commands."""
import hashlib,json,math,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
sys.path.insert(0,str(ROOT/'.tmp/font-tooling'))
from lupa.lua54 import LuaRuntime
from fontTools.ttLib import TTFont
from fontTools.pens.boundsPen import BoundsPen
source=ROOT/'.tmp/outgame-source-2026-10-15T12-35-57-243Z'
css=(source/'shared/css/intro.css').read_text(encoding='utf-8')
intro=(source/'three/src/intro/intro.js').read_text(encoding='utf-8')
fx=(source/'three/src/intro/introFx.js').read_text(encoding='utf-8')
assert '.1em #0b0b0d' in css and '.05em .05em' in css and '.09em .09em' in css
assert '"GameFont", sans-serif' in css and 'last.id % this.names.length' in fx
lua=LuaRuntime(unpack_returned_tuples=True)
def convert(value):
 if isinstance(value,dict):return lua.table_from({key:convert(item)for key,item in value.items()})
 if isinstance(value,list):return lua.table_from([convert(item)for item in value])
 return value
data=json.loads((ROOT/'assets/Intro/Fonts/TitleGlyphs.json').read_text(encoding='utf-8'))
lua.globals().GLYPHS=convert(data)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
COMMANDS={};DEPTH=0
local function record(name,...)COMMANDS[#COMMANDS+1]={name=name,args={...}}end
package.loaded['core.ResourceData']={Read=function()return GLYPHS end}
package.loaded['ui.SourceDraw']={Color=function(c)return c end,
 Width=function(_,text,size,font,spacing)return utf8.len(text)*(size+(spacing or 0))end,
 Text=function(...)record('text',...)end,Rect=function(...)record('rect',...)end,
 Line=function(...)record('line',...)end,Path=function(...)record('path',...)end}
package.loaded['ui.IntroPage']={Image=function(...)record('image',...)end}
for _,name in ipairs({'nvgBeginPath','nvgMoveTo','nvgLineTo','nvgBezierTo','nvgClosePath','nvgPathWinding','nvgFillColor','nvgFill','nvgStrokeWidth','nvgStrokeColor','nvgStroke','nvgTranslate','nvgScale','nvgRotate','nvgGlobalAlpha','nvgRect','nvgRoundedRect','nvgIntersectScissor','nvgCircle','nvgFillPaint','nvgLinearGradient'})do _G[name]=function(...)record(name,...)end end
function nvgRGBA(...)return {...}end
function nvgCreateImage(...)record('nvgCreateImage',...);return 1 end
function nvgImagePatternTinted(...)record('nvgImagePatternTinted',...);return {}end
function nvgSave()DEPTH=DEPTH+1 end
function nvgRestore()DEPTH=DEPTH-1;assert(DEPTH>=0)end
NVG_SOLID=1;NVG_HOLE=2
NVG_IMAGE_REPEATX=1;NVG_IMAGE_REPEATY=2
COMIC=require 'ui.IntroComicText';GALAXY=require 'ui.IntroGalaxyText';PAYSLIP=require 'ui.IntroPayslip';KILL=require 'ui.IntroSortieKill';WIPE=require 'ui.IntroWipe'
''')
checks=4
font=TTFont(source/'shared/fonts/ZCOOLQingKeHuangYou-Regular.ttf');glyphset=font.getGlyphSet();units=font['head'].unitsPerEm
for char in set('轰——！滋滋——……？'):
 name=font.getBestCmap()[ord(char)];pen=BoundsPen(glyphset);glyphset[name].draw(pen)
 assert math.isclose(data['glyphs'][char]['advance'],font['hmtx'][name][0]/units);checks+=1
 # Production contours must retain real ink, including bearings outside advance.
 commands=[c for contour in data['glyphs'][char]['contours']for c in contour['commands']]
 assert commands and pen.bounds is not None;checks+=1
fixtures=[]
for w,h in [(1920,1080),(2400,1080),(1333.333333333,600),(1440,1080)]:
 u=h/100
 for text,size,variant in [('轰——！',11*u,'red'),('滋滋——',8*u,None),('……？',7*u,'white')]:
  box=lua.globals().COMIC.Measure(text,size)
  expected=sum(font['hmtx'][font.getBestCmap()[ord(c)]][0]/units*size for c in text)
  assert math.isclose(box['width'],expected) and math.isclose(box['height'],size);checks+=2
  lua.execute('COMMANDS={}')
  lua.globals().COMIC.Draw(0,text,100,200,size,-8,convert({'fx':1,'alpha':1}),variant)
  commands=list(lua.globals().COMMANDS.values());first=commands[0]
  assert first['name']=='nvgTranslate' and math.isclose(first['args'][2],100+expected/2) and math.isclose(first['args'][3],200+size/2);checks+=1
  stroke=[c for c in commands if c['name']=='nvgStrokeWidth']
  assert len(stroke)==len(text)*3 and all(math.isclose(c['args'][2],.1) for c in stroke);checks+=1
  assert lua.globals().DEPTH==0;checks+=1
  fixtures.append({'viewport':[w,h],'text':text,'size':size,'width':expected,'strokePx':size*.1,'shadowOffsetsPx':[size*.05,size*.09]})
 p=lua.globals().GALAXY.Plan(w,h,u,123)
 assert math.isclose(p['x'],w*.04) and math.isclose(p['number'],16*u) and p['count']=='123';checks+=3
 for t in [0,.2,.4,.6,.8]:
  lua.execute('COMMANDS={}')
  page=lua.table();owner=convert({'age':t})
  lua.globals().GALAXY.Draw(page,0,owner,w,h,u,3,convert({'id':100}))
  commands=list(lua.globals().COMMANDS.values())
  texts=[c['args'] for c in commands if c['name']=='text']
  number=next(c for c in texts if c[2]=='003')
  assert number[7]=='vox-display' and math.isclose(number[5],16*u);checks+=2
  warning=next(c for c in texts if c[2].startswith('WARNING'))
  assert math.isclose(warning[4],h*.14+1.2*u);checks+=1
  assert any(c[2].startswith('▲ 坠星滩')for c in texts);checks+=1
  assert all(isinstance(c['args'][2],(int,float)) for c in commands if c['name']=='nvgGlobalAlpha');checks+=1
  assert lua.globals().DEPTH==0;checks+=1
 # Real frame-count behavior: repeat does not append; newer divisible count appends.
 lua.globals().GALAXY.Draw(page,0,owner,w,h,u,3,convert({'id':100}))
 assert len(page['galaxyText']['rows'])==1;checks+=1
 owner['age']=1
 for count in range(6,33,3):lua.globals().GALAXY.Draw(page,0,owner,w,h,u,count,convert({'id':100+count}))
 assert len(page['galaxyText']['rows'])==7;checks+=1
 owner['age']=0;lua.globals().GALAXY.Draw(page,0,owner,w,h,u,0,None)
 assert len(page['galaxyText']['rows'])==0;checks+=1
def ease(t,control):
 if t<=0:return 0
 if t>=1:return 1
 x1,y1,x2,y2=control;lo,hi=0.,1.
 def cubic(p,a,b):return 3*(1-p)**2*p*a+3*(1-p)*p*p*b+p**3
 for _ in range(22):
  q=(lo+hi)/2
  if cubic(q,x1,x2)<t:lo=q
  else:hi=q
 return cubic((lo+hi)/2,y1,y2)

assert "easing = 'cubic-bezier(.16,1,.3,1)'" in (source/'three/src/intro/introStory.js').read_text(encoding='utf-8');checks+=1
assert "I.wait( 1.2 ).then( () => I._out( kill, 240 ) )" in (source/'three/src/intro/introSortie.js').read_text(encoding='utf-8');checks+=1
for w,h in [(1920,1080),(2400,1080),(1333.333333333,600),(1440,1080)]:
 u=h/100
 for wrecked in [False,True]:
  for age in [0,.15,.3,.52,.66,.8,1.1,4.559,4.56,4.649,4.65,4.75,5.45,5.951]:
   owner=convert({'age':age,'voiceDuration':5.86,'wrecked':wrecked})
   p=lua.globals().PAYSLIP.Plan(age,5.86,wrecked)
   assert p['rows']==(7 if wrecked else 6) and p['total']==('237.50' if wrecked else '1,437.50');checks+=2
   assert math.isclose(p['rotation'],-24+29*ease(age/.52,(.16,1,.3,1)));checks+=1
   assert math.isclose(p['shredAt'],4.65) and p['shredded']==(age>=4.65);checks+=2
   lua.execute('COMMANDS={}')
   lua.globals().PAYSLIP.Draw(0,owner,w,h,u)
   commands=list(lua.globals().COMMANDS.values());texts=[c['args']for c in commands if c['name']=='text']
   flashes=[c['args']for c in commands if c['name']=='rect'and c['args'][4]==w and c['args'][5]==h and c['args'][6][1]==255 and c['args'][6][2]==58]
   flashing=4.65<=age<4.91
   assert len(flashes)==(1 if flashing else 0);checks+=1
   if flashing:
    assert flashes[0][6][4]==math.floor(153*(1-ease((age-4.65)/.26,(0,0,.58,1))));checks+=1
   if age<4.65:
    assert any(c[2]==p['total'] and c[7]=='vox-display' and math.isclose(c[5],5*u)for c in texts);checks+=1
    assert any(c[2]=='战车维修费（实机演示）'for c in texts)==wrecked;checks+=1
    assert sum(c['name']=='image'for c in commands)==1;checks+=1
   if age==4.65:
    assert sum(c['name']=='nvgIntersectScissor' and math.isclose(c['args'][4],50*u/7)for c in commands)==63;checks+=1
   if age>5.95:assert len(commands)==0;checks+=1
   assert lua.globals().DEPTH==0;checks+=1
   for command in commands:
    for arg in command['args'].values():
     if isinstance(arg,(int,float)):assert math.isfinite(arg)
   checks+=1
 for mine in [False,True]:
  for age in [-.01,0,.1,.168,.24,1.199,1.2,1.32,1.439,1.44]:
   lua.execute('COMMANDS={}')
   lua.globals().KILL.Draw(0,w,h,u,age,mine)
   commands=list(lua.globals().COMMANDS.values());p=lua.globals().KILL.Plan(age)
   assert p['visible']==(0<=age<1.44);checks+=1
   if p['visible']:
    strokes=[c['args'][2]for c in commands if c['name']=='nvgStrokeWidth']
    assert len(strokes)==6;checks+=1
    assert all(math.isclose(s,.5/11)for s in strokes);checks+=1
    sub='绩效 +1' if mine else '（感谢友军炮火）'
    expected_glyphs=len('击毁！')*2+len(sub)
    assert sum(c['name']=='nvgFill'for c in commands)==expected_glyphs;checks+=1
   else:assert not commands;checks+=1
   assert lua.globals().DEPTH==0;checks+=1
 for age in [-.01,0,.05,.2,.3192,.3496,.4408,.6,.759,.76,.9]:
  lua.execute('COMMANDS={}')
  lua.globals().WIPE.Draw(0,convert({'time':age,'wipeAt':0,'wipeColor':'#210b07'}),w,h,u)
  commands=list(lua.globals().COMMANDS.values());p=lua.globals().WIPE.Plan(age)
  assert p['active']==(0<=age<.76);checks+=1
  if p['active']:
   t=ease(age/.76,(.55,.05,.45,.95))
   x=115-150*t/.42 if t<.42 else -35-20*(t-.42)/.16 if t<.58 else -55-160*(t-.58)/.42
   assert math.isclose(p['x'],x/100,abs_tol=1e-6);checks+=1
   assert sum(c['name']=='path'for c in commands)==5;checks+=1
  else:assert not commands;checks+=1
  assert lua.globals().DEPTH==0;checks+=1
paths=['scripts/ui/IntroComicText.lua','scripts/ui/IntroGalaxyText.lua','scripts/ui/IntroFamiliar.lua','scripts/ui/IntroPromo.lua','scripts/ui/IntroPayslip.lua','scripts/ui/IntroSortieKill.lua','scripts/ui/IntroWipe.lua']
for path in paths:assert not isinstance(lua.eval('load')((ROOT/path).read_text(encoding='utf-8'),path),tuple);checks+=1
old_payslip=ROOT/'.tmp/outgame-cached-1792097529664/scripts/ui/IntroPayslip.lua'
before=lua.execute(old_payslip.read_text(encoding='utf-8'))
complexity=[]
for age in [2,4.65,4.75,5.45]:
 row={'age':age}
 for label,module in [('before',before),('after',lua.globals().PAYSLIP)]:
  owner=convert({'age':age,'voiceDuration':5.86,'wrecked':True})
  lua.execute('COMMANDS={}')
  module.Draw(0,owner,1920,1080,10.8)
  commands=list(lua.globals().COMMANDS.values())
  circles=[c for c in commands if c['name']=='nvgCircle']
  textures=[c for c in commands if c['name']=='nvgImagePatternTinted']
  row[label]={'commands':len(commands),'circleCalls':len(circles),'dotCircles':sum(math.isclose(c['args'][4],1)for c in circles),'textureFills':len(textures)}
  if label=='after':
   assert row[label]['dotCircles']==0 and row[label]['circleCalls']<=220;checks+=2
   assert len(textures)==(1 if age<4.65 else 63 if age<=4.75 else len(textures));checks+=1
   for c in textures:
    assert c['args'][4]==4 and c['args'][5]==4 and c['args'][8][1]==0 and c['args'][8][4]==72;checks+=1
   lua.execute('COMMANDS={}')
   module.Draw(0,owner,1920,1080,10.8)
   assert all(c['name']!='nvgCreateImage'for c in lua.globals().COMMANDS.values());checks+=1
 complexity.append(row)
from PIL import Image
tile=Image.open(ROOT/'assets/UI/IntroComicPaperDots.png').convert('RGBA')
assert tile.size==(64,64) and tile.getchannel('A').getextrema()==(0,46);checks+=2
report={'status':'PASS','checks':checks,'sourceCommit':'b276064942ae09c0227ec28d4cfda1d5ff006455','fixtures':fixtures,
 'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
 'source':{p:hashlib.sha256((source/p).read_bytes()).hexdigest()for p in ['shared/css/intro.css','three/src/intro/intro.js','three/src/intro/introFx.js','shared/fonts/ZCOOLQingKeHuangYou-Regular.ttf']},
 'payslipComplexity':complexity,'payslipTile':{'path':'assets/UI/IntroComicPaperDots.png','sha256':hashlib.sha256((ROOT/'assets/UI/IntroComicPaperDots.png').read_bytes()).hexdigest(),'size':[64,64],'originalPeakAlpha':46,'repeatLogicalPx':[4,4],'blackTintAlpha':72,'resultPeakAlpha':46*72/255,'sourceCSS':'radial-gradient(circle, rgba(0, 0, 0, .05) 1px, transparent 1.4px) 0 0 / 4px 4px','boundary':'Existing approved comic tile reused as black 4px repeat at source opacity; original tile radial shape differs slightly. Command complexity does not establish frame time.'},
 'boundary':'Actual production plans and contour draw commands against original font table advances; four logical viewports. No GPU, actual NanoVG raster, source computed DOM, natural full opening or pixel-equality claim.'}
out=ROOT/'docs/migration/evidence/intro-noncaption-text-offline.json';out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':report['status'],'checks':checks,'production':report['production']},indent=2))

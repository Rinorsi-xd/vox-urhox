"""Execute frozen actVirtues/shakeDom and actual Lua comic draw calls; no GPU."""
import hashlib,json,math,os,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
reference=json.loads(subprocess.check_output(['node','tools/migration/source-intro-comic-motion.mjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().GLYPHS=lua.table_from(json.loads((ROOT/'assets/Intro/Fonts/TitleGlyphs.json').read_text(encoding='utf-8')),recursive=True)
lua.execute('''
package.path='scripts/?.lua;'..package.path
EVENTS={};STATE={alpha=1};STACK={};CAPTURE=false
local function Event(kind,v)v=v or {};v.kind=kind;v.alpha=STATE.alpha;v.panels=PANELS or false;EVENTS[#EVENTS+1]=v end
package.loaded['ui.SourceDraw']={Path=function(_,p)Event('path',{points=p})end,
 Gradient=function()Event('paper')end,Rect=function()Event('rect')end,Text=function(_,text)Event('text',{text=text})end,Color=function(c)return c end}
local handles={city=1,order=2,workshop=3,family=4,dove=5,dove_red=6}
package.loaded['urhox-libs/UI/Core/ImageCache']={Get=function(path)return handles[path] end,GetSize=function(path)if path=='dove' or path=='dove_red' then return 800,1200 elseif path=='family' then return 1400,800 else return 1920,1080 end end}
NVG_IMAGE_REPEATX=1;NVG_IMAGE_REPEATY=2
function nvgSave()STACK[#STACK+1]={alpha=STATE.alpha}end
function nvgRestore()assert(#STACK>0);STATE=table.remove(STACK)end
function nvgGlobalAlpha(_,a)STATE.alpha=a end
function nvgTranslate(_,x,y)Event('translate',{x=x,y=y})end
function nvgRotate(_,angle)Event('rotate',{angle=angle})end
function nvgCreateImage(_,path)return 101 end
function nvgDeleteImage(_,handle)Event('delete',{handle=handle})end
function nvgRGBA(...)return {...}end
function nvgImagePattern(_,x,y,w,h,angle,handle,alpha)local path=handle;for name,id in pairs(handles)do if id==handle then path=name end end;Event('image',{x=x,y=y,w=w,h=h,angle=angle,handle=path});return {}end
for _,name in ipairs({'nvgFillPaint','nvgFill','nvgFillColor','nvgStrokeColor','nvgStrokeWidth','nvgStroke'})do _G[name]=function()end end
COMIC=require 'ui.IntroComic';MOTION=require 'ui.IntroComicMotion';OPACITY=require 'ui.IntroOpacity'
function DrawCase(width,height,age,capture,rootAlpha)
 EVENTS={};STATE={alpha=1};STACK={};CAPTURE=capture
 local owner={shot='leave',age=age,time=3+age,log={{shot='prosper',t=0},{shot='order',t=1.5},{shot='leave',t=3}},data={images={city='city',order='order',workshop='workshop',family='family',dove='dove'}},host={}}
 owner.host.DrawCapture=function(_,name,r)Event('capture',{name=name,rect=r});return CAPTURE end
 local page={owner=owner};OPACITY.Push(1,rootAlpha)
 COMIC.BeginPanels(page,1,width,height,height/100);COMIC.Draw(page,1,width,height,height/100);COMIC.EndPanels(1)
 OPACITY.Pop(1);assert(#STACK==0 and STATE.alpha==1,'draw state leak')
 return EVENTS,page
end
package.loaded['ui.SourceParagraph']={New=function()return {Measure=function()return {height=20}end,
 Draw=function(_,_,text,x,y,width)Event(text:sub(1,1)=='*' and 'comic-fine' or 'caption',{x=x,y=y,width=width})end}end}
package.loaded['ui.IntroTypography']={Begin=function()end,face='game'}
package.loaded['ui.IntroTitleCard']={Plan=function(id)return {id=id}end,Draw=function()Event('title')end}
package.loaded['core.ResourceData']={Read=function()return GLYPHS end}
package.loaded['ui.IntroFilm']={Under=function()end,Over=function()end}
package.loaded['ui.IntroPage']={Image=function()Event('page-image')end}
function nvgScale()end
function nvgIntersectScissor()end
function nvgBeginPath()end
function nvgCircle()end
function nvgRadialGradient()return {}end
for _,name in ipairs({'nvgMoveTo','nvgLineTo','nvgBezierTo','nvgClosePath','nvgPathWinding'})do _G[name]=function()end end
NVG_SOLID=1;NVG_HOLE=2
local impact=require 'ui.IntroComicText';local no,bang=impact.No,impact.Bang
impact.No=function(...)Event('text',{text='NO!'});return no(...)end
impact.Bang=function(...)Event('text',{text='砰——！'});return bang(...)end
NVG_ALIGN_CENTER=1
local beginPanels,endPanels=COMIC.BeginPanels,COMIC.EndPanels
COMIC.BeginPanels=function(...)assert(not PANELS);beginPanels(...);PANELS=true end
COMIC.EndPanels=function(...)assert(PANELS);PANELS=false;endPanels(...)end
PROMO=require 'ui.IntroPromo'
function PromoCase(id,age)
 EVENTS={};STATE={alpha=1};STACK={};PANELS=false
 local owner={shot=id,age=age,time=4+age,caption='approved caption',log={{shot='prosper',t=0},{shot='order',t=1.5},{shot='leave',t=3}},data={images={city='city',order='order',workshop='workshop',family='family',dove='dove',dove_red='dove_red'}}}
 if id=='no' then owner.log[#owner.log+1]={shot='no',t=4}end
 PROMO.Draw({owner=owner,k=1},1,1920,1080,10.8)
 assert(not PANELS and #STACK==0 and STATE.alpha==1,'Promo panel/alpha state leak')
 return EVENTS
end
function DrawBurstCase(width,height,age,rootAlpha)
 EVENTS={};STATE={alpha=1};STACK={}
 local owner={shot='no',age=age,time=4+age,log={{shot='prosper',t=0},{shot='no',t=4}},data={images={dove_red='dove_red'}}}
 local page={owner=owner};OPACITY.Push(1,rootAlpha)
 require('ui.IntroComicBurst').Draw(page,1,width,height)
 OPACITY.Pop(1);assert(#STACK==0 and STATE.alpha==1,'burst state leak')
 return EVENTS,page,owner
end
''')
checks=0
def check(condition,message):
 global checks
 checks+=1
 assert condition,message
def near(a,b,message):check(abs(a-b)<1e-6,message+f': {a} != {b}')
def table(value):return lua.table_from(value,recursive=True)
def unpack(v):
 if hasattr(v,'items'):
  keys=list(v.keys());return [unpack(v[i])for i in range(1,len(keys)+1)]if keys and all(isinstance(k,int)for k in keys)else {k:unpack(x)for k,x in v.items()}
 return v
moves=[{'x':-.7,'s1':1.12,'s2':1.03},{'x':1.4,'y':-.6,'bob':5,'r':3,'w':1.9},{'y':.25,'s1':1,'s2':1.1},{'x':-.5,'s1':1.04,'s2':1},{'x':.6,'s1':1.08,'s2':1,'bob':.8,'w':2.4}]
for case in reference['cases']:
 shakes=[e for e in case['events']if e.get('options',{}).get('duration')==260]
 check(len(shakes)==3,'source shakes each entering panel')
 for index,shake in enumerate(shakes):
  frames=shake['frames'];page=lua.table();at=case['marks'][index]['at']
  expected=[tuple(float(n)for n in re.findall(r'\* (-?\d+(?:\.\d+)?(?:e[+-]?\d+)?)',frame['translate']))for frame in frames]
  for fraction in [0,.05,.1,.15,.55,.99,1,1.1]:
   owner=table({'shot':case['marks'][index]['mark'],'time':at+fraction*.26,'age':fraction*.26,'log':[{'shot':case['marks'][index]['mark'],'t':at}]})
   x,y=lua.globals().MOTION.Shake(page,owner,10.8)
   if fraction>=1:near(x,0,'shake ends x');near(y,0,'shake ends y');continue
   p=fraction*10;j=min(9,int(p));mix=p-j
   near(x,(expected[j][0]+(expected[j+1][0]-expected[j][0])*mix)*10.8,'linear source keyframe x')
   near(y,(expected[j][1]+(expected[j+1][1]-expected[j][1])*mix)*10.8,'linear source keyframe y')
 no=next(e for e in case['events']if e.get('options',{}).get('duration')==520)
 expected=[tuple(float(n)for n in re.findall(r'\* (-?\d+(?:\.\d+)?(?:e[+-]?\d+)?)',frame['translate']))for frame in no['frames']]
 page=lua.table();no_at=case['noAt']-.5
 for fraction in [-.1,0,.05,.5,.99,1,1.1]:
  owner=table({'shot':'no','time':case['noAt']+fraction*.52,'age':.5+fraction*.52,'log':[{'shot':'no','t':no_at}]})
  x,y=lua.globals().MOTION.Shake(page,owner,10.8)
  if fraction<0 or fraction>=1:near(x,0,'NO shake outside cue x');near(y,0,'NO shake outside cue y');continue
  p=fraction*10;j=min(9,int(p));mix=p-j
  near(x,(expected[j][0]+(expected[j+1][0]-expected[j][0])*mix)*10.8,'actual frozen NO shake x')
  near(y,(expected[j][1]+(expected[j+1][1]-expected[j][1])*mix)*10.8,'actual frozen NO shake y')
 for sample in case['samples']:
  for i,layer in enumerate(sample['layers']):
   mark=case['marks'][0 if i<2 else 1 if i==2 else 2]
   age=sample['time']-mark['at'];values=[float(n)for n in re.findall(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?',layer['transform'])]
   for width,height in [(1920,1080),(2400,1080),(1440,1080)]:
    rect={'x':17,'y':29,'w':width*.17,'h':height*.62};iw,ih=(800,1200)if i==1 else (1400,800)if i==4 else (1920,1080)
    contain=i in [1,4];r=lua.globals().MOTION.Layer(table(rect),age,table(moves[i]),iw,ih,contain)
    dx,dy,scale,deg=values;angle=deg*math.pi/180;fit=(min if contain else max)(rect['w']/iw,rect['h']/ih)
    left=-iw*fit/2;top=rect['h']/2-ih*fit if contain else -ih*fit/2
    near(r['x'],17+rect['w']/2+dx*.01*rect['w']+(math.cos(angle)*left-math.sin(angle)*top)*scale,'actual frozen layer image x')
    near(r['y'],29+rect['h']/2+dy*.01*rect['h']+(math.sin(angle)*left+math.cos(angle)*top)*scale,'actual frozen layer image y')
    near(r['w'],iw*fit*scale,'actual frozen layer image width');near(r['h'],ih*fit*scale,'actual frozen layer image height')
for width,height in [(1920,1080),(2400,1080),(1440,1080)]:
 for age in [0,.05,.13,.26,1,4,8]:
  for capture in [False,True]:
   events,page=lua.globals().DrawCase(width,height,age,capture,.37);events=unpack(events)
   check(len([e for e in events if e['kind']=='capture'])==1,'actual leave panel requests one capture')
   check(len([e for e in events if e['kind']=='image'and e['handle']=='workshop'])==(0 if capture else 1),'capture success or workshop fallback')
   c=next(e for e in events if e['kind']=='capture')['rect'];pw=width*.455;ph=height*.415
   expected=lua.globals().MOTION.Layer(table({'x':-pw*.06,'y':-ph*.06,'w':pw*1.12,'h':ph*1.12}),age,table(moves[3]),pw*1.12,ph*1.12,False)['box']
   for name in ['x','y','w','h']:near(c[name],expected[name],'captured background follows same im transform')
   check(len(c['points'])==8,'capture uses original polygon clip')
   fine=next(e for e in events if e['kind']=='comic-fine')
   near(fine['x'],pw*.06+1.35*(height/100)*.8,'fine print follows source panel-local left and padding')
   near(fine['width'],pw*.91-2*1.35*(height/100)*.8,'fine print uses source available width for wrapping')
   check(0<=fine['alpha']<=.37,'fine print inherits panel entrance and parent opacity')
   near(next(e for e in events if e['kind']=='paper')['alpha'],.37,'paper composes root opacity')
# Actual draw owns and releases only its cached dot images/shake samples.
lua.globals().COMIC.Dispose(page)
check(page['comicPatterns']is None and page['comicShakes']is None,'comic disposal clears owned caches')
check(page['comicFine']is None,'comic disposal releases cached fine print layout')
for age in [0,.04,.08,.16,.2]:
 opacity=lua.globals().MOTION.PaperOpacity(table({'age':age,'time':age,'log':[{'shot':'prosper','t':0}]}))
 check(0<=opacity<=1,'paper entrance bounded')
 if age==0:near(opacity,0,'paper starts transparent')
 if age>=.16:near(opacity,1,'paper ends opaque')
for shot in ['prosper','order','leave','no']:
 for age in [0,.05,.26,.4,.5,.55,1.1]:
  events=unpack(lua.globals().PromoCase(shot,age))
  check(len([e for e in events if e['kind']=='caption'and not e['panels']])==1,'actual Promo keeps approved caption outside panels')
  check(all(e['panels']for e in events if e['kind']=='paper'),'actual Promo paper belongs to panels')
  check(all(not e['panels']for e in events if e['kind']=='title'),'actual Promo title cards outside panels')
  if shot=='no'and age>=.5:
   check(all(e['panels']for e in events if e.get('text')=='砰——！'),'actual Promo impact SFX inside panels')
   check(all(not e['panels']for e in events if e.get('text')=='NO!'),'actual Promo NO slam outside panels')
  if shot=='no':
   check(len([e for e in events if e['kind']=='title'])==(3 if age<.15 else 0),'all three accumulated titles retain source 150ms exit window')
   doves=[e for e in events if e['kind']=='image' and e['handle'] in ['dove','dove_red']]
   check(all(e['handle']==('dove_red' if age>=.4 else 'dove') for e in doves),'red image switches at source hit cue')
BURST=lua.eval("package.loaded['ui.IntroComicBurst']")
for case in reference['bursts']:
 particles=BURST.Particles(table(case['box']),case['seed'])
 check(len(particles)==36 and case['hidden']=='hidden','source burst emits 36 and hides original')
 for particle,source in zip(particles.values(),case['particles']):
  dx,dy=[float(n) for n in re.findall(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?',source['frames'][1]['translate'])]
  rotation=float(source['frames'][1]['rotate'][:-3])
  near(particle['dx'],dx,'actual frozen _burst displacement x');near(particle['dy'],dy,'actual frozen _burst displacement y')
  near(particle['rotation'],rotation,'actual frozen _burst rotation');near(particle['duration'],source['options']['duration']/1000,'actual frozen _burst lifetime')
for width,height in [(1920,1080),(2400,1080),(1440,1080)]:
 for age in [.49,.5,.7,1,1.69,1.7]:
  events,page,owner=lua.globals().DrawBurstCase(width,height,age,.37);events=unpack(events)
  images=[e for e in events if e['kind']=='image']
  expected=0 if age<.5 else sum(age-.5<p['duration'] for p in page['comicBurst']['particles'].values())
  check(len(images)==expected,'actual burst draws only live source fragments')
  check(all(e['handle']=='dove_red' for e in images),'every fragment uses warmed red bitmap')
  check(all(0<=e['alpha']<=.37 for e in images),'fragment opacity composes parent fade')
  lua.globals().COMIC.Dispose(page);check(page['comicBurst'] is None,'burst cache released with comic')
exit=reference['titleExit'];check(exit['options']['duration']==150 and exit['options']['easing']=='ease-in','original title exit duration/curve')
check(exit['frames']==[{'opacity':1,'scale':1},{'opacity':0,'scale':1.08}],'original title exit endpoints')
lua.execute('''
package.loaded['ui.IntroTitleCard']=nil
package.loaded['ui.IntroGlyphs']={Width=function(text,size,spacing)return utf8.len(text)*(size*.5+spacing)end,
 Ascent=function()return .8 end,Descent=function()return .2 end,Glyph=function()return {advance=.5}end,
 Draw=function()EVENTS[#EVENTS+1]={kind='glyph',alpha=STATE.alpha}end}
package.loaded['ui.SourceDraw'].Width=function(_,text,size,_,spacing)return utf8.len(text)*(size*.5+spacing)end
for _,name in ipairs({'nvgSkewX','nvgMoveTo','nvgLineTo','nvgClosePath'})do _G[name]=function()end end
TITLE=require 'ui.IntroTitleCard'
function DrawTitleExit(age)
 EVENTS={};STATE={alpha=1};STACK={};OPACITY.Push(1,.37)
 TITLE.Draw(1,1920,1080,10.8,10,TITLE.Plan('prosper'),age)
 OPACITY.Pop(1);assert(#STACK==0 and STATE.alpha==1,'title exit state leak')
 return EVENTS
end
''')
for age in [0,.015,.075,.149,.15,.2]:
 lo,hi=0,1
 for _ in range(60):
  mid=(lo+hi)/2;x=3*(1-mid)**2*mid*.42+3*(1-mid)*mid*mid+mid**3
  if x<min(1,age/.15):lo=mid
  else:hi=mid
 q=(lo+hi)/2;progress=3*(1-q)*q*q+q**3
 alpha,scale=lua.globals().TITLE.Exit(age)
 check(abs(alpha-(1-progress))<1e-4 and abs(scale-(1+.08*progress))<1e-5,'actual TitleCard source ease-in exit')
 glyphs=[e for e in unpack(lua.globals().DrawTitleExit(age)) if e['kind']=='glyph']
 check(bool(glyphs)==(age<.15),'actual TitleCard exits at 150ms')
 check(all(abs(e['alpha']-.37*alpha)<1e-8 for e in glyphs),'actual TitleCard nested glyphs compose exit/root opacity')
data=json.loads((ROOT/'assets/Intro/Intro.json').read_text(encoding='utf-8'))
lua.globals().DATA=table(data)
lua.execute('''
package.loaded['urhox-libs/UI']={}
package.loaded['core.Coord']={}
package.loaded['core.ResourceData']={Read=function()return DATA end}
package.loaded['ui.IntroTypography'].Dependencies=function()return {}end
DEPS=require('intro.IntroSession').Dependencies()
local images=package.loaded['urhox-libs/UI/Core/ImageCache'];local loaded=false
images.GetContext=function()return 1 end;images.IsLoaded=function()return loaded end
images.Get=function(path)assert(path==DATA.images.dove_red);loaded=true;return 6 end
images.GetSize=function()return 1024,1024 end
RELEASES=0;images.Release=function(path)assert(path==DATA.images.dove_red);loaded=false;RELEASES=RELEASES+1 end
time={frameNumber=1}
local W=require 'ui.IntroImageWarmup';local portrait={}
WARM=W.New({dove_red=DATA.images.dove_red},function()return portrait end)
assert(WARM:Step(1,true));assert(WARM.ready and WARM.index==1)
assert(WARM:Step(1,true));WARM:Dispose();WARM:Dispose()
assert(RELEASES==1,'derived image released exactly once')
''')
check(data['images']['dove_red'] in list(lua.globals().DEPS.values()),'actual session download dependency includes red dove')
check(lua.globals().RELEASES==1,'actual warmup uploads and releases red image once')
from PIL import Image
original=Image.open(ROOT/'assets/Intro/Images/dove.png').convert('RGBA')
derived=Image.open(ROOT/'assets/Intro/Images/dove_red.png').convert('RGBA')
check(original.size==derived.size and original.getchannel('A').tobytes()==derived.getchannel('A').tobytes(),'derived image preserves exact source alpha and dimensions')
out={'result':'PASS','checks':checks,'sourceCommit':reference['baseline']['commit'],'sourceHashes':reference['sourceHashes'],
 'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in ['scripts/ui/IntroComic.lua','scripts/ui/IntroComicMotion.lua','scripts/ui/IntroPromo.lua','scripts/ui/IntroComicBurst.lua','scripts/ui/IntroTitleCard.lua','scripts/ui/IntroComicText.lua','scripts/ui/IntroGlyphs.lua','assets/Intro/Fonts/TitleGlyphs.json','assets/Intro/Intro.json','assets/Intro/Images/dove_red.png','tools/migration/check-intro-comic-motion.py','tools/migration/source-intro-comic-motion.mjs','tools/migration/bake-intro-red-dove.py']},
 'boundary':'Actual frozen JS actVirtues/shakeDom/_burst/titleCard exit plus Lua motion, Comic/Promo/Burst/TitleCard draws and real Session dependencies/ImageWarmup release. Mocked NanoVG/image upload/host capture. No GPU/build/natural Web, browser color rounding or visual acceptance.'}
(ROOT/'docs/migration/evidence/intro-comic-motion-offline.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print(json.dumps(out))

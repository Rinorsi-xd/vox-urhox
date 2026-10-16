"""Frozen actFamiliar timings versus production plan and drawing doubles."""
import hashlib,json,os,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
source=ROOT/'.tmp/outgame-source-2026-10-15T12-35-57-243Z/three/src/intro/intro.js'
text=source.read_text(encoding='utf-8').split('async actFamiliar()')[1].split('async actGalaxy()')[0]
assert text.count('await this.wait( 0.34 )')==2
assert "duration: 3000" in text and 'Math.sin( t * 2.2 ) * 0.008' in text
assert "{ scale: 2.4, rotate:" in text and 'delay: 120' in text and 'duration: 220' in text
lua=LuaRuntime(unpack_returned_tuples=True)
def convert(value):
 if isinstance(value,dict):return lua.table_from({key:convert(item)for key,item in value.items()})
 if isinstance(value,list):return lua.table_from([convert(item)for item in value])
 return value
lua.globals().GLYPHS=convert(json.loads((ROOT/'assets/Intro/Fonts/TitleGlyphs.json').read_text(encoding='utf-8')))
lua.execute("package.path='scripts/?.lua;'..package.path;package.loaded['ui.SourceDraw']={};package.loaded['urhox-libs/UI/Core/ImageCache']={};package.loaded['ui.IntroTypography']={face='game',Begin=function()end}")
lua.execute("package.loaded['core.ResourceData']={Read=function()return GLYPHS end}")
module=lua.eval("require('ui.IntroFamiliar')")[0]
def ease(x,c):
 if x<=0:return 0
 if x>=1:return 1
 def f(t,a,b):return 3*(1-t)**2*t*a+3*(1-t)*t*t*b+t**3
 lo,hi=0.,1.
 for _ in range(60):
  m=(lo+hi)/2
  if f(m,c[0],c[2])<x:lo=m
  else:hi=m
 return f((lo+hi)/2,c[1],c[3])
checks=0
for frame in range(1201):
 age=frame/300;plans=module.Plan(age)
 assert len(plans)==sum(age>=delay for delay in [0,.34,.68]);checks+=1
 for i,p in plans.items():
  delay=[0,.34,.68][i-1];t=age-delay
  expected={'age':t,'entry':ease(t/.3,(.2,.9,.3,1.05)),'alpha':ease(t/.3,(.2,.9,.3,1.05)),
   'scale':(1.14-.14*min(1,t/3))if i==1 else(1+.12*min(1,t/3))if i==2 else 1,
   'imageX':.02-.04*min(1,t/3)if i==2 else 0,'fx':ease((t-.12)/.22,(.2,.9,.3,1.3))}
  for key,value in expected.items():assert abs(p[key]-value)<2e-6,(age,i,key,p[key],value);checks+=1
draw=lua.execute('''
local D=package.loaded['ui.SourceDraw'];local Images=package.loaded['urhox-libs/UI/Core/ImageCache'];local checks,captures,depth=0,0,0
function D.Width(_,text,size,_,spacing)return utf8.len(text)*(size*.6+(spacing or 0))end
for _,name in ipairs({'Rect','Line','Text','Path','Gradient'})do D[name]=function()end end
function D.Color(c)return c end
function Images.Get(_)return 1 end;function Images.GetSize(_)return 1024,1024 end
for _,name in ipairs({'nvgBeginPath','nvgIntersectScissor','nvgCircle','nvgRect','nvgRoundedRect','nvgFillPaint','nvgFillColor','nvgFill','nvgStrokeWidth','nvgStrokeColor','nvgStroke','nvgTranslate','nvgScale','nvgRotate','nvgGlobalAlpha','nvgMoveTo','nvgLineTo','nvgBezierTo','nvgClosePath','nvgPathWinding'})do _G[name]=function()end end
function nvgSave()depth=depth+1 end;function nvgRestore()depth=depth-1;assert(depth>=0)end
function nvgImagePattern(...)return {}end;function nvgRGBA(...)return {...}end;function nvgCreateImage(...)return 1 end
NVG_IMAGE_REPEATX=1;NVG_IMAGE_REPEATY=2
for _,aspect in ipairs({{1920,1080},{2400,1080},{1920,1200}})do
 for _,age in ipairs({0,.2,.339,.34,.5,.679,.68,1,2,4})do
  local page={owner={age=age,data={images={workshop='workshop',machinist_idle='person'}},host={DrawCapture=function(_,name,r)assert(name=='charge'or name=='wreck');assert(#r.points==8);captures=captures+1;return true end}}}
  require('ui.IntroFamiliar').Draw(page,1,aspect[1],aspect[2],aspect[2]/100)
  assert(depth==0);checks=checks+1
 end
end
return {checks=checks,captures=captures}
''')
checks+=draw['checks']
paths=['scripts/ui/IntroFamiliar.lua','scripts/ui/IntroPromo.lua','scripts/ui/IntroComicText.lua','scripts/ui/IntroGalaxyText.lua']
for p in paths:assert not isinstance(lua.eval('load')((ROOT/p).read_text(encoding='utf-8'),p),tuple);checks+=1
result={'status':'PASS','checks':checks,'samples':1201,'drawCaptures':draw['captures'],'sourceCommit':'b276064942ae09c0227ec28d4cfda1d5ff006455','sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},'notVerified':['actual Web rendering','complete natural opening','pixel equality','true phone performance']}
(ROOT/'docs/migration/evidence/intro-familiar-offline.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))

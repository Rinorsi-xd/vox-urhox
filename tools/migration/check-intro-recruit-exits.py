"""Frozen source timeline against actual Lua Promo/TitleCard and OpeningHost camera calls."""
import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
reference=json.loads(subprocess.check_output(['node','tools/migration/source-intro-recruit-exits.mjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
def table(v):
 if isinstance(v,dict):return lua.table_from({k:table(x)for k,x in v.items()})
 if isinstance(v,list):return lua.table_from([table(x)for x in v])
 return v
lua.globals().GLYPHS=table(json.loads((ROOT/'assets/Intro/Fonts/TitleGlyphs.json').read_text(encoding='utf-8')))
lua.execute('''
package.path='scripts/?.lua;'..package.path
ALPHA=1;SCALE=1;STACK={};DRAWS={};CAPTIONS=0;GLYPHDRAWS=0
package.loaded['core.ResourceData']={Read=function()return GLYPHS end}
package.loaded['core.Coord']={Vec=function(x,y,z)return{x=-x,y=y,z=z}end}
package.loaded['construction.Blueprint']={}
package.loaded['app.SceneLoader']={New=function()return{Update=function()end}end}
package.loaded['ui.SourceDraw']={Width=function(_,s,size,_,spacing)return utf8.len(s)*(size*.6+(spacing or 0))end,
 Text=function()end,Color=function(c)return c end,Rect=function()end,Line=function()end,Path=function()end,Gradient=function()end}
package.loaded['ui.SourceParagraph']={New=function()return{Measure=function()return{height=20}end,Draw=function()CAPTIONS=CAPTIONS+1 end}end}
package.loaded['ui.IntroTypography']={face='game',Begin=function()end}
package.loaded['ui.IntroPage']={Image=function()end}
package.loaded['ui.IntroFilm']={Under=function()end,Over=function()end}
package.loaded['ui.IntroPromoFx']={Draw=function()end,MottoBlack=function()return 0 end}
package.loaded['ui.IntroMotto']={Draw=function()DRAWS[#DRAWS+1]={text='MOTTO',alpha=ALPHA,scale=SCALE}end}
NVG_ALIGN_CENTER=1;NVG_ALIGN_RIGHT=2;NVG_CW=1;NVG_SOLID=1;NVG_HOLE=2
for _,name in ipairs({'nvgBeginPath','nvgMoveTo','nvgLineTo','nvgBezierTo','nvgClosePath','nvgPathWinding','nvgFillColor','nvgFill','nvgStrokeWidth','nvgStrokeColor','nvgStroke','nvgTranslate','nvgRotate','nvgRect','nvgRoundedRect','nvgIntersectScissor','nvgCircle','nvgFillPaint','nvgArc','nvgSkewX'})do _G[name]=function(...)for _,v in ipairs({...})do if type(v)=='number'then assert(v==v and math.abs(v)<math.huge)end end end end
function nvgSave()STACK[#STACK+1]={ALPHA,SCALE}end
function nvgRestore()local s=table.remove(STACK);assert(s,'draw stack underflow');ALPHA,SCALE=s[1],s[2]end
function nvgGlobalAlpha(_,a)ALPHA=a end
function nvgScale(_,x,y)SCALE=SCALE*x end
function nvgRGBA(...)return{...}end
function nvgRadialGradient()return{}end
local Glyph=require 'ui.IntroGlyphs';local glyphDraw=Glyph.Draw
Glyph.Draw=function(...)GLYPHDRAWS=GLYPHDRAWS+1;return glyphDraw(...)end
local Card=require 'ui.IntroTitleCard';local draw=Card.Draw
Card.Draw=function(vg,w,h,u,age,plan,...)
 DRAWS[#DRAWS+1]={text=plan.text,alpha=ALPHA,scale=SCALE,age=age}
 return draw(vg,w,h,u,age,plan,...)
end
PROMO=require 'ui.IntroPromo';SHOTS=require 'intro.IntroShots';HOST=require 'app.OpeningHost'
function Render(promo,I,w,h,parent)
 DRAWS={};CAPTIONS=0;GLYPHDRAWS=0;ALPHA=1;SCALE=1;STACK={}
 local opacity=require 'ui.IntroOpacity';opacity.Push(0,parent)
 promo.Draw({owner=I,k=1},0,w,h,h/100);opacity.Pop(0)
 assert(#STACK==0 and ALPHA==1 and SCALE==1,'unbalanced outer state')
 return DRAWS,CAPTIONS,GLYPHDRAWS
end
function Camera(hostModule,shotsModule,id,age,I,hit)
 package.loaded['intro.IntroShots']=shotsModule
 local host=hostModule.New({});local state=host.state;state.activeScene='crater';state.cameraLift=0
 local casts,updates=0,0;local body={}
 state.world={space={Raycast=function(_,origin,direction,length,ignore)
  assert(ignore==body);casts=casts+1
  if hit and casts==1 then return{dist=1}end
 end}}
 state.session={combat={player={Position=function()return{66,2,-174}end},cart={vehicle={body=body}}},environment={Update=function(_,dt,node)assert(dt==1/60);updates=updates+1 end}}
 local camera={node={LookAt=function(self,p)self.look=p end}}
 host.CameraShot(id,age,I,camera)
 return camera,casts,updates
end
''')
checks=0;frames=0;camera_cases=0
def check(value,msg):
 global checks
 assert value,msg
 checks+=1
def close(a,b):return abs(a-b)<2e-6
def ease(t):
 lo,hi=0.,1.
 for _ in range(40):
  v=(lo+hi)/2;q=1-v;x=3*q*q*v*.42+3*q*v*v+v*v*v
  if x<t:lo=v
  else:hi=v
 v=(lo+hi)/2
 return 3*(1-v)*v*v+v*v*v
def fixture(case,t):
 names={'vo_n12':'recruit','vo_n13':'peacekeeper','vo_n14':'master','vo_n15':'mechanic','vo_n16':'motto','vo_n17':'disclaimer'}
 marks=[{'id':names[v['id']],'t':v['t']}for v in case['voices']if v['t']<=t+1e-9]
 shot=marks[-1]['id'];at=marks[-1]['t'];cards=[c for c in case['cards']if c['enter']<=t+1e-9]
 current=cards[-1]if cards else None
 big=current['text']if shot in ('recruit','peacekeeper','master','mechanic')else ''
 return {'shot':shot,'age':t-at,'time':t,'big':big,'wordAt':current['enter']-at if shot=='master'else 0,
  'voiceDuration':case['duration'],'caption':'批准字幕','log':[{'shot':m['id'],'t':m['t']}for m in marks],
  'data':{'durations':{'vo_n14':case['duration'],'vo_n16':8.87},'images':{}},'host':{}}
def expected(case,t):
 return [(c,0 if t<c['exit']else ease((t-c['exit'])/c['exitDuration']))for c in case['cards']if c['enter']<=t+1e-9 and t<c['exit']+c['exitDuration']-1e-9]
for case in reference['cases']:
 times={0.}
 for card in case['cards']:
  for q in [-.001,0,.25,.5,.99,1,1.01]:times.add(card['exit']+(q*card['exitDuration']if q>=0 else q))
 for t in sorted(times):
  for w,h in [(1920,1080),(2400,1080),(1440,1080)]:
   for parent in [1,.35]:
    draws,captions,glyphs=lua.globals().Render(lua.globals().PROMO,table(fixture(case,t)),w,h,parent)
    actual=list(draws.values());exp=expected(case,t);titles=[d for d in actual if d['text']!='MOTTO']
    check([d['text']for d in titles]==[c['text']for c,p in exp],f'visible title order {case["duration"]} {t}')
    for d,(c,p)in zip(titles,exp):
     check(close(d['alpha'],parent*(1-p)),f'exit alpha {c["text"]} {t}')
     check(close(d['scale'],1+.08*p),f'exit scale {c["text"]} {t}')
    check(captions==1,'approved caption exactly once')
    check(not titles or glyphs>0,'actual glyph draw reached')
    frames+=1
 for sample in case['camera']:
  age=sample['age'];n17=next(v['t']for v in case['voices']if v['id']=='vo_n17')
  I=table({'ready':True,'recruitAt':5,'time':5+age,'host':{}})
  I['host']=lua.eval('{GroundAt=function()return 0 end,SortieStatus=function()return{pos={66,2,-174},yaw=0}end}')
  shot='motto'if age<n17 else 'disclaimer'
  at,look,fov=lua.globals().SHOTS.Camera(shot,age-n17,I)
  check(all(close(at[i+1],v)for i,v in enumerate(sample['at'])),'source continuous camera position')
  check(all(close(look[i+1],v)for i,v in enumerate(sample['look']))and fov==sample['fov'],'source camera aim/fov')
  for hit in [False,True]:
   camera,casts,updates=lua.globals().Camera(lua.globals().HOST,lua.globals().SHOTS,shot,age-n17,I,hit)
   p=camera['node']['position'];target=sample['at']
   check(close(p['x'],-target[0])and close(p['y'],target[1]+(.5 if hit else 0))and close(p['z'],target[2]),'actual host pose and obstruction lift')
   check(casts==(2 if hit else 1)and updates==1,'actual host raycast ignores cart and updates environment')
   camera_cases+=1
oldroot=ROOT/'.tmp/outgame-cached-1792119610798';negatives=[]
oldpromo=lua.execute((oldroot/'scripts/ui/IntroPromo.lua').read_text(encoding='utf-8'))
case=reference['cases'][0];t=case['cards'][0]['exit']+.05;I=table(fixture(case,t))
draws,_,_=lua.globals().Render(oldpromo,I,1920,1080,1)
check(len(list(draws.values()))!=len(expected(case,t)),'frozen package reproduces discarded outgoing card');negatives.append('frozen Promo loses outgoing card')
oldshots=lua.execute((oldroot/'scripts/intro/IntroShots.lua').read_text(encoding='utf-8'))
check(oldshots.Camera('disclaimer',0,table({'host':{}}))is None,'frozen shot omits disclaimer pose');negatives.append('frozen IntroShots disclaimer pose')
oldhost=lua.execute((oldroot/'scripts/app/OpeningHost.lua').read_text(encoding='utf-8'))
I=table({'ready':True,'recruitAt':0,'time':22,'host':{}});I['host']=lua.eval('{GroundAt=function()return 0 end,SortieStatus=function()return{pos={66,2,-174},yaw=0}end}')
_,casts,_=lua.globals().Camera(oldhost,lua.globals().SHOTS,'disclaimer',.2,I,True)
check(casts==0,'frozen host skips disclaimer avoidance');negatives.append('frozen OpeningHost skips disclaimer raycast')
paths=['scripts/ui/IntroPromo.lua','scripts/ui/IntroRecruitTitles.lua','scripts/ui/IntroTitleCard.lua','scripts/ui/IntroGlyphs.lua','assets/Intro/Fonts/TitleGlyphs.json','scripts/ui/IntroOpacity.lua','scripts/ui/IntroGateMotion.lua','scripts/intro/IntroShots.lua','scripts/app/OpeningHost.lua']
result={'result':'PASS','checks':checks,'frames':frames,'cameraCases':camera_cases,'negativeControls':negatives,'source':reference,
 'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
 'boundary':'Actual frozen actRecruit and titleCard.out timeline; actual Lua Promo, TitleCard and glyph commands, opacity composition and state balance; actual OpeningHost.New/CameraShot and IntroShots.SafeCamera with static raycast adapters. Three voice lengths, six exits, three viewports and parent opacity. No GPU pixels, real native raycasts, rendered parity or user visual acceptance.'}
out=ROOT/'docs/migration/evidence/intro-recruit-exits-offline.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items()if k not in ('source','productionHashes')},ensure_ascii=False))

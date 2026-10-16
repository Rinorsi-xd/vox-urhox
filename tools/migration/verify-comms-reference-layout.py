"""Actual caller rendering coordinates against source homeViewport sizing."""
from pathlib import Path
import sys,json,re,subprocess,hashlib,os
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
cases=[(1920,1080,1,1,False),(2880,1800,1,1,False),(2880,1800,2,2,False),(3840,2160,2,2,False),(1600,900,1,1,False),(1280,720,1,.95,False),(2560,1080,1,1,False),(1200,900,1,1,False),(2400,1080,3,2.12,True),(1920,1080,2,1.73,True),(2048,1536,2,2,True)]
source=Path('D:/Rino_Project/Vox/shared/ui/homeScale.js')
ui_scale=Path('D:/Rino_Project/Vox/shared/ui/uiScale.js').read_text(encoding='utf-8-sig')
assert re.search(r'storyHud:\s*0\.62',ui_scale)
js="""import {homeViewport} from 'file:///D:/Rino_Project/Vox/shared/ui/homeScale.js';
let compact=false;globalThis.document={documentElement:{hasAttribute:()=>compact}};
const cases=JSON.parse(process.argv[1]);console.log(JSON.stringify(cases.map(c=>{const [w,h,dpr,,touch]=c;compact=touch&&Math.min(w,h)/dpr<=600;const v=homeViewport(w/dpr,h/dpr);return {scale:v.scale*dpr*(compact?.62:1),compact};})));"""
ref=json.loads(subprocess.check_output(['node','--input-type=module','-e',js,json.dumps(cases)],text=True))
codes={n:(ROOT/('scripts/ui/'+n+'.lua')).read_text(encoding='utf-8-sig') for n in ['CommsLayout','MissionHud','Epilogue']}
def run(case,height,cinematic,legacy=False):
 lua=LuaRuntime(unpack_returned_tuples=True)
 lua.globals().case=lua.table_from(case);lua.globals().cardHeight=height;lua.globals().cinematic=cinematic
 cc=codes.copy()
 if legacy:
  cc['CommsLayout']=cc['CommsLayout'].replace('return math.min(width/(reference*16/9),height/reference)*(compact and .62 or 1)','return 1')
 lua.globals().codes=lua.table_from(cc)
 deps=set()
 for code in cc.values():deps.update(re.findall(r"require\s*\(?\s*['\"]([^'\"]+)",code))
 lua.globals().deps=lua.table_from(sorted(deps))
 return lua.execute(r"""
local noop=function()end
for _,dep in ipairs(deps)do package.preload[dep]=function()return {}end end
package.path='scripts/?.lua;'..package.path
package.preload['ui.CommsLayout']=assert(load(codes.CommsLayout))
local classes={}
local Base={Extend=function(_,name)local cls={};cls.__index=cls;setmetatable(cls,{__call=function(_,props)return setmetatable({props=props},cls)end});classes[name]=cls;return cls end}
local w,h=case[1]/case[4],case[2]/case[4]
local UI={Widget=Base,Panel=Base,GetViewportSize=function()return w,h end}
package.loaded['urhox-libs/UI']=UI
package.loaded['controls.TouchMode']={Enabled=function()return case[5]end}
package.loaded['ui.SourceDraw']=setmetatable({Color=function(c)return c end},{__index=function()return noop end})
package.loaded['ui.IntroTypography']={Begin=noop}
package.loaded['ui.MissionPrompt']={New=function()return {Render=noop}end}
package.loaded['ui.MissionBanner']={Draw=noop}
package.loaded['ui.EpilogueMotion']={Now=function()return 0 end}
package.loaded['core.ResourceData']={Read=function()return {images={chairman_cut={path='chairman'}},data={}}end}
local tx,ty,sx,sy=0,0,1,1;local stack={}
nvgSave=function()stack[#stack+1]={tx,ty,sx,sy}end
nvgRestore=function()local s=table.remove(stack);tx,ty,sx,sy=table.unpack(s)end
nvgTranslate=function(_,x,y)tx=tx+x*sx;ty=ty+y*sy end
nvgScale=function(_,x,y)sx=sx*x;sy=sy*y end
nvgGlobalAlpha=noop;nvgBeginPath=noop;nvgRect=noop;nvgFillPaint=noop;nvgFill=noop
nvgCreateImage=function()return 1 end;nvgImagePatternTinted=noop;nvgRGBA=noop
NVG_IMAGE_REPEATX=1;NVG_IMAGE_REPEATY=2
local capture={}
package.loaded['ui.CommsCard']={Height=function()return cardHeight end,Draw=function(_,card,x,y,width,height,k)
 capture[#capture+1]={x=(tx+x*sx)*case[4],y=(ty+y*sy)*case[4],w=width*k*sx*case[4],h=height*k*sy*case[4],font=19*k*sy*case[4]}
end}
graphics={GetWidth=function()return case[1]end,GetHeight=function()return case[2]end,GetDPR=function()return case[3]end}
assert(load(codes.MissionHud))()
local mission={rules={StepSpec=function()return nil end,time=0},voice={card={who='boss',text='合同改成长期的'},time=10},player={alive=true},boss=cinematic and {cinematic=true}or nil,level={no='01'}}
local page=setmetatable({session={touch=case[5],story=mission},GetAbsoluteLayout=function()return {x=0,y=0,w=w,h=h}end},classes.VoxMissionHud)
page:Render(1)
assert(load(codes.Epilogue))()
page=setmetatable({owner={rules={current={kind='say'},time=1,age=1},voice=mission.voice,motion={pages={}}}},classes.VoxStoryEpilogue)
page:Render(1)
return capture
""")
checks=0;rows=[]
for case,expected in zip(cases,ref):
 for height in [196,360]:
  for cinematic in [False,True]:
   actual=run(case,height,cinematic)
   for i,label in [(1,'mission'),(2,'epilogue')]:
    a=dict(actual[i]);k=expected['scale'];bottom=(case[1]*.09+14*k) if label=='mission' and cinematic else (64 if label=='mission' else 24)*k
    for key,want in {'x':20*k,'y':case[1]-bottom-height*k,'w':646*k,'h':height*k,'font':19*k}.items():
     assert abs(a[key]-want)<1e-7,(case,label,key,a[key],want);checks+=1
    assert a['x']>=0 and a['y']>=0 and a['x']+a['w']<=case[0] and a['y']+a['h']<=case[1]+1e-7;checks+=1
    rows.append({'case':case,'surface':label,'height':height,'cinematic':cinematic,**a})
old=run(cases[1],196,False,True)
assert abs(old[2]['w']-646*ref[1]['scale'])>100
checks+=1
report={'status':'PASS','checks':checks,'cases':len(cases),'sourceHomeScaleSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sourceUiScaleSha256':hashlib.sha256(Path('D:/Rino_Project/Vox/shared/ui/uiScale.js').read_bytes()).hexdigest(),'productionSha256':{n:hashlib.sha256((ROOT/('scripts/ui/'+n+'.lua')).read_bytes()).hexdigest()for n in codes},'negativeControl':'restored fixed scale at 2880x1800 produces 646px card versus expected 969px','renders':rows,'boundary':'Actual MissionHud.Render and Epilogue.Render with affine NanoVG/UI/paragraph adapters; no GPU, native text shaping or physical display acceptance.'}
path=ROOT/'docs/migration/evidence/comms-reference-layout-offline.json';path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({k:v for k,v in report.items()if k!='renders'},ensure_ascii=False,indent=2))

import hashlib,json,os,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
os.chdir(ROOT)
baseline=json.loads((ROOT/'docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json').read_text(encoding='utf-8'))
source=Path(baseline['snapshot'])/'shared/ui/matchHud.js'
css=source.read_text(encoding='utf-8')
assert re.search(r'body\.match-running #mechReticle \[data-compass\]\{transform:translateY\(calc\(100px \* var\(--mh-ui, 1\)\)\)\}',css)
lua=LuaRuntime(unpack_returned_tuples=True)
result=lua.execute("""
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local stack,dy={},0;local texts={};local checks=0
package.loaded['ui.SourceDraw']={Line=function()end}
package.loaded['ui.ReticleDraw']={Poly=function()end,Text=function(_,text,x,y)texts[tostring(text)]=y+dy end}
package.loaded['ui.ReticleState']={}
package.loaded['ui.ReticleNavigation']={Render=function()end}
NVG_ALIGN_CENTER=2
function nvgSave()stack[#stack+1]=dy end
function nvgRestore()dy=table.remove(stack)end
function nvgTranslate(_,x,y)dy=dy+y end
function nvgGlobalAlpha()end
local Gauges=require 'ui.ReticleGauges'
for _,screen in ipairs({{1920,1080},{2400,1080},{840,378},{1605,388}})do
 for _,touch in ipairs({false,true})do
  local w,h=screen[1],screen[2];local k=math.min(w/1920,h/1080)
  for _,battle in ipairs({false,true})do
   local session={yaw=0,touch=touch,battle=battle and {} or nil}
   Gauges.Compass(1,{session=session},{k=k,cx=w/2,width=w,height=h})
   local ref=touch and 600 or 1080
   local offset=battle and 100*math.min(w/(ref*16/9),h/ref)*(touch and .8 or 1)or 0
   assert(math.abs(texts['000']-(72*k+offset))<1e-9,'source compass CSS translation')
   assert(dy==0 and #stack==0,'compass transform cannot move other HUD')
   checks=checks+2
  end
 end
end
return checks
""")
report={'result':'PASSED','assertions':result,'sourceCommit':baseline['commit'],'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'productionSha256':hashlib.sha256((ROOT/'scripts/ui/ReticleGauges.lua').read_bytes()).hexdigest(),'scope':'Actual Compass transform and original100px*mh-ui CSS across4viewports,PC/touch,match/nonmatch. No screenshot claim.'}
(ROOT/'docs/migration/evidence/compass-match-offset-offline.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))

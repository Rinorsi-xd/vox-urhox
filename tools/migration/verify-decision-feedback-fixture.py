"""Exercise dedicated fixture render/ACK lifecycle without starting hardware."""
import json,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
data=json.loads((ROOT/'assets/Intro/Intro.json').read_text(encoding='utf-8'))
lua.globals().DATA=lua.table_from({'images':lua.table_from(data['images']),'caps':lua.table_from(data['caps'])})
lua.execute('''
package.path='scripts/?.lua;'..package.path
LOGS={};ACK=false;SHUTDOWN=false;DRAWN=0;KEY_F8=1;MM_ABSOLUTE=1;DOWNLOAD_READY=false;GATE_TICKS=0
cjson={encode=function(row)LOGS[#LOGS+1]=row;return tostring(#LOGS)end}
print=function()end
input={GetKeyPress=function()local v=ACK;ACK=false;return v end}
graphics={GetDPR=function()return 1 end}
function SubscribeToEvent()end
function UnsubscribeFromEvent()end
function nvgScale()end
local UI={}
UI.Widget={Extend=function()local class={};setmetatable(class,{__call=function(_,value)value.Destroy=function()end;return setmetatable(value,{__index=class})end});return class end}
UI.Init=function(config)assert(DOWNLOAD_READY);assert(config.scale==1080)end
UI.SetRoot=function(page)ROOT_PAGE=page end
UI.GetViewportSize=function()return 1920,1080 end
UI.GetScale=function()return 1 end
UI.Shutdown=function()SHUTDOWN=true end
package.loaded['urhox-libs/UI']=UI
package.loaded['ui.SourceDraw']={Begin=function()end}
package.loaded['ui.IntroPromo']={Draw=function(page,_,w,h,u)assert(w==1920 and h==1080 and u==10.8);assert(page.owner.downloaded);DRAWN=DRAWN+1 end}
package.loaded['ui.IntroDecisionFx']={Plan=function(owner)return {progress=owner.holdProgress}end}
package.loaded['ui.IntroOpacity']={Push=function()end,Pop=function()end}
package.loaded['urhox-libs/UI/Core/ImageCache']={Get=function(path)assert(DOWNLOAD_READY and path);return 7 end,GetSize=function(path)
 if IMAGE_PLACEHOLDER then return 16,16 end
 if path:find('company%-emblem')then return 261,263 end
 return 2304,2304 end,Clear=function()CLEARED=true end}
package.loaded['ui.SourceFonts']={Resolve=function()assert(DOWNLOAD_READY);return {body='actual-body',bold='actual-bold'}end}
package.loaded['controls.TouchMode']={Scale=function(surface)assert(surface=='home');return 1080 end}
package.loaded['core.ResourceData']={Read=function(path)assert(path=='Intro/Intro.json');return DATA end}
cache={Exists=function()return DOWNLOAD_READY end}
package.loaded['app.ResourceGate']={New=function()return {Start=function(_,paths,done)assert(#paths==8);DOWNLOAD_DONE=done end,Cancel=function()GATE_CANCELLED=true end}end,
 UpdatePending=function()GATE_TICKS=GATE_TICKS+1;if GATE_TICKS==2 then DOWNLOAD_READY=true;DOWNLOAD_DONE(true)end end}
''')
text=(ROOT/'tools/migration/decision-feedback-render.lua').read_text(encoding='utf-8')
lua.execute(text)
lua.globals().Start()
assert lua.globals().ROOT_PAGE is None
lua.execute('DecisionFeedbackUpdate()')
assert lua.globals().ROOT_PAGE is None
lua.execute('DecisionFeedbackUpdate()')
assert lua.globals().ROOT_PAGE is not None
lua.execute('IMAGE_PLACEHOLDER=true;PLACEHOLDER_ACCEPTED=pcall(function()ROOT_PAGE:Render(1)end);IMAGE_PLACEHOLDER=false')
assert not lua.globals().PLACEHOLDER_ACCEPTED
checks=4
for index,stage in enumerate(['hold-zero','hold-half','hold-full','decided-early','decided-late'],1):
 for frame in range(9):
  lua.execute('ROOT_PAGE:Render(1);DecisionFeedbackUpdate()')
 assert len(lua.globals().LOGS)==index-1;checks+=1
 lua.execute('ROOT_PAGE:Render(1);DecisionFeedbackUpdate()')
 row=lua.globals().LOGS[index]
 assert row['stage']==stage and row['frames']==10;checks+=1
 expected=data['caps']['n06'if index<4 else'n07']
 assert row['owner']['caption']==expected;checks+=1
 for _ in range(3):lua.execute('ROOT_PAGE:Render(1);DecisionFeedbackUpdate()')
 assert len(lua.globals().LOGS)==index;checks+=1
 lua.execute('ACK=true;DecisionFeedbackUpdate()')
assert lua.globals().SHUTDOWN and lua.globals().CLEARED;checks+=1
assert lua.globals().LOGS[6]['status']=='PASS'and lua.globals().LOGS[6]['released'];checks+=1
assert lua.globals().ROOT_PAGE is None;checks+=1
assert lua.globals().DRAWN==65;checks+=1
lua.globals().Stop()
assert lua.globals().GATE_CANCELLED;checks+=1
for name in ['app.HangarApp','app.TrialSession','storage.BlueprintStore']:
 assert lua.eval('package.loaded')[name]is None;checks+=1
print(json.dumps({'status':'READY_NOT_RUN','checks':checks,'renderAdapterCalls':65,'stages':5,'hardware':False,'boundary':'Actual fixture state/ACK/cleanup under Lua doubles; no real GPU, fonts, image decoding or natural playback claim.'},indent=2))

"""Execute frozen H5 result grading and real Lua debug actions/widget lifecycle."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

SOURCE = r'''
const fs=require('node:fs'),crypto=require('node:crypto'),vm=require('node:vm');
const b=JSON.parse(fs.readFileSync('docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json'));
const hashes={};function read(p){const raw=fs.readFileSync(require('node:path').join(b.snapshot,p));const h=crypto.createHash('sha256').update(raw).digest('hex');if(h!==b.files[p].sha256)throw Error('Frozen source drift: '+p);hashes[p]=h;return raw.toString('utf8');}
const raw=read('three/src/debug/debugPanel.js'),story=read('three/src/battle/storyMission.js');
const el=()=>({style:{},classList:{contains:()=>false,toggle(){}},setAttribute(){},addEventListener(){},querySelector(){return null;},getBoundingClientRect(){return {left:1838,top:64,right:1908,bottom:108};}});
const trace=[],ctx=vm.createContext({URL,location:{href:'http://localhost/?debug'},document:{head:{appendChild(){}},body:{appendChild(){},classList:{contains:()=>false}},createElement:el,addEventListener(){}},localStorage:{getItem(){return null;},removeItem(k){trace.push(k);}},performance:{now:()=>0},requestAnimationFrame(){},setTimeout(){},addEventListener(){},createTestPreview:()=>({}),createHudChecks:()=>({}),console:{info(){}},STORY_LEVELS:[],TEST_PAGE_GROUPS:[],HUD_SOUNDS:[],COMBAT_TUNING:{},TUNING_FIELDS:[]});
vm.runInContext(raw.replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'').replaceAll('import.meta.url',JSON.stringify('file:///frozen/three/src/debug/debugPanel.js'))+'\nglobalThis.install=installDebug;',ctx);
const app={shell:{ui:{toast(){}},stash:{}},drive:{},editor:{}};ctx.install(app);
(async()=>{for(const a of ['clrProfile','clrStory','clrSalvage'])await app.debug.act(a);
const body=story.slice(story.indexOf('\t_result() {')+'\t_result() {'.length,story.indexOf('\n\tkey( e )',story.indexOf('\t_result() {'))).replace(/\}\s*$/,'');
const f=vm.runInNewContext('(function(){'+body+'})',{document:{},localStorage:{getItem:()=>null},recordClear:()=>({newBest:false,best:null})});
const grades=[];for(const deaths of [0,1,2])for(const fails of [0,1])for(const time of [0,419,420,599,600]){let out;const m={stats:{deaths,fails},time,level:{id:'l1'},hud:{result(v){out=v;}}};f.call(m);grades.push({deaths,fails,time,grade:out.grade});}
process.stdout.write(JSON.stringify({commit:b.commit,sourceHashes:hashes,clearKeys:trace,grades}));})();
'''
golden = json.loads(subprocess.check_output(['node', '-e', SOURCE], text=True, encoding='utf-8'))
paths = ['scripts/app/DebugActions.lua', 'scripts/ui/DebugPanel.lua', 'scripts/main.lua', 'scripts/app/HangarApp.lua']
hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
lua = LuaRuntime(unpack_returned_tuples=True)
def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value
lua.globals().golden = table(golden)
lua.globals().tutorialData = table(json.loads((ROOT / 'assets/UI/Tutorial.json').read_text(encoding='utf-8')))
host = (ROOT / 'scripts/app/HangarApp.lua').read_text(encoding='utf-8')
lua.globals().hostArgumentLoop = host[host.index('    for _,arg in ipairs(GetArguments()) do'):host.index('    self.store=')]
checks = list(lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local checks={};local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
for _,case in ipairs({{args={},on=false},{args={'-vox-debug=1'},on=true},{args={'-vox-debug'},on=true},{args={'-vox-debug=0'},on=false},{args={'-dev'},on=true}}) do
 local self={debugEnabled=false};GetArguments=function() return case.args end
 local fn=assert(load('return function(self) '..hostArgumentLoop..' end'))();fn(self)
 Check(self.debugEnabled==case.on,'actual final host argument loop '..(case.args[1] or 'default-off'))
end
local home={tab='hangar'};home.SetTab=function(v) home.tab=v end;home.SetLobby=function(v) app.lobby=v end
package.loaded['ui.GarageHud']={GetState=function() return home end,Refresh=function() end}
package.loaded['story.MissionData']={levels={{id='story1',no=1,name='test'}}}
local touch=false;package.loaded['controls.TouchMode']={Enabled=function() return touch end}
local Actions=require 'app.DebugActions';local state={god=false};local writes={};local toast={}
app={store={Read=function() end,Write=function(_,key,data,validator,deleted) writes[#writes+1]={key=key,data=data,deleted=deleted};return true end},
 toasts={Push=function(_,text) toast[#toast+1]=text end},salvageLobby={data={items={wheel=2},credits=10},Save=function() return true end}}
app.salvageLobby.store=app.store
app.EnterTrial=function(_,map) app.entered=map;return true end
app.EnterBattle=function(_,mode) app.entered=mode;return true end
app.EnterBuild=function() app.build={} end;app.ExitBuild=function() app.build=nil end
app.StartOpening=function(_,part) app.opened=part;return true end
Check(Actions.Context(app)=='home','startup without trial does not index nil')
Check(#Actions.Sections(app,state)>0,'startup no tutorial renders real sections')
local TutorialRules=require 'story.TutorialRules';app.tutorial={data=tutorialData,initialized=false,rules=TutorialRules.New(tutorialData,nil,function() end),State=function() return {} end}
app.tutorial.Start=function(t) t.rules:Start(1,nil,{}) end
local sections=Actions.Sections(app,state);Check(#sections[2].buttons==#tutorialData.steps,'actual tutorial data shape produces every jump button')
for _,spec in ipairs(tutorialData.steps) do Check(Actions.Execute(app,state,'tutJump:'..spec.id),'tutorial jump '..spec.id);Check(app.tutorial.rules:StepSpec().id==spec.id,'actual tutorial rule selected '..spec.id) end
for _,row in ipairs({{'mapTest','trial'},{'mapCrater','crater'},{'mapSalvage','salvage'},{'mElim','elimination'},{'mConq','conquest'},{'mEsc','escort'},{'storyN:1','story1'}}) do
 Check(Actions.Execute(app,state,row[1]) and app.entered==row[2],'real dispatch '..row[1]) end
for _,a in ipairs({'intro','introContract','introGate'}) do Check(Actions.Execute(app,state,a),'opening action '..a) end
for _,a in ipairs({'clrProfile','clrStory','clrSalvage'}) do Check(Actions.Execute(app,state,a),'clear action '..a) end
for i,key in ipairs({'intro-profile','story-progress','stash'}) do Check(writes[#writes-3+i].key==key and writes[#writes-3+i].deleted,'actual namespaced tombstone '..golden.clearKeys[i]) end
Check(Actions.Execute(app,state,'svFill') and app.salvageLobby.data.items.wheel==22,'owned stash items add20')
Check(Actions.Execute(app,state,'svCash') and app.salvageLobby.data.credits==10010,'real credits add10000')
Check(Actions.Execute(app,state,'svEmpty') and next(app.salvageLobby.data.items)==nil,'real inventory emptied')
local Rules=require 'story.MissionRules'
for i,g in ipairs(golden.grades) do local level={steps={},par={420,600},spawn={pos={0,0,0}}};local r=Rules.New(level);r.time=g.time;r.stats.deaths=g.deaths;r.stats.fails=g.fails
 local seen;app.trial={story={level=level,rules=r,Events=function(m) for _,e in ipairs(m.rules:Drain()) do seen=e end end}}
 Check(Actions.Execute(app,state,'stResult') and seen.grade==g.grade and seen.time==g.time and r.finished,'frozen H5 result grade '..i) end
for _,policy in ipairs({'truckHp','shield'}) do local level={steps={},gradePolicy=policy,spawn={}};local r=Rules.New(level);r.stats[policy=='truckHp' and 'truckHp' or 'shield']=.2
 local seen;app.trial={story={level=level,rules=r,Events=function(m) seen=m.rules:Drain()[1] end}}
 Check(Actions.Execute(app,state,'stResult') and seen.grade==(policy=='truckHp' and 'B' or 'A'),'story authored cap '..policy) end
local p={incomingDamageMultiplier=1,alive=true,bodyHp=10,bodyHpMax=100,struct=2,structMax=20,Position=function() return {1,2,3} end,Heal=function(u) u.bodyHp=100 end,RestoreMissing=function(u) u.restored=true end,Flush=function() end}
app.trial={world={layout={teleports={{name='A',pos={1,2,3}}}}},combat={player=p,SyncPlayer=function() end},Pause=function(s) s.paused=true end,ApplyResetSpot=function(s,spot) s.spot=spot end,ResetCamera=function(s) s.reset=true end}
Check(Actions.Context(app)=='drive','practice context');Check(#Actions.Status(app,60,state)==3,'real player status')
Check(Actions.Execute(app,state,'god') and p.incomingDamageMultiplier==0,'god enabled');Check(Actions.Execute(app,state,'god') and p.incomingDamageMultiplier==1,'god restored')
Check(Actions.Execute(app,state,'heal') and p.bodyHp==100 and p.restored,'heal restores missing parts')
Check(Actions.Execute(app,state,'tp:1') and app.trial.spot.pos[1]==1 and app.trial.reset,'teleport uses actual session reset')
local disposed=0;app.trial.battle={rules={state='live',Emit=function(r,kind,e) r.event=e end},AfterStep=function(b) b.mvpShow={preparing=true,Dispose=function() disposed=disposed+1 end} end}
Check(Actions.Execute(app,state,'mResultWin') and app.trial.battle.rules.winner=='blue' and app.trial.battle.mvpShow.done and disposed==1,'direct result disposes preparing MVP without waiting')
app.trial.battle.mvpShow={preparing=false,Dispose=function() disposed=disposed+1 end}
Check(Actions.Execute(app,state,'mResult') and disposed==2 and app.trial.battle.mvpShow.done,'end MVP finishes rather than skipping one shot')
local Widget={};function Widget:Extend() local t={};t.__index=t;return setmetatable(t,{__call=function(c,p) return setmetatable({props=p,Destroy=function(s) s.destroyed=true end},c) end}) end
local W,H=1920,1080;local globals,overlays={},{};local ui={Widget=Widget,GetViewportSize=function() return W,H end,GetSafeAreaInsets=function() return {top=0,left=0,right=0} end,
 RegisterGlobalComponent=function(k,v) globals[k]=v end,UnregisterGlobalComponent=function(k) globals[k]=nil end,PushOverlay=function(v) overlays[v]=true end,PopOverlay=function(v) overlays[v]=nil end,ClearFocus=function() end,CancelPointer=function() end}
package.loaded['urhox-libs/UI']=ui;package.loaded['ui.SourceDraw']={Begin=function() end,Rect=function() end,Text=function() end,Width=function(_,text,size) return #text*size*.5 end}
function nvgSave() end;function nvgRestore() end;function nvgIntersectScissor() end
local pressed=false;input={GetKeyPress=function() local v=pressed;pressed=false;return v end};KEY_F8=8;MM_ABSOLUTE=1;local platform='Web';function GetPlatform() return platform end
local Panel=require 'ui.DebugPanel';local panel=Panel.New(app);Check(globals['vox-debug']==panel.page and overlays[panel.page],'one global widget registered and overlay attached')
panel:Layout();Check(panel.toggleRect.x==1838 and panel.toggleRect.y==64,'source PC70x44 top-right placement')
Check(not panel.page:HitTest(10,500) and panel.page:HitTest(1840,70),'closed widget passes through playfield')
pressed=true;panel:Update(.016);Check(panel.open and app.trial.paused and input.mouseMode==MM_ABSOLUTE,'F8 opens and releases gameplay input')
VOX_SKIP_TUTORIAL=true;VOX_CLOUD_VALIDATION=true;pressed=true;panel:Update(.016);Check(panel.open and pressed,'QA F8 remains unconsumed for probe');pressed=false;VOX_SKIP_TUTORIAL=nil;VOX_CLOUD_VALIDATION=nil
panel.maxScroll=1000;panel.scroll=400;panel.page:OnWheel(0,100);Check(panel.scroll==360,'Web100 delta scrolls40px');platform='Windows';panel.page:OnWheel(0,1);Check(panel.scroll==320,'desktop1 delta scrolls40px')
for _,vp in ipairs({{1920,1080},{2560,1080},{1280,576},{1024,768},{800,360}}) do W,H=table.unpack(vp);panel:Layout();panel.page:Render(1);local t,r=panel.toggleRect,panel.panelRect
 Check(t.x>=0 and t.x+t.w<=W and t.y>=0 and t.y+t.h<=H,'toggle fits '..W..'x'..H)
 Check(r.x>=0 and r.x+r.w<=W and r.y>=0 and r.y+r.h<=H,'panel fits '..W..'x'..H)
 for _,row in ipairs(panel.buttons) do Check(row.x>=r.x and row.x+row.w<=r.x+r.w and row.y>=r.y and row.y+row.h<=r.y+r.h,'clipped button fits '..W..'x'..H..' '..row.id) end end
W,H=1920,1080;touch=true;panel:Layout();Check(panel.toggleRect.x==12 and panel.toggleRect.y==518,'touch landscape left-center placement');touch=false
panel:SetOpen(false);panel:Layout();local x,y=panel.toggleRect.x+5,panel.toggleRect.y+5;local event={pointerId=1,pointerType='mouse',x=x,y=y}
panel.page:OnPointerDown(event);panel.page:OnPointerMove({pointerId=1,x=x+3,y=y+3});panel.page:OnPointerUp(event);Check(panel.open,'under6px motion remains click')
panel.page:OnClick(event);Check(panel.open,'synthetic click suppressed after pointerup')
panel.page:OnPointerDown(event);panel.page:OnPointerMove({pointerId=1,x=-100,y=-100});panel.page:OnPointerUp({pointerId=1,x=-100,y=-100});panel:Layout()
Check(panel.open and panel.toggleRect.x==4 and panel.toggleRect.y==4 and writes[#writes].key=='debug-position','drag clamps and persists normalized position without toggling')
local page=panel.page;panel:Dispose();panel:Dispose();Check(not globals['vox-debug'] and not overlays[page] and page.destroyed,'idempotent dispose removes renderer overlay and widget')
local bootApp={debugEnabled=true,Start=function(s) s.started=true end,Stop=function(s) s.stopped=true end,Update=function(s) s.updated=true end}
local order={};local debugOwner={Update=function(_,dt) order[#order+1]='debug';Check(dt==.02,'main forwards real event timestep') end,Dispose=function() order[#order+1]='dispose' end}
package.loaded['app.HangarApp']={New=function() return bootApp end}
package.loaded['ui.DebugPanel']={New=function(a) Check(a.started,'debug installed after app UI bootstrap');return debugOwner end}
package.loaded['storage.CloudStorage']={Boot=function(fn) fn() end,Update=function() order[#order+1]='storage' end,Stop=function() order[#order+1]='storage-stop' end}
package.loaded['render.RectLightLookup']={Ensure=function(fn) fn(true) end};package.loaded['render.MatchMapShot']={Initialize=function() end,Shutdown=function() end}
_tr=true;function SubscribeToEvent() end;function UnsubscribeFromEvent() end
assert(loadfile('scripts/main.lua'))();Start();Check(bootApp.debugPanel==debugOwner,'real main attaches user debug module')
HandleUpdate(nil,{GetFloat=function() return .02 end});Check(order[1]=='storage' and order[2]=='debug' and bootApp.updated,'main debug input precedes app gameplay update')
Stop();Check(bootApp.stopped and bootApp.debugPanel==nil and order[3]=='dispose' and order[4]=='storage-stop','main disposes panel before host storage shutdown')
bootApp.debugEnabled=false;Start();Check(bootApp.debugPanel==nil,'production debug off installs no widget');Stop()
return checks
''').values())
assert hashes == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}, 'Debug production drift during check'
report = {'result': 'PASS', 'sourceCommit': golden['commit'], 'sourceHashes': golden['sourceHashes'], 'productionHashes': hashes,
          'checks': checks, 'sourceCases': len(golden['grades']) + 3,
          'resources': {'assets/UI/Tutorial.json': hashlib.sha256((ROOT / 'assets/UI/Tutorial.json').read_bytes()).hexdigest()},
          'testInputs': {'tools/migration/check-debug-panel.py': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},
          'boundary': 'Real frozen H5 debug installation/actions and result method executed in Node; actual Lua actions, tutorial/mission rules, widget input/layout/disposal executed. Engine, storage, draw, application scene hosts adapted. No browser/GPU/native visual acceptance; debug test pages, HUD checks, tuning and URL flags remain unported.'}
output = ROOT / 'docs/migration/evidence/debug-panel-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'sourceCases': report['sourceCases']}))

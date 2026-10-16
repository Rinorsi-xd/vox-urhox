"""Exercise the actual QA Dump function during released-hall transitions."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
probe = ROOT / 'tools/migration/probe-outgame-web.lua'
source = probe.read_text(encoding='utf-8')
timing = source[:source.index('VOX_SKIP_TUTORIAL=true')]
dump = source[source.index('local function Dump(app)'):source.index('\nfunction HandleUpdate(et,ed)')]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
local modules={
 ['ui.GarageHud']={GetState=function()return nil end},
 ['controls.TouchMode']={Enabled=function()return false end,Compact=function()return false end},
 ['render.Quality']={current={name='medium'}},
 ['storage.CloudStorage']={Snapshot=function()return {ready=true}end},
 ['combat.Matchmaker']={Valid=function()return true end},
}
require=function(name)assert(modules[name],name);return modules[name]end
UI={GetViewportSize=function()return 1920,1080 end}
graphics={GetWidth=function()return 1920 end,GetHeight=function()return 1080 end,GetDPR=function()return 1 end}
GetPlatform=function()return 'Web' end
GetNativePlatform=function()return 'Windows' end
input={touchEmulation=false};renderer={numBatches=10,numPrimitives=20}
AudioState=function()return {}end;PauseState=function()return nil end
SalvageInventory=function()return nil end;ResourceStats=function()return {resourceBytes=123}end
cjson={encode=function(data)captured=data;return 'snapshot' end}
print=function(line)lastLine=line end
Time={GetSystemTime=function()return 0 end}
''')
lua.globals().actualDump = lua.execute(timing + dump + '\nreturn Dump')
result = lua.execute(r'''
local checks=0
local function Check(ok,label)checks=checks+1;assert(ok,label)end
local poison=setmetatable({},{__index=function(_,key)error('disposed native access '..key)end})
for mask=0,6 do
 local app={blueprint={name='retained',Size=function()return 7 end},
  store={Read=function()return {games=3}end},
  scene=mask&1~=0 and poison or nil,camera=mask&2~=0 and poison or nil,hangar=mask&4~=0 and poison or nil,
  loader={state='loading',phase='scene',progress=.55,gate={total=30,completed=30},prepareFrames=4},
  pendingMap={id='crater'},mapTransition={Snapshot=function()return {released=true,recovering=false}end},
  loadingFlow={page={backRect={12,14,80,24}},Snapshot=function()return {active=true,phase='loading'}end}}
 actualDump(app)
 Check(captured.mode=='loading' and not captured.sceneVisible,'transition mode and absent viewport')
 Check(captured.loading.phase=='scene' and captured.loading.progress==.55,'real loader phase and progress retained')
 Check(captured.loadingFlow.backRect[1]==12 and captured.loadingFlow.active,'cancel button and flow retained')
 Check(captured.performance.mapTransition.released and captured.performance.resourceBytes==123,'memory lifecycle retained')
 Check(captured.blueprint=='retained' and captured.parts==7,'blueprint identity retained')
 Check(lastLine=='OUTGAME_STATE snapshot' and captured.camera==nil and captured.hangar==nil,'single reduced snapshot without native references')
end
testApp={blueprint={name='fallback',Size=function()return 11 end},
 store={Read=function()return {}end},loader={state='loading',phase='scene',progress=.4,gate={total=1,completed=1}},
 loadingFlow={page={backRect={1,2,3,4}},Snapshot=function()return {active=true}end},
 mapTransition={Snapshot=function()return {released=true}end}}
return {pass=true,checks=checks,scenarios=7}
''')
update = source[source.index('function HandleUpdate(et,ed)'):source.index('\nlocal originalPostUpdate=HandlePostUpdate')]
lua.execute('HandleUpdate=function()end\n' + timing + '\nlocal frames=0;local samples={};local sampleMode="";local Dump=actualDump\n' + update)
wiring = lua.execute(r'''
KEY_F8='F8';input.GetKeyPress=function(_,key)return key==KEY_F8 end
VOX_HANGAR={app=testApp};VOX_TRIAL=nil;HandleUpdate(nil,nil)
assert(captured.blueprint=='fallback','initial observed app captured')
VOX_HANGAR=nil;VOX_TRIAL=nil;captured=nil;HandleUpdate(nil,nil)
assert(captured and captured.blueprint=='fallback','actual HandleUpdate retains app while both production globals nil')
assert(captured.mode=='loading' and captured.loadingFlow.backRect[1]==1,'fallback produces actual transitional Dump')
assert(VOX_HANGAR==nil and VOX_TRIAL==nil,'QA must not restore production globals')
testApp.stopped=true;captured=nil;HandleUpdate(nil,nil)
assert(captured==nil,'stopped fallback must not access app')
return 5
''')
report = dict(result)
report['checks'] += wiring
report['handleUpdateChecks'] = wiring
report['probeSha256'] = hashlib.sha256(probe.read_bytes()).hexdigest()
report['boundary'] = 'Actual extracted Lua QA Dump function; released-scene references poison on access; no browser/native launch.'
out = ROOT / 'docs/migration/evidence/transition-probe-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))

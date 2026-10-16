"""Frozen GameMusic.tick oracle versus actual Lua audio panel and app mapping."""
from pathlib import Path
import hashlib,json,os,subprocess,sys
root=Path(__file__).resolve().parents[2];os.chdir(root)
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime,LuaError
source=json.loads(subprocess.check_output(['node','--experimental-vm-modules','tools/migration/source-game-audio.cjs'],text=True))
state_path=root/'scripts/audio/GameMusicState.lua'

def run(mutation=None):
 lua=LuaRuntime(unpack_returned_tuples=True)
 lua.execute("""
package.path='scripts/?.lua;'..package.path
Time={GetSystemTime=function() return 0 end};graphics={GetWidth=function() return 1920 end,GetHeight=function() return 1080 end,GetDPR=function() return 1 end}
local function Widget(p)
 return {props=p or {},state={},AddChild=function() end,SetText=function(self,t) self.text=t end,SetDisabled=function(self,v) self.props.disabled=v end}
end
local Factory=setmetatable({Extend=function(self) return setmetatable({},{__call=function(_,p) return Widget(p) end}) end},{__call=function(_,p) return Widget(p) end})
package.preload['urhox-libs/UI']=function() return {Panel=Factory,ScrollView=Factory,GetScale=function() return 1 end,GetViewportSize=function() return 1920,1080 end} end
package.preload['ui.DialogHost']=function() return {Open=function(owner) local w=Widget();w.AddContent=function() end;owner.dialog=w;return w end,Close=function(owner) owner.dialog=nil end} end
package.preload['ui.SourceButton']=function() return Factory end
package.preload['ui.SourceGraphicsControls']=function() return {Row=Factory,Checkbox=Factory,Slider=Factory} end
package.preload['ui.SourceHint']=function() return Factory end
package.preload['controls.TouchMode']=function() return {Enabled=function() return false end} end
local player={enabled=true,volume=.75,userPaused=false,Track=function() return {title='test'} end}
OWNER={app={music=player}}
require('audio.AudioLevels').Init(nil)
MODAL=require('ui.AudioSettings').Open(OWNER)
assert(MODAL.sourceAudioSettings==true,'Actual constructed audio panel must carry explicit identity')
""")
 state_source=state_path.read_text(encoding='utf-8')
 if mutation=='old-modal':state_source=state_source.replace('not dialog.sourceAudioSettings','true')
 if mutation=='boolean-dialog':state_source=state_source.replace("type(dialog)=='table'","dialog~=nil")
 lua.execute("package.loaded['audio.GameMusicState']=nil;package.preload['audio.GameMusicState']=function()\n"+state_source+'\nend')
 checks=1;rows=[]
 for case in source['audioPanels']:
  lua.globals().CASE=lua.table_from({key:value for key,value in case.items() if key!='expected'})
  actual=lua.execute("""
local c=CASE;local Levels=require 'audio.AudioLevels';Levels.Init(nil)
local owner={};Levels.SetSpeaking(owner,c.voice);if c.feedback then Levels.FeedbackFor(10) end
local dialog=c.modal and (c.audioPanel and MODAL or {}) or nil
local app={mode='hangar'};local home={tab='home',dialog=dialog}
if c.active or c.editing then
 app.mode='trial';app.trial={map={id='crater'},pointer={captured=c.locked},dialog=dialog,
  endless=c.editing and {run={state='editing'}} or nil};home.dialog=nil
end
local value=require('audio.GameMusicState').FromApp(app,home)
Levels.SetSpeaking(owner,false)
return value
""")
  for key in ['scene','destination','matching','paused','duck']:
   assert actual[key]==case['expected'][key],(case['name'],key,actual[key],case['expected'][key])
   checks+=1
  rows.append({'name':case['name'],'duck':actual['duck']})
 # A closed/unbuilt UI uses false sentinels, including a cold native startup.
 # Execute FromApp itself with every absent owner/dialog shape, not a facade.
 boolean_cases=lua.execute("""
local Levels=require 'audio.AudioLevels';Levels.Init(nil)
local owner={};Levels.SetSpeaking(owner,false)
local State=require 'audio.GameMusicState'
local cases={
 {'hangar-home-nil',{mode='hangar'},nil},
 {'hangar-home-false',{mode='hangar'},false},
 {'hangar-dialog-nil',{mode='hangar'},{tab='home'}},
 {'hangar-dialog-false',{mode='hangar'},{tab='home',dialog=false}},
 {'hangar-trial-false',{mode='hangar',trial=false},{tab='home',dialog=false}},
 {'trial-session-false',{mode='trial',trial=false},{tab='home',dialog=false}},
 {'trial-session-nil',{mode='trial'},nil},
 {'home-dialog-true',{mode='hangar'},{tab='home',dialog=true}},
}
for _,row in ipairs(cases) do
 local value=State.FromApp(row[2],row[3])
 assert(value.scene=='hangar' and value.duck==1 and value.paused==false,row[1])
end
return #cases
""")
 checks+=boolean_cases*3
 return {'checks':checks,'cases':rows,'absentDialogCases':boolean_cases}

report=run()
rejected=False
try:run('old-modal')
except AssertionError:rejected=True
assert rejected,'Prior unconditional modal attenuation must fail frozen oracle'
boolean_rejected=False
try:run('boolean-dialog')
except (AssertionError,LuaError):boolean_rejected=True
assert boolean_rejected,'Broken nil-only dialog guard must fail actual cold-start false sentinel'
report.update(result='PASS',negativeOldModal='REJECTED',negativeBooleanDialog='REJECTED',sourceCommit=source['commit'],sourceHashes=source['hashes'],
 productionHashes={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in ['scripts/ui/AudioSettings.lua','scripts/audio/GameMusicState.lua']},
 toolHashes={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in ['tools/migration/source-game-audio.cjs','tools/migration/check-audio-panel-duck.py']},
 testInputs={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in ['tools/migration/source-game-audio.cjs','tools/migration/check-audio-panel-duck.py']},
 boundary='Actual frozen GameMusic.tick executes with external DOM/audio boundaries adapted. Actual Lua AudioSettings.Open constructs modal and actual GameMusicState.FromApp consumes it. CPU mapping, not native control interaction, audio output or Web acceptance.')
target=root/'docs/migration/evidence/audio-panel-duck-offline.json';target.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))

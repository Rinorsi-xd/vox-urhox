"""Compare real Lua input/result methods to the frozen H5 methods."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

LUA = r'''
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
for _,name in ipairs({'controls.ChaseCamera','controls.ChaseState','render.DriveView','controls.DriveInput','ui.DriveHud',
 'render.WeaponView','render.CombatEffects','render.CombatView','core.Coord','urhox-libs/UI','ui.DialogHost','render.TargetFeedback',
 'story.MissionData','combat.ArenaData','combat.CarUnit','combat.EnemyDriver','core.Math3','drive.SpawnSpecCache','audio.AudioLevels'}) do
 package.preload[name]=function() return {} end
end
for i,name in ipairs({'RETURN','R','N','BACKSPACE','ESCAPE','T','SPACE','I','C','E','F','G','V','TAB','A','D','LEFT','RIGHT','1','2','3','4','5','6','7','8','9','0'}) do _G['KEY_'..name]=i end
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local Session=require 'app.TrialSession'
local Comms=require 'audio.StoryComms'
local card={age=0,typing=1,length=3,pending='voice',speakEnd=2}
local voice=setmetatable({card=card},Comms)
local session=setmetatable({story={rules={finished=false},voice=voice},weapons={Select=function() end},practice=false},Session)
session:HandleKey(KEY_RETURN)
Check(card.finishedTyping and not card.skipped,'first ordinary Enter completes actual StoryComms text')
session:HandleKey(KEY_RETURN)
Check(card.skipped and card.age==4 and card.pending==nil and card.speakEnd==0,'second ordinary Enter skips actual StoryComms line')
local calls=0;session.story.voice={SkipLine=function() calls=calls+1 end}
session.story.boss={Key=function() return true end};session:HandleKey(KEY_RETURN)
Check(calls==0,'Boss cinematic input remains exclusive')
session.story.boss={Key=function() return false end};session:HandleKey(KEY_RETURN)
Check(calls==1,'post-cinematic Boss returns ordinary dialogue Enter')
local epi=0;session.story.epilogue={active=true,Key=function() epi=epi+1 end};session:HandleKey(KEY_RETURN)
Check(epi==1 and calls==1,'epilogue retains Enter ownership')
session.story.epilogue=nil;session.story.boss=nil;session.story.rules.finished=true;session.app={};session.map={id='story1'}
session:HandleKey(KEY_RETURN);Check(session.wantsReturn and calls==1,'finished result Enter still returns')
session.wantsReturn=false;session:HandleKey(KEY_R)
Check(session.wantsReturn and session.app.restartStory=='story1' and calls==1,'result replay remains intact')
session.story=nil;session:HandleKey(KEY_RETURN);Check(calls==1,'ordinary trial does not gain story action')
local Mission=require 'story.Mission'
for _,sample in ipairs(SOURCE.cases) do
 local written,paused,radio= nil,0,0
 local old=sample.old
 local store={Read=function() return old and {s1={grade=old.grade,time=old.time,clears=old.clears},other={grade='A'}} or {other={grade='A'}} end,
  Write=function(_,key,value) Check(key=='story-progress','correct progress key');written=value;return true end}
 local quotePrepared=0
 local mission=setmetatable({level={id='s1'},voice={PrepareResultQuote=function(_,text) Check(type(text)=='string' and #text>0,'result schedules authored quote');quotePrepared=quotePrepared+1 end},radio={Play=function(_,cue) Check(cue=='done','result done cue');radio=radio+1 end},
  rules={grade=sample.grade,Drain=function() return {{type='result',grade=sample.grade,time=sample.time}} end},
  session={Pause=function() paused=paused+1 end,app={store=store}}},Mission)
 mission:Events()
 Check(mission.newBest==sample.newBest,'source new-best grade/time contract')
 Check(written.s1.grade==sample.best.grade,'source retains highest grade independently')
 Check(written.s1.time==sample.best.time,'source retains shortest time independently')
 Check(written.s1.clears==sample.best.clears,'source increments clear count')
 Check(written.other.grade=='A' and mission.saved and paused==1 and radio==0 and quotePrepared==1,'result keeps progress and lifecycle without repeating completion cue')
end
return {result='PASS',checks=checks,sourceProgressScenarios=#SOURCE.cases,
 boundary='Actual Lua TrialSession.HandleKey, StoryComms.SkipLine and Mission.Events against actual frozen JS key/recordClear; native-free UI/audio/actor doubles. No Web/render/audio continuity acceptance.'}
'''


def main():
    os.chdir(ROOT)
    source = json.loads(subprocess.check_output(
        ['node', '--experimental-vm-modules', 'tools/migration/story-input-progress-source.mjs'], text=True, encoding='utf-8'))
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value

    lua.globals().SOURCE = convert(source)
    result = dict(lua.execute(LUA))
    result['source'] = source['source']
    result['production'] = {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() for relative in
                            ['scripts/app/TrialSession.lua', 'scripts/story/Mission.lua', 'scripts/audio/StoryComms.lua']}
    output = ROOT / 'docs/migration/evidence/story-input-progress-offline.json'
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()

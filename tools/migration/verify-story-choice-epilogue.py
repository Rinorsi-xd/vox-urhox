"""Actual frozen StoryMission timers/leave versus production Lua death and epilogue flow."""
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

reference = json.loads(subprocess.check_output(
    ['node', 'tools/migration/story-choice-epilogue-source.mjs'], text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)


def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value


def plain(value):
    if hasattr(value, 'items'):
        items = dict(value)
        if all(isinstance(key, int) for key in items):
            return [plain(items[key]) for key in range(1, len(items) + 1)]
        return {key: plain(item) for key, item in items.items()}
    return value


levels = {f's{index}': json.loads((ROOT / f'assets/Story/Mission/Level{index}.json').read_text(
    encoding='utf-8-sig'))['level'] for index in [2, 3, 4, 5]}
lua.globals().Levels = convert(levels)
old = ROOT / '.tmp/outgame-cached-1792088233891/scripts'
lua.globals().OldMission = (old / 'story/Mission.lua').read_text(encoding='utf-8-sig')
lua.globals().OldRules = (old / 'story/MissionRules.lua').read_text(encoding='utf-8-sig')
runner = lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,id in ipairs({'story.MissionData','combat.ArenaData','combat.CarUnit','combat.EnemyDriver','core.Math3','drive.SpawnSpecCache'})do
 package.preload[id]=function()return {}end
end
local attached
package.preload['ui.Epilogue']=function()return {Attach=function(_,_,callback)
 attached={callback=callback};return attached
end}end
local Mission=require 'story.Mission';local Rules=require 'story.MissionRules'
local Legacy=assert(load(OldMission))();local LegacyRules=assert(load(OldRules))()
return {
 choices=function(test,legacy)
  local level=Levels[test.level];local step,index
  for i,s in ipairs(level.steps)do if s.id==test.step then step=s;index=i;break end end
  local rules=(legacy and LegacyRules or Rules).New(level,{Update=function()end})
  rules.begun=true;rules:Go(index);rules:Drain()
  local chosen,beat=step.ask,nil
  for _,b in ipairs(step.beats or {})do if b.ask and b.ask.id==test.id then chosen=b.ask;beat=b end end
  assert(chosen.id==test.id,'authored choice missing')
  rules.stepT=beat and beat.t or 0;rules.progress=beat and beat.p or 0
  -- Exercise production Beats with just the authored trigger; unrelated spawn/FX
  -- beats are independently covered and must not inject extra choices here.
  local selected={};for k,v in pairs(step)do selected[k]=v end
  selected.ask=not beat and chosen or nil;selected.beats=beat and {beat} or {}
  rules.level={spawn=level.spawn,steps={selected}};rules.index=1
  local world={alive=false,pos={0,0,0},enemies=0,enemyPositions={},talking=false}
  rules:Beats(.6,world)
  local sayEvents,choicesOpened=0,0
  local function Reply()
   local found
   for _,event in ipairs(rules:Drain())do
    if event.type=='say' then found=event.lines;sayEvents=sayEvents+1
    elseif event.type=='choice' then choicesOpened=choicesOpened+1 end
   end
   return found
  end
  local reply=Reply();local frames={}
  for _,to in ipairs(test.times)do
   local dt=.01;rules.time=to-dt;rules.deadAt=to-.1
   rules:Step(dt,world)
   reply=Reply() or reply
   frames[#frames+1]={time=to,choice=rules.choice and rules.choice.prompt,
    flag=rules.flags[chosen.id],reply=reply,choicesOpened=choicesOpened,sayEvents=sayEvents,stepT=rules.stepT}
  end
  return frames
 end,
 epilogue=function(test,legacy)
  local progress={s5={grade='A',time=90,clears=2},epilogue=test.prior>0 and test.prior or nil}
  local starts,exits,writes=0,0,0
  local function Copy(data)
   local copy={};for key,value in pairs(data)do copy[key]=type(value)=='table' and Copy(value) or value end;return copy
  end
  local store={Read=function()return Copy(progress)end,Write=function(_,key,data)
   assert(key=='story-progress');progress=Copy(data);writes=writes+1;return true
  end}
  local function New()
   return setmetatable({level=Levels.s5,rules={finished=true},session={scene={},app={store=store}}},
    {__index=legacy and Legacy or Mission})
  end
  local current=New()
  local left={}
  local function Leave(target)
   if left[target]then return end
   local previous=attached
   local started=target:StartEpilogue({},function()left[target]=true;exits=exits+1 end)
   if started and attached~=previous then starts=starts+1 end
   if not started then left[target]=true;exits=exits+1 end
  end
  local function Sample()return {starts=starts,exits=exits,watched=(progress.epilogue or 0)>=6}end
  Leave(current);local first=Sample();Leave(current);local repeated=Sample()
  if test.finish and current.epilogue then attached.callback()end
  local final=Sample();Leave(New())
  assert(progress.s5.grade=='A' and progress.s5.clears==2,'episode save damaged clear record')
  return {first=first,repeatState=repeated,final=final,reenter=Sample(),writes=writes}
 end
}
''')

checks = 0
reproduced = []
for case in reference['choiceCases']:
    actual = plain(runner.choices(convert(case), False))
    for got, expected in zip(actual, case['frames'], strict=True):
        for key in ['choice', 'flag', 'reply', 'choicesOpened', 'sayEvents', 'stepT']:
            assert got.get(key) == expected.get(key), (case['id'], got, expected)
            checks += 1
    before = plain(runner.choices(convert(case), True))
    assert before != actual, ('old choice unexpectedly matched', case['id'])
    reproduced.append({'case': case['id'], 'before': before, 'after': actual})
    checks += 1
for case in reference['epilogueCases']:
    actual = plain(runner.epilogue(convert(case), False))
    for key, alias in [('first', 'first'), ('repeat', 'repeatState'), ('final', 'final'), ('reenter', 'reenter')]:
        assert actual[alias] == case[key], (case, key, actual[alias])
        checks += 1
    assert actual['writes'] == (0 if case['prior'] >= 6 else 1)
    checks += 1
    if case['prior'] < 6:
        before = plain(runner.epilogue(convert(case), True))
        assert before['first'] != actual['first']
        reproduced.append({'case': f"epilogue-{case['prior']}-{case['finish']}", 'before': before, 'after': actual})
        checks += 1

report = {'pass': True, 'checks': checks, 'choiceCases': len(reference['choiceCases']),
          'epilogueCases': len(reference['epilogueCases']), 'source': reference['source'],
          'production': {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
                         for relative in ['scripts/story/Mission.lua', 'scripts/story/MissionRules.lua']},
          'beforeSnapshot': str(old.relative_to(ROOT)), 'reproduced': reproduced,
          'boundary': 'Actual frozen StoryMission._beats/ask/update/leave against actual Lua MissionRules Beats/dead Step and Mission.StartEpilogue. Deterministic source timeout/localStorage and Lua store/UI adapters; authored s2/s3/s4 choices and v6 epilogue. No browser/native, natural mission, audible or performance acceptance.'}
output = ROOT / 'docs/migration/evidence/story-choice-epilogue-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: value for key, value in report.items() if key != 'reproduced'}, ensure_ascii=False, indent=2))

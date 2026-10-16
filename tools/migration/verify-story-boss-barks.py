"""Compare actual frozen Boss.say/talk/_ultBlast with actual Lua rule dispatch."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-barks-source.mjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)


def convert(value):
    if isinstance(value,dict):return lua.table_from({k:convert(v) for k,v in value.items()})
    if isinstance(value,list):return lua.table_from([convert(v) for v in value])
    return value


def plain(value):
    if hasattr(value,'items'):
        rows=dict(value)
        if not rows:return []
        if all(isinstance(k,int) for k in rows):return [plain(rows[k]) for k in range(1,len(rows)+1)]
        return {k:plain(v) for k,v in rows.items()}
    return value


old=ROOT/'.tmp/outgame-cached-1792113063203/scripts/combat/StoryBoss.lua'
assert hashlib.sha256(old.read_bytes()).hexdigest()=='16867f032b72a7ddcedd3ef8ecca3bdbcea0ee53fcff43b6c5a97e7455af4c44'
data=json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8-sig'))
assert data['level']['steps'][1]['lines']==reference['authoredLines']
lua.globals().BossData=convert(data)
lua.globals().LegacyBossCode=old.read_text(encoding='utf-8-sig')
run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'combat.CarUnit','combat.EnemyDriver','core.Coord','audio.StoryRadio'})do package.preload[name]=function()return {}end end
package.preload['core.ResourceData']=function()return {Read=function()return BossData end}end
local Boss=require 'combat.StoryBoss';local Rules=require 'story.BossRules';local Legacy=assert(load(LegacyBossCode))()
for i=1,100 do local name,value=debug.getupvalue(Boss.Say,i);if not name then break end;if name=='BARKS' then CurrentBarks=value end end
return function(test,legacy)
 local calls={};local voice={Talking=function()return test.talking end,Say=function(_,lines,urgent,append)
  calls[#calls+1]={lines=lines,urgent=urgent,append=append}
 end}
 local lines={};for key,value in pairs(BossData.level.steps[2].lines)do lines[key]=value end
 if test.synthetic then lines[test.key]={'nono','synthetic bark gate','nono_deadpan'}end
 local rules=Rules.New(BossData.boss,150)
 local player={pos={0,0,0},bodyHpMax=3000,hull=true,Position=function(self)return self.pos end,
  HurtHull=function()end,RecordDamage=function()end,Explode=function()end,Flush=function()end}
 local self=setmetatable({rules=rules,time=10,storyUntil=test['until'],step={lines=lines,title='boss'},
  unit={},mission={voice=voice,player=player,rules={}},world={layout={enginePit={points={floorCentre={0,0,0}}}}},session={},
  radio={Play=function()end},Capture=function()end,Fx=function()end,Ground=function()return 0 end,
  Team=function()return {player}end,UnderRoof=function()return test.safe end},
  {__index=legacy and Legacy or Boss})
 if test.mode=='ult' then rules:Emit('ultBlast')else rules:Emit('say',{key=test.key})end
 self:Events()
 return {calls=calls,storyUntil=self.storyUntil}
end
''')
run_players=lua.execute(r'''
Scene=function()return {CreateChild=function()return {CreateComponent=function()return {SetSoundType=function()end,StopImmediate=function()end}end}end,Dispose=function()end}end
cache={GetResourceAsync=function()end}
audio={PauseSoundType=function()end,ResumeSoundType=function()end}
package.preload['audio.AudioLevels']=function()return {RawGain=function()return .4 end,SetSpeaking=function()end}end
package.preload['ui.CommsCard']=function()return {Tick=function()end,Dispose=function()end}end
package.preload['audio.StoryCommsCues']=function()return {New=function()return {Play=function()end,Update=function()end,Dispose=function()end}end}end
local Boss=require 'combat.StoryBoss';local Rules=require 'story.BossRules';local Comms=require 'audio.StoryComms';local Legacy=assert(load(LegacyBossCode))()
return function(test,legacy)
 Comms.Shutdown();local card=Comms.New(nil,{voices={}})
 card.time=10-test.age;card:Say({{'nono','retained previous bark'}},false,false);card:Update(.001,true);card.time=10
 local self=setmetatable({time=10,storyUntil=test['until'],step=BossData.level.steps[2],mission={voice=card},rules=Rules.New(BossData.boss,150)},
  {__index=legacy and Legacy or Boss})
 if test.key=='firstRise' then self.rules:Say('firstRise',true);self:Events()
 elseif test.key=='down' then self.storyUntil=0;self:Say('down',legacy and nil or true)
 elseif test.key=='phase2' then self.rules:Say('phase2',true);self:Events()
 elseif test.key=='ultHit' then self:Say('ultHit',legacy and nil or true)
 elseif test.key=='entrance' then self:Say('entrance',legacy and nil or true)
 else self:Say(test.key)end
 local result={current=card.card and card.card.text or false,queue=card.queue,storyUntil=self.storyUntil}
 card:Dispose();Comms.Shutdown();return result
end
''')
run_once=lua.execute(r'''
local Boss=require 'combat.StoryBoss'
return function(key)
 local calls={};local voice={talking=true,Talking=function(self)return self.talking end,
  Say=function(_,lines,urgent,append)calls[#calls+1]={lines=lines,urgent=urgent,append=append}end}
 local self=setmetatable({time=10,storyUntil=0,step=BossData.level.steps[2],mission={voice=voice}},{__index=Boss})
 local trace={}
 for _,talking in ipairs({true,false,false})do
  voice.talking=talking;self:Once(key);local copy={};for i,v in ipairs(calls)do copy[i]=v end
  trace[#trace+1]={calls=copy,said=self.said[key]==true,storyUntil=self.storyUntil}
 end
 return trace
end
''')
run_events=lua.execute(r'''
local Boss=require 'combat.StoryBoss';local Rules=require 'story.BossRules';local Legacy=assert(load(LegacyBossCode))()
return function(key,legacy)
 local calls={};local voice={talking=true,Talking=function(self)return self.talking end,
  Say=function(_,lines,urgent,append)calls[#calls+1]={lines=lines,urgent=urgent,append=append}end}
 local player={pos={0,0,0},alive=true,Position=function(self)return self.pos end,vehicle={telemetry={contact=1}}}
 local self=setmetatable({time=10,storyUntil=0,step=BossData.level.steps[2],mission={voice=voice,player=player},
  rules=Rules.New(BossData.boss,150),session={},world={},Team=function()return {player}end,
  Fx=function()end,Remove=function()end,Ground=function()return 0 end,HitUnit=function()end},
  {__index=legacy and Legacy or Boss})
 local trace={}
 for _,talking in ipairs({true,false,false})do
  voice.talking=talking
  if key=='allyDown' then self.allies={{unit={pos={0,0,0},alive=false,Flush=function()end}}};self:StepAllies(.01)
  elseif key=='stompHit' then self.rules:Emit('impact',{pos={0,0,0},r=10,damage=1,kind='stomp'});self:Events()
  else self.rules:Emit(key=='sweepHit' and 'sweep' or 'lanes',{pos={0,0,0},yaw=0});self:Events()end
  local copy={};for i,v in ipairs(calls)do copy[i]=v end
  trace[#trace+1]={calls=copy,said=self.said and self.said[key]==true or false,storyUntil=self.storyUntil}
 end
 return trace
end
''')
assert sorted(lua.globals().CurrentBarks.keys())==sorted(reference['barks'])
checks=2
failures=[]
before=[]
for case in reference['cases']:
    actual=plain(run(convert(case['test']),False))
    previous=plain(run(convert(case['test']),True))
    for key in ['calls','storyUntil']:
        checks+=1
        expected=case['expected'][key]
        equal=actual[key]==expected or isinstance(actual[key],(int,float)) and abs(actual[key]-expected)<1e-9
        if not equal:failures.append({'test':case['test'],'key':key,'actual':actual[key],'expected':expected})
        old_equal=previous[key]==expected or isinstance(previous[key],(int,float)) and abs(previous[key]-expected)<1e-9
        if not old_equal:before.append({'test':case['test'],'key':key,'actual':previous[key],'expected':expected})
for case in reference['playerCases']:
    actual=plain(run_players(convert(case['test']),False))
    previous=plain(run_players(convert(case['test']),True))
    for key,expected in case['expected'].items():
        checks+=1
        equal=actual[key]==expected or isinstance(actual[key],(int,float)) and isinstance(expected,(int,float)) and abs(actual[key]-expected)<1e-9
        if not equal:failures.append({'playerTest':case['test'],'key':key,'actual':actual[key],'expected':expected})
        if previous[key]!=expected:before.append({'playerTest':case['test'],'key':key,'actual':previous[key],'expected':expected})
for case in reference['onceCases']:
    checks+=1
    actual=plain(run_once(case['key']))
    if actual!=case['trace']:failures.append({'onceKey':case['key'],'actual':actual,'expected':case['trace']})
for case in reference['eventCases']:
    checks+=1
    actual=plain(run_events(case['key'],False))
    previous=plain(run_events(case['key'],True))
    if actual!=case['trace']:failures.append({'actualEventKey':case['key'],'actual':actual,'expected':case['trace']})
    if previous!=case['trace']:before.append({'actualEventKey':case['key'],'actual':previous,'expected':case['trace']})
digest=lambda path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
report={'result':'PASS' if not failures and before else 'FAIL','checks':checks,'cases':len(reference['cases']),
 'actualCommunicationsCases':len(reference['playerCases']),'onceCases':len(reference['onceCases']),
 'actualHitAndAllyDeathCases':len(reference['eventCases']),
 'source':reference['source'],'sourceBarks':reference['barks'],'failures':failures,
 'reproducedBeforeFix':{'snapshot':str(old.relative_to(ROOT)),'sha256':hashlib.sha256(old.read_bytes()).hexdigest(),'differences':before},
 'production':{p:digest(p) for p in ['scripts/combat/StoryBoss.lua','scripts/story/BossRules.lua','assets/Story/Mission/Level5.json']},
 'tools':{p:digest(p) for p in ['tools/migration/story-boss-barks-source.mjs','tools/migration/verify-story-boss-barks.py']},
 'boundary':'Actual complete frozen FoxBoss.say/talk/once/_ultBlast versus actual Lua BossRules.Emit -> StoryBoss.Events -> Say/Once. Actual NonoComms and actual StoryComms compare retained card and queue for firstRise, pod, truck, entrance, down, phase2 and ultHit; native/DOM/audio adapters only. Authored lines preserved; retired-key synthetic cases separately identified. No audible playback, GPU, natural fifth-mission completion or frame-time acceptance.'}
out=ROOT/'docs/migration/evidence/story-boss-barks-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':report['result'],'checks':checks,'cases':len(reference['cases']),'failed':len(failures),
 'beforeDifferences':len(before),'firstFailure':failures[:1]},ensure_ascii=False))
if failures or not before:sys.exit(1)

"""Actual frozen H5 timer callbacks versus production Mission timers and Events."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
reference=json.loads(subprocess.check_output(['node','tools/migration/story-mission-timers-source.mjs'],text=True,encoding='utf-8'))
legacy=ROOT/'.tmp/outgame-cached-1792115578618/scripts/story/MissionRules.lua'
legacy_hash=hashlib.sha256(legacy.read_bytes()).hexdigest()

def run(test,variant='production'):
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
    code=(ROOT/'scripts/story/MissionRules.lua').read_text(encoding='utf-8-sig')
    if variant=='legacy':code=legacy.read_text(encoding='utf-8-sig')
    if variant=='wrong-fail-delay':code=code.replace('self:Now()-self.failAt<3','self:Now()-self.failAt<2.9')
    if variant=='wrong-ask-delay':code=code.replace('at=self:Now()+.3','at=self:Now()+.2')
    lua.globals().RulesCode=code
    lua.globals().Test=convert(test)
    lua.globals().Reference=convert(reference)
    lua.globals().SimulationOnly=variant=='simulation-only'
    result=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'story.MissionData','combat.ArenaData','combat.CarUnit','combat.EnemyDriver','core.Math3','drive.SpawnSpecCache'})do package.preload[name]=function()return {}end end
local Rules=assert(load(RulesCode))()
local Mission=require 'story.Mission';local Timers=require 'story.MissionTimers'
local wall=10000;local nodes={};local log={}
Time={GetSystemTime=function()return wall end}
Node=function()
 local node={};nodes[#nodes+1]=node
 function node:CreateScriptObject()return {SubscribeToEvent=function(_,event,callback)self.event=event;self.callback=callback end}end
 function node:Dispose()self.disposed=true;self.callback=nil end
 return node
end
local function Add(event)log[#log+1]=event end
local step=Test.kind=='escort' and Reference.escort or Reference.hold
if Test.op=='beat' then step.beats={{t=0,ask=Reference.choice}}end
local convoy=Test.kind=='escort' and require('story.ConvoyRules').New(step,{nodes={}},function()return 0 end) or nil
if convoy then convoy.d=50;convoy.v=4;convoy.hp=.2;convoy.cpD=10;convoy.cpHp=.8 end
local rules=Rules.New({steps={step}},convoy,function()return wall/1000 end)
rules.begun=true;rules:Go(1);rules:Drain();rules.time=10
local owner=setmetatable({rules=rules,convoy=convoy,level={steps={step}},player={alive=true},
 voice={Say=function(_,lines,urgent)if lines and #lines>0 then Add({kind='say',lines=lines,urgent=urgent==true})end end},
 radio={Play=function(_,cue)if cue=='alert' then Add({kind='radio',cue=cue})end end},
 view={Objective=function()Add({kind='objective',index=rules.index-1})end},
 choiceView={Cancel=function()end,Open=function(_,spec)Add({kind='choice',prompt=spec.prompt})end,Pick=function()end},
 Banner=function(_,kick,title,sub,tone,ms)Add({kind='banner',kick=kick,title=title,sub=sub,tone=tone,ms=ms})end,
 Place=function(_,at)Add({kind='place',at=at})end,
 ClearEnemies=function()Add({kind='clearEnemies'})end},{__index=Mission})
local timer=Timers.New(owner)
-- The frozen legacy rules intentionally lack the independent timer adapter.
if not rules.UpdateTimers then rules.UpdateTimers=function()rules:UpdateChoices()end end
if Test.op=='fail' then rules:Fail('failed',{{'nono','failure'}});if Test['repeat']then rules:Fail('duplicate',{{'nono','wrong'}})end
elseif Test.op=='ask' then rules:Ask(Reference.choice)
else rules:Beats(.1,{talking=false,enemies=0})end
owner:Events()
local frames={}
for _,action in ipairs(Test.actions)do
 wall=10000+action.wall
 if action.reason then owner.reason=action.reason end
 if action.pick~=nil then rules:Choose(action.pick+1);owner:Events()end
 if not SimulationOnly then for _,node in ipairs(nodes)do if not node.disposed then node.callback()end end end
 local copy={};for i,event in ipairs(log)do copy[i]=event end
 frames[#frames+1]={log=copy,failing=rules.failAt~=nil,choice=rules.choice~=nil,flag=rules.flags.test,simTime=rules.time}
end
timer:Dispose();timer:Dispose()
return {frames=frames,released=timer.node==nil and timer.mission==nil and timer.disposed and nodes[1].disposed}
''')
    result=plain(result)
    for frame in result['frames']:frame.setdefault('flag',None)
    return result

checks=0
failures=[]
negatives={name:[] for name in ['legacy','simulation-only','wrong-fail-delay','wrong-ask-delay']}
for case in reference['cases']:
    result=run(case['test'])
    checks+=1
    assert result['released']
    for index,(actual,expected) in enumerate(zip(result['frames'],case['expected'],strict=True)):
        for key,value in expected.items():
            checks+=1
            if actual.get(key)!=value:failures.append({'case':case['test']['name'],'frame':index,'key':key,'actual':actual.get(key),'expected':value})
    for variant in negatives:
        if run(case['test'],variant)['frames']!=case['expected']:negatives[variant].append(case['test']['name'])
for name,cases in negatives.items():checks+=1;assert cases,('Mutation escaped',name)
assert not failures,json.dumps(failures,ensure_ascii=False)
paths=['scripts/story/Mission.lua','scripts/story/MissionRules.lua','scripts/story/MissionTimers.lua']
report={'result':'PASS','checks':checks,'cases':len(reference['cases']),'source':reference['source'],
 'productionHashes':{path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in paths},
 'inputs':{path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in ['tools/migration/story-mission-timers-source.mjs','tools/migration/verify-story-mission-timers.py']},
 'legacy':{'path':str(legacy.relative_to(ROOT)),'sha256':legacy_hash},'negativeControls':negatives,
 'boundary':'Actual frozen StoryMission.fail/ask/_beats callbacks and actual escort/hold retry; production MissionRules, MissionTimers and Mission.Events. Native Node and screen/audio adapters. Sim clocks held fixed. No GPU/native listener, natural mission, Web focus, overlapping choices or audible output acceptance.'}
output=ROOT/'docs/migration/evidence/story-mission-timers-offline.json'
output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))

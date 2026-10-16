"""Execute frozen H5 timer callbacks against staged or current production Lua."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
STAGE=ROOT/'.tmp/boss-exposed-candidate'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--staged',action='store_true',help='Verify staged candidate before production integration')
parser.add_argument('--output',type=Path)
args=parser.parse_args()
TARGET=STAGE/'scripts' if args.staged else ROOT/'scripts'
LEGACY=ROOT/'.tmp/outgame-cached-1792114575097'
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

FROZEN={'scripts/combat/StoryBoss.lua':'426d76cf94aeef94c0b4490ba721652c2a7bef152f9e3dd7f0e01c696126aaee',
        'scripts/story/BossRules.lua':'597396c26f1b0b57a5d50dddc55fb0a68189d063c742c65079f385bb8ef68f1a'}
def frozen():
    for path,expected in FROZEN.items():
        assert hashlib.sha256((LEGACY/path).read_bytes()).hexdigest()==expected,path
def hashes():
    paths=['combat/StoryBoss.lua','story/BossRules.lua','combat/BossExposedDelay.lua']
    return {'production':{path:hashlib.sha256((ROOT/'scripts'/path).read_bytes()).hexdigest() if (ROOT/'scripts'/path).exists() else None for path in paths},
            'target':{path:hashlib.sha256((TARGET/path).read_bytes()).hexdigest() for path in paths},'frozen5487':FROZEN}
frozen()
before=hashes()
reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-exposed-source.mjs'],text=True,encoding='utf-8'))
data=json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8-sig'))
assert reference['lines']==data['level']['steps'][1]['lines']

def run(test,variant='candidate'):
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
    lua.globals().BossData=convert(data)
    lua.globals().Test=convert(test)
    timer=(TARGET/'combat/BossExposedDelay.lua').read_text(encoding='utf-8-sig')
    if variant=='zero-delay':timer=timer.replace('+2600','+0')
    if variant=='finished-gate':timer=timer.replace('not boss.mission.reason and','not boss.mission.reason and not boss.mission.finished and')
    if variant=='simulation-only':timer=timer.replace("receiver:SubscribeToEvent('Update',function() self:Update() end)","receiver:SubscribeToEvent('BossSimulationUpdate',function() self:Update() end)")
    lua.globals().TimerCode=timer
    lua.globals().CodeRoot=str(LEGACY/'scripts' if variant=='frozen-5487' else TARGET).replace('\\','/')
    result=lua.execute(r'''
package.path=CodeRoot..'/?.lua;scripts/?.lua;'..package.path
for _,name in ipairs({'combat.CarUnit','combat.EnemyDriver','core.Coord','audio.StoryRadio'})do package.preload[name]=function()return {}end end
package.preload['core.ResourceData']=function()return {Read=function()return BossData end}end
package.preload['combat.BossExposedDelay']=function()return assert(load(TimerCode))()end
local wall=10000;local nodes={}
Time={GetSystemTime=function()return wall end}
Node=function()
 local node={};nodes[#nodes+1]=node
 function node:CreateScriptObject()return {SubscribeToEvent=function(_,event,callback)self.event=event;self.callback=callback end}end
 function node:Dispose()self.disposed=true;self.callback=nil end
 return node
end
local Boss=require 'combat.StoryBoss';local Rules=require 'story.BossRules'
local rules=Rules.New(BossData.boss,150);rules.hp=100;rules.kneels=Test.initialKneels or 1
local calls={};local voice={Talking=function()return Test.talking==true end,
 Say=function(_,lines,urgent,append)calls[#calls+1]={wall=wall,lines=lines,urgent=urgent,append=append}end}
local player={weapons={energy=0,energyMax=100}}
local boss=setmetatable({rules=rules,time=10,storyUntil=Test['until'] or 0,step=BossData.level.steps[2],
 mission={voice=voice,player=player,rules={stats={}}},view={Dispose=function()end},allies={},unit={},shots={},
 Capture=function()end,Banner=function()end,Remove=function()end},{__index=Boss})
math.random=function()return 1 end
local trace={}
for _,action in ipairs(Test.actions)do
 wall=10000+action.wall
 if action.hp~=nil then rules.hp=action.hp end
 if action.reason~=nil then boss.mission.reason=action.reason end
 if action.finished~=nil then boss.mission.finished=action.finished end
 if action.kneel then
  for i,node in ipairs(rules.nodes)do node.broken=i<=action.broken end
  rules.state='fight';rules:Kneel();boss:Events()
 end
 if action.dispose then boss:Dispose()end
 for _,node in ipairs(nodes)do if not node.disposed and node.event=='Update' then node.callback()end end
 local snapshot={};for i,call in ipairs(calls)do snapshot[i]=call end
 local pending=0;for _,node in ipairs(nodes)do if not node.disposed then pending=pending+1 end end
 trace[#trace+1]={calls=snapshot,storyUntil=boss.storyUntil,scheduled=rules.exposedSaid==true,pending=pending}
end
return {trace=trace,listeners=#nodes,disposed=nodes[1] and nodes[1].disposed or false}
''')
    return plain(result)

checks=1
failures=[]
negative={variant:[] for variant in ['frozen-5487','zero-delay','finished-gate','simulation-only']}
for case in reference['cases']:
    result=run(case['test'])
    checks+=1
    assert result['listeners']<=1,case['test']['name']
    expected=case['expected']
    if case['test']['name']=='leave-disposes':
        # Native Dispose cancels the listener eagerly; source callback remains queued but suppresses speech.
        expected=json.loads(json.dumps(expected))
        for frame in expected[1:]:frame['pending']=0
        checks+=2
        assert result['disposed'] and result['listeners']==1
    for index,(actual,wanted) in enumerate(zip(result['trace'],expected)):
        for key in wanted:
            checks+=1
            if actual[key]!=wanted[key]:failures.append({'case':case['test']['name'],'frame':index,'key':key,'actual':actual[key],'expected':wanted[key]})
    for variant in negative:
        actual=run(case['test'],variant)['trace']
        if actual!=expected:negative[variant].append(case['test']['name'])
for variant,cases in negative.items():
    checks+=1
    assert cases,f'Mutation escaped: {variant}'
deadline=next(case['test'] for case in reference['cases'] if case['test']['name']=='deadline-and-repeat')
legacy_calls=run(deadline,'frozen-5487')['trace'][0]['calls']
candidate_calls=run(deadline)['trace'][0]['calls']
exposed=data['level']['steps'][1]['lines']['exposed']
if isinstance(exposed[0],str):exposed=[exposed]
checks+=2
assert any(call['lines']==exposed for call in legacy_calls),'Production immediate speech was not reproduced'
assert not any(call['lines']==exposed for call in candidate_calls),'Candidate spoke before the deadline'
assert not failures,json.dumps(failures,ensure_ascii=False)
frozen()
after=hashes()
assert before==after,'Inputs changed during the regression'
evidence={'status':'PASS','scope':'CPU-only actual H5 wall-clock callbacks and actual Lua Rules/Events/Say; no browser or actual audio playback',
 'target':'staged' if args.staged else 'production','targetRoot':str(TARGET),'checks':checks,'cases':len(reference['cases']),
 'baseline':reference['baseline'],'before':before,'after':after,
 'productionHashes':{'scripts/'+path:digest for path,digest in after['production'].items() if digest is not None},
 'inputs':{path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in ['tools/migration/story-boss-exposed-source.mjs','tools/migration/verify-story-boss-exposed.py']},
 'negativeControls':negative,'unverified':['native listener behavior','Web timer focus behavior','natural Level5 playback','actual audio'],
 'failures':failures}
output=args.output or ROOT/('docs/migration/evidence/story-boss-exposed'+('-staged' if args.staged else '')+'-offline.json')
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(evidence,ensure_ascii=False))

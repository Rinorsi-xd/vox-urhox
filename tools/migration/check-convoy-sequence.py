"""Compare actual frozen escort checkpoints with Lua rules and Mission.Events."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference=json.loads(subprocess.check_output(['node','tools/migration/source-convoy-sequence.cjs'],encoding='utf-8'))
authored=json.loads((ROOT/'assets/Story/Mission/Level2.json').read_text(encoding='utf-8-sig'))['level']
def authored_subset(source,imported):
    if isinstance(source,dict): return {k:authored_subset(v,imported[k]) for k,v in source.items()}
    if isinstance(source,list):
        assert len(source)==len(imported),'Authored Level2 array drift'
        return [authored_subset(a,b) for a,b in zip(source,imported)]
    return imported
assert authored_subset(reference['level'],authored)==reference['level'],'Authored Level2 drift'
lua=LuaRuntime(unpack_returned_tuples=True)
def to_lua(value):
    if isinstance(value,dict): return lua.table_from({k:to_lua(v) for k,v in value.items()})
    if isinstance(value,list): return lua.table_from([to_lua(v) for v in value])
    return value
def from_lua(value):
    if hasattr(value,'keys'):
        keys=list(value.keys())
        if keys and all(isinstance(k,int) for k in keys): return [from_lua(value[k]) for k in sorted(keys)]
        return {k:from_lua(value[k]) for k in keys}
    return value
convoy=(ROOT/'scripts/story/ConvoyRules.lua').read_text(encoding='utf-8-sig')
before="        r:Emit('say',{lines=s.cpLines[self.cp]})\n        r:Emit('radio',{cue='install'})"
after="        r:Emit('radio',{cue='install'})\n        r:Emit('say',{lines=s.cpLines[self.cp]})"
mode=sys.argv[1] if len(sys.argv)>1 else 'production'
assert mode in {'production','candidate','baseline','old-order','no-cue','no-lines'},'Unknown verification mode'
if mode=='candidate':
    assert convoy.count(before)+convoy.count(after)==1
    convoy=convoy.replace(before,after)
elif mode in {'baseline','old-order'}:
    assert convoy.count(before)+convoy.count(after)==1
    convoy=convoy.replace(after,before)
elif mode=='no-cue':
    assert convoy.count("        r:Emit('radio',{cue='install'})")==1
    convoy=convoy.replace("        r:Emit('radio',{cue='install'})",'')
elif mode=='no-lines':
    assert convoy.count("        r:Emit('say',{lines=s.cpLines[self.cp]})")==1
    convoy=convoy.replace("        r:Emit('say',{lines=s.cpLines[self.cp]})",'')
mission=(ROOT/'scripts/story/Mission.lua').read_text(encoding='utf-8-sig')
lua.globals().Dependencies=to_lua(re.findall(r'require\s*\(?\s*[\'\"]([^\'\"]+)',mission))
lua.globals().ConvoyCode=convoy
lua.globals().Reference=to_lua(reference)
actual=from_lua(lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,id in ipairs(Dependencies)do if id~='story.MissionRules' and id~='story.ConvoyRules'then package.preload[id]=function()return {}end end end
package.preload['story.ConvoyRules']=assert(load(ConvoyCode,'@scripts/story/ConvoyRules.lua'))
math.random=function()return 1 end
local Mission=require 'story.Mission'
local Rules=require 'story.MissionRules'
local Convoy=require 'story.ConvoyRules'
local events,cases={},{};local current=0
local function Emit(kind,...)events[#events+1]={case=current,type=kind,args={...}}end
local step;for _,s in ipairs(Reference.level.steps)do if s.kind=='escort'then step=s end end
for _,input in ipairs(Reference.cases)do
 current=input.id
 local truck=Convoy.New(step,Reference.nav,function(_,_,hint)return hint end)
 truck.cp=input.cp;truck.hp=input.hp;truck.d=truck.total*step.checkpoints[input.cp+1]-.01;truck.v=input.cross and step.speed or 0
 local pos={truck.pos[1],truck.pos[2],truck.pos[3]};if not input.cross then pos[1]=pos[1]+step.leash+1 end
 local r=Rules.New({steps={step}},truck);r.time=5;r.stats={};r.index=1
 local m=setmetatable({rules=r,level=Reference.level,player={alive=input.alive},
  voice={Say=function(_,lines,urgent)Emit('say',lines or {},urgent==true)end},
  radio={Play=function(_,cue)Emit('radio',cue)end},Banner=function(_,...)Emit('banner',...)end,
  view={truck={},time=0}},{__index=Mission})
 truck:Update(r,input.dt,{alive=input.alive,pos=pos,enemyPositions={},talking=false})
 m:Events()
 cases[#cases+1]={cp=truck.cp,cpD=truck.cpD,cpHp=truck.cpHp,d=truck.d,v=truck.v,hp=truck.hp,pos=truck.pos,yaw=truck.yaw,
  stats=r.stats,checkpoint=r.checkpoint,progress=r.progress,retitle=r.retitle}
end
return {cases=cases,events=events}
'''))
checks=0
failures=[]
def compare(path,a,b):
    global checks
    checks+=1
    if a==[] and b=={}: return
    if isinstance(a,(int,float)) and isinstance(b,(int,float)):
        if abs(a-b)>1e-9: failures.append({'path':path,'expected':a,'actual':b})
    elif isinstance(a,dict) and isinstance(b,dict):
        for key in a.keys()|b.keys(): compare(path+'/'+str(key),a.get(key),b.get(key))
    elif isinstance(a,list) and isinstance(b,list):
        if len(a)!=len(b): failures.append({'path':path+'/length','expected':len(a),'actual':len(b)})
        for i,(x,y) in enumerate(zip(a,b)): compare(path+'/'+str(i),x,y)
    elif a!=b: failures.append({'path':path,'expected':a,'actual':b})
compare('events',reference['events'],actual['events'])
compare('cases',[case['expected'] for case in reference['cases']],actual['cases'])
report={'status':'FAIL' if failures else 'PASS','mode':mode,'checks':checks,'cases':len(reference['cases']),
 'events':len(reference['events']),'failures':failures,'baseline':reference['baseline'],'sourceHashes':reference['hashes'],
 'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['scripts/story/ConvoyRules.lua','scripts/story/Mission.lua','assets/Story/Mission/Level2.json']},
 'testedConvoySha256':hashlib.sha256(convoy.encode()).hexdigest(),
 'boundary':'Actual frozen H5 escort.update and authored Level2 vs Lua ConvoyRules.Update and Mission.Events. Controlled checkpoint states, deterministic ground callback, no Native/Web, renderer, audio playback, natural completion or performance acceptance.'}
out=ROOT/('docs/migration/evidence/convoy-sequence-'+mode+'-offline.json')
out.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='failures'},indent=2))
print(json.dumps({'failureCount':len(failures),'firstFailures':failures[:5]},ensure_ascii=False,indent=2))
sys.exit(1 if failures else 0)

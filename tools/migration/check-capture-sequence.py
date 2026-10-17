"""Execute frozen capture rules and production Lua rules/event consumer on identical inputs."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference = json.loads(subprocess.check_output(['node', 'tools/migration/source-capture-sequence.cjs'], encoding='utf-8'))
authored = json.loads((ROOT / 'assets/Story/Mission/Level4.json').read_text(encoding='utf-8-sig'))['level']
assert {k: authored[k] for k in reference['level']} == reference['level'], 'Authored Lua Level4 differs from the frozen source'
lua = LuaRuntime(unpack_returned_tuples=True)
observer = lua.eval('loadfile')('tools/migration/capture-consumers-web-observer.lua')
assert not isinstance(observer, tuple), observer
def to_lua(value):
    if isinstance(value, dict): return lua.table_from({k: to_lua(v) for k, v in value.items()})
    if isinstance(value, list): return lua.table_from([to_lua(v) for v in value])
    return value
def from_lua(value):
    if hasattr(value, 'keys'):
        keys = list(value.keys())
        if keys and all(isinstance(k, int) for k in keys): return [from_lua(value[k]) for k in sorted(keys)]
        return {k: from_lua(value[k]) for k in keys}
    return value
lua.globals().Dependencies = to_lua(re.findall(r'require\s*\(?\s*[\'"]([^\'"]+)', (ROOT / 'scripts/story/Mission.lua').read_text(encoding='utf-8-sig')))
lua.globals().Level = to_lua(authored)
lua.globals().Frames = to_lua(reference['frames'])
mutant = sys.argv[1] if len(sys.argv)>1 else None
if mutant:
    variants = {
        'encounter': ('scripts/story/CaptureRules.lua', "r:Emit('say',{lines=s.alert,urgent=true});r:Emit('radio',{cue='alert'})\n        r:Emit('hideBeacon')", "r:Emit('say',{lines=s.alert,urgent=true});r:Emit('hideBeacon')\n        r:Emit('radio',{cue='alert'})"),
        'capture': ('scripts/story/CaptureRules.lua', "r:Emit('radio',{cue='install'})\n            r:Emit('say',{lines=s.capLines,urgent=true})", "r:Emit('say',{lines=s.capLines,urgent=true})\n            r:Emit('radio',{cue='install'})"),
        'scrub': ('scripts/story/Mission.lua', "self.view:Scrub(e.id);self.radio:Play('pickup')", "self.radio:Play('pickup');self.view:Scrub(e.id)"),
        'complete': ('scripts/story/Mission.lua', "elseif e.type=='complete' then self.view:HideBeacon();self:ClearEnemies();self.view:Objective(nil,nil)", "elseif e.type=='complete' then self.radio:Play('done');self.view:HideBeacon();self:ClearEnemies();self.view:Objective(nil,nil)")}
    path, before, after = variants[mutant]
    code = (ROOT/path).read_text(encoding='utf-8-sig')
    if mutant=='complete':
        assert code.count("            self.radio:Play('done')\n")==1
        code=code.replace("            self.radio:Play('done')\n",'')
    assert code.count(before)==1
    lua.globals().MutantModule = path.removeprefix('scripts/').removesuffix('.lua').replace('/','.')
    lua.globals().MutantCode = code.replace(before, after)
actual = from_lua(lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,id in ipairs(Dependencies)do if id~='story.MissionRules' then package.preload[id]=function()return {}end end end
package.preload['render.StoryStomp']=function()return {Emit=function()end}end
if MutantCode then package.preload[MutantModule]=assert(load(MutantCode,'@'..MutantModule))end
local Mission=require 'story.Mission';local Rules=require 'story.MissionRules'
local events,snapshots={},{};local frame=0;local enemies={};local r,m,site
local function Emit(kind,...)events[#events+1]={frame=frame,type=kind,args={...}}end
for _,input in ipairs(Frames)do
 if site~=input.site then
  site=input.site;enemies={};local s
  for _,step in ipairs(Level.steps)do if step.id==site then s=step end end
  r=Rules.New({steps={s},id=Level.id,no=Level.no,name=Level.name});r.begun=true
  m=setmetatable({rules=r,level=r.level,player={alive=true},
   voice={Say=function(_,lines,urgent)Emit('say',lines or {},urgent==true)end},
   radio={Play=function(_,cue)Emit('radio',cue)end},
   Banner=function(_,...)Emit('banner',...)end,
   Spawn=function(_,e)Emit('spawn',e.enemies,e.tag);for _ in ipairs(e.enemies)do enemies[#enemies+1]={tag=e.tag,pos=s.pos}end end,
   ClearEnemies=function()Emit('clearEnemies');enemies={}end,
   objective={Objective=function()end,Done=function()Emit('objectiveDone')end,Retitle=function()end},
   view={sites={},Objective=function()end,HideBeacon=function()Emit('hideBeacon')end,
    SiteCaptured=function(_,id)Emit('siteCaptured',id)end,Scrub=function(_,id)Emit('scrub',id)end}},Mission)
  r:Go(1);m:Events();r.asked=true
 end
 frame=input.frame;if input.clear then enemies={}end
 local tags,positions={},{};for _,e in ipairs(enemies)do tags[e.tag]=(tags[e.tag]or 0)+1;positions[#positions+1]=e.pos end
 local nav={nodes={}};for _,e in ipairs(r:StepSpec().guards)do if type(e.at)=='string'then nav.nodes[e.at]=r:StepSpec().pos end end
 -- Preserve Rules.Step/Done/Go. Capture the final state immediately before Done replaces the objective.
 local last
 local done=r.Done;r.Done=function(self,world,lines)
  last={phase=self.cap.phase,p=self.cap.p,scrub=self.cap.scrub,progress=self.progress,
   sites=self.stats.sites or 0,graffiti=self.stats.graffiti or 0,checkpoint=self.checkpoint,done=true}
  return done(self,world,lines)
 end
 r:Step(input.dt,{alive=true,pos=input.pos,enemyTags=tags,enemyPositions=positions,nav=nav,
  enemies=#enemies,interact=input.interact,size={w=2,below=1.5,above=1.5},talking=false})
 r.Done=done
 local state=last or {phase=r.cap.phase,p=r.cap.p,scrub=r.cap.scrub,progress=r.progress,
  sites=r.stats.sites or 0,graffiti=r.stats.graffiti or 0,checkpoint=r.checkpoint,done=false}
 state.frame=frame;snapshots[#snapshots+1]=state;m:Events()
end
return {events=events,snapshots=snapshots}
'''))
expected = reference['events']
failures = []
def compare(path, a, b):
    if a==[] and b=={}: return
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        if abs(a-b) > 1e-9: failures.append({'path': path, 'expected': a, 'actual': b})
    elif isinstance(a, dict) and isinstance(b, dict):
        for key in a.keys() | b.keys(): compare(path+'/'+str(key), a.get(key), b.get(key))
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b): failures.append({'path': path+'/length', 'expected': len(a), 'actual': len(b)})
        for i,(x,y) in enumerate(zip(a,b)): compare(path+'/'+str(i),x,y)
    elif a != b: failures.append({'path':path,'expected':a,'actual':b})
compare('events', expected, actual['events'])
# Lua Rules.progress exposes the capture/scrub meter, whereas JS stores capture p in cap and setsZoneProgress.
for snapshot in reference['snapshots']:
    snapshot['progress'] = snapshot['scrub']/1.6 if snapshot['phase']=='scrub' else snapshot['p']
compare('snapshots', reference['snapshots'], actual['snapshots'])
report={'status':'FAIL' if failures else 'PASS','frames':len(reference['frames']),
 'events':len(expected),'failures':failures,'source':reference,'actual':actual,
 'hashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['scripts/story/CaptureRules.lua','scripts/story/MissionRules.lua','scripts/story/Mission.lua','assets/Story/Mission/Level4.json']},
 'boundary':'Actual frozen KINDS.capture, StoryMission._go/_done/_complete/near; actual authored A/B/C data, Lua MissionRules.Step/Done/Go and Mission.Events including completion consumers. Controlled per-site capture sequences each end at actual completion. Enemy positions/liveness and interact inputs are controlled; B choice is suppressed in both. Constructors, graphics and audio are adapters. No natural driving, audible/rendered or performance acceptance.'}
suffix='-negative-'+mutant if mutant else '-failure' if failures else ''
output=ROOT/f'docs/migration/evidence/capture-sequence-offline{suffix}.json'
output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':report['status'],'frames':report['frames'],'events':report['events'],'failures':failures[:12],'totalFailures':len(failures),'evidence':str(output)},ensure_ascii=False))
if mutant:
    assert failures, 'Negative control did not detect the restored old order'
else:
    sys.exit(bool(failures))

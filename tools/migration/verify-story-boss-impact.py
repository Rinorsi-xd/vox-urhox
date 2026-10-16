"""Actual frozen Boss entry/phase impacts versus production Lua dispatch."""
import hashlib, json, os, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-impact-source.mjs'],encoding='utf-8'))
data=json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8'))
current=(ROOT/'scripts/combat/StoryBoss.lua').read_text(encoding='utf-8')

def run(test,code):
 lua=LuaRuntime(unpack_returned_tuples=True)
 def convert(v):
  if isinstance(v,dict):return lua.table_from({k:convert(x)for k,x in v.items()})
  if isinstance(v,list):return lua.table_from([convert(x)for x in v])
  return v
 def plain(v):
  if not hasattr(v,'items'):return v
  d=dict(v)
  if all(isinstance(k,int)for k in d):return [plain(d[i])for i in range(1,len(d)+1)]
  return {k:plain(x)for k,x in d.items()}
 lua.globals().DATA=convert(data);lua.globals().TEST=convert(test);lua.globals().CODE=code
 return plain(lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'combat.CarUnit','combat.EnemyDriver','core.Coord','audio.StoryRadio'})do package.preload[name]=function()return {}end end
package.preload['core.ResourceData']=function()return {Read=function()return DATA end}end
local Boss=assert(load(CODE))();local Rules=require'story.BossRules';local r=Rules.New(DATA.boss,150)
local unit={pos={0,0,0}};local session={trauma=TEST.trauma}
local self=setmetatable({rules=r,time=0,flow={stage=TEST.stage,t=0},session=session,unit=unit,at={enter={0,0,0}},
 radio={Play=function()end},view={Update=function()end},mission={voice={Talking=function()return false end}},
 Banner=function()end,Say=function()end},{__index=Boss})
local frames={}
for _,s in ipairs(TEST.steps)do
 if s.reset~=nil then session.trauma=s.reset end
 if TEST.stage=='introCine' then self.skip=s.skip;self:Update(s.dt)
 else r:Phase(s.phase);self:Events()end
 frames[#frames+1]={trauma=session.trauma or 0,shook=self.flow.shook==true,stage=self.flow.stage,phase=r.phase}
end
return frames
'''))

checks=0
for case in reference['cases']:
 actual=run(case['test'],current)
 for got,want in zip(actual,case['expected'],strict=True):
  assert got==want,(case['test']['name'],got,want);checks+=len(want)
mutants={
 'missing-entry':current.replace("if f.t>1.2 and not f.shook then f.shook=true;self.session.trauma=math.max(self.session.trauma or 0,.45) end",''),
 'missing-phase':current.replace("self.session.trauma=math.max(self.session.trauma or 0,.5);self.radio:Play('alert');self:Banner(e.phase", "self.radio:Play('alert');self:Banner(e.phase"),
 'repeated-entry':current.replace('f.t>1.2 and not f.shook','f.t>1.2'),
 'overwrite-stronger':current.replace('math.max(self.session.trauma or 0,.45)','.45').replace('math.max(self.session.trauma or 0,.5)','.5'),
}
negative={}
for name,code in mutants.items():
 assert code!=current,name
 failures=[c['test']['name']for c in reference['cases']if run(c['test'],code)!=c['expected']]
 assert failures,name;negative[name]=failures
legacy=ROOT/'.tmp/outgame-cached-1792127759340/scripts/combat/StoryBoss.lua'
legacy_code=legacy.read_text(encoding='utf-8-sig')
legacy_hash=hashlib.sha256(legacy.read_bytes()).hexdigest()
assert legacy_hash=='227d5ca6c3e05f067529c58e94431d73289b689179bd202eb1bd75295d09dbef'
legacy_failures=[c['test']['name']for c in reference['cases']if run(c['test'],legacy_code)!=c['expected']]
assert legacy_failures,'Actual previous package unexpectedly matched missing impact cues'
paths=['scripts/combat/StoryBoss.lua','scripts/story/BossRules.lua','assets/Story/Mission/Level5.json',
 'tools/migration/story-boss-impact-source.mjs','tools/migration/verify-story-boss-impact.py']
report={'result':'PASS','checks':checks,'cases':len(reference['cases']),'source':reference['source'],'negativeControls':negative,
 'actualPreviousPackage':{'path':str(legacy.relative_to(ROOT)).replace('\\','/'),'sha256':legacy_hash,'mismatchedCases':legacy_failures},
 'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
 'boundary':'Actual frozen BOSS_KIND.update and FoxBoss._phase versus actual Lua StoryBoss.Update and BossRules.Phase -> StoryBoss.Events. Native camera/HUD/physics boundaries doubled. Covers strict 1.2s boundary, once-only entry, early skip/stall, both phase transitions, duplicate/regressive phases and stronger existing trauma. No GPU, native shake visibility, natural mission completion, build or performance acceptance.'}
out=ROOT/'docs/migration/evidence/story-boss-impact-offline.json';out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))

"""Actual source key handler and actual TrialSession held-key branch replay."""
import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-cinematic-input-source.mjs'],encoding='utf-8'))
path=ROOT/'scripts/app/TrialSession.lua';code=path.read_text(encoding='utf-8')
legacy=ROOT/'.tmp/outgame-cached-1792127759340/scripts/app/TrialSession.lua'
data=json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8'))

def run(text,test):
 start=text.index('        local boss=self.story.boss')if '        local boss=self.story.boss' in text else text.index('        if self.story.boss and input:GetKeyDown(KEY_RETURN) then')
 end=text.index('\n    end\n    if self.endless then',start)
 actual=text[start:end]
 lua=LuaRuntime(unpack_returned_tuples=True)
 def conv(v):
  if isinstance(v,dict):return lua.table_from({k:conv(x)for k,x in v.items()})
  if isinstance(v,list):return lua.table_from([conv(x)for x in v])
  return v
 lua.globals().TEST=conv(test)
 lua.globals().BLOCK=actual
 lua.globals().DATA=conv(data);lua.globals().BOSS_CODE=(ROOT/'scripts/combat/StoryBoss.lua').read_text(encoding='utf-8')
 frames,ending=lua.execute(r'''
KEY_RETURN=1
local sample
input={GetKeyDown=function()return sample.down end,GetKeyPress=function()return sample.press end}
local tick=assert(load('return function(self,dt) '..BLOCK..' end'))()
local boss={flow={}};local self={story={boss=boss}};local frames={}
for _,s in ipairs(TEST.steps)do
 sample=s;boss.cinematic=s.cine
 if s.newFlow or s.luaNewFlow then boss.flow={};boss.skip=nil end
 tick(self,s.dt);frames[#frames+1]={skip=boss.skip==true}
end
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'combat.CarUnit','combat.EnemyDriver','core.Coord','audio.StoryRadio'})do package.preload[name]=function()return {}end end
package.preload['core.ResourceData']=function()return {Read=function()return DATA end}end
local Boss=assert(load(BOSS_CODE))();local Rules=require'story.BossRules';local rules=Rules.New(DATA.boss,150)
local ending=setmetatable({skip=boss.skip,flow={stage='ending',t=4,open=0},rules=rules,time=0,
 unit={pos={0,0,0}},mission={voice={Talking=function()return false end,Hide=function()end}},view={Update=function()end},Banner=function()end},{__index=Boss})
ending:Update(0)
return frames,ending.done==true
''')
 return {'frames':[{'skip':bool(v['skip'])}for v in frames.values()],'endingSkipped':bool(ending)}

checks=0
for case in reference['cases']:
 expected=case['expected']
 actual=run(code,case['test']);assert actual==expected,(case['test']['name'],actual,expected);checks+=len(expected['frames'])+1
historical=[]
for case in reference['historicalDifferences']:
 actual=run(code,case['test'])
 assert actual==case['expectedCurrent'],(case['test']['name'],actual)
 assert case['source']['endingSkipped'] and not actual['endingSkipped']
 assert actual!=case['source'],'Historical stale-hold behavior must remain an explicit divergence'
 checks+=len(actual['frames'])+1
 historical.append({'name':case['test']['name'],'source':case['source'],'current':actual,
                    'reason':'H5 reuses F and stale holdAt across intro/fight/ending; current flow requires a fresh cinematic press to prevent an unintended ending skip.'})
before=[]
for case in reference['cases']:
 if run(legacy.read_text(encoding='utf-8-sig'),case['test'])!=case['expected']:before.append(case['test']['name'])
assert 'fight-release-ending' in before and 'held-across-fight-ending' in before
mutants={
 'ordinary-fight-armed':code.replace('boss and boss.cinematic and input:GetKeyDown','boss and input:GetKeyDown'),
 'no-fresh-press-required':code.replace('elseif self.bossEnterFlow==boss.flow then','else'),
 'inclusive-threshold':code.replace('self.bossEnterHeld>.9','self.bossEnterHeld>=.9'),
}
negative={}
for name,text in mutants.items():
 failures=[c['test']['name']for c in reference['cases']if run(text,c['test'])!=c['expected']]
 assert failures,name;negative[name]=failures
paths=['scripts/app/TrialSession.lua','scripts/combat/StoryBoss.lua','tools/migration/story-boss-cinematic-input-source.mjs','tools/migration/verify-story-boss-cinematic-input.py']
report={'result':'PASS','checks':checks,'cases':len(reference['cases']),'source':reference['source'],
 'historicalSourceDifferences':historical,
 'actualPreviousPackage':{'path':str(legacy.relative_to(ROOT)).replace('\\','/'),'sha256':hashlib.sha256(legacy.read_bytes()).hexdigest(),'mismatchedCases':before},
 'negativeControls':negative,'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
 'boundary':'Complete frozen BOSS_KIND.key executes with controlled performance.now and delivered key/repeat events. Actual current TrialSession.Update held-key block executes with input-state doubles, followed by actual StoryBoss.Update ending. Six controlled scenarios match source ending results; two historical same-F stale-holdAt sequences intentionally differ and are recorded separately. This is a conservative unintended-skip fix, not 1:1 parity with all historical H5 held-key behavior. Legacy actual packaged block and three mutations are required negative controls. No GPU, natural Boss win, input event frequency or end-to-end cinematic acceptance.'}
out=ROOT/'docs/migration/evidence/story-boss-cinematic-input-offline.json';out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))

"""Compare actual frozen comic cue calls with actual Lua Ad/Mark/Say scheduling."""
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

reference=json.loads(subprocess.check_output(['node','tools/migration/source-intro-comic-cues.mjs'],encoding='utf-8'))
production=ROOT/'scripts/intro/IntroSession.lua'
before=ROOT/'.tmp/outgame-cached-1792117688715/scripts/intro/IntroSession.lua'
before_sha='578326411a31286aa93e9cc7f12e4f3589b8fbd1df492e5064119463fe1fa07d'
assert hashlib.sha256(before.read_bytes()).hexdigest()==before_sha
checks=0

def check(ok,label):
    global checks
    checks+=1
    assert ok,label

def plain(value):
    if hasattr(value,'items'):
        data=dict(value.items())
        return [plain(data[k]) for k in range(1,len(data)+1)] if data and all(isinstance(k,int) for k in data) else {k:plain(v) for k,v in data.items()}
    return value

def run(raw,durations):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().SESSION_SOURCE=raw
    lua.globals().DURATIONS=lua.table_from(dict(zip(['vo_n02a','vo_n02b','vo_n02c'],durations)))
    return plain(lua.execute('''
package.path='scripts/?.lua;'..package.path
package.loaded['urhox-libs/UI']={};package.loaded['core.Coord']={}
print=function()end
local Session=assert(load(SESSION_SOURCE))()
local events={};local I;local start
local function event(value)
 value.t=I.time;events[#events+1]=value
end
local audio={Music=function()end,Voice=function(_,id)
 if DURATIONS[id] then event({type='voice',id=id}) end
 return DURATIONS[id] or 2
end,Sfx=function(_,id,opt)
 if start or id=='whoosh' then start=start or I.time;event({type='sfx',id=id,opt=opt}) end
end}
I=setmetatable({active=true,time=0,age=0,log={},data={caps={}},audio=audio,
 host={Shot=function(id)
  if id=='prosper' then start=start or I.time end
  if id=='no' then error('COMIC_END') end
 end}},Session)
I.Wait=function(self,seconds)
 if start then event({type='wait',seconds=seconds}) end
 self.time=self.time+seconds;return true
end
local ok,err=pcall(I.Ad,I)
assert(not ok and tostring(err):find('COMIC_END'),'Actual Ad reaches end of three panels')
for _,e in ipairs(events)do e.t=e.t-start end
return events
'''))

def compare(raw,cases):
    rows=[]
    for case in cases:
        actual=run(raw,case['durations'])
        expected=case['events']
        check(len(actual)==len(expected),'Comic actual cue count matches frozen source')
        for current,wanted in zip(actual,expected):
            check(current['type']==wanted['type'],'Comic actual source call order')
            check(abs(current['t']-wanted['t'])<1e-9,'Comic cue time unchanged')
            if wanted['type']=='sfx':
                check(current['id']==wanted['id'],'Comic sound identity')
                check(current['opt']['vol']==wanted['opt']['vol'],'Comic source cue gain')
                check('rate' not in current['opt'] and 'loop' not in current['opt'],'Comic default rate and one-shot')
            elif wanted['type']=='voice':
                check(current['id']==wanted['id'],'Comic original narration order')
            else:
                check(abs(current['seconds']-wanted['seconds'])<1e-9,'Comic original wait duration')
        rows.append({'durations':case['durations'],'events':actual})
    return rows

current=production.read_text(encoding='utf-8')
rows=compare(current,reference['cases'])
negatives=[]
variants=[('frozen prior production',before.read_text(encoding='utf-8')),
 ('wrong cut gain',current.replace("self.audio:Sfx('whoosh',{vol=.5})\n for _,step", "self.audio:Sfx('whoosh',{vol=.4})\n for _,step",1)),
 ('wrong panel gain',current.replace("self:Mark(step[1]);self.audio:Sfx('whoosh',{vol=.6});self.big", "self:Mark(step[1]);self.audio:Sfx('whoosh',{vol=.5});self.big",1)),
 ('missing panel cue',current.replace("self:Mark(step[1]);self.audio:Sfx('whoosh',{vol=.6});self.big", "self:Mark(step[1]);self.big",1))]
for label,raw in variants:
    check(raw!=current,'Negative changes actual candidate: '+label)
    try:compare(raw,reference['cases'][:1])
    except AssertionError as error:negatives.append({'case':label,'rejected':str(error)})
    else:raise AssertionError('Negative escaped: '+label)
paths=['scripts/intro/IntroSession.lua','tools/migration/source-intro-comic-cues.mjs','tools/migration/check-intro-comic-cues.py']
report={'result':'PASS','checks':checks,'cases':rows,'negativeControls':negatives,
 'baseline':reference['baseline'],'sourceHashes':reference['sourceHashes'],
 'priorProductionSha256':before_sha,'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
 'boundary':'Actual frozen actVirtues/cut/_panel/words/voice and current Lua Ad/Mark/Say execute. Controlled wait clock checks original cue ordering, gains, narration and duration for actual/short/long voice lengths. Frozen previous production and three cue mutations must fail. DOM/audio devices are adapters; no browser, GPU, audible output, native timing, build or mobile acceptance.'}
out=ROOT/'docs/migration/evidence/intro-comic-cues-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':checks,'cases':len(rows),'negatives':len(negatives),'report':str(out)}))

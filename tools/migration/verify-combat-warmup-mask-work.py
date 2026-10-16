"""Actual frozen/candidate warmup frame equivalence and native-property work count."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

OLD=ROOT/'.tmp/outgame-cached-1792126975801/scripts/render/CombatWarmup.lua'
CURRENT=ROOT/'scripts/render/CombatWarmup.lua'
FIXTURE=ROOT/'tools/migration/check-combat-warmup-mask-work.lua'
old,current=OLD.read_text(encoding='utf-8'),CURRENT.read_text(encoding='utf-8')

def plain(v):
    if hasattr(v,'items'):
        rows=dict(v.items())
        return [plain(rows[k])for k in sorted(rows)]if rows and all(isinstance(k,int)for k in rows)else{k:plain(x)for k,x in rows.items()}
    return v

def run(source,workload=False):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().OLD_SOURCE=old
    lua.globals().CURRENT_SOURCE=source
    lua.globals().ONLY_WORKLOAD=workload
    lua.globals().print=lambda *args:None
    return plain(lua.execute(FIXTURE.read_text(encoding='utf-8')))

result=run(current)
negative=[]
old_work=run(old,True)
assert old_work['oldWrites']==old_work['currentWrites']
assert not old_work['currentWrites']<old_work['oldWrites']*.08
negative.append({'case':'actual frozen 82d old implementation','failure':'mask-work budget detects repeated whole-scene setters',
                 'writes':old_work['currentWrites']})
for before,after,label in [
    ('for i,item in ipairs(self.exposed) do item.drawable.viewMask=0;self.exposed[i]=nil end',
     'for i,item in ipairs(self.exposed) do self.exposed[i]=nil end','clear exposed without hiding previous frame'),
    ('if item.mask~=0 then self.exposed[#self.exposed+1]=item end','if false then self.exposed[#self.exposed+1]=item end','omit exposure ownership'),
    ('for _,item in ipairs(self.all) do item.drawable.viewMask=0 end','for _,item in ipairs(self.all) do end','omit initial full hide'),
    ('for _,item in ipairs(self.all) do item.drawable.viewMask=item.mask end','for _,item in ipairs(self.all) do end','omit final restoration'),
]:
    assert before in current,label
    try:run(current.replace(before,after,1))
    except Exception as error:
        assert 'same rendered/lifetime state'in str(error),str(error)
        negative.append({'case':label,'failure':str(error).split('\n')[0]})
    else:raise AssertionError('Mutation incorrectly passed '+label)

paths=['scripts/render/CombatWarmup.lua','scripts/render/WarmupSignature.lua','scripts/render/FlashWarmup.lua','scripts/render/AimLines.lua',
       'scripts/render/CombatEffects.lua','scripts/app/LoadingFlow.lua']
tools=['tools/migration/check-combat-warmup-mask-work.lua','tools/migration/verify-combat-warmup-mask-work.py',
       'tools/migration/check-combat-warmup.lua']
assert CURRENT.read_text(encoding='utf-8')==current,'Production changed during comparison'
report={'result':'PASS',**result,'negativeControls':negative,
        'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
        'testInputs':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in tools},
        'oldFixture':{'path':OLD.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(OLD.read_bytes()).hexdigest()},
        'boundary':'Actual frozen 82d and candidate CombatWarmup modules execute with actual CombatEffects/AimLines/FlashWarmup and strict native-property/vector/geometry adapters. At every original presentation boundary, compare graph membership, node positions/scales/enabled/disposed state, every drawable mask/enabled/model/material/geometry count, light state, phase/group/index/proxy counts and absence of gameplay FX. Completion, every small-fixture cancellation boundary, initialization/presented failures and idempotent release covered. These fixtures omit unknown native model-layout APIs, so the later signature candidate conservatively preserves their original groups; supported-layout compaction has a separate fixture. Mask setters are counted with Lua __newindex standing in for native binding calls; counts are deterministic synthetic workload evidence, not CPU milliseconds or actual S3 counts. No GPU, shader-compile-set, Web load-time, audio-continuity, mobile or visual acceptance.'}
out=ROOT/'docs/migration/evidence/combat-warmup-mask-work-offline.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':result['checks'],'scenarios':result['scenarios'],
                  'workload':{k:v for k,v in result['workload'].items()if k!='stages'},'negativeControls':len(negative)}))

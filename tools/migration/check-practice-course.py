"""Execute frozen course callback and actual HUD callbacks without GPU."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root=Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node','tools/migration/check-practice-course-source.cjs'],check=True)
fixtures=json.loads((root/'.tmp/source-practice-course.json').read_text(encoding='utf-8'))
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

def execute(code):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value,dict):return lua.table_from({k:table(v) for k,v in value.items()})
        if isinstance(value,list):return lua.table_from([table(v) for v in value])
        return value
    lua.globals().fixtures=table(fixtures)
    lua.globals().HUD_CODE=code
    return lua.execute((root/'tools/migration/check-practice-course.lua').read_text(encoding='utf-8'))

files=['scripts/ui/DriveHud.lua','scripts/app/TrialSession.lua']
hashes={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in files}
code=(root/files[0]).read_text(encoding='utf-8')
checks=execute(code)
negative=[]
frozen=root/'.tmp/outgame-cached-1792115578618/scripts/ui/DriveHud.lua'
mutants=[('frozen manifest-49c15ba7 DriveHud',frozen.read_text(encoding='utf-8'))]
for label,before,after in [
    ('resume missing','session:Resume()',''),
    ('info duration wrong',"'info',6000","'info',3200"),
    ('disposed callback still runs','session.disposed or not session:GoTo(item[3])','not session:GoTo(item[3])'),
    ('missing target still resumes','session.disposed or not session:GoTo(item[3])','session.disposed'),
]:
    assert before in code,label
    mutants.append((label,code.replace(before,after,1)))
for label,mutant in mutants:
    try:execute(mutant)
    except Exception as error:
        assert 'source valid/invalid/disposed' in str(error),str(error)
        negative.append({'name':label,'result':'REJECTED','failure':str(error).splitlines()[0]})
    else:raise AssertionError('Undetected negative control '+label)
assert hashes=={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in files}
report={'result':'PASS','sourceCommit':fixtures['commit'],'sourceHashes':fixtures['sourceHashes'],'productionHashes':hashes,
        'sourceCases':len(fixtures['cases']),'checks':[checks[i] for i in range(1,len(checks)+1)],'negativeControls':negative,
        'boundary':'Actual frozen onLegCourse callback, actual DriveHud.Create button callbacks and exact actual TrialSession.GoTo method. UI construction stops after both course buttons; spawning, toast and Resume are controlled edge adapters. No GPU/browser/real pointer capture or rendered feedback acceptance.'}
out=root/'docs/migration/evidence/practice-course-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':len(checks),'negativeControls':len(negative),'evidence':str(out)}))

"""Regress zero-step presentation lifecycle against the actual failed Web snapshot."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

def plain(value):
    if hasattr(value,'items'):
        return {key:plain(item) for key,item in value.items()}
    return value

snapshot=ROOT/'.tmp/outgame-cached-1792084158158/scripts/app/TrialSession.lua'
old=LuaRuntime(unpack_returned_tuples=True)
old.globals().TrialSource=snapshot.read_text(encoding='utf-8')
before=plain(old.execute("return dofile('tools/migration/check-trial-event-boundary.lua')"))
assert before['pass'] is False and 'suspension' in before['reproducedBeforeFix']['error'],before
current=LuaRuntime(unpack_returned_tuples=True)
after=plain(current.execute("return dofile('tools/migration/check-trial-event-boundary.lua')"))
assert after['pass'] is True,after
paths=['scripts/app/TrialSession.lua','scripts/combat/PlayerViewSync.lua','scripts/drive/Vehicle.lua','scripts/render/DriveView.lua','scripts/render/CombatView.lua']
report={'pass':True,'checks':after['checks']+before['checks'],'before':before,'after':after,
    'failedPackage':{'manifest':'manifest-e266101a.json','trialSHA256':hashlib.sha256(snapshot.read_bytes()).hexdigest()},
    'production':{path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in paths},
    'boundary':after['boundary']+' F2 external damage reproduces this scheduling boundary; this does not establish that normal firing always triggers the old failure. Actual Web failure is retained separately.'}
(ROOT/'docs/migration/evidence/trial-event-boundary-offline.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))

"""Actual OpeningHost targeting, countdown inheritance and missile closure."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

def plain(value):
    if hasattr(value,'items'):
        rows=dict(value.items())
        if rows and all(isinstance(key,int) for key in rows):
            return [plain(rows[key]) for key in sorted(rows)]
        return {key:plain(item) for key,item in rows.items()}
    return value

def execute(host_path,reference,dependency_only=False):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value,dict): return lua.table_from({key:table(item) for key,item in value.items()})
        if isinstance(value,list): return lua.table_from([table(item) for item in value])
        return value
    lua.globals().HOST_PATH=host_path.as_posix()
    lua.globals().OLD_HOST_PATH=old.as_posix()
    lua.globals().SHOTS_PATH=(ROOT/'scripts/intro/IntroShots.lua').as_posix()
    lua.globals().STRIKE_REFERENCE=table(reference)
    names=['Intro/Intro.json','Crater/Resources.json','Combat/MissileView.json']
    lua.globals().RESOURCE_DATA=table({name:json.loads((ROOT/'assets'/name).read_text(encoding='utf-8')) for name in names})
    lua.execute('print=function()end')
    code=(ROOT/'tools/migration/check-opening-host-residuals.lua').read_text(encoding='utf-8')
    if dependency_only: code=code[:code.index('local strikeCases={}')]+'return true'
    return plain(lua.execute(code))

reference=json.loads(subprocess.check_output(['node','tools/migration/source-opening-strike.mjs'],encoding='utf-8'))
old=ROOT/'.tmp/outgame-cached-1792106681145/scripts/app/OpeningHost.lua'
old_hash=hashlib.sha256(old.read_bytes()).hexdigest()
assert old_hash=='d26bd0f28b9c8c436b7f75266ce06d5c30bfb5d160ae1af8e7b36044601cf3f5','Frozen 749 host changed'
negative=[]
try:
    execute(old,reference,True)
except Exception as error:
    assert 'Only the four MissileView paths extend dependencies' in str(error),str(error)
    negative.append({'case':'missing missile dependency closure','failure':str(error).split('\n')[0]})
else: raise AssertionError('Historical dependency omission unexpectedly passed')

# Isolate the strike negative control from the earlier independent dependency failure.
lua=LuaRuntime(unpack_returned_tuples=True)
old_strike=plain(lua.execute('''
package.path="scripts/?.lua;"..package.path
package.loaded['construction.Blueprint']={};package.loaded['core.Coord']={}
package.loaded['app.SceneLoader']={New=function()return{Update=function()end}end}
local point={62,2,-176};local target;local count=0
package.loaded['intro.IntroStrike']={New=function(_,p)count=count+1;target={table.unpack(p)};return{Update=function()end}end}
local Host=assert(loadfile("'''+old.as_posix()+'''"))();local host=Host.New({})
host.state.session={combat={player={alive=true,Position=function()return point end}}}
local I={time=0,ready=true,playing=false,shot='fixture',audio={Sfx=function()end}}
host.SortieStep(4,I);assert(count==1)
point={80,2,-158};I.time=1.8;host.Update(.01,I)
return{beamPoint=target,playerAtFire=point,horizontalMiss=math.sqrt((target[1]-point[1])^2+(target[3]-point[3])^2)}
'''))
assert old_strike['horizontalMiss']>25
negative.append({'case':'premature target freeze','observed':old_strike,'detail':'Actual 749 beam remains at lock-entry position after player moves through 1.8s; old host executes its real update.'})
old_shots=ROOT/'.tmp/outgame-cached-1792106681145/scripts/intro/IntroShots.lua'
assert hashlib.sha256(old_shots.read_bytes()).hexdigest()=='6f9fd890b365b677b7de82b8a490d2516351b1f42d55c04f9373685a6840e838','Frozen 749 camera changed'
old_camera=LuaRuntime(unpack_returned_tuples=True)
shots=old_camera.execute('return assert(loadfile("'+old_shots.as_posix()+'"))()')
camera_misses=[]
for case in reference['cameraCases']:
    fixture=old_camera.table_from({'host':old_camera.table_from({'GroundAt':lambda x,z:x*.01-z*.02})})
    actual=plain(shots.Camera('sortie-countdown',0,fixture)[0])
    miss=sum((actual[n]-case['from'][n])**2 for n in range(3))**.5
    assert miss>.1
    camera_misses.append({'wait':case['wait'],'actual':actual,'expected':case['from'],'distance':miss})
negative.append({'case':'fixed countdown camera start','observed':camera_misses,'detail':'Actual frozen 749 IntroShots resets the camera regardless of the last presented brief pose.'})
paths=['scripts/app/OpeningHost.lua','scripts/intro/IntroShots.lua','scripts/intro/IntroStrike.lua','scripts/render/MissileView.lua','assets/Combat/MissileView.json']
hashes={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in paths}
result=execute(ROOT/'scripts/app/OpeningHost.lua',reference)
assert hashes=={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in paths}
report={'result':'PASS','checks':result['count'],'baseline':reference['baseline'],'sourceHashes':reference['sourceHashes'],
        'productionHashes':hashes,'cases':result,'historicalNegativeControls':{'manifest':'manifest-7493837a.json','hostSha256':old_hash,'shotsSha256':hashlib.sha256(old_shots.read_bytes()).hexdigest(),'checks':negative},
        'boundary':'Actual frozen post-lock beam construction, brief camera task and camMove implementation compared with actual Lua OpeningHost and IntroShots using controlled native/scene/player/audio adapters; actual MissileView.Dependencies. Camera waits 2.2/10/30s, three viewport adapter sizes, immutable snapshot and cancellation/reentry. No GPU, collision/beam rendering, projected viewport composition, natural playback, network timing or performance acceptance. Does not revalidate frozen 749 package.'}
out=ROOT/'docs/migration/evidence/opening-host-residuals-offline.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':result['count'],'evidence':str(out),'negativeControls':len(negative)}))

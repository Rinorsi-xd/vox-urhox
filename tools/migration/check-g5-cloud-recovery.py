"""Exercise G5 checkpoints through the real cloud adapter with controlled SDK/FS."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime, LuaError, lua_type

PRODUCTION = [
    'scripts/storage/CloudStorage.lua', 'scripts/storage/CloudSync.lua',
    'scripts/storage/BlueprintStore.lua', 'scripts/storage/BlueprintCode.lua',
    'scripts/storage/RecordNumbers.lua', 'scripts/endless/Records.lua',
    'scripts/endless/Run.lua', 'scripts/endless/Inventory.lua',
    'scripts/construction/Blueprint.lua', 'scripts/app/SalvageLobby.lua',
    'scripts/salvage/StashRules.lua',
]
BEFORE = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in PRODUCTION}
BASELINE = json.loads((ROOT / 'docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json').read_text(encoding='utf-8'))
SOURCE_HASHES = {}
for source_path in ['shared/battle/endless.js', 'three/src/battle/endlessSession.js', 'three/src/salvage/salvageRun.js']:
    source_file = Path(BASELINE['snapshot']) / source_path
    digest = hashlib.sha256(source_file.read_bytes()).hexdigest()
    assert digest == BASELINE['files'][source_path]['sha256'], source_path
    SOURCE_HASHES[source_path] = digest
RESOURCE_HASHES = {}
LUA = r'''
package.path='scripts/?.lua;tools/migration/?.lua;'..package.path
require('g5-offline-imports').Exclude({'render.Quality','render.CraterPostProcess'})
local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Copy(t) if type(t)~='table' then return t end;local out={};for k,v in pairs(t) do out[k]=Copy(v) end;return out end
package.loaded['core.ResourceData']={Read=ReadResource}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function() return true end}
FILE_READ=1;FILE_WRITE=2
local fs={};local writes={};local readCallbacks={};local id='12345';local failWrites=false
fileSystem={FileExists=function(_,path) return fs[path]~=nil end}
function File(path,mode)
    local value
    if mode==FILE_READ then value=fs[path] elseif not failWrites then value='' end
    return {size=value and #value or 0,IsOpen=function() return value~=nil end,
        ReadString=function() return value end,WriteString=function(_,text) value=text end,
        Flush=function() fs[path]=value end,Dispose=function() end}
end
GetArguments=function() return {} end;GetUserId=function() return id end
local database={}
clientCloud={userId=id}
function clientCloud:BatchGet()
    local keys={};return {Key=function(_,key) keys[#keys+1]=key end,
        Fetch=function(_,events) readCallbacks[#readCallbacks+1]={keys=keys,events=events} end}
end
function clientCloud:Set(key,value,events) writes[#writes+1]={key=key,text=value,events=events} end
local function ReplyRead(values) readCallbacks[#readCallbacks].events.ok(values or database) end
local function Ack(n) local request=writes[n or #writes];database[request.key]=request.text;request.events.ok() end
local Cloud=require 'storage.CloudStorage'
local Store=require 'storage.BlueprintStore'
local Records=require 'endless.Records'
local Run=require 'endless.Run'
local C=require('endless.Data').config
local runKey='vox-save-v1-vox-garage-'..C.runKey
local bestKey='vox-save-v1-vox-garage-'..C.bestKey
local function Boot()
    local count=0;Cloud.Boot(function() count=count+1 end)
    Check(count==0 and Cloud.Snapshot().state=='loading','boot waits for cloud read')
    ReplyRead();Check(count==1,'boot completes once after cloud read')
end
local function Restart()
    Cloud.Stop();fs={};Boot();return Store.New('vox-garage')
end
Boot()
Check(Cloud.Snapshot().state=='ready','empty authenticated cloud adapter ready')
local store=Store.New('vox-garage')
local source=ReadResource('Warehouse/Manifest.json').starter
local run=Run.New(source,'cloud-recovery-seed')
run.state='rest';run.wave=5;run.tier=2;run.lives=2;run.credits=3000
run.score=1500;run.time=321.75;run.damage=94;run.repairs=1
run.supplies={{kind='part',type='laser1',id='laser1',tier=1,name='laser'}}
local selected=run:ChooseSupply(1)
Check(selected and #run.supplies==0,'actual supply choice consumed before checkpoint')
local saved=run:Save()
Check(Records.Run(saved),'actual Run.Save passes production checkpoint validator')
Check(store:Write(C.runKey,saved,Records.Run),'actual alternating file checkpoint write')
Check(Cloud.Snapshot().pending==1 and database[runKey]==nil,'local success does not mean remote durability')
Cloud.Update(1)
Check(#writes==1 and writes[1].key==runKey,'real adapter maps checkpoint to existing cloud namespace')
Check(Cloud.Snapshot().pending==1,'in-flight write remains pending before ack')
Ack()
Check(Cloud.Snapshot().pending==0,'SDK ack completes checkpoint durability')
local expectedGeneration=cjson.decode(database[runKey]).generation
store=Restart()
Check(Cloud.Snapshot().state=='ready','fresh local filesystem hydrates acknowledged checkpoint')
local restored,generation=store:Read(C.runKey,Records.Run)
Check(restored~=nil and generation==expectedGeneration,'new local store reads hydrated checkpoint generation')
local nextRun=Run.New(restored.blueprint,restored.seed,restored)
for _,key in ipairs({'wave','tier','lives','credits','score','time','damage','repairs','weaponDrought','seed'}) do
    Check(nextRun[key]==run[key],'fresh actual Run preserves '..key)
end
Check(nextRun.state=='rest' and #nextRun.supplies==0,'restore resumes rest without replaying selected supply')
Check(nextRun.inventory.laser1==run.inventory.laser1,'chosen limited part retained exactly once')
Check(#nextRun.blueprint.parts==#run.blueprint.parts,'full real blueprint retained after cloud hydration')
local first=nextRun:Save();first.credits=3100
Check(store:Write(C.runKey,first,Records.Run),'first subsequent revision written')
Cloud.Update(1);local oldIndex=#writes
local latest=nextRun:Save();latest.credits=3300
Check(store:Write(C.runKey,latest,Records.Run),'newer checkpoint accepted while old revision in flight')
writes[oldIndex].events.timeout()
Check(Cloud.Snapshot().state=='blocked' and Cloud.Snapshot().pending==2,'uncertain request preserves active and newer checkpoint')
local writeCount=#writes;Cloud.Update(30)
Check(#writes==writeCount,'timeout cannot advance or overwrite in uncertain order')
Ack(oldIndex);Cloud.Update(1)
Check(#writes==writeCount+1,'late definitive ack safely starts retained latest revision')
Ack();store=Restart()
restored=store:Read(C.runKey,Records.Run)
Check(restored.credits==3300,'fresh restore selects latest acknowledged checkpoint after timeout')
local invalid=Copy(restored);invalid.lives=0
local malformed=cjson.encode({v=1,generation=10,data=invalid})
Check(not Cloud.Decode(malformed,runKey),'dead run checkpoint rejected before hydration')
invalid=Copy(restored);invalid.inventory.laser1=-1
Check(not Cloud.Decode(cjson.encode({v=1,generation=10,data=invalid}),runKey),'negative limited inventory rejected before hydration')
local previous=database[runKey];database[runKey]=malformed
Cloud.Stop();fs={};local count=0;Cloud.Boot(function() count=count+1 end);ReplyRead()
Check(count==1 and Cloud.Snapshot().state=='blocked','invalid remote checkpoint blocks cloud restore without hanging startup')
Check(not Store.New('vox-garage'):Read(C.runKey,Records.Run),'invalid checkpoint not installed as playable local run')
Cloud.Update(20);Check(#writes==writeCount+1,'blocked restore never uploads fresh defaults over old run')
database[runKey]=previous;store=Restart()
Check(store:Write(C.runKey,nil,Records.Run,true),'completed-run tombstone written through real store')
Cloud.Update(1);Ack();store=Restart()
local deleted,deletedGeneration=store:Read(C.runKey,Records.Run)
Check(deleted==nil and deletedGeneration>1,'fresh session cannot resurrect acknowledged completed run')
Check(Cloud.Decode(database[runKey],runKey).deleted,'cloud deletion uses schema tombstone')
Check(database[bestKey]==nil,'checkpoint changes do not manufacture best-score records')
local Lobby=require 'app.SalvageLobby'
local lobby=Lobby.New({})
local previousCount=lobby:Owned('scrap');local beforeData=lobby.data
failWrites=true
local failed,reason=lobby:CommitRun('cloud-extract',{ok=true,cargo={scrap=7}}, {})
failWrites=false
Check(not failed and reason~=nil and lobby.data==beforeData,'real stash settlement rolls back entire object on file-open failure')
Check(lobby:Owned('scrap')==previousCount,'failed settlement never grants unsaved cargo')
Check(lobby:BeginRun('cloud-extract'),'actual raid accounting checkpoint saves')
Check(lobby:CommitRun('cloud-extract',{ok=true,cargo={scrap=7}},{}),'actual successful settlement saves')
Cloud.Update(1);Ack();store=Restart()
lobby=Lobby.New({})
Check(lobby:Owned('scrap')==previousCount+7,'real stash cargo restores from acknowledged cloud after file reset')
Check(lobby.data.stats.raids==1 and lobby.data.stats.extracted==1 and lobby.data.stats.lost==0,'restored raid accounting is counted once')
Check(lobby.data.lastRun=='cloud-extract' and lobby.data.lastStartedRun=='cloud-extract','run idempotency markers survive cloud restoration')
local beforeReplay=lobby.data
Check(lobby:CommitRun('cloud-extract',{ok=true,cargo={scrap=7}},{}),'replayed restored settlement safely succeeds')
Check(lobby.data==beforeReplay and lobby:Owned('scrap')==previousCount+7,'restored settlement cannot grant same cargo twice')
Cloud.Update(1);Ack()
local after=nextRun:Save();Check(store:Write(C.runKey,after,Records.Run),'new run accepted before account switch')
Cloud.Update(1);local identityIndex=#writes;id='99999';Cloud.Update(1);Ack(identityIndex)
Check(Cloud.Snapshot().state=='blocked' and Cloud.Snapshot().reason=='identity_changed','actual adapter refuses old account acknowledgment after identity change')
Cloud.Stop()
return checks
'''


def execute(mutation=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    null = lua.table()
    same = lua.eval('rawequal')

    def convert(value):
        if value is None:
            return null
        if isinstance(value, dict):
            return lua.table_from({k: convert(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(v) for v in value])
        return value

    def plain(value):
        if lua_type(value) != 'table':
            return value
        if same(value, null):
            return None
        keys = list(value.keys())
        if keys and all(isinstance(k, int) and k > 0 for k in keys) and max(keys) == len(keys):
            return [plain(value[i]) for i in range(1, len(keys) + 1)]
        return {str(k): plain(v) for k, v in value.items()}

    def resource(path):
        file = ROOT / 'assets' / path
        RESOURCE_HASHES[str(file.relative_to(ROOT)).replace('\\', '/')] = hashlib.sha256(file.read_bytes()).hexdigest()
        return convert(json.loads(file.read_text(encoding='utf-8')))

    lua.globals().ReadResource = resource
    lua.globals().cjson = lua.table_from({'null': null,
        'encode': lambda value: json.dumps(plain(value), ensure_ascii=False, separators=(',', ':')),
        'decode': lambda text: convert(json.loads(text))})
    if mutation:
        path, old, new = mutation
        text = (ROOT / path).read_text(encoding='utf-8')
        assert text.count(old) == 1, 'Mutation anchor must be unique: ' + path
        text = text.replace(old, new, 1)
        lua.globals().overrideSource = text
        module = path.removeprefix('scripts/').removesuffix('.lua').replace('/', '.')
        lua.execute(f"package.preload['{module}']=assert(load(overrideSource,'@negative-control'))")
    return list(lua.execute(LUA).values())


checks = execute()
mutations = [
    ('scripts/storage/CloudStorage.lua', "local ok,restored=pcall(Store.Hydrate,namespace,key,record)", "local ok,restored=true,true"),
    ('scripts/storage/CloudStorage.lua', "valid=Records.Run(data)", "valid=true"),
    ('scripts/storage/CloudSync.lua', "self.ack[key]=item.version;self.active=false", "self.ack[key]=item.version;self.active=false;self.pending={};self.queue={}"),
    ('scripts/app/SalvageLobby.lua', "if self.data.lastRun==runId then return true end", "if false then return true end"),
    ('scripts/app/SalvageLobby.lua', "if not ok then self.data=previous end;return ok,err\nend\nfunction M:Cells", "return ok,err\nend\nfunction M:Cells"),
]
negative = []
expected_assertions = ['new local store reads hydrated checkpoint generation',
    'dead run checkpoint rejected before hydration',
    'late definitive ack safely starts retained latest revision',
    'restored settlement cannot grant same cargo twice',
    'real stash settlement rolls back entire object on file-open failure']
for mutation, expected in zip(mutations, expected_assertions, strict=True):
    try:
        execute(mutation)
    except LuaError as error:
        assert expected in str(error).splitlines()[0], 'Negative failed outside intended assertion: ' + str(error)
        negative.append({'file': mutation[0], 'mutation': mutation[2], 'rejected': True,
                         'reason': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control passed: ' + mutation[0])
assert BEFORE == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in PRODUCTION}, 'Production drift'
report = {'result': 'PASS', 'checks': checks, 'runtime': 'Lua 5.4 via lupa',
          'sourceCommit': 'b276064942ae09c0227ec28d4cfda1d5ff006455',
          'sourceHashes': SOURCE_HASHES,
          'productionHashes': BEFORE, 'resources': RESOURCE_HASHES,
          'testInputs': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in
              ['tools/migration/check-g5-cloud-recovery.py', 'tools/migration/g5-offline-imports.lua']},
          'negativeControls': negative,
          'boundary': 'Real Run/Inventory/Blueprint, Records, BlueprintStore, CloudStorage.Boot/Decode and CloudSync executed. Frozen JS is hash-bound provenance only in this runner, not an executed oracle. SDK callbacks, account identity, JSON bridge and filesystem are controlled adapters. Unused render hoists fail on access. No actual account/network, browser reload, natural battle completion, rendering, audio or mobile performance acceptance.'}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=Path('docs/migration/evidence/g5-cloud-recovery-offline.json'))
out = ROOT / parser.parse_args().output
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(checks), 'negativeControls': len(negative), 'evidence': str(out)}))

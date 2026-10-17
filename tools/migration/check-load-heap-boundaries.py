"""Offline Lua54 wrapper checks; never launches the game or collects the heap."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

SOURCE = (ROOT / 'tools/migration/qa-load-heap-boundaries.lua').read_text(encoding='utf-8')
MOCK = r'''
marks={};frame=1; checkpoints=0
cjson={encode=function(row) marks[#marks+1]=row;return 'qa' end}
print=function() end
GetTime=function() return {frameNumber=frame} end
Time={GetSystemTime=function() return frame*16 end}
cache={GetTotalMemoryUse=function() return 123 end,GetNumBackgroundLoadResources=function() return 0 end}
App={}
function App:Start()
 self.hangar={};self.mode='hangar';self.mapTransition={current={released=false}}
 self.loadingFlow={active=true,phase='warming'}
 function self.loadingFlow:Close() self.active=false;self.phase='closed';return 'closed',nil,7 end
 self.loader={phase='idle'}
 function self.loader:ReadScene() self.reads=(self.reads or 0)+1;return 'read',nil,2 end
 function self.loader:Load(path,ready,failed,options) self.options=options;return 'load',nil,9 end
 return 'started',nil,3
end
function App:EnterTrial(mapId,battleMode)
 if self.reject then return false,'rejected' end
 self.hangar=nil;self.mapTransition.current.released=true;self.loadingFlow.active=true
 local options={prepare=function(scene,checkpoint)
  checkpoint(.3,'terrain');checkpoint(.6,'session');checkpoints=checkpoints+1;checkpoint(.9,'vehicles')
  return 'prepared',nil,8
 end}
 self.loader:Load('Map.xml',nil,nil,options)
 return true,'entered'
end
function App:Reload() self.trial=nil;self.hangar={};self.mode='hangar';self.loadingFlow.active=true;return 'reloaded',nil,4 end
function App:ReleaseSettledAssets() return true,nil,11 end
'''
CHECK = r'''
local function Returns(values,a,c) assert(values[1]==a and values[2]==nil and values[3]==c and values.n==3) end
local app=setmetatable({}, {__index=App})
Returns(table.pack(app:Start()),'started',3)
Returns(table.pack(app.loadingFlow:Close()),'closed',7)
assert(#marks==1 and marks[1].tag=='hall-stable')
app.reject=true;local rejected=table.pack(app:EnterTrial('salvage'));assert(rejected[1]==false and rejected[2]=='rejected')
assert(VOX_QA_LOAD_HEAP_BOUNDARIES.active==false);app.reject=false
local entered=table.pack(app:EnterTrial('salvage'));assert(entered[1]==true and entered[2]=='entered')
frame=2;Returns(table.pack(app:ReleaseSettledAssets()),true,11)
frame=3;Returns(table.pack(app.loader:ReadScene()),'read',2)
frame=4
local yielded={}
local job=coroutine.create(function()
 Returns(table.pack(app.loader.options.prepare({},function(progress,stage)
  yielded[#yielded+1]={progress,stage};coroutine.yield(stage)
 end)),'prepared',8)
end)
local ok,stage=coroutine.resume(job);assert(ok and stage=='terrain' and #marks==3)
ok,stage=coroutine.resume(job);assert(ok and stage=='session' and #marks==4 and checkpoints==0)
ok,stage=coroutine.resume(job);assert(ok and stage=='vehicles' and checkpoints==1)
ok=coroutine.resume(job);assert(ok and coroutine.status(job)=='dead' and #yielded==3)
app.trial={};app.mode='trial';frame=5;Returns(table.pack(app.loadingFlow:Close()),'closed',7)
assert(#marks==5 and marks[5].tag=='activation-closed')
frame=6;Returns(table.pack(app:Reload()),'reloaded',4)
if fenceFirst then
 app:ReleaseSettledAssets();assert(#marks==5);app.loadingFlow:Close()
else
 app.loadingFlow:Close();assert(#marks==5);app:ReleaseSettledAssets()
end
assert(#marks==6 and marks[6].tag=='returned-cleanup')
app:ReleaseSettledAssets();app.loadingFlow:Close();assert(#marks==6)
local expected={'hall-stable','old-hall-cleaned','resources-ready','physics-prepared','activation-closed','returned-cleanup'}
for i,tag in ipairs(expected) do assert(marks[i].tag==tag and marks[i].sequence==i) end
assert(marks[4].frame==4 and marks[4].atomicAllocatorSnapshot==false)
return #marks
'''

results=[]
for fence_first in [False, True]:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)
    lua.execute('return (function()\n' + SOURCE + '\nend)()').Install(lua.globals().App)
    lua.globals().fenceFirst = fence_first
    results.append(lua.execute(CHECK))

composition = None
if len(sys.argv) == 3:
    prepared = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
    source_dir = Path(prepared['source_directory'])
    suffix_dir = Path(sys.argv[2])
    combined = (source_dir / 'scripts/main.lua').read_text(encoding='utf-8')
    for name in ['qa-frame-wall-observer.lua', 'probe-outgame-web.lua', 'monitor-disabled-observer.lua']:
        combined += '\n' + (ROOT / 'tools/migration' / name).read_text(encoding='utf-8')
    combined += '\n' + (suffix_dir / 'suffix.lua').read_text(encoding='utf-8')
    compiled = LuaRuntime().eval('load')(combined, 'frozen-main-qa-monitor-disabled-load-boundaries')
    assert not isinstance(compiled, tuple), compiled
    composition = 'Frozen main + standard QA + monitor-disabled + boundary suffix compiles in Lua54.'

print(json.dumps({'result': 'PASS', 'lua': '5.4', 'runs': len(results), 'boundariesPerRun': results,
                  'checks': 'Original multiple returns, exact hooks, rejected entry reset, yielding checkpoints, both cleanup/close orders, deduplication.',
                  'composition': composition,
                  'boundary': 'Offline mocked methods only; no game, allocator or performance acceptance.'}))

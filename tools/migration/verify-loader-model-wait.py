"""Execute the complete frozen/candidate Loader under deterministic Lua54 mocks."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

BASELINE = (ROOT / '.tmp/outgame-cached-1792189057538/scripts/app/SceneLoader.lua').read_text(encoding='utf-8')
CANDIDATE = (ROOT / '.tmp/load-heap-model-wait-f881/SceneLoader.lua').read_text(encoding='utf-8')
assert CANDIDATE.replace("self.warmWait=(item.type=='Model' and 0 or 3)", 'self.warmWait=3') == BASELINE
MOCK = r'''
clock=0;frame=0;events={};prepared={};queries={};queued={};disposed=0;cleanup=0;cancels=0;commits=0;failed=false
Time={GetSystemTime=function()return clock end}
local gate={}
function gate.New()return setmetatable({},{__index=gate})end
function gate:Cancel()self.cancelled=true end
function gate:Start(paths,callback)self.total=#paths;self.completed=#paths;self.bytes=20;callback(true)end
function require(name)
 if name=='app.ResourceGate' then return gate end
 if name=='urhox-libs.Platform.PlatformUtils' then return {IsWebPlatform=function()return true end}end
 error(name)
end
function print(text)
 local name=text:match('Prepared (%S+)')
 if name then prepared[#prepared+1]={name=name,frame=frame}end
end
cache={}
function cache:GetExistingResource(kind,name)
 queries[#queries+1]={kind=kind,name=name,frame=frame}
 if inspectError then error('inspection failed')end
 if immediateReady then return {memoryUse=100,width=1,height=1}end
 local job=queued[name]
 if not job then return nil end
 job.polls=job.polls+1
 if neverReady then return nil end
 if kind=='Texture2DArray' and job.polls==1 then return {memoryUse=100,width=0,height=0}end
 if job.polls<(readyPolls or 2)then return nil end
 return {memoryUse=100,width=1,height=1}
end
function cache:BackgroundLoadResource(kind,name,sendEvent)
 if queueError then error('queue failed')end
 queued[name]={kind=kind,polls=0,frame=frame}
 events[#events+1]={'queue',kind,name,sendEvent};return false
end
function cache:GetTotalMemoryUse()return 1000 end
function cache:GetFile(name)
 if fileError then error('file failed')end
 if missingFile then return nil end
 return {Dispose=function()disposed=disposed+1 end}
end
LOAD_SCENE=1;LOAD_SCENE_AND_RESOURCES=2
environmentBakeCache={RequestBake=function()return true end}
function Scene()
 return {asyncProgress=1,asyncLoading=false,
  LoadAsyncXML=function(_,file,mode)events[#events+1]={'read',mode};return true end,
  GetComponents=function()return {}end,
  StopAsyncLoading=function()end,
  Dispose=function()disposed=disposed+1 end}
end
function newLoader(resources)
 local loader=Loader.New(function()events[#events+1]={'scene-prepare'}end)
 loader.canStart=function()return canStart~=false end
 loader:Load('Map.xml',function(scene)commits=commits+1;events[#events+1]={'commit'}end,
  function(message)failed=message end,
  {resources={'A.bin'},webWarmup=resources,
   prepare=function(scene,checkpoint)
    for _,progress in ipairs({.2,.6,.9})do clock=clock+4;checkpoint(progress,'session')end
    events[#events+1]={'prepared-world'}
   end,
   cleanup=function()cleanup=cleanup+1 end,cancel=function()cancels=cancels+1 end})
 return loader
end
function tick(loader,delta)
 frame=frame+1;clock=clock+(delta or 16);loader:FramePresented();loader:Update(.016)
end
function complete(loader)
 for i=1,300 do tick(loader);if loader.state~='loading'then return end end
 error('fixture deadline')
end
'''


def run(source, code):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)
    lua.globals().Loader = lua.execute(source)
    return lua.execute(code)


checks = 0
reports = []
for source, label in [(BASELINE, 'baseline'), (CANDIDATE, 'candidate')]:
    result = run(source, r'''
local loader=newLoader({{type='Model',name='a.bin'},{type='Texture2D',name='b.png'},{type='Model',name='c.bin'},{type='Texture2DArray',name='d.xml'}})
complete(loader)
assert(loader.state=='ready' and commits==1 and not failed)
assert(#prepared==4 and prepared[1].name=='a.bin' and prepared[2].name=='b.png' and prepared[3].name=='c.bin' and prepared[4].name=='d.xml')
assert(loader.prepareFrames==4 and loader.maxPrepareMs==4)
assert(queued['d.xml'].polls==2)
assert(loader.phaseTimes.download~=nil and loader.phaseTimes.resources~=nil)
return frame,#queries,prepared[1].frame,prepared[2].frame,prepared[3].frame,prepared[4].frame
''')
    reports.append({'source': label, 'frames': result[0], 'queries': result[1], 'readyFrames': list(result[2:])})
    checks += 8
    for resource in ['Texture2D', 'Texture2DArray', 'Model']:
        run(source, f'''
immediateReady=true
local loader=newLoader({{{{type='{resource}',name='one'}},{{type='Model',name='two'}}}})
while #prepared<1 do tick(loader)end
local at=frame;local initial=loader.warmWait
assert(initial==({str(label == 'candidate').lower()} and '{resource}'=='Model' and 0 or 3))
for i=1,initial do local n=#queries;tick(loader);assert(#queries==n and loader.warmIndex==2)end
tick(loader);assert(#prepared==2 and frame-at==initial+1)
complete(loader);assert(commits==1 and loader.state=='ready')
''')
        checks += 5
    run(source, r'''
canStart=false;local loader=newLoader({{type='Model',name='one'}})
for i=1,5 do tick(loader)end;assert(#queries==0 and loader.beginDownload~=nil)
canStart=true;tick(loader);assert(loader.phase=='resources' and #queries==0)
tick(loader);assert(#queries==0 and loader.phaseFrames==1)
tick(loader);assert(loader.phaseFrames==2 and #queries==1)
''')
    checks += 4
    for mode in ['inspectError=true', 'queueError=true', 'fileError=true', 'missingFile=true']:
        run(source, mode + r'''
local loader=newLoader({{type='Model',name='one'}});complete(loader)
assert(loader.state=='failed' and failed and commits==0 and cleanup==1 and cancels==1)
assert(loader.pending==nil and loader.warmPending==nil and loader.options==nil)
''')
        checks += 3
    run(source, r'''
neverReady=true;local loader=newLoader({{type='Model',name='one'}})
while not loader.warmPending do tick(loader)end
tick(loader,20001);assert(loader.state=='failed' and failed:find('timed out') and commits==0)
assert(loader.warmPending==nil and loader.pending==nil and cleanup==1 and cancels==1)
''')
    checks += 4
    run(source, r'''
local loader=newLoader({{type='Model',name='old'}})
while not loader.warmPending do tick(loader)end
local generation=loader.generation;loader:Cancel();assert(loader.generation==generation+1 and loader.warmPending==nil and loader.state=='idle')
for i=1,5 do tick(loader)end;assert(commits==0 and not failed)
loader:Load('new.xml',function()commits=commits+1 end,function(message)failed=message end,{resources={},webWarmup={{type='Model',name='new'}}})
complete(loader);assert(commits==1 and loader.state=='ready' and not failed)
assert(#prepared==1 and prepared[1].name=='new')
''')
    checks += 5
    run(source, r'''
local loader=newLoader({{type='Model',name='one'}})
while not loader.warmPending do tick(loader)end
loader.warmPending.token=loader.generation-1;local before=#queries;tick(loader)
assert(loader.warmPending==nil and #queries==before and commits==0)
complete(loader);assert(loader.state=='ready' and commits==1)
''')
    checks += 3

assert reports[0]['queries'] == reports[1]['queries']
assert reports[0]['frames'] - reports[1]['frames'] == 6
checks += 2
output = {'result': 'PASS', 'lua': '5.4', 'checks': checks, 'runs': reports,
          'boundary': 'Complete real Loader source under fake engine/cache/time. Six fewer update slots for two Model resources; textures retain three. This is not a Runtime wall-time, GPU-retirement or performance result.'}
(ROOT / '.tmp/load-heap-model-wait-f881/offline-loader-verification.json').write_text(json.dumps(output, indent=2), encoding='utf-8')
print(json.dumps(output))

"""Offline source/observer checks; no browser or engine performance acceptance."""
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

spec = importlib.util.spec_from_file_location('drive_sections', HERE / 'perf-drive-sections.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)
snapshot = ROOT / '.tmp/outgame-cached-1792164278829'
node = r"""
const fs=require('node:fs'),tool=require('./tools/migration/build-drive-sections-probe.cjs');
const prepared=JSON.parse(fs.readFileSync(process.argv[1]+'/identity.json'));
console.log(JSON.stringify({probe:tool.buildDriveSectionsProbe(prepared),gait:tool.instrumentGait(fs.readFileSync('scripts/drive/LegGait.lua','utf8').replace(/\r\n/g,'\n')),contact:tool.instrumentContact(fs.readFileSync('scripts/drive/ContactControl.lua','utf8').replace(/\r\n/g,'\n'))}));
"""
output = json.loads(subprocess.check_output(['node', '-e', node, str(snapshot)], cwd=ROOT, text=True, encoding='utf-8'))
gait = (ROOT / 'scripts/drive/LegGait.lua').read_text(encoding='utf-8')
contact = (ROOT / 'scripts/drive/ContactControl.lua').read_text(encoding='utf-8')
assert output['gait'] == tool.instrument_gait(gait), 'Web gait transform must exactly reuse the Native section boundaries'
assert output['contact'] == tool.instrument_contact(contact), 'Web contact transform must exactly reuse the Native section boundaries'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('assert(load(...))', output['probe'])
lua.execute('assert(load(...))', (ROOT / 'scripts/main.lua').read_text(encoding='utf-8') + '\n'
            + (HERE / 'qa-frame-wall-observer.lua').read_text(encoding='utf-8') + '\n'
            + output['probe'] + '\n' + (HERE / 'probe-outgame-web.lua').read_text(encoding='utf-8')
            + '\n' + (HERE / 'monitor-disabled-observer.lua').read_text(encoding='utf-8'))
setup = """
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local realRequire=require
local modules={}
_G.QA_MODULES=modules
require=function(name)
 if name=='core.Math3' then return realRequire(name) end
 if not modules[name] then modules[name]=setmetatable({},{__index=function(t,key)
  local f=function(...)return ... end;rawset(t,key,f);return f
 end}) end
 return modules[name]
end
local ticks=0
Time={GetSystemTime=function()ticks=ticks+1;return ticks end}
_G.QA_EMITTED={}
cjson={encode=function(value) QA_EMITTED[#QA_EMITTED+1]=value;return '{}' end}
print=function()end
QA_MODULES['drive.Vehicle']={Step=function(a,b,c,d)return a,b,c,d end,
 StepRotors=function(...)return ... end,PostStep=function(...)return ... end}
"""
lua.execute(setup)
lua.execute(output['probe'])
result = lua.execute("""
local M=VOX_QA_DRIVE_SECTIONS
assert(M.Snapshot().enabled==false and M.Snapshot().installed==false)
local app={trial={},loadingFlow={active=false}}
M.BeginFrame(app);M.EndFrame();assert(M.Snapshot().frames==0)
M.Toggle();assert(M.Snapshot().enabled and M.Snapshot().installed)
assert(#M.Snapshot().calibration.repeats==3)
assert(M.Snapshot().bindings==57)
local Vehicle=QA_MODULES['drive.Vehicle']
for i=1,5 do
 M.BeginFrame(app)
 local a,b,c,d=Vehicle.Step(7,nil,false,4)
 assert(a==7 and b==nil and c==false and d==4)
 M.EndFrame()
end
assert(M.Snapshot().frames==5 and M.Snapshot().pending==5)
M.Emit();assert(#QA_EMITTED==3 and #QA_EMITTED[1].frames==2 and #QA_EMITTED[3].frames==1)
assert(M.Snapshot().pending==0)
local names=QA_EMITTED[1].names;local vehicleId,updateId
for id,name in ipairs(names)do if name=='vehicle.Step' then vehicleId=id elseif name=='update.production' then updateId=id end end
assert(vehicleId and updateId)
for _,message in ipairs(QA_EMITTED)do for _,frame in ipairs(message.frames)do
 local found=false
 for _,row in ipairs(frame.values)do
  assert(row[4]<=row[3] and row[5]<=row[3])
  if row[1]==vehicleId then assert(row[2]==1);found=true end
 end
 assert(found)
end end
M.Toggle();assert(not M.Snapshot().enabled)
M.BeginFrame(app);M.EndFrame();assert(M.Snapshot().frames==5)
return {bindings=M.Snapshot().bindings,frames=M.Snapshot().frames,batches=#QA_EMITTED}
""")
# Reuse the actual algorithm/force/ray-order fixture with the Web-generated code.
equivalence = LuaRuntime(unpack_returned_tuples=True)
for name, value in {'GAIT_BASE': gait, 'CONTACT_BASE': contact, 'GAIT_PROBE': output['gait'],
                    'CONTACT_PROBE': output['contact'], 'SCOPE_SOURCE': (HERE / 'perf-drive-sections-scope.lua').read_text(encoding='utf-8')}.items():
    equivalence.globals()[name] = value
eq = equivalence.execute((HERE / 'check-drive-sections.lua').read_text(encoding='utf-8'))
duplicate = output['probe'].replace("{'drive.Vehicle',{'Step','StepRotors','PostStep'},'vehicle'},",
                                   "{'drive.Vehicle',{'Step','StepRotors','PostStep'},'vehicle'},\n{'drive.Vehicle',{'Step'},'vehicle'},")
assert duplicate != output['probe']
negative = LuaRuntime(unpack_returned_tuples=True)
negative.execute(setup)
negative.execute(duplicate)
try:
    negative.execute('VOX_QA_DRIVE_SECTIONS.Toggle()')
except Exception as error:
    assert 'Duplicate drive scope binding: vehicle.Step' in str(error), str(error)
else:
    raise AssertionError('Duplicate binding negative control survived')
print(json.dumps({'result': 'PASS', 'syntax': 2, 'nativeWebTransformParity': True,
                  'bindings': result['bindings'], 'frames': result['frames'], 'boundedBatches': result['batches'],
                  'algorithmEquivalenceChecks': eq['checks'], 'duplicateBindingNegativeControl': 'REJECTED',
                  'boundary': 'Lua54/offline fake clock and module boundaries; no measured Web or device performance.'}))

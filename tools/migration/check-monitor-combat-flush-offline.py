"""Execute the added suffix with the real monitor Wrap; no engine/FPS claim."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

monitor = (root / 'scripts/diagnostics/PerformanceMonitor.lua').read_text('utf8')
suffix = (root / 'tools/migration/monitor-combat-flush-observer.lua').read_text('utf8')
prefix = r'''
local required,wrapped,events,called=0,0,0,0
local methods={Graph=true,Connectivity=true,Build=true,BuildParts=true,MergeBoxes=true,Spec=true,For=true,DisposeVehicle=true}
local modules={}
local original=function(a)called=called+1;if a=='fail'then error('original-error')end;return nil,a,nil end
require=function(name)
 required=required+1
 if not modules[name]then modules[name]={};for k in pairs(methods)do modules[name][k]=original end end
 return modules[name]
end
local app={}
local performance=nil
local updates=0
HandleUpdate=function(...)updates=updates+1;return nil,... end
local presented=function(...)return nil,... end
HandleFramePresented=presented
GetTime=function()return {frameNumber=17}end
cjson={encode=function(value)assert(value.count==8 and value.frame==17);return 'ready'end}
print=function(value)assert(value=='MONITOR_COMBAT_FLUSH_READY ready');events=events+1 end
'''
checks = r'''
assert(HandleFramePresented==presented,'FramePresented must stay byte-identical')
HandleUpdate(1);assert(required==0 and wrapped==0 and events==0)
app.trial={};HandleUpdate(2);assert(required==0)
app.trial.vehicle={};HandleUpdate(3);assert(required==0,'No monitor must not load modules')
local completed=0
local tokenMt={__close=function()completed=completed+1 end}
local begins={}
performance={enabled=true,recording=true,wrapped=setmetatable({},{__mode='k'}),restores=setmetatable({},{__mode='k'}),
 Begin=function(_,label)begins[#begins+1]=label;return setmetatable({},tokenMt)end}
performance.Wrap=function(self,...)
 wrapped=wrapped+1;return actualMonitor.Wrap(self,...)
end
local ret=table.pack(HandleUpdate(41,nil,43))
assert(ret.n==4 and ret[1]==nil and ret[2]==41 and ret[3]==nil and ret[4]==43)
assert(required==8 and wrapped==8 and events==1)
for _=1,5 do HandleUpdate()end
assert(required==8 and wrapped==8 and events==1,'Install exactly once')
local expected={
 {'construction.Blueprint','Graph','flush.graph'},
 {'construction.Blueprint','Connectivity','flush.connectivity'},
 {'drive.VehicleSpec','Build','flush.specBuild'},
 {'drive.VehicleSpec','BuildParts','flush.buildParts'},
 {'drive.VehicleSpec','MergeBoxes','flush.mergeBoxes'},
 {'construction.Rotors','Spec','flush.rotors'},
 {'construction.TurretRange','For','flush.turretRange'},
 {'combat.CarUnit','DisposeVehicle','flush.disposeVehicle'},
}
for _,entry in ipairs(expected)do
 local fn=modules[entry[1]][entry[2]];assert(fn~=original)
 local out=table.pack(fn(27));assert(out.n==3 and out[1]==nil and out[2]==27 and out[3]==nil)
 assert(begins[#begins]==entry[3])
 local ok,err=pcall(fn,'fail');assert(not ok and tostring(err):find('original%-error'))
end
assert(called==16 and #begins==16 and completed==16,'Existing Wrap preserves calls/returns/errors/close')
performance.recording=false;modules['construction.Blueprint'].Graph(9)
assert(called==17 and #begins==16 and completed==16)
assert(HandleFramePresented==presented)
return 'PASS: actual Wrap, eight exact scopes, one-time live install, nil returns/errors, no FramePresented changes'
'''
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().actualMonitor = lua.execute(monitor)
print(lua.execute(prefix + suffix + checks))

negative = r'''
app.trial={vehicle={}}
performance={enabled=false}
local ok,err=pcall(HandleUpdate)
assert(not ok and tostring(err):find('default enabled monitor'))
assert(required==0 and events==0)
performance={enabled=true,Wrap=function()end}
require=function()return {}end
ok,err=pcall(HandleUpdate)
assert(not ok and tostring(err):find('Missing flush method'))
assert(events==0,'A missing method must not announce ready')
return 'PASS: disabled monitor and missing method fail closed'
'''
lua = LuaRuntime(unpack_returned_tuples=True)
print(lua.execute(prefix + suffix + negative))

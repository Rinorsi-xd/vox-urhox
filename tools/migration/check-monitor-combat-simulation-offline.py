"""Validate isolated wrappers and actual exported-method availability; no Runtime."""
import json
import re
import sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
suffix=(root/'tools/migration/monitor-combat-simulation-observer.lua').read_text('utf8')
bindings=re.findall(r"\{'([^']+)','([^']+)','([^']+)'\}",suffix)
assert len(bindings)==29 and len({row[2] for row in bindings})==29
for module,method,label in bindings:
    source=(root/'scripts'/(module.replace('.','/')+'.lua')).read_text('utf8')
    assert re.search(r'function M[.:]'+re.escape(method)+r'\(',source),(module,method)
assert not re.search(r'\bdebug\b|collectgarbage|Raycast|\.Quad',suffix)
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().actualMonitor=lua.execute((root/'scripts/diagnostics/PerformanceMonitor.lua').read_text('utf8'))
lua.globals().expected=lua.table_from([lua.table_from(row) for row in bindings])
prefix=r'''
local modules,events,required,wrapped,called={},{},0,0,0
local original=function(...) called=called+1;if select(1,...)=='fail' then error('EXPECTED_ORIGINAL_ERROR',0) end;return nil,... end
for _,entry in ipairs(expected)do modules[entry[1]]=modules[entry[1]]or{};modules[entry[1]][entry[2]]=original end
require=function(name)required=required+1;return assert(modules[name])end
local app={};local performance=nil
HandleUpdate=function(...)return nil,...end
local presented=function(...)return nil,...end;HandleFramePresented=presented
GetTime=function()return{frameNumber=17}end
cjson={encode=function(v)assert(v.count==29 and v.frame==17 and v.debugUpvalues==false);return 'ready'end}
print=function(v)events[#events+1]=v end
'''
checks=r'''
assert(HandleFramePresented==presented)
HandleUpdate(1);assert(required==0 and wrapped==0 and #events==0)
app.trial={vehicle={}};HandleUpdate(2);assert(required==0)
local completed,begins=0,{}
local tokenMt={__close=function()completed=completed+1 end}
performance={enabled=true,recording=true,wrapped=setmetatable({},{__mode='k'}),restores=setmetatable({},{__mode='k'}),
 Begin=function(_,label)begins[#begins+1]=label;return setmetatable({},tokenMt)end}
performance.Wrap=function(self,...)wrapped=wrapped+1;return actualMonitor.Wrap(self,...)end
local ret=table.pack(HandleUpdate(41,nil,43))
assert(ret.n==4 and ret[1]==nil and ret[2]==41 and ret[3]==nil and ret[4]==43)
assert(required==29 and wrapped==29 and #events==1 and events[1]=='MONITOR_COMBAT_SIMULATION_READY ready')
for i=1,5 do HandleUpdate()end
assert(required==29 and wrapped==29 and #events==1)
for _,entry in ipairs(expected)do
 local fn=modules[entry[1]][entry[2]];assert(fn~=original)
 local out=table.pack(fn(27,nil,29));assert(out.n==4 and out[1]==nil and out[2]==27 and out[3]==nil and out[4]==29)
 assert(begins[#begins]==entry[3])
 local ok,err=pcall(fn,'fail');assert(not ok and tostring(err):find('EXPECTED_ORIGINAL_ERROR',1,true))
end
assert(called==58 and #begins==58 and completed==58)
performance.recording=false;modules['drive.LegGait'].Foothold(9)
assert(called==59 and #begins==58 and completed==58)
assert(HandleFramePresented==presented)
return 'PASS: 29 existing exports, exact one-time scopes, original args/returns/errors, default Wrap and unchanged FramePresented'
'''
print(lua.execute(prefix+suffix+checks))
negative=r'''
app.trial={vehicle={}};performance={enabled=false}
local ok,err=pcall(HandleUpdate)
assert(not ok and tostring(err):find('default enabled monitor',1,true) and required==0)
performance={enabled=true,Wrap=function()end};modules['combat.EnemyDriverThink'].Run=nil
ok,err=pcall(HandleUpdate)
assert(not ok and tostring(err):find('Missing simulation method',1,true) and #events==0)
return 'PASS: disabled monitor / missing actual method fail closed'
'''
print(lua.execute(prefix+suffix+negative))
print(json.dumps({'status':'OFFLINE_PASS','bindings':len(bindings),'nativeOrWebExecuted':False}))

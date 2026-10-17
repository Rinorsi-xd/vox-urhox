"""Offline actual Lua wall-scope accounting; no engine or hardware launch."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().ProbeSource = (ROOT / 'tools/migration/qa-native-owner-times.lua').read_text(encoding='utf-8')
result = lua.execute(r'''
local Factory=assert(load(ProbeSource))()
local time=0;local checks=0
local function Check(v,label)assert(v,label);checks=checks+1 end
local probe=Factory.New(function()return time end)
local api={}
local sentinel={}
api.Child=function(a,b,c)time=time+3;return a,b,c end
api.Parent=function()time=time+2;local a,b,c=api.Child(1,nil,false);assert(a==1 and b==nil and c==false);time=time+5 end
api.Error=function()time=time+4;error(sentinel)end
local original=api.Parent
probe:Wrap(api,'Parent','parent');probe:Wrap(api,'Child','child');probe:Wrap(api,'Error','error')
api.Parent();Check(probe.rows[1].calls==0,'dormant timing excludes calls')
probe.enabled=true;api.Parent();local ok,err=pcall(api.Error);probe.enabled=false
Check(not ok and err==sentinel,'original error identity preserved')
local r=probe:Report()
Check(r.rows[1].ms==10 and r.rows[1].selfMs==7 and r.rows[1].calls==1,'nested parent wall/self')
Check(r.rows[2].ms==3 and r.rows[2].selfMs==3 and r.rows[2].calls==1,'nested child wall/self')
Check(r.rows[3].ms==4 and r.rows[3].errors==1,'error scope recorded')
Check(probe.depth==0 and not r.invalid,'stack unwinds completely')
probe:Restore();Check(api.Parent==original,'method restored')
local noop={Run=function()return 1,nil,false end};local p=Factory.New(function()return 1 end)
p:Wrap(noop,'Run','noop');collectgarbage('collect');collectgarbage('stop')
local before=collectgarbage('count');p.enabled=true
ok,err=pcall(function()for _=1,10000 do local a,b,c=noop.Run();assert(a==1 and b==nil and c==false)end end)
p.enabled=false;local growth=collectgarbage('count')-before;collectgarbage('restart');assert(ok,err)
Check(p.rows[1].calls==10000 and growth<4,'no per-call result/token allocation')
return {checks=checks,noOpCalls=10000,noOpNetKiB=growth,boundary='Offline Lua 5.4 diagnostic accounting only; not engine timing or a subtractable observer correction.'}
''')
print(json.dumps(dict(result)))
lua.execute('assert(load(...))', (ROOT / 'tools/migration/perf-vehicle-allocation-native.lua').read_text(encoding='utf-8'))
print('Native probe syntax PASS')

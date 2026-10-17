"""Execute the actual QA boundary ring in Lua 5.4 without runtime or FPS claims."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().CORE = (root / 'tools/migration/engine-envelope-core.lua').read_text(encoding='utf-8')
lua.execute(r'''
local events,enabled,chosen,serial,clockCalls,ms={},false,false,0,0,0
SubscribeToEvent=function(name,fn)events[name]=fn end
Time={GetSystemTime=function()clockCalls=clockCalls+1;return ms end}
local function log(message)
 local data={GetInt=function()return 1 end,GetString=function(_,key)if key=='Message'then return message end;return '' end}
 events.LogMessage(nil,data)
end
print=log
engine={DumpProfiler=function()log('Profiler1.1.0 / Actual mock dump')end}
local sparse={EnvelopeState=function()return enabled,chosen,serial end}
local api=assert(load(CORE))().New(sparse)
local names={'PreRenderUpdate','RenderUpdate','PostRenderUpdate','BeginRendering','PreRenderUI','PostPreRenderUI','PostRenderUI','EndRendering','PreEndFrame','EndFrame'}
for _,name in ipairs(names)do events[name]()end
assert(clockCalls==0,'Dormant events must not read clocks')
api.Dump('before');assert(clockCalls==0)
enabled=true;serial=1
for _,name in ipairs(names)do events[name]()end
assert(clockCalls==0,'Unselected events must not read clocks')
chosen=true
assert(not pcall(api.Dump,'during'),'No dump while capture enabled')
assert(not pcall(api.Stop),'No stop while capture enabled')
for id,name in ipairs(names)do ms=(0xfffffff8+id)&0xffffffff;events[name]()end
chosen=false;for _,name in ipairs(names)do events[name]()end
assert(clockCalls==10)
enabled=false;local r=api.Stop()
assert(r.events==10 and #r.rows==30 and r.overflow==false and #r.dumps==2)
assert(r.dumps[1].label=='before'and r.dumps[2].label=='after')
for _,d in ipairs(r.dumps)do assert(d.ok and not d.overflow and #d.messages==2)end
for id=1,10 do local o=(id-1)*3;assert(r.rows[o+1]==1 and r.rows[o+2]==id and r.rows[o+3]==((0xfffffff8+id)&0xffffffff))end
-- Overflow is explicit and does not overwrite earlier samples or read another clock.
local full=assert(load(CORE))().New(sparse);enabled=true;chosen=true
for i=1,512*32+1 do events.EndFrame()end
assert(clockCalls==10+512*32);enabled=false;local overflow=full.Stop()
assert(overflow.overflow and overflow.events==512*32 and #overflow.rows==512*32*3)
-- Dump failure is retained as unavailable, outside the measurement window.
engine.DumpProfiler=function()error('mock unavailable')end
local absent=assert(load(CORE))().New(sparse);absent.Dump('before');local failed=absent.Stop()
assert(not failed.dumps[1].ok and failed.dumps[1].error:find('mock unavailable'))
assert(failed.events==0 and #failed.rows==0)
''')
suffix = subprocess.check_output(['node', '-e', "process.stdout.write(require('./tools/migration/engine-envelope-prepare.cjs').suffix())"], cwd=root, encoding='utf-8')
lua.globals().SUFFIX = suffix
lua.execute('assert(load(SUFFIX))')
print('PASS: actual Lua 5.4 dormant/unselected clock gates, complete numeric ring, uint32 timestamps, forbidden in-window dump/stop, explicit overflow, failed dump preservation, complete generated suffix syntax. Offline only.')

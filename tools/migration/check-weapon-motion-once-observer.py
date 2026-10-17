"""Execute the actual QA suffix with Lua54 mocks; no game/performance run."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().SOURCE = (ROOT / 'tools/migration/weapon-motion-once-observer.lua').read_text(encoding='utf-8')
result = lua.execute(r'''
local motion={};local calls=0;local outputs={};local key=false;local duplicate=false;local fail=false
function motion.Update(self,...)calls=calls+1;return nil,'value',... end
local original=motion.Update;package.loaded['render.WeaponMotion']=motion
KEY_F9='F9';input={GetKeyPress=function()return key end}
cjson={encode=function(value)local copy={};for k,v in pairs(value)do copy[k]=v end;outputs[#outputs+1]=copy;return '{}' end}
print=function()end
local a,b={},{};app={trial={},loadingFlow={active=false}}
function HandleUpdate()
    local x,y,z=motion.Update(a,17);assert(x==nil and y=='value' and z==17)
    motion.Update(b)
    if duplicate then motion.Update(a)end
    if fail then error('post-failure')end
    return nil,'update',23
end
function HandlePostUpdate()return nil,'post'end
local stopped=false;function Stop()stopped=true;return nil,'stop'end
assert(load(SOURCE))()
-- Repeated identical simulation time is irrelevant: actual callbacks split frames.
key=true;local x,y,z=HandleUpdate('Update',{time=1});HandlePostUpdate()
assert(x==nil and y=='update' and z==23)
HandleUpdate();HandlePostUpdate('PostUpdate',{time=1})
assert(#outputs==2 and outputs[2].observedFrames==2 and outputs[2].weaponCalls==4)
assert(outputs[2].duplicateCalls==0 and outputs[2].maxPerFrame==1 and outputs[2].uniqueWeapons==2)
duplicate=true;HandleUpdate();HandlePostUpdate()
assert(outputs[3].duplicateCalls==1 and outputs[3].maxPerFrame==2 and outputs[3].maxWeaponCallsInFrame==3)
motion.Update(a);duplicate=false;fail=true
local ok,err=pcall(HandleUpdate);assert(not ok and tostring(err):find('post%-failure'))
assert(outputs[4].updateErrors==1 and outputs[4].outsideUpdateCalls==1)
motion.Update(a);fail=false;HandleUpdate();HandlePostUpdate()
assert(outputs[5].outsideUpdateCalls==2 and outputs[5].updateCallbacks==5)
-- Deliberate warmup repeats must not be counted as gameplay duplicates.
app.loadingFlow.active=true;duplicate=true;HandleUpdate();HandlePostUpdate()
assert(outputs[6].weaponCalls==11 and outputs[6].duplicateCalls==1 and outputs[6].outsideUpdateCalls==5)
app.loadingFlow.active=false;app.trial=nil;HandleUpdate();HandlePostUpdate()
assert(outputs[7].weaponCalls==11 and outputs[7].outsideUpdateCalls==8)
local sx,sy=Stop();assert(stopped and sx==nil and sy=='stop' and motion.Update==original)
return 'PASS: actual Update boundaries, identity counts, duplicates, paused time, returns, errors, loading/no-trial exclusions, outside calls and restore'
''')
print(result)

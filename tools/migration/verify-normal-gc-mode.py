"""Offline Lua 5.4 controller checks with a fake engine and fake collector."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

SOURCE = (ROOT / 'tools/migration/qa-normal-gc-mode.lua').read_text(encoding='utf-8')
BOOT = r'''
calls={};gcMode='generational';running=true;clock=100;pending=0;background=0
cycle={epoch=1,active=false,stepping=false,restoreRequested=false}
input={focus=true,minimized=false,GetKeyPress=function()return false end}
KEY_F10=10;KEY_F11=11
Time={GetSystemTime=function()return clock end}
cache={GetNumBackgroundLoadResources=function()return background end}
local function encode(value)
    if type(value)=='string' then return string.format('%q',value) end
    if type(value)~='table' then return tostring(value) end
    local out={};for _,v in ipairs(value)do out[#out+1]=encode(v)end
    return '['..table.concat(out,',')..']'
end
cjson={encode=encode}
acks={};print=function(value)acks[#acks+1]=value end
function require(name)
    if name=='core.CollectionCycle' then return {State=function()return cycle end} end
    if name=='render.RenderTargetLifetime' then return {PendingCount=function()return pending end} end
    error('unexpected require '..name)
end
app={loadingFlow={active=false},loader={state='ready'},trial={pointer={captured=true},battle={rules={state='live'},entries={}}}}
VOX_HANGAR={app=app}
parts={
    {id=2,type='wheel',pos={1,0,2},rot=4,color=5,g=0},
    {id=1,type='cannon',pos={0,1,0},rot=0,color=7,g=0},
}
for i=1,8 do
    app.trial.battle.entries[i]={slot=i,member={player=i==1,role='heavy',variant=0},
        unit={team=i<=4 and 'blue' or 'red',bp={List=function()return parts end}}}
end
updates=0;stops=0
function HandleUpdate()updates=updates+1 end
function Stop()stops=stops+1 end
function collectgarbage(operation,...)
    calls[#calls+1]={operation=operation,args=table.pack(...)}
    if operation=='isrunning' then return running end
    if operation=='count' then return 1024 end
    if operation=='incremental' or operation=='generational' then
        if failMode then error('fake mode failure')end
        local previous=gcMode;gcMode=operation;return previous
    end
    if operation=='fake-error' then error('original fake error')end
    return 'original-result',nil,17,...
end
originalGc=collectgarbage
'''
checks = 0


def setup(target='incremental', extra=''):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(BOOT + extra)
    lua.execute('do\n' + SOURCE.replace('__VOX_GC_TARGET__', repr(target)) + '\nend')
    return lua


def check(lua, script):
    global checks
    lua.execute(script)
    checks += 1


for target in ('generational', 'incremental'):
    lua = setup(target)
    check(lua, "assert(#calls==0);HandleUpdate();assert(#calls==0 and updates==1)")
    check(lua, "VOX_QA_NORMAL_GC_MODE.Select();assert(gcMode==VOX_QA_NORMAL_GC_MODE.target)")
    check(lua, "local s=VOX_QA_NORMAL_GC_MODE.Snapshot();assert(s.phase=='selected' and s.previous=='generational' and s.running and s.guard.clear and #s.assembly==8)")
    check(lua, "local a=VOX_QA_NORMAL_GC_MODE.Snapshot().assembly;assert(a[1].count==2 and #a[1].fnv1a32==8)")
    check(lua, "local n=#calls;for i=1,100 do HandleUpdate()end;assert(#calls==n and updates==101)")
    check(lua, "collectgarbage('count');collectgarbage('isrunning');assert(not VOX_QA_NORMAL_GC_MODE.contaminated)")
    check(lua, "VOX_QA_NORMAL_GC_MODE.Restore();assert(gcMode=='generational' and collectgarbage==originalGc and VOX_QA_NORMAL_GC_MODE.restored)")
    check(lua, "for _,call in ipairs(calls)do assert(call.operation=='count' or call.operation=='isrunning' or call.operation=='generational' or call.operation=='incremental');assert(call.args.n==0)end")
    check(lua, "local n=#calls;VOX_QA_NORMAL_GC_MODE.Restore();assert(#calls==n+1);Stop();assert(stops==1)")

for extra in (
    'pending=1', 'background=1', 'cycle.active=true', 'cycle.stepping=true',
    'cycle.restoreRequested=true', 'app.pendingAssetRelease={}',
    'app.assetReleaseIncremental=true', 'app.openingRetirements={}',
    "app.loader.state='loading'", 'app.loadingFlow.active=true',
    'app.mapPreview={}', 'app.vehicleSwitch={pending={}}', 'input.focus=false',
    'input.minimized=true', 'app.trial.pointer.captured=false', 'app.trial.dialog={}',
    'app.trial.intro={done=false}', "app.trial.battle.rules.state='prep'", 'running=false',
    'table.remove(app.trial.battle.entries)',
):
    lua = setup(extra=extra)
    check(lua, "VOX_QA_NORMAL_GC_MODE.Select();assert(VOX_QA_NORMAL_GC_MODE.phase=='rejected');for _,c in ipairs(calls)do assert(c.operation=='isrunning')end;assert(collectgarbage==originalGc)")

for operation in ('step', 'collect', 'stop', 'restart', 'setpause', 'setstepmul', 'generational', 'incremental'):
    lua = setup()
    check(lua, "VOX_QA_NORMAL_GC_MODE.Select()")
    if operation in ('incremental', 'generational'):
        script = f"local previous=collectgarbage('{operation}');assert(previous=='incremental')"
    else:
        script = f"local a,b,c,d,e=collectgarbage('{operation}',128,'sentinel');assert(a=='original-result' and b==nil and c==17 and d==128 and e=='sentinel')"
    check(lua, script + ";assert(VOX_QA_NORMAL_GC_MODE.contaminated and VOX_QA_NORMAL_GC_MODE.mutations==1)")
    check(lua, "VOX_QA_NORMAL_GC_MODE.Restore();assert(gcMode=='generational' and collectgarbage==originalGc)")

lua = setup()
check(lua, "VOX_QA_NORMAL_GC_MODE.Select();local ok,message=pcall(collectgarbage,'fake-error');assert(not ok and message:find('original fake error'));assert(VOX_QA_NORMAL_GC_MODE.contaminated)")
check(lua, "VOX_QA_NORMAL_GC_MODE.Restore();assert(VOX_QA_NORMAL_GC_MODE.restored)")
lua = setup()
check(lua, "VOX_QA_NORMAL_GC_MODE.Select();collectgarbage=function()end;local replacement=collectgarbage;VOX_QA_NORMAL_GC_MODE.Restore();assert(collectgarbage==replacement and VOX_QA_NORMAL_GC_MODE.contaminated and VOX_QA_NORMAL_GC_MODE.error=='wrapper-ownership-lost')")
lua = setup()
check(lua, "VOX_QA_NORMAL_GC_MODE.Select();failMode=true;VOX_QA_NORMAL_GC_MODE.Restore();assert(not VOX_QA_NORMAL_GC_MODE.restored and VOX_QA_NORMAL_GC_MODE.phase=='restore-failed' and collectgarbage==originalGc)")
lua = setup(extra='failMode=true')
check(lua, "VOX_QA_NORMAL_GC_MODE.Select();assert(VOX_QA_NORMAL_GC_MODE.phase=='rejected' and collectgarbage==originalGc)")
lua = setup()
check(lua, "VOX_QA_NORMAL_GC_MODE.Select();Stop();assert(stops==1 and VOX_QA_NORMAL_GC_MODE.restored and collectgarbage==originalGc)")
lua = setup()
check(lua, "VOX_QA_NORMAL_GC_MODE.Select();VOX_QA_NORMAL_GC_MODE.Select();assert(VOX_QA_NORMAL_GC_MODE.error=='selection-already-attempted');local n=0;for _,c in ipairs(calls)do if c.operation=='incremental'then n=n+1 end end;assert(n==1)")
lua = setup()
check(lua, "VOX_QA_NORMAL_GC_MODE.Select();signature=VOX_QA_NORMAL_GC_MODE.Snapshot().assembly[1].fnv1a32")
signature = lua.globals().signature
reordered = setup(extra='parts={parts[2],parts[1]}')
check(reordered, "VOX_QA_NORMAL_GC_MODE.Select();signature=VOX_QA_NORMAL_GC_MODE.Snapshot().assembly[1].fnv1a32")
assert reordered.globals().signature == signature
changed = setup(extra="parts[1].type='other-weapon'")
check(changed, "VOX_QA_NORMAL_GC_MODE.Select();signature=VOX_QA_NORMAL_GC_MODE.Snapshot().assembly[1].fnv1a32")
assert changed.globals().signature != signature
print(f'PASS: {checks + 2} offline Lua 5.4 fake-engine/controller checks; no Native/browser or real collector mode changes')

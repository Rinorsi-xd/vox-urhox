"""Actual Lua 5.4 GC modes and production release ownership; no native/GPU run."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

PRELUDE = r'''
package.path='scripts/?.lua;'..package.path
local function noop()end
for _,name in ipairs({'Config','construction.Blueprint','construction.Prefab',
 'render.VehicleView','scene.Hangar','controls.OrbitCamera','app.SceneLoader',
 'app.HotReload','render.Quality'})do package.loaded[name]={}end
package.loaded['urhox-libs/UI']={Shutdown=noop}
package.loaded['ui.GarageHud']={Dispose=noop}
package.loaded['audio.IntroAudioTail']={CancelAll=noop}
package.loaded['audio.UiSound']={Dispose=noop}
package.loaded['audio.StoryComms']={Shutdown=noop}
environmentBakeCache={ClearCache=noop};cache={};renderer={};input={}
print=noop
RT=assert(load(RT_SOURCE,'@render/RenderTargetLifetime.lua'))()
package.loaded['render.RenderTargetLifetime']=RT
-- Hoisted app dependencies are outside these release/stop scenarios.
for name in APP_SOURCE:gmatch('require%s*%(?%s*[\'"]([%w./-]+)[\'"]') do
 if name~='core.CollectionCycle' and not package.loaded[name] then package.loaded[name]={} end
end
App=assert(load(APP_SOURCE,'@app/HangarApp.lua'))()
function NewApp()
 return setmetatable({mapTransition={Stop=noop},vehicleGate={Cancel=noop},
  loader={Cancel=noop},toasts={Dispose=noop},music={Dispose=noop},ambience={Dispose=noop},
  previews={Dispose=noop},store={Flush=noop},graphicsSettings={Dispose=noop},
  previousState={}},App)
end
function Mode()
 local previous=collectgarbage('incremental');collectgarbage(previous);return previous
end
function Garbage(count,targets)
 local finalized=0;local disposed=0
 collectgarbage('stop')
 local held={}
 for i=1,count do held[i]=setmetatable({i,string.rep('x',50)},
  {__gc=function()finalized=finalized+1 end})end
 for i=1,targets do
  RT.Retire({GetRenderSurface=function()
   return setmetatable({SetNumViewports=function()end},
    {__gc=function()finalized=finalized+1 end})
  end,Dispose=function()disposed=disposed+1 end})
 end
 held=nil;collectgarbage('restart')
 return function()return finalized,disposed end
end
function Run(mode,frames,targets)
 collectgarbage('collect');collectgarbage(mode)
 local app=NewApp();local released=0
 local counts=Garbage(20000,targets)
 app:DeferAssetRelease(function()released=released+1 end,true)
 local first=0
 for frame=1,frames do
  local temp={frame,string.rep('b',100)}
  RT.Update()
  if app.pendingAssetRelease and app:ReleaseSettledAssets() and first==0 then first=frame end
 end
 local finalized,disposed=counts()
 return {released=released,first=first,pending=app.pendingAssetRelease~=nil,
  finalized=finalized,textureDisposed=disposed,retired=RT.PendingCount(),mode=Mode()}
end
function BorrowerCrossCycle()
 local C=require 'core.CollectionCycle'
 collectgarbage('incremental');collectgarbage('collect')
 local surfaceDone,early,disposed=false,false,false;local weak
 local texture={GetRenderSurface=function()return weak[1]end,
  Dispose=function()early=not surfaceDone;disposed=true end}
 local surface=setmetatable({SetNumViewports=function()end},
  {__gc=function()surfaceDone=true end})
 weak=setmetatable({surface},{__mode='v'});RT.Retire(texture)
 C.Collect();local advanced=C.Epoch()
 collectgarbage('stop')
 local sentinel=setmetatable({},{__gc=function()for _=1,3 do RT.Update()end end})
 surface=nil;sentinel=nil;C.Collect()
 local earlyAtFinalizer=early
 for _=1,1000 do RT.Update();if RT.PendingCount()==0 then break end end
 return {advanced=advanced,early=earlyAtFinalizer,disposed=disposed,
  surfaceFinalized=surfaceDone,pending=RT.PendingCount()}
end
function SharedEpoch()
 local C=require 'core.CollectionCycle';collectgarbage('generational')
 C.Collect();local oldEpoch=C.Epoch();local released=0
 local app=NewApp();app:DeferAssetRelease(function()released=released+1 end,true)
 local step=C.Step;C.Step=function()return false end
 assert(not app:ReleaseSettledAssets() and released==0,'old epoch cannot release a newer queued owner')
 C.Step=step
 for _=1,1000 do if C.Step(128)then break end end
 assert(C.Epoch()>oldEpoch)
 C.Step=function()error('App must consume another consumer completion without opening a cycle')end
 assert(app:ReleaseSettledAssets() and released==1)
 C.Step=step;assert(not C.State().active and Mode()=='generational')
 return true
end
function NoUnusedLease()
 local C=require 'core.CollectionCycle';collectgarbage('generational');collectgarbage('stop')
 local kept={};for i=1,50000 do kept[i]={i,string.rep('x',50)}end
 local surface={SetNumViewports=function()end};local weak=setmetatable({surface},{__mode='v'})
 local disposed=false
 RT.Retire({GetRenderSurface=function()return weak[1]end,Dispose=function()disposed=true end})
 surface=nil;C.Collect()
 for _=1,3 do RT.Update()end
 if not disposed then
  for _=1,10000 do if C.Step(128)then break end end
  assert(not C.State().active)
  local calls=0;local step=C.Step
  C.Step=function(...)calls=calls+1;return step(...)end
  for _=1,3 do RT.Update()end
  C.Step=step
  assert(calls==0,'consuming a completed epoch must not start an unneeded lease')
 end
 assert(disposed and RT.PendingCount()==0 and not C.State().active)
 assert(Mode()=='generational');return true
end
function MidCycleFence()
 local C=require 'core.CollectionCycle';collectgarbage('generational')
 local real=collectgarbage
 collectgarbage=function(kind,...)if kind=='step'then real(kind,...);return false end;return real(kind,...)end
 assert(not C.Step(128));local before=C.Epoch();local released=0
 local app=NewApp();app:DeferAssetRelease(function()released=released+1 end,true)
 assert(app.assetReleaseEpoch==before+1)
 collectgarbage=real
 for _=1,1000 do if C.Step(128)then break end end
 assert(C.Epoch()==before+1)
 local step=C.Step;C.Step=function()return false end
 assert(not app:ReleaseSettledAssets() and released==0)
 C.Step=step
 for _=1,1000 do if app:ReleaseSettledAssets()then break end end
 assert(released==1 and not app.pendingAssetRelease and Mode()=='generational')
 return true
end
function CollectorErrors()
 local C=require 'core.CollectionCycle';collectgarbage('generational')
 local real=collectgarbage
 for _,operation in ipairs({'step','collect'})do
  collectgarbage=function(kind,...)
   if kind==operation then error('expected collector failure')end
   return real(kind,...)
  end
  local ok,err=pcall(operation=='step'and C.Step or C.Collect)
  collectgarbage=real
  assert(not ok and tostring(err):find('expected collector failure',1,true))
  assert(not C.State().active and not C.State().stepping and Mode()=='generational')
 end
 return true
end
function FinalizerFullReentry()
 local C=require 'core.CollectionCycle';collectgarbage('generational');collectgarbage('stop')
 local disposed,surfaceDone,early=false,false,false;local weak
 local nestedFlush=false
 local texture={GetRenderSurface=function()return weak[1]end,
  Dispose=function()disposed=true;early=not surfaceDone end}
 local surface=setmetatable({SetNumViewports=function()end},{__gc=function()
  RT.Flush();nestedFlush=true;surfaceDone=true
 end})
 weak=setmetatable({surface},{__mode='v'});RT.Retire(texture);surface=nil
 C.Collect()
 local disposedDuringFinalizer=early
 RT.Flush()
 local app=NewApp();local released=0;local nestedResult,nestedPending
 app:DeferAssetRelease(function()released=released+1 end)
 collectgarbage('stop')
 local sentinel=setmetatable({},{__gc=function()
  nestedResult=app:ReleaseSettledAssets();nestedPending=app.pendingAssetRelease~=nil
 end})
 sentinel=nil;C.Collect()
 local releasedDuringFinalizer=released
 local completed=app:ReleaseSettledAssets()
 return {nestedFlush=nestedFlush,surfaceFinalized=surfaceDone,disposed=disposed,
  early=disposedDuringFinalizer,nestedAppResult=nestedResult,nestedAppPending=nestedPending,
  releasedDuringFinalizer=releasedDuringFinalizer,released=released,completed=completed,
  pending=app.pendingAssetRelease~=nil,mode=Mode()}
end
function FullFinalizerQueuesOwner()
 local app=NewApp();local released=0
 collectgarbage('generational');collectgarbage('stop')
 app:DeferAssetRelease(function()released=released+1 end)
 local sentinel=setmetatable({},{__gc=function()
  app:DeferAssetRelease(function()released=released+1 end)
 end})
 sentinel=nil
 assert(not app:ReleaseSettledAssets() and released==0 and app.pendingAssetRelease)
 assert(app:ReleaseSettledAssets() and released==2 and not app.pendingAssetRelease)
 assert(Mode()=='generational');return true
end
function FinalizerRestore(action)
 local C=require 'core.CollectionCycle';collectgarbage('generational');collectgarbage('stop')
 local app=NewApp();local released=0;local done=false;local ok,msg
 app:DeferAssetRelease(function()released=released+1 end,true)
 local sentinel=setmetatable({},{__gc=function()
  ok,msg=pcall(function()
   if action=='stop' then app:Stop()
   else app:DeferAssetRelease(function()released=released+1 end) end
  end)
  done=true
 end})
 sentinel=nil
 local real=collectgarbage
 collectgarbage=function(kind,...)
  if kind=='step' then real(kind,...);return false end
  return real(kind,...)
 end
 for _=1,1000 do C.Step(128);if done then break end end
 collectgarbage=real
 assert(done and ok,tostring(msg))
 local restored=Mode();local active=C.State().active
 if action~='stop' then assert(app:ReleaseSettledAssets() and released==2)end
 return {mode=restored,active=active,stopped=app.stopped or false,
  released=released,pending=app.pendingAssetRelease~=nil}
end
function FinalizerDuringModeRestore()
 local C=require 'core.CollectionCycle';collectgarbage('generational');collectgarbage('stop')
 local first,second=false,false;local nestedStep,nestedCollect,unchanged
 local sentinel=setmetatable({},{__gc=function()
  first=true
  local nextSentinel=setmetatable({},{__gc=function()
   second=true;local epoch=C.Epoch()
   nestedStep=C.Step(128);nestedCollect=C.Collect();unchanged=C.Epoch()==epoch
  end})
  nextSentinel=nil
 end})
 sentinel=nil
 for _=1,1000 do if C.Step(128) then break end end
 local active=C.State().active
 return {first=first,second=second,nestedStep=nestedStep,nestedCollect=nestedCollect,
  epochUnchanged=unchanged,active=active,mode=Mode()}
end
'''


def runtime(app_source, rt_source, collection_source=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().APP_SOURCE = app_source
    lua.globals().RT_SOURCE = rt_source
    if collection_source is not None:
        lua.globals().COLLECTION_SOURCE = collection_source
        lua.execute("package.preload['core.CollectionCycle']=function()return assert(load(COLLECTION_SOURCE))()end")
    lua.execute(PRELUDE)
    return lua


def plain(value):
    if hasattr(value, 'items'):
        return {key: plain(item) for key, item in value.items()}
    return value


def fixture_sha256(path):
    # Git checkouts may use CRLF; pin the original Lua source with LF endings.
    source = path.read_text(encoding='utf-8').replace('\r\n', '\n')
    return hashlib.sha256(source.encode('utf-8')).hexdigest()


historical = {
    'manifest': 'manifest-e41f909a.json',
    'targetCommit': '9541dc59ef2f281cafa5126762a57550189e04dc',
    'dirtyExport': True,
    'fixtureHashEncoding': 'UTF-8 with LF line endings',
    'originalExportSha256': {
        'app/HangarApp.lua': '3c045877fb2a0280e99da235c5aca5a7ec9b436b7c7644b8a1f663527c6f1fb8',
        'render/RenderTargetLifetime.lua': '305d9583c3b4ef5f01adae2457f33939cf32de740b53bc28f1d78de29fe24485',
    },
    'fixtures': {
        'tools/migration/fixtures/e41-hangar-release.lua': '2696728466e27fd63bcc7d1bdd0351cfc38d05321045e2fe6bb81fc8d285f4a2',
        'tools/migration/fixtures/e41-render-target-lifetime.lua': '7d5ca6946a892e78f6ff1faa6e8d520479bb2a0a22df3db75e4fb20d5d98bf05',
    },
    'boundary': 'Exact exported app release methods plus the full exported retirement module; unrelated app methods omitted.',
}
for fixture, expected in historical['fixtures'].items():
    assert fixture_sha256(ROOT / fixture) == expected, fixture
old_app = (ROOT / 'tools/migration/fixtures/e41-hangar-release.lua').read_text(encoding='utf-8')
old_rt = (ROOT / 'tools/migration/fixtures/e41-render-target-lifetime.lua').read_text(encoding='utf-8')
negative = plain(runtime(old_app, old_rt).eval('Run')("generational", 10000, 12))
assert negative['finalized'] == 20012 and negative['released'] == 0
assert negative['pending'] and negative['retired'] == 12

app_path = ROOT / 'scripts/app/HangarApp.lua'
rt_path = ROOT / 'scripts/render/RenderTargetLifetime.lua'
app = app_path.read_text(encoding='utf-8')
rt = rt_path.read_text(encoding='utf-8')
paths = ['scripts/app/HangarApp.lua', 'scripts/render/RenderTargetLifetime.lua',
         'scripts/core/CollectionCycle.lua', 'tools/migration/check-intro-gc-fence.py',
         *historical['fixtures'],
         'tools/migration/fixtures/render-target-lifetime-before-clear-fence.lua',
         'tools/migration/fixtures/collection-cycle-before-finalizer-restore.lua']
hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
cases = {}
for mode in ('incremental', 'generational'):
    result = plain(runtime(app, rt).eval('Run')(mode, 1000, 12))
    assert result['released'] == 1 and not result['pending'], result
    assert result['mode'] == mode, result
    assert result['finalized'] == 20012 and result['textureDisposed'] == 12, result
    assert result['retired'] == 0 and 0 < result['first'] <= 1000, result
    cases[mode] = result

unsafe_path = ROOT / 'tools/migration/fixtures/render-target-lifetime-before-clear-fence.lua'
assert fixture_sha256(unsafe_path) == '7c1295960f14142c2cb663f6d84ab65f8ec93629dbd64c435025350360eea0b4'
unsafe = plain(runtime(app, unsafe_path.read_text(encoding='utf-8')).eval('BorrowerCrossCycle')())
assert unsafe['early'] and unsafe['surfaceFinalized'] and unsafe['disposed'], unsafe
safe = plain(runtime(app, rt).eval('BorrowerCrossCycle')())
assert not safe['early'] and safe['surfaceFinalized'] and safe['disposed'] and safe['pending'] == 0, safe
fence_cases = {'historicalBorrowerUnsafe': unsafe, 'borrowerCrossCycle': safe}
for name in ('SharedEpoch', 'NoUnusedLease', 'MidCycleFence', 'CollectorErrors'):
    fence_cases[name] = runtime(app, rt).eval(name)()
unguarded_app = app.replace("elseif not CollectionCycle.Collect() then return false end", "else CollectionCycle.Collect() end")
unguarded_rt = rt.replace("if not CollectionCycle.Collect() then return end", "CollectionCycle.Collect()")
assert unguarded_app != app and unguarded_rt != rt
unsafe_reentry = plain(runtime(unguarded_app, unguarded_rt).eval('FinalizerFullReentry')())
assert unsafe_reentry['early'] and unsafe_reentry['releasedDuringFinalizer'] == 1, unsafe_reentry
safe_reentry = plain(runtime(app, rt).eval('FinalizerFullReentry')())
assert safe_reentry['nestedFlush'] and safe_reentry['surfaceFinalized'] and safe_reentry['disposed'], safe_reentry
assert not safe_reentry['early'] and not safe_reentry['nestedAppResult'], safe_reentry
assert safe_reentry['nestedAppPending'] and safe_reentry['releasedDuringFinalizer'] == 0, safe_reentry
assert safe_reentry['completed'] and safe_reentry['released'] == 1 and not safe_reentry['pending'], safe_reentry
assert safe_reentry['mode'] == 'generational', safe_reentry
fence_cases['unguardedFullReentryUnsafe'] = unsafe_reentry
fence_cases['fullFinalizerReentry'] = safe_reentry
fence_cases['fullFinalizerQueuesOwner'] = runtime(app, rt).eval('FullFinalizerQueuesOwner')()
old_collection_path = ROOT / 'tools/migration/fixtures/collection-cycle-before-finalizer-restore.lua'
assert fixture_sha256(old_collection_path) == 'f7630ac50ca64d427f5f2b285d2c35f147009b446c582060996d3974d7a3595b'
old_collection = old_collection_path.read_text(encoding='utf-8')
for action in ('stop', 'upgrade'):
    unsafe_restore = plain(runtime(app, rt, old_collection).eval('FinalizerRestore')(action))
    assert unsafe_restore['mode'] == 'incremental' and not unsafe_restore['active'], unsafe_restore
    safe_restore = plain(runtime(app, rt).eval('FinalizerRestore')(action))
    assert safe_restore['mode'] == 'generational' and not safe_restore['active'], safe_restore
    assert not safe_restore['pending'] and safe_restore['released'] == (0 if action == 'stop' else 2), safe_restore
    fence_cases[action + 'FinalizerHistoricalUnsafe'] = unsafe_restore
    fence_cases[action + 'FinalizerRestore'] = safe_restore
unsafe_mode_reentry = plain(runtime(app, rt, old_collection).eval('FinalizerDuringModeRestore')())
assert unsafe_mode_reentry['active'] or not unsafe_mode_reentry['epochUnchanged'], unsafe_mode_reentry
safe_mode_reentry = plain(runtime(app, rt).eval('FinalizerDuringModeRestore')())
assert safe_mode_reentry['first'] and safe_mode_reentry['second'], safe_mode_reentry
assert not safe_mode_reentry['nestedStep'] and not safe_mode_reentry['nestedCollect'], safe_mode_reentry
assert safe_mode_reentry['epochUnchanged'] and not safe_mode_reentry['active'], safe_mode_reentry
assert safe_mode_reentry['mode'] == 'generational', safe_mode_reentry
fence_cases['modeRestoreFinalizerHistoricalUnsafe'] = unsafe_mode_reentry
fence_cases['modeRestoreFinalizerReentry'] = safe_mode_reentry

ownership = plain(runtime(app, rt).execute(r'''
collectgarbage('collect');collectgarbage('generational')
local app=NewApp();local released=0;local real=collectgarbage
collectgarbage=function(kind,...)
 if kind=='step' then real(kind,...);return false end
 return real(kind,...)
end
app:DeferAssetRelease(function()released=released+1 end,true)
assert(not app:ReleaseSettledAssets() and app.pendingAssetRelease)
app:Stop();app:Stop()
collectgarbage=real
assert(Mode()=='generational' and released==0 and not app.pendingAssetRelease)
local stop=true
app=NewApp();collectgarbage=function(kind,...)
 if kind=='step' then real(kind,...);return false end
 return real(kind,...)
end
app:DeferAssetRelease(function()released=released+1 end,true)
assert(not app:ReleaseSettledAssets())
app:DeferAssetRelease(function()released=released+1 end)
collectgarbage=real
assert(app:ReleaseSettledAssets() and released==2 and Mode()=='generational')
local upgrade=true
app=NewApp()
app:DeferAssetRelease(function()
 app:DeferAssetRelease(function()released=released+1 end,true)
end,true)
for _=1,1000 do if app:ReleaseSettledAssets() then break end end
assert(app.pendingAssetRelease and Mode()=='generational')
for _=1,1000 do if app:ReleaseSettledAssets() then break end end
assert(not app.pendingAssetRelease and released==3 and Mode()=='generational')
local reentry=true
app=NewApp();app:DeferAssetRelease(function()error('expected callback failure')end,true)
local failed=false
for _=1,1000 do
 local ok,done=pcall(app.ReleaseSettledAssets,app)
 if not ok then assert(tostring(done):find('expected callback failure',1,true));failed=true;break end
end
assert(failed and Mode()=='generational')
return {stop=stop,synchronousUpgrade=upgrade,callbackReentry=reentry,callbackErrorRestoresMode=failed}
'''))

assert hashes == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
report = {
    'result': 'PASS', 'checks': 1 + len(cases) + len(ownership) + len(fence_cases),
    'checkUnit': 'named scenarios', 'historicalNegative': negative, 'historicalFixture': historical,
    'cases': cases, 'ownership': ownership, 'fenceCases': fence_cases,
    'productionHashes': hashes,
    'boundary': 'Actual Lua 5.4 collector and full production App/RenderTargetLifetime modules, with table finalizers and controlled native service adapters. Historical e41 reproduces reclaimed objects with a permanently pending generational fence. No WASM collector-mode, native userdata finalizer, GPU, browser, memory-residency or timing acceptance.'}
out = ROOT / 'docs/migration/evidence/intro-gc-fence-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))

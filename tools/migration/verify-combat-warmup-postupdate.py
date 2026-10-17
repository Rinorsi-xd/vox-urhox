"""Real Lua app/trial lifecycle; old package is a required negative control."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

APP = ROOT / 'scripts/app/HangarApp.lua'
FIXTURE = ROOT / 'tools/migration/check-combat-warmup-postupdate.lua'
HISTORICAL = ROOT / '.tmp/outgame-cached-1792125241918/scripts/app/HangarApp.lua'


def run(source):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().APP_SOURCE = source
    lua.globals().print = lambda *args: None
    return lua.execute(FIXTURE.read_text(encoding='utf-8'))


source = APP.read_text(encoding='utf-8')
result = run(source)
try:
    run(HISTORICAL.read_text(encoding='utf-8'))
except Exception as error:
    negative = str(error).splitlines()[0]
    assert 'warm line survives real PostUpdate before render' in negative, negative
else:
    raise AssertionError('Old package unexpectedly preserved pre-render warm geometry')

constructor_access = source.replace('function App:PostUpdate(dt)\n',
    'function App:PostUpdate(dt)\n    HangarPreview.New()\n', 1)
assert constructor_access != source
try:
    run(constructor_access)
except Exception as error:
    strict_failure = str(error).splitlines()[0]
    assert 'constructor-only dependency used in PostUpdate fixture: render.HangarPreview.New' in strict_failure, strict_failure
else:
    raise AssertionError('Constructor-only dependency was allowed through a no-op stub')

paths = ['scripts/app/HangarApp.lua', 'scripts/app/TrialSession.lua', 'scripts/app/LoadingFlow.lua',
         'scripts/render/CombatWarmup.lua', 'scripts/render/AimLines.lua', 'scripts/render/AimLinesRules.lua',
         'scripts/render/FlashWarmup.lua', 'scripts/render/SceneWarmup.lua', 'scripts/render/WarmupSignature.lua',
         'scripts/render/EquipmentWarmup.lua']
tools = ['tools/migration/check-combat-warmup-postupdate.lua',
         'tools/migration/check-combat-warmup.lua', 'tools/migration/verify-combat-warmup-postupdate.py']
report = {
    'result': 'PASS', 'checks': result['checks'], 'phases': result['phases'],
    'negativeControls': [
        {'manifest': '848f4d10', 'appSha256': hashlib.sha256(HISTORICAL.read_bytes()).hexdigest(), 'failure': negative},
        {'case': 'constructor dependency unexpectedly accessed by PostUpdate', 'failure': strict_failure}],
    'productionHashes': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in paths},
    'testInputs': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in tools},
    'boundary': 'Real HangarApp.PostUpdate, TrialSession.PostUpdate, LoadingFlow.Rendered/Close/Fail, CombatWarmup and AimLines. Unused hoisted constructor dependencies are strict fail-on-access stubs. Engine geometry/camera/resource adapters; no GPU shader submission, audible acceptance or load-time improvement claim.'
}
out = ROOT / 'docs/migration/evidence/combat-warmup-postupdate-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': report['checks'], 'phases': report['phases'], 'negativeControls': report['negativeControls']}))

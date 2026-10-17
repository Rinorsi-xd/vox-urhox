"""Map warmup obligations and native instance setter semantics, without GPU launches."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

paths = ['scripts/render/CombatWarmup.lua', 'scripts/render/MapWarmupProbes.lua', 'scripts/render/WarmupSignature.lua']
sources = {name: (ROOT / name).read_text('utf8') for name in paths}
fixture = (ROOT / 'tools/migration/check-map-warmup.lua').read_text('utf8')


def run(changed=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *args: None
    for name, source in (changed or sources).items():
        module = name.removeprefix('scripts/').removesuffix('.lua').replace('/', '.')
        lua.globals().MODULE_SOURCE = source
        lua.globals().MODULE_NAME = module
        lua.execute('local source=MODULE_SOURCE; package.preload[MODULE_NAME]=function()return assert(load(source))()end')
    return dict(lua.execute(fixture).items())


result = run()
negative = []
for path, before, after, label in [
    (paths[0], "'instanceColor','instanceCustomData','useInstanceColor','useInstanceCustomData'",
     "'useInstanceColor','useInstanceCustomData','instanceColor','instanceCustomData'", 'old native setter ordering'),
    (paths[0], 'for _,group in ipairs(mapProbes) do self.volumeGroups[#self.volumeGroups+1]=group end',
     'for _,group in ipairs(mapProbes) do end', 'omit measured ordinary Scatter probes'),
    (paths[1], 'elseif not keyed[key] then', 'elseif true then', 'repeat every Scatter chunk instead of exact representatives'),
    (paths[1], 'singleKeys=singles,singleVolumeOnly=true', 'singleKeys=singles,singleVolumeOnly=false',
     'rebuild already-warmed instanced Scatter stages'),
]:
    assert before in sources[path], label
    mutated = {**sources, path: sources[path].replace(before, after, 1)}
    try:
        run(mutated)
    except Exception as error:
        negative.append({'case': label, 'failure': str(error).split('\n')[0]})
    else:
        raise AssertionError('Mutation incorrectly passed: ' + label)

result['negativeControls'] = negative
result['productionHashes'] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in paths}
result['fixtureHashes'] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in [
    'tools/migration/check-map-warmup.lua', 'tools/migration/verify-map-warmup.py',
    'tools/migration/check-combat-warmup.lua']}
for name, source in sources.items():
    assert (ROOT / name).read_text('utf8') == source, 'Production source changed: ' + name
out = ROOT / 'docs/migration/evidence/map-warmup-offline.json'
out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
print(json.dumps(result))

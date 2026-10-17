"""Execute the served QA fault suffix offline; no engine or browser launches."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source_path = ROOT / 'tools/migration/qa-loading-failure.lua'
source = source_path.read_text('utf8')
flow = (ROOT / 'scripts/app/LoadingFlow.lua').read_text('utf8')
fixture = (ROOT / 'tools/migration/check-qa-loading-failure.lua').read_text('utf8')


def run(code):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *args: None
    lua.globals().QA_SOURCE = code
    lua.globals().FLOW_SOURCE = flow
    return dict(lua.execute(fixture).items())


result = run(source)
negative = []
for before, after, label in [
    ('if Warmup.New==replacement then Warmup.New=actualNew end',
     'if false then Warmup.New=actualNew end', 'leave injection constructor installed'),
    ('local results=table.pack(actual(self,...))', 'local results={n=0}', 'skip actual wrapped method'),
    ('if binding.object[binding.name]==binding.wrapped then binding.object[binding.name]=binding.original end',
     'if false then binding.object[binding.name]=binding.original end', 'retain QA hooks after hall recovery'),
]:
    assert before in source, label
    try:
        run(source.replace(before, after, 1))
    except Exception as error:
        negative.append({'case': label, 'failure': str(error).split('\n')[0]})
    else:
        raise AssertionError('Mutation incorrectly passed: ' + label)
result['negativeControls'] = negative
paths = ['tools/migration/qa-loading-failure.lua', 'tools/migration/check-loading-failure-web.cjs',
         'tools/migration/serve-outgame.cjs', 'tools/migration/audit-snapshot-http.cjs',
         'tools/migration/check-qa-loading-failure.lua', 'scripts/app/LoadingFlow.lua', 'scripts/render/CombatWarmup.lua']
result['hashes'] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in paths}
assert source_path.read_text('utf8') == source, 'Suffix changed while executing'
out = ROOT / 'docs/migration/evidence/qa-loading-failure-offline.json'
out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
print(json.dumps(result))

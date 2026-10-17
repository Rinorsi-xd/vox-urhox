"""Real transformed-module equivalence and nested scope checks, without runtime."""
import json
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
subprocess.run(['node', str(ROOT / 'tools/migration/g1-web-cpu-support-prepare.cjs')], check=True)
folder = ROOT / '.tmp/g1-web-cpu-support-candidates'
identity = json.loads((ROOT / '.tmp/outgame-cached-1792174992428/identity.json').read_text(encoding='utf-8'))
source = Path(identity['source_directory']) / 'scripts'
read = lambda p: p.read_text(encoding='utf-8')
lua = LuaRuntime(unpack_returned_tuples=True)
result = lua.execute(read(ROOT / 'tools/migration/g1-web-cpu-support-selftest.lua'),
                     read(source / 'drive/RaySuspension.lua'), read(folder / 'RaySuspension.lua'),
                     read(source / 'physics/Space.lua'), read(folder / 'Space.lua'),
                     read(ROOT / 'tools/migration/perf-drive-sections-scope.lua'))
lua.execute('assert(load(...))', read(folder / 'probe.lua'))
record = dict(result.items())
assert record['status'] == 'PASS'
def plain(value):
    if hasattr(value, 'items'):
        rows = dict(value.items())
        return [plain(rows[i]) for i in range(1, len(rows)+1)] if rows and set(rows) == set(range(1, len(rows)+1)) else {k: plain(v) for k,v in rows.items()}
    return value
runtime = LuaRuntime(unpack_returned_tuples=True)
logs = []
runtime.globals().print = lambda *args: logs.append(' '.join(map(str, args)))
runtime.globals().cjson = runtime.table_from({'encode': lambda value: json.dumps(plain(value), separators=(',', ':'))})
runtime.execute(read(ROOT / 'tools/migration/g1-web-cpu-selftest.lua'), 'profile', False, 'crater')
runtime.execute("package.loaded['drive.ChassisStability']={Step=function()end};package.loaded['drive.HoverControl']={Step=function()end}")
runtime.execute("""
local done,updates,cancelled=nil,0,false
package.loaded['app.ResourceGate']={
 New=function()return {Start=function(_,paths,cb)assert(#paths==1 and paths[1]=='Crater/VisualHeight.bin');done=cb end,
 Cancel=function()cancelled=true end}end,
 UpdatePending=function(dt)assert(dt>=0);updates=updates+1;if updates==2 then done(true,'')end end}
cache={Exists=function()assert(updates>=2);return true end,
 GetFile=function()return {size=1643544,ReadFileID=function()return 'VHF1'end,Dispose=function()end}end}
SUPPORT_PRELOAD_ASSERT=function()assert(updates==2 and cancelled)end
""")
runtime.execute(read(folder / 'probe.lua'))
runtime.globals().Start()
for _ in range(90):
    runtime.globals().G1WebCpuUpdate()
chunks = [json.loads(line.split('G1_WEB_CPU_CHUNK ',1)[1]) for line in logs if 'G1_WEB_CPU_CHUNK ' in line]
assert chunks and len(chunks) == chunks[0]['count']
integrated = json.loads(''.join(chunk['data'] for chunk in chunks))
assert integrated['status'] == 'PASS' and len(integrated['scopes']) == 14 and integrated['totalMs'] == 420
runtime.globals().SUPPORT_PRELOAD_ASSERT()
assert integrated['supportPreload']['ready'] and integrated['supportPreload']['fileBytes'] == 1643544
record['integratedCoroutineSteps'] = integrated['steps']
(ROOT / 'docs/migration/evidence/g1-web-cpu-support-offline.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(json.dumps(record))

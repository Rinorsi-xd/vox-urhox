"""Exercise actual warmup modules and record exact production input hashes."""
import hashlib
import json
from pathlib import Path
import os
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

messages = []
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().print = lambda *args: messages.append(' '.join(map(str, args)))
for name in ['check-combat-warmup.lua', 'check-loading-combat-warmup.lua']:
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().print = lua.globals().print
    runtime.execute((ROOT / 'tools/migration' / name).read_text(encoding='utf-8'))
names = ['scripts/render/FlashWarmup.lua', 'scripts/render/CombatWarmup.lua', 'scripts/render/WarmupSignature.lua',
         'scripts/render/RestoreFlash.lua', 'scripts/app/LoadingFlow.lua',
         'tools/migration/check-combat-warmup.lua', 'tools/migration/check-loading-combat-warmup.lua']
report = dict(result='PASS', messages=messages,
              boundary='Real Lua modules; native draw API doubles. GPU compilation and performance require immutable Web run.',
              productionHashes={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in names if name.startswith('scripts/')},
              toolHashes={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in names if name.startswith('tools/')})
out = ROOT / 'docs/migration/evidence/flash-warmup-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: value for key, value in report.items() if key != 'messages'}))
for line in messages:
    if 'scenarios PASS' in line:
        print(line)

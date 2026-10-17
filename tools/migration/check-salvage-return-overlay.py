"""Actual DebugPanel HitTest and SourceModal/DialogHost lifecycle with UI host adapters."""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

probe = (root / 'tools/migration/probe-outgame-web.lua').read_text(encoding='utf-8')
source = probe.split('-- QA_OVERLAY_SNAPSHOT_BEGIN\n', 1)[1].split('-- QA_OVERLAY_SNAPSHOT_END', 1)[0]
paths = ['scripts/ui/DebugPanel.lua', 'scripts/ui/SourceModal.lua', 'scripts/ui/OwnedModal.lua',
         'scripts/ui/DialogHost.lua', 'tools/migration/probe-outgame-web.lua']
hashes = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().overlaySnapshotSource = source
lua.globals().fullProbeSource = probe
lua.execute('local fn,err=load(fullProbeSource);assert(fn,err)')
checks = lua.execute((root / 'tools/migration/check-salvage-return-overlay.lua').read_text(encoding='utf-8'))
assert hashes == {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
report = {'result': 'PASS', 'runtime': lua.lua_implementation, 'hashes': hashes,
          'checks': [checks[i] for i in range(1, len(checks) + 1)],
          'boundary': 'Actual production DebugPanel HitTest and SourceModal/DialogHost open/close/dispose methods and actual QA snapshot function. Widget/native draw services adapted. No browser, Native/GPU or actual public click acceptance.'}
out = root / 'docs/migration/evidence/salvage-return-overlay-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(report['checks']), 'evidence': str(out)}))

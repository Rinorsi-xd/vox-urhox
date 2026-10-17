"""Compare exact baseline/candidate range outputs using deterministic fake geometry."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

subprocess.run(['node', str(ROOT / 'tools/migration/g1-web-cpu-occids-candidate.cjs')], check=True)
identity = json.loads((ROOT / '.tmp/outgame-cached-1792169432758/identity.json').read_text(encoding='utf-8'))
baseline = (Path(identity['source_directory']) / 'scripts/construction/TurretRange.lua').read_text(encoding='utf-8')
candidate = (ROOT / '.tmp/g1-web-cpu-occids-candidate/TurretRange.lua').read_text(encoding='utf-8')
lua = LuaRuntime(unpack_returned_tuples=True)
result = lua.execute((ROOT / 'tools/migration/g1-web-cpu-occids-selftest.lua').read_text(encoding='utf-8'), baseline, candidate)
print(json.dumps(dict(result.items()), ensure_ascii=True))

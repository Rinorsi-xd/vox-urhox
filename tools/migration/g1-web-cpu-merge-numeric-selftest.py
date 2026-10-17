"""Validate the isolated numeric-index candidate against the complete real module."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

subprocess.run(['node', str(ROOT / 'tools/migration/g1-web-cpu-merge-numeric-prepare.cjs')], check=True)
identity = json.loads((ROOT / '.tmp/outgame-cached-1792171171463/identity.json').read_text(encoding='utf-8'))
source = Path(identity['source_directory']) / 'scripts/drive/VehicleSpec.lua'
variant = ROOT / '.tmp/g1-web-cpu-merge-numeric-candidate/VehicleSpec.lua'
lua = LuaRuntime(unpack_returned_tuples=True)
result = lua.execute((ROOT / 'tools/migration/g1-web-cpu-merge-numeric-selftest.lua').read_text(encoding='utf-8'),
                     source.read_text(encoding='utf-8'), variant.read_text(encoding='utf-8'))
record = {key: value for key, value in result.items()}
assert record['status'] == 'PASS' and record['comparisons'] >= 240
output = ROOT / 'docs/migration/evidence/g1-web-cpu-merge-numeric-offline.json'
output.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(json.dumps(record))

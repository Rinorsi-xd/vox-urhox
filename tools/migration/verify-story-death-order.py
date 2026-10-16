"""Frozen enemy death/flee order versus actual Lua mission and rule chain."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source = json.loads(subprocess.check_output(['node', 'tools/migration/story-death-order-source.mjs'], text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)

def convert(value):
    if isinstance(value, dict): return lua.table_from({k: convert(v) for k, v in value.items() if v is not None})
    if isinstance(value, list): return lua.table_from([convert(v) for v in value])
    return value

lua.globals().SOURCE = convert(source)
old_path = ROOT / '.tmp/outgame-cached-1792092083711/scripts/story/Mission.lua'
old = old_path.read_text(encoding='utf-8')
old_sha = hashlib.sha256(old.encode('utf-8')).hexdigest()
assert old_sha == '448c2965ef3e354068cce1ee007e1c40d3b0ecc9f4896a719d512fac77581849', 'Old control must match actual immutable 0bcd Mission.lua'
lua.globals().OLD_MISSION = old
result = dict(lua.execute((ROOT / 'tools/migration/check-story-death-order.lua').read_text(encoding='utf-8')))
result['source'] = source['source']
result['oldProductionSha256'] = old_sha
result['production'] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [
    'scripts/story/Mission.lua', 'scripts/story/MissionRules.lua']}
result['releaseBoundary'] = 'Next batch only; not included in immutable manifest-0bcd53d6.json.'
output = ROOT / 'docs/migration/evidence/story-death-order-offline.json'
output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))

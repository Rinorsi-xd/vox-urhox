"""Actual frozen StoryHud methods/CSS versus production MissionObjective and wiring."""
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

source = json.loads(subprocess.check_output(
    ['node', '--experimental-vm-modules', 'tools/migration/story-objective-source.mjs'], text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)


def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value


lua.globals().SOURCE = convert(source)
result = dict(lua.execute((ROOT / 'tools/migration/check-story-objective.lua').read_text(encoding='utf-8')))
result['source'] = source['source']
result['production'] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [
    'scripts/ui/MissionObjective.lua', 'scripts/ui/MissionHud.lua', 'scripts/story/Mission.lua', 'scripts/story/MissionRules.lua']}
output = ROOT / 'docs/migration/evidence/story-objective-offline.json'
output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))

"""Frozen StoryHud choice/pick/cancel methods versus actual production state/events."""
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
source = json.loads(subprocess.check_output(['node', '--experimental-vm-modules', 'tools/migration/story-choice-presentation-source.mjs'], text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
def convert(value):
    if isinstance(value, dict): return lua.table_from({k: convert(v) for k, v in value.items()})
    if isinstance(value, list): return lua.table_from([convert(v) for v in value])
    return value
lua.globals().SOURCE = convert(source)
result = dict(lua.execute((ROOT / 'tools/migration/check-story-choice-presentation.lua').read_text(encoding='utf-8')))
result['source'] = source['source']
result['production'] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [
    'scripts/ui/MissionChoiceState.lua', 'scripts/ui/MissionChoice.lua', 'scripts/story/Mission.lua', 'scripts/story/MissionRules.lua', 'scripts/ui/SourceButtonMotion.lua']}
output = ROOT / 'docs/migration/evidence/story-choice-presentation-offline.json'
output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))

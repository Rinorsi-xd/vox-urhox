"""Exercise the actual old-Web audio fallback without a native decoder."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
lua = LuaRuntime(unpack_returned_tuples=True)
result = dict(lua.execute((ROOT / 'tools/migration/check-story-comms-fallback.lua').read_text(encoding='utf-8')))
previous = ROOT / '.tmp/outgame-cached-1792123715225/scripts/audio/StoryComms.lua'
negative = LuaRuntime(unpack_returned_tuples=True)
negative.globals().TEST_CODE = previous.read_text(encoding='utf-8')
try:
    negative.execute((ROOT / 'tools/migration/check-story-comms-fallback.lua').read_text(encoding='utf-8'))
except Exception as error:
    assert 'download completion never queries Sound cache' in str(error), str(error)
    result['negativeControl'] = '6a actual callback cache reentry reproduced'
else:
    raise AssertionError('Previous actual production must fail callback isolation')
result['production'] = {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() for relative in
                        ['scripts/audio/StoryComms.lua', 'scripts/app/ResourceGate.lua']}
result['testInputs'] = {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() for relative in
                       ['tools/migration/verify-story-comms-fallback.py',
                        'tools/migration/check-story-comms-fallback.lua']}
output = ROOT / 'docs/migration/evidence/story-comms-fallback-offline.json'
output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))

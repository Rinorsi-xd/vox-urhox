"""Compare shipping rendering modules with the exact frozen pre-change build."""
import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference = ROOT / '.tmp/outgame-cached-1792066874405/scripts/render'
for name, expected in {
    'EffectBatch.lua': 'de97c5a7de1ef8a2a61a5ce45c120be0471639ba2e9604d943f134bd730236c4',
    'JoinedMesh.lua': '49c5269c641b1d11d69bde3981d230be62554cb3ada8fb981e24d72b10d0aedc',
}.items():
    assert hashlib.sha256((reference / name).read_bytes()).hexdigest() == expected

lua = LuaRuntime()


def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return False if value is None else value


resources = {name: json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8'))
             for name in ('Parts/Catalog.json', 'Parts/JoinedShapes.json')}
lua.execute((ROOT / 'tools/migration/check-render-destruction-cost.lua').read_text(encoding='utf-8'),
            convert({'baseline': reference.as_posix(), 'resources': resources}))

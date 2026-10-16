"""Execute frozen JS result production methods and the real Lua result renderer."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def main():
    os.chdir(ROOT)
    source = json.loads(subprocess.check_output(
        ['node', '--experimental-vm-modules', 'tools/migration/story-result-rows-source.mjs'], text=True, encoding='utf-8'))
    levels = [json.loads((ROOT / f'assets/Story/Mission/Level{i}.json').read_text(encoding='utf-8'))['level'] for i in range(1, 6)]
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value

    lua.globals().SOURCE = convert(source)
    lua.globals().LEVELS = convert(levels)
    result = dict(lua.execute((ROOT / 'tools/migration/check-story-result-rows.lua').read_text(encoding='utf-8')))
    result['source'] = source['source']
    result['production'] = {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() for relative in
                            ['scripts/story/MissionResultRows.lua', 'scripts/ui/MissionResult.lua', 'scripts/ui/ActionButton.lua']}
    output = ROOT / 'docs/migration/evidence/story-result-rows-offline.json'
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()

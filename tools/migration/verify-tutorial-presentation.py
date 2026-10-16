"""Exercise authored tutorial text selection, routes and suspension in Lua 5.4."""
import hashlib
import json
import os
import sys
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def main():
    os.chdir(ROOT)
    data = json.loads((ROOT / 'assets/UI/Tutorial.json').read_text(encoding='utf-8-sig'))
    baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8-sig'))
    assert data['source']['commit'] == baseline['commit'], 'Tutorial was imported from a different baseline'
    for relative, digest in data['source']['presentation'].items():
        assert hashlib.sha256((Path(baseline['snapshot']) / relative).read_bytes()).hexdigest() == digest
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value

    lua.globals().TEST_DATA = convert(data)
    subprocess.run(['node', 'tools/migration/check-ui-sounds-source.cjs'], check=True)
    sounds_source = json.loads((ROOT / '.tmp/ui-sounds-source.json').read_text(encoding='utf-8'))
    lua.globals().TEST_SOURCE = convert(sounds_source)
    result = dict(lua.execute((ROOT / 'tools/migration/check-tutorial-presentation.lua').read_text(encoding='utf-8')))
    result['source'] = data['source']
    result['soundSource'] = sounds_source
    result['production'] = {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
                            for relative in ['scripts/story/Tutorial.lua', 'scripts/story/TutorialRules.lua',
                                             'scripts/ui/TutorialPage.lua', 'assets/UI/Tutorial.json']}
    output = ROOT / 'docs/migration/evidence/tutorial-presentation-offline.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()

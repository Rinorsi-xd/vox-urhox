"""Run actual frozen H5 inputs against Lua consumers, with immutable old negatives."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def sha(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def run(fixtures, session, controls):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value

    def plain(value):
        if hasattr(value, 'items'):
            keys = list(value.keys())
            if all(isinstance(k, int) for k in keys):
                return [plain(value[i]) for i in sorted(keys)]
            return {k: plain(v) for k, v in value.items()}
        return value

    lua.globals().READ_RESOURCE = lambda name: convert(json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8-sig')))
    lua.globals().JSON = lambda value: json.dumps(plain(value), sort_keys=True, separators=(',', ':'))
    lua.globals().INPUT_SESSION_MODULE = session
    lua.globals().INPUT_CONTROLS_MODULE = controls
    lua.globals().fixtures = convert(fixtures)
    lua.execute('cjson={null={}}')
    return plain(lua.execute((ROOT / 'tools/migration/check-build-input-consumer.lua').read_text(encoding='utf-8')))


def main():
    started = datetime.now(timezone.utc)
    subprocess.run(['node', 'tools/migration/check-build-input-source.mjs'], check=True)
    fixtures = json.loads((ROOT / '.tmp/build-input-source.json').read_text(encoding='utf-8'))
    assert fixtures['commit'] == 'b276064942ae09c0227ec28d4cfda1d5ff006455'
    paths = ['scripts/app/BuildSession.lua', 'scripts/controls/BuildInput.lua']
    old = ['.tmp/outgame-cached-1792140646894/' + p for p in paths]
    assert [sha(p) for p in old] == [
        '6785af3845dd2d6829db30392a67b487b4c1715cbc482663e8d52e7ba1f95b80',
        '5d7232c61f9ecf12624a0a8a8c0a3b122a1494243ed13e46deacd51dde87a66d']
    production = paths + ['scripts/construction/' + n + '.lua' for n in ['BuildEditor', 'BuildStretch', 'Blueprint', 'EditHistory', 'BuildGroups', 'SelectionTools']] + ['scripts/controls/Wheel.lua']
    before = {p: sha(p) for p in production}
    current = run(fixtures, *paths)
    if not current['passed']:
        print(json.dumps(current, indent=2), flush=True)
        raise AssertionError('Actual input consumer differs from frozen source')
    negatives = {}
    for name, modules, prefix in [
        ('old-session', [old[0], paths[1]], 'wheel'),
        ('old-controls', [paths[0], old[1]], 'pointer')]:
        result = run(fixtures, *modules)
        assert not result['passed'] and any(v.startswith(prefix) for v in result['failures']), name
        if name == 'old-session':
            assert any(v.startswith('stretch cancel') for v in result['failures']), 'Old undo bug not detected'
        negatives[name] = result
    assert before == {p: sha(p) for p in production}, 'Production changed during verification'
    report = {'result': 'PASS', **current, 'sourceCommit': fixtures['commit'],
              'sourceHashes': fixtures['sourceHashes'], 'sourceCases': {k: len(fixtures[k]) for k in ['wheels', 'keys', 'pointers']},
              'negativeControls': negatives, 'productionHashes': before,
              'testInputs': {p: sha(p) for p in ['tools/migration/check-build-input-source.mjs', 'tools/migration/check-build-input-consumer.lua', 'tools/migration/verify-build-input-consumer.py']},
              'started': started.isoformat(),
              'scope': 'Actual H5 wheel/keys/pointer methods and Lua BuildSession/BuildInput/BuildEditor/history; renderer/platform input adapted. CPU only, no Web, native, mobile, visuals or performance acceptance.'}
    evidence = ROOT / 'docs/migration/evidence'
    folder = evidence / ('build-input-consumer-' + started.strftime('%Y-%m-%dT%H-%M-%S-%fZ'))
    folder.mkdir(parents=True)
    for dest in [folder / 'report.json', evidence / 'build-input-consumer-offline.json']:
        dest.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()

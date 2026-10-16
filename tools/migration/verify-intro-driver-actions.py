"""Verify the opening consumes the original recovery and salvo AI outputs."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def main():
    os.chdir(ROOT)
    baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8-sig'))
    relative = 'three/src/intro/intro.js'
    source = Path(baseline['snapshot']) / relative
    source_bytes = source.read_bytes()
    digest = hashlib.sha256(source_bytes).hexdigest()
    assert digest == baseline['files'][relative]['sha256'], 'Frozen intro source changed'
    text = source_bytes.decode('utf-8')
    for required in ['if ( c.reset ) u.vehicle.place( c.reset.pos, c.reset.yaw );',
                     'if ( c.flip ) u.vehicle.flip();', 'salvo: c.salvo']:
        assert required in text, 'Source recovery/fire contract missing: ' + required
    lua = LuaRuntime(unpack_returned_tuples=True)
    result = dict(lua.execute((ROOT / 'tools/migration/check-intro-driver-actions.lua').read_text(encoding='utf-8')))
    result['source'] = {'branch': baseline['branch'], 'commit': baseline['commit'], 'path': relative, 'sha256': digest}
    result['production'] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                            for name in ['scripts/intro/IntroBattle.lua', 'scripts/combat/DriverActions.lua']}
    output = ROOT / 'docs/migration/evidence/intro-driver-actions-offline.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()

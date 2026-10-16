"""Run actual Lua Body regression and strict-zero point-velocity comparison."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def plain(value):
    if hasattr(value, 'items'):
        items = dict(value.items())
        if items and all(isinstance(key, int) for key in items):
            return [plain(items[index]) for index in range(1, len(items) + 1)]
        return {key: plain(item) for key, item in items.items()}
    return value


def main():
    os.chdir(ROOT)
    lua = LuaRuntime(unpack_returned_tuples=True)
    previous = ROOT / '.tmp/outgame-cached-1792063134142'
    frozen = ROOT / '.tmp/outgame-cached-1792105799832'
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    assert sha(frozen / 'scripts/physics/Body.lua') == 'b5f5e01b0a4f0bfa107ab04f2f334aa60017044dbebb7656aa47cc8240ddc54a', '989c baseline identity changed'
    lua.globals().NAV_BEFORE_ROOT = previous.as_posix()
    regression = plain(lua.execute((ROOT / 'tools/migration/check-body-cache-offline.lua').read_text(encoding='utf-8')))
    lua.globals().BODY_POINT_BEFORE_ROOT = frozen.as_posix()
    focused = plain(lua.execute((ROOT / 'tools/migration/check-body-point-velocity.lua').read_text(encoding='utf-8')))
    result = {
        'result': 'PASSED', 'lua': lua.eval('_VERSION'),
        'candidateStage': 'after frozen manifest-989c7ba6; not included in its Web evidence',
        'production': {'scripts/physics/Body.lua': sha(ROOT / 'scripts/physics/Body.lua')},
        'baseline989c': {'root': str(frozen), 'bodySha256': sha(frozen / 'scripts/physics/Body.lua')},
        'bodyCacheRegressionBaseline': str(previous),
        'bodyCacheRegression': regression, 'pointVelocity': focused,
    }
    output = ROOT / 'docs/migration/evidence/body-point-velocity-offline.json'
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({
        'result': result['result'], 'lua': result['lua'], 'candidateStage': result['candidateStage'],
        'bodyCacheAssertions': regression['assertions'], 'suspensionCases': len(regression['suspensionCases']),
        'pointVelocityAssertions': focused['assertions'], 'pointVelocityCases': len(focused['cases']),
        'production': result['production'], 'baseline989c': result['baseline989c'], 'output': str(output),
    }, indent=2))


if __name__ == '__main__':
    main()

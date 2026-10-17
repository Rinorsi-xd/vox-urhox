"""Exercise the complete controller's cached target-module boundary in Lua 5.4."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--snapshot', type=Path, default=ROOT)
args = parser.parse_args()
base = args.snapshot.resolve()
relative = 'scripts/combat/BattleController.lua'
path = base / relative
before_bytes = path.read_bytes()
source = path.read_text(encoding='utf8')
digest = lambda data: hashlib.sha256(data).hexdigest()
lua = LuaRuntime(unpack_returned_tuples=True)
run = lua.eval(r'''function(source)
    local calls, imports, checks = {}, {}, 0
    local context, entry = {}, {}
    local result, secondary = {}, false
    local expectedResult, expectedSecondary = result, secondary
    local target = {}
    function target.Pick(...)
        assert(select('#', ...) == 2, 'Target.Pick arity')
        local self, item = ...
        assert(self == context and item == entry, 'Target.Pick identity/arguments')
        calls[#calls + 1] = {self, item}
        return result, secondary, nil, 'tail'
    end
    local unrelated = setmetatable({}, {__index=function(_, key)
        error('Unrelated dependency touched: '..tostring(key))
    end})
    local loading = true
    local env = setmetatable({require=function(name)
        assert(loading, 'Hot path attempted require: '..name)
        imports[name] = (imports[name] or 0) + 1
        return name == 'combat.MatchTarget' and target or unrelated
    end}, {__index=_G})
    local controller = assert(load(source, '@BattleController.lua', 't', env))()
    loading = false
    assert(type(controller) == 'table' and type(controller.Pick) == 'function', 'Real controller export')
    assert(imports['combat.MatchTarget'] == 1, 'One module lookup during loading')
    local function check(value, message) assert(value, message); checks = checks + 1 end
    for iteration = 1, 4 do
        local a, b, c, d = controller.Pick(context, entry)
        check(a == expectedResult and b == expectedSecondary and c == nil and d == 'tail', 'All return values preserved')
        check(#calls == iteration, 'Exactly one target selection per call')
        context, entry = {}, {}
        if iteration % 2 == 0 then result = false else result = nil end
        secondary = {iteration=iteration}
        expectedResult, expectedSecondary = result, secondary
    end
    -- Cached module tables must still observe method replacement (hot reload).
    local replacement = {}
    target.Pick = function(self, item)
        assert(self == context and item == entry, 'Replacement arguments')
        return replacement
    end
    check(controller.Pick(context, entry) == replacement, 'Cached table reads current Pick method')
    return checks
end''')

checks = run(source)
needle = 'return MatchTarget.Pick(self,entry)'
assert source.count(needle) == 1, 'Mutation controls need the exact current delegate'
mutants = {
    'hot-require': "return require('combat.MatchTarget').Pick(self,entry)",
    'wrong-arguments': 'return MatchTarget.Pick(entry,self)',
    'dropped-tail-returns': 'local result=MatchTarget.Pick(self,entry);return result',
    'skipped-selection': 'return nil',
}
negative_controls = []
for name, replacement in mutants.items():
    try:
        run(source.replace(needle, replacement, 1))
    except Exception as error:
        negative_controls.append({'name': name, 'rejected': True, 'reason': str(error).splitlines()[0]})
    else:
        raise AssertionError('Contract accepted mutation: ' + name)
assert path.read_bytes() == before_bytes, 'Controller changed during validation'
report = {
    'result': 'PASS', 'snapshot': str(base), 'checks': checks,
    'runtime': lua.lua_implementation,
    'productionHashes': {relative: digest(path.read_bytes())},
    'toolSha256': digest(Path(__file__).read_bytes()),
    'negativeControls': negative_controls,
    'boundary': 'Complete real BattleController module loaded with strict unrelated dependency sentinels. Actual Pick called repeatedly with identity checks, nil/false/tail returns, cached-table method replacement and no post-load require. Does not exercise whole BeforeStep, physics, rendered match or performance.'
}
output = ROOT / 'docs/migration/evidence/battle-target-delegation-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
print(json.dumps({'result': report['result'], 'checks': checks, 'negativeControls': len(negative_controls), 'evidence': str(output)}))

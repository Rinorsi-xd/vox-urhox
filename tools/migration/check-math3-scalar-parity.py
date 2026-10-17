"""Check exact Lua 5.4 arithmetic parity; this is not a performance benchmark."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

SUITE = r'''
local old = assert(load(MATH_BASELINE, 'baseline-Math3'))()
local new = assert(load(MATH_CANDIDATE, 'candidate-Math3'))()
local counts = {calls=0, components=0, nan=0, negativeZero=0, integer=0, negatives=0}
local function numberEqual(a,b)
    if math.type(a) ~= math.type(b) then return false end
    if a ~= a or b ~= b then return a ~= a and b ~= b end
    return string.pack('d',a) == string.pack('d',b)
end
local function vectorEqual(a,b)
    for i=1,3 do if not numberEqual(a[i],b[i]) then return false end end
    return true
end
local function copy(a)
    local result={};for k,v in pairs(a) do result[k]=v end;return result
end
local function unchanged(a,b)
    for k,v in pairs(a) do assert(numberEqual(v,b[k]),'input mutation: '..tostring(k)) end
    for k in pairs(b) do assert(a[k]~=nil,'input shape mutation') end
end
local function check(name,a,b,t)
    local savedA,savedB=copy(a),copy(b)
    local expected=old[name](a,b,t)
    local actual=new[name](a,b,t)
    assert(vectorEqual(expected,actual),name..' arithmetic mismatch')
    unchanged(savedA,a);unchanged(savedB,b)
    assert(actual~=a and actual~=b,'must return fresh vector')
    counts.calls=counts.calls+1
    for i=1,3 do
        local value=expected[i];counts.components=counts.components+1
        if value~=value then counts.nan=counts.nan+1 end
        if value==0 and 1/value==-math.huge then counts.negativeZero=counts.negativeZero+1 end
        if math.type(value)=='integer' then counts.integer=counts.integer+1 end
    end
end
local special={0.0,-0.0,1.0,-1.0,2.0,-2.0,1e-300,-1e-300,
    1e300,-1e300,2^-1074,-2^-1074,2^-1022,-2^-1022,
    2^53,-2^53,math.huge,-math.huge,0/0}
for i,a in ipairs(special) do
    for j,b in ipairs(special) do
        local c=special[(i+j-1)%#special+1]
        for _,t in ipairs({0.0,-0.0,1.0,-1.0,0.5,1.5}) do
            check('Mix',{a,b,c},{b,c,a},t)
        end
        check('Reject',{a,b,c},{b,c,a})
        check('Unrotate',{x=a,y=b,z=c,w=special[(i*3+j-1)%#special+1]},{b,c,a})
    end
end
local integers={0,1,-1,2,-2,17,-31,math.maxinteger,math.mininteger}
for _,a in ipairs(integers) do
    for _,b in ipairs(integers) do
        check('Mix',{a,b,a},{b,a,b},b)
        check('Reject',{a,b,a},{b,a,b})
        check('Unrotate',{x=a,y=b,z=a,w=b},{a,b,a})
    end
end
math.randomseed(151017,1016)
local function randomValue()
    local mantissa=math.random()*2-1
    return mantissa*2^math.random(-490,490)
end
for case=1,12000 do
    local a={randomValue(),randomValue(),randomValue()}
    local b={randomValue(),randomValue(),randomValue()}
    check('Mix',a,b,case%7==0 and -1.5 or math.random()*3-1)
    check('Reject',a,b)
    local q={x=randomValue(),y=randomValue(),z=randomValue(),w=randomValue()}
    if case%5==0 then q={x=0.0,y=-0.0,z=0.0,w=0.0}
    elseif case%7==0 then q={x=0.0,y=0.0,z=0.0,w=1.0}
    elseif case%11==0 then q={x=1.0,y=-2.0,z=3.0,w=-4.0} end
    check('Unrotate',q,a)
end
local function negative(expected,actual,label)
    assert(not vectorEqual(expected,actual),'negative not detected: '..label)
    counts.negatives=counts.negatives+1
end
negative(old.Mix({1e16,1,2},{1,2,3},1),{1,2,3},'weighted Mix loses cancellation')
negative(old.Reject({1,1,1},{1e16,-1e16,1}),
    {1-1e16*(1e16+(-1e16+1)),1+1e16*(1e16+(-1e16+1)),1-(1e16+(-1e16+1))},
    'reassociated dot')
negative(old.Unrotate({x=0,y=0,z=0,w=2},{1,2,3}),{1,2,3},'normalizing nonunit quaternion')
negative(old.Unrotate({x=0,y=0,z=0,w=0},{1,2,3}),{1,2,3},'unit Rotate shortcut')
negative({-0.0,1.0,2.0},{0.0,1.0,2.0},'signed zero lost')
assert(counts.negativeZero>0 and counts.integer>0 and counts.nan>0,'boundary coverage missing')
return counts
'''


def main():
    evidence = ROOT / 'docs/migration/evidence/native-vehicle-allocation-2026-10-17'
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline', type=Path, default=evidence / 'before/Math3.lua')
    parser.add_argument('--candidate', type=Path, default=evidence / 'math3-candidate.lua')
    parser.add_argument('--output', type=Path, default=evidence / 'math3-scalar-parity.json')
    args = parser.parse_args()
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().MATH_BASELINE = args.baseline.read_text(encoding='utf-8-sig')
    lua.globals().MATH_CANDIDATE = args.candidate.read_text(encoding='utf-8-sig')
    counts = dict(lua.execute(SUITE).items())
    result = {
        'status': 'PASS', 'runtime': str(lua.eval('_VERSION')),
        'baseline': str(args.baseline.resolve()),
        'baselineSha256': hashlib.sha256(args.baseline.read_bytes()).hexdigest(),
        'candidate': str(args.candidate.resolve()),
        'candidateSha256': hashlib.sha256(args.candidate.read_bytes()).hexdigest(),
        'counts': counts,
        'comparison': 'same Lua numeric type and double bits; NaN classification only',
        'boundary': 'pure arithmetic, no engine, timing, GC, rendering, hardware or FPS claim',
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()

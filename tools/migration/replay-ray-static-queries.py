"""Exact captured-query replay; optional normal-GC ABBA is local Lua CPU only."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

parser = argparse.ArgumentParser()
parser.add_argument('--capture', type=Path)
parser.add_argument('--self-test', action='store_true')
parser.add_argument('--benchmark', action='store_true')
parser.add_argument('--passes', type=int, default=32)
parser.add_argument('--candidate', type=Path, default=Path('.tmp/ray-static-bounds-4a3a-1017-b'))
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
assert bool(args.capture) != args.self_test
assert not (args.self_test and args.benchmark), 'Synthetic recorder test cannot benchmark'
assert 1 <= args.passes <= 1024
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;?.lua;'..package.path")


def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value


def plain(value):
    if not hasattr(value, 'items'):
        return value
    entries = list(value.items())
    if entries and all(isinstance(key, int) for key, _ in entries):
        return [plain(value[i]) for i in range(1, len(entries) + 1)]
    return {key: plain(item) for key, item in entries}


candidate_root = ROOT / args.candidate
identity = json.loads((candidate_root / 'identity.json').read_text(encoding='utf-8'))
sources = {name: (candidate_root / file).read_text(encoding='utf-8') for name, file in
           {'baseline': 'VehicleRay.baseline.lua', 'candidate': 'VehicleRay.candidate.lua'}.items()}
for key, source in sources.items():
    assert hashlib.sha256(source.encode()).hexdigest() == identity[key + 'Sha256']
lua.globals().SOURCES = convert(sources)
recorder_source = (ROOT / 'tools/migration/ray-static-query-recorder.lua').read_text(encoding='utf-8')
prepared_capture = ROOT / '.tmp/ray-static-query-capture-4a3a-1017-a'
if args.self_test and prepared_capture.exists():
    prepared_identity = json.loads((prepared_capture / 'identity.json').read_text(encoding='utf-8'))
    for relative, expected in prepared_identity['sourceHashes'].items():
        assert hashlib.sha256((prepared_capture / relative).read_bytes()).hexdigest() == expected
    lua.globals().CAPTURE_ENTRY_SOURCE = (prepared_capture / 'scripts/ray-static-query-capture.lua').read_text(encoding='utf-8')
    lua.execute('assert(load(CAPTURE_ENTRY_SOURCE))')
if args.self_test:
    lua.globals().RECORDER_SOURCE = recorder_source
    lua.globals().cjson = lua.table_from({'encode': lambda value: json.dumps(plain(value), sort_keys=True)})
    captured = lua.execute(r'''
local module=assert(load(SOURCES.baseline))()
local original=module.Cast
local units={}
for i=1,8 do
 local vehicle={spec={boxes={{center={0,0,0},half={1,1,1},partId=i}},hulls={},sensors={}},
  rotors=i%2==0 and {{}}or {},wheels={},legHitboxes={items={}},mechHitboxes={items={}},
  body={translation=function()return {x=0,y=0,z=0}end,rotation=function()return {x=0,y=0,z=0,w=1}end}}
 units[i]={vehicle=vehicle}
end
local recorder=assert(load(RECORDER_SOURCE))().New{units=units}
recorder:Install(module)
for _,unit in ipairs(units)do
 module.Cast(unit.vehicle,{0,0,-3},{0,0,1},10)
 module.Cast(unit.vehicle,{0,0,-3},{0,0,1},10)
end
recorder:Restore();assert(module.Cast==original)
local result=recorder:Report()
assert(result.vehicleCount==8 and #result.records==16 and result.cold==8 and result.warm==8)
assert(result.coldByRotor['0']==4 and result.coldByRotor['1']==4,'Actual rotor classification')
return result
''')
    capture = plain(captured)
    capture['collectorRunning'] = True
    capture_hash = None
else:
    raw = args.capture.read_bytes()
    capture_hash = hashlib.sha256(raw).hexdigest()
    capture = json.loads(raw)
    assert capture['status'] == 'ACTUAL_RAY_QUERY_CAPTURE_PASS'
    assert capture['restored'] is True and capture['collectorRunning'] is True
    assert capture['vehicleCount'] == 8 and capture['cold'] > 0 and capture['warm'] > 0
    assert capture['timingValidity'] == 'INVALID_QUERY_CAPTURE_OVERHEAD'
    capture_identity = json.loads((args.capture.parent / 'identity.json').read_text(encoding='utf-8'))
    assert capture_identity['queryCapture']['originalRaySha256'] == identity['baselineSha256']
lua.globals().CAPTURE = convert(capture)
setup = lua.execute(r'''
local function Bytes(hex)
 assert(type(hex)=='string'and #hex%2==0)
 return (hex:gsub('..',function(s)return string.char(assert(tonumber(s,16)))end))
end
local function Vec(hex)local x,y,z=string.unpack('<ddd',Bytes(hex));return {x,y,z}end
local function Quat(hex)if not hex then return nil end;local x,y,z,w=string.unpack('<dddd',Bytes(hex));return {x=x,y=y,z=z,w=w}end
local function Shape(row)return {center=Vec(row[1]),half=Vec(row[2]),quat=Quat(row[3]),partId=row[4]or nil,rotor=row[5]or nil}end
local function Shapes(rows)local out={};for i,row in ipairs(rows)do out[i]=Shape(row)end;return out end
local function Bounds(row)return row and {center=Vec(row[1]),half=Vec(row[2])}or nil end
local specs={}
for id,spec in ipairs(CAPTURE.specs)do specs[id]={boxes=Shapes(spec[1]),hulls=Shapes(spec[2]),sensors=Shapes(spec[3])}end
local rotorLists={};local records={};local coldByRotor={};local cold,warm=0,0
for i,row in ipairs(CAPTURE.records)do
 local wheels={}
 for j,w in ipairs(row.wheels)do
  local drop,radius,width=string.unpack('<ddd',Bytes(w[5]))
  wheels[j]={center=Vec(w[1]),conn=Vec(w[2]),down=w[3]and Vec(w[3])or nil,axle=Vec(w[4]),
   drop=drop,radius=radius,width=width,track=w[6],partId=w[7]or nil}
 end
 if not rotorLists[row.rotors]then local out={};for n=1,row.rotors do out[n]={}end;rotorLists[row.rotors]=out end
 local p=Vec(row.p);local expected=row.expected and {dist=(string.unpack('<d',Bytes(row.expected[1]))),normal=Vec(row.expected[2]),
  partId=row.expected[3]or nil,point=Vec(row.expected[4])}or false
 if expected then assert(row.expected[5],'Original hit body identity')end
 records[i]={vehicle=row.vehicle,spec=specs[row.spec],rotors=rotorLists[row.rotors],rotorCount=row.rotors,
  p={x=p[1],y=p[2],z=p[3]},q=Quat(row.q),wheels=wheels,legs=Shapes(row.legs),mech=Shapes(row.mech),
  origin=Vec(row.origin),direction=Vec(row.direction),length=(string.unpack('<d',Bytes(row.length))),
  preBounds=Bounds(row.preBounds),postBounds=Bounds(row.postBounds),expected=expected}
 if row.preBounds then warm=warm+1 else cold=cold+1;local key=tostring(row.rotors);coldByRotor[key]=(coldByRotor[key]or 0)+1 end
end
assert(cold==CAPTURE.cold and warm==CAPTURE.warm)
for key,count in pairs(coldByRotor)do assert(count==CAPTURE.coldByRotor[key])end
local function Units()
 local units={}
 for i=1,8 do
  local vehicle={}
  vehicle.body={translation=function()return vehicle.active.p end,rotation=function()return vehicle.active.q end}
  units[i]=vehicle
 end
 return units
end
local modules={A=assert(load(SOURCES.baseline))(),B=assert(load(SOURCES.candidate))()}
local units={A=Units(),B=Units()};local checks=0
local function Eq(a,b,label)
 checks=checks+1;assert(type(a)==type(b),label..' type')
 if type(a)=='number'then assert(string.pack('<d',a)==string.pack('<d',b),label..' bits')
 elseif type(a)=='table'then
  for k,v in pairs(a)do Eq(v,b[k],label..'.'..tostring(k))end
  for k in pairs(b)do assert(a[k]~=nil,label..' extra')end
 else assert(a==b,label..' value')end
end
local function Apply(vehicle,row)
 vehicle.active=row;vehicle.spec=row.spec;vehicle.rotors=row.rotors;vehicle.wheels=row.wheels
 vehicle.legHitboxes={items=row.legs};vehicle.mechHitboxes={items=row.mech};vehicle.rayBounds=row.preBounds
end
local function Validate(variant)
 local count,hits,sum=0,0,0
 for i,row in ipairs(records)do
  local vehicle=units[variant][row.vehicle];Apply(vehicle,row)
  local hit=modules[variant].Cast(vehicle,row.origin,row.direction,row.length)
  if hit then assert(hit.body==vehicle.body);hit.body=nil;hits=hits+1;sum=sum+hit.dist end
  Eq(hit or false,row.expected,variant..'.query'..i)
  Eq(vehicle.rayBounds,row.postBounds,variant..'.bounds'..i);count=count+1
 end
 return {queries=count,hits=hits,sum=sum,checks=checks}
end
local oldRandom=math.random;local randomCalls=0
math.random=function(...)randomCalls=randomCalls+1;return oldRandom(...)end
function RAY_REPLAY_RESTORE()math.random=oldRandom;assert(randomCalls==0,'Ray replay must not consume RNG')end
function RAY_REPLAY_BENCH(variant,passes)
 assert(collectgarbage('isrunning'),'Normal GC required')
 local hitCount,sum=0,0
 for _=1,passes do for _,row in ipairs(records)do
  local vehicle=units[variant][row.vehicle];Apply(vehicle,row)
  local hit=modules[variant].Cast(vehicle,row.origin,row.direction,row.length)
  if hit then hitCount=hitCount+1;sum=sum+hit.dist end
 end end
 assert(collectgarbage('isrunning'));assert(randomCalls==0)
 return {queries=#records*passes,hits=hitCount,sum=sum}
end
function RAY_REPLAY_VALIDATE()return {baseline=Validate('A'),candidate=Validate('B'),checks=checks}end
local verification=RAY_REPLAY_VALIDATE()
return {verification=verification,queries=#records,cold=cold,warm=warm,specs=#specs,coldByRotor=coldByRotor}
''')
result = {'status': 'RECORDED_QUERY_REPLAY_PASS', 'captureIsSynthetic': args.self_test,
          'captureSha256': capture_hash, 'sourceIdentity': identity, 'setup': plain(setup),
          'benchmark': None}
try:
    if args.benchmark:
        run = lua.globals().RAY_REPLAY_BENCH
        run('A', 4)
        run('B', 4)
        blocks = []
        for variant in ('A', 'B', 'B', 'A'):
            started = time.perf_counter()
            workload = plain(run(variant, args.passes))
            elapsed = time.perf_counter() - started
            blocks.append({'variant': variant, 'elapsedSeconds': elapsed, 'workload': workload})
        assert all(block['workload'] == blocks[0]['workload'] for block in blocks), 'Identical actual query workload'
        result['benchmark'] = {'kind': 'LOCAL_LUA54_NORMAL_GC_ABBA', 'passes': args.passes, 'blocks': blocks,
                               'modeUntouched': True, 'automaticGC': True}
        result['postBenchmarkValidation'] = plain(lua.globals().RAY_REPLAY_VALIDATE())
finally:
    lua.globals().RAY_REPLAY_RESTORE()
result['boundary'] = ('Exact IEEE754 actual-record input/output replay when captureIsSynthetic=false. Same process, identical queries and authored '
                      'shape/body snapshots with normal automatic GC. Native body getters are replay closures, not engine calls. Apply also allocates two '
                      'small dynamic containers equally in both variants. Optional ABBA measures this local Lua ray task only, without AI/physics stepping, '
                      'rendering/audio/UI, and cannot establish full-game Web or Snapdragon845 FPS. Synthetic recorder self-test cannot benchmark.')
with args.output.open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))

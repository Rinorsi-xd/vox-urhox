"""Compare actual frozen JS and production Lua track transforms without a GPU."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

fixture = json.loads(subprocess.check_output(
    ['node', str(ROOT / 'tools/migration/source-track-spin-fixtures.mjs')], cwd=ROOT, text=True))
before_path = ROOT / '.tmp/outgame-cached-1792110839635/scripts/render/PartRig.lua'
current_path = ROOT / 'scripts/render/PartRig.lua'
before_text = before_path.read_text(encoding='utf-8-sig')
current_text = current_path.read_text(encoding='utf-8-sig')
drive_text = (ROOT / 'scripts/render/DriveView.lua').read_text(encoding='utf-8-sig')
bind_text = 'function M:Bind' + drive_text.split('function M:Bind')[1].split('function M:ResetPose')[0]
track_update = next(line.strip() for line in drive_text.splitlines() if 'for _,t in ipairs(self.tracks) do Rig.SetTrack' in line)
assert before_text.split('function M.SetWheel')[1] == current_text.split('function M.SetWheel')[1]
adapter = r'''
local vector={};vector.__index=vector
vector.__add=function(a,b)return Vector3(a.x+b.x,a.y+b.y,a.z+b.z)end
vector.__sub=function(a,b)return Vector3(a.x-b.x,a.y-b.y,a.z-b.z)end
vector.__mul=function(a,b)return Vector3(a.x*b,a.y*b,a.z*b)end
Vector3=setmetatable({},{__call=function(_,x,y,z)return setmetatable({x=x,y=y,z=z},vector)end})
Vector3.UP=Vector3(0,1,0)
local rotation={};rotation.__index=rotation
rotation.__mul=function(a,b)return Vector3(
 a[1]*b.x+a[4]*b.y+a[7]*b.z,a[2]*b.x+a[5]*b.y+a[8]*b.z,a[3]*b.x+a[6]*b.y+a[9]*b.z)end
function Quaternion(a,b,c)
 if type(a)=='table' then return setmetatable({a.x,a.y,a.z,b.x,b.y,b.z,c.x,c.y,c.z},rotation)end
 local angle=a*math.pi/180;local co,si=math.cos(angle),math.sin(angle)
 local x,y,z=b.x,b.y,b.z;local t=1-co
 return setmetatable({t*x*x+co,t*x*y+si*z,t*x*z-si*y,
 t*x*y-si*z,t*y*y+co,t*y*z+si*x,t*x*z+si*y,t*y*z-si*x,t*z*z+co},rotation)
end
Vector4=setmetatable({ZERO={}},{__call=function()return {}end})
cjson={null={}}
local Node={};Node.__index=Node
function Node:CreateChild(name)local n=setmetatable({name=name,position=Vector3(0,0,0)},Node);return n end
function Node:CreateComponent()return {SetMaterial=function()end}end
function RootNode()return setmetatable({},Node)end
package.preload['core.Coord']=function()return {Vec=function(x,y,z)return Vector3(-x,y,z)end}end
package.preload['parts.Materials']=function()return {Get=function()end}end
package.preload['Config']=function()return {HexLinear=function()end}end
package.preload['render.WeaponPresentation']=function()return {}end
package.preload['parts.PartAssets']=function()return {Model=function()end}end
function MakeVis(rig)
 local vis={node=RootNode(),models={},resources={}}
 MODULE.Build(vis.node,rig,{type='track2',color=0},vis)
 return vis
end
function Matrix(node)
 local r=node.rotation;local p=node.position
 return {r[1],r[2],r[3],0,r[4],r[5],r[6],0,r[7],r[8],r[9],0,p.x,p.y,p.z,1}
end
'''


def convert(lua, value):
    if isinstance(value, dict):
        return lua.table_from({k: convert(lua, v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(lua, v) for v in value])
    return value


def mirror(matrix):
    signs = [-1, 1, 1, 1]
    return [v * signs[i % 4] * signs[i // 4] for i, v in enumerate(matrix)]


def array(table):
    return [table[i] for i in range(1, len(table) + 1)]


def compare(a, b):
    return max(abs(x-y) for x, y in zip(a, b))


def check(text):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(adapter)
    module = lua.execute(text)
    lua.globals().MODULE = module
    lua.globals().ROT = lua.execute((ROOT / 'scripts/core/Rotations.lua').read_text(encoding='utf-8-sig'))
    lua.globals().BIND_TEXT = bind_text
    lua.globals().TRACK_UPDATE = track_update
    lua.globals().CELL = fixture['CELL']
    lua.execute(r'''
local noop=function()return {}end
package.preload['render.RotorView']=function()return {New=noop}end
package.preload['render.MechView']=function()return {New=noop}end
local prefix=[[
local M={};local Rot=ROT;local Config={CELL=CELL};local Spec={};local Math={}
local Coord={RotQuat=function()return Quaternion(0,Vector3.UP)end}
local View={PartLocalPos=function(p)return Vector3(-p.x,p.y,p.z)end}
local Actuators={New=function()return {}end};local Legs=Actuators
]]
local binding=assert(load(prefix..BIND_TEXT..' return M'))()
local update=assert(load('local Rig=MODULE;local Config={CELL=CELL};return function(self) '..TRACK_UPDATE..' end'))()
function Rebind(vis,sign,travel)
 local ri
 for i,r in pairs(ROT.ROTATIONS)do
  if ROT.ApplyRot(i,{1,0,0})[3]==sign then ri=i;break end
 end
 assert(ri~=nil)
 local p={id=7,rot=ri,x=3,y=2,z=-1}
 local bp={List=function()return {p}end}
 local vehicle={wheels={{partId=7,track=true,drop=.15},{partId=7,track=true,drop=.15,['end']=true}},
  spec={},WheelTravel=function()return travel end}
 local self={view={visuals={[7]=vis}},equipment={Bind=function()end},ResetPose=function()end,Update=update}
 local oldRig=vis.rig;local oldNode=vis.node
 binding.Bind(self,bp,vehicle)
 assert(#self.tracks==1 and self.tracks[1].vis==vis and self.tracks[1].sign==sign)
 assert(vis.rig==oldRig and vis.node==oldNode)
 assert(vis.node.position.x==-3 and math.abs(vis.node.position.y-(2-.15/CELL))<1e-12 and vis.node.position.z==-1)
end
''')
    active = {}
    failed = []
    checks = {'wheelMatrices': 0, 'padMatrices': 0, 'spokePositions': 0, 'retainedRigSteps': 0, 'actualBindRebinds': 0}
    max_error = {'wheel': 0, 'pad': 0}
    pad_results = []
    for case in fixture['cases']:
        key = (case['type'], case['sign'])
        if key not in active:
            rig = json.loads((ROOT / f"assets/Parts/Rigs/{case['type']}.json").read_text(encoding='utf-8-sig'))
            active[key] = lua.globals().MakeVis(convert(lua, rig))
        vis = active[key]
        saved_rig = vis['rig']
        if case['retained']:
            lua.globals().Rebind(vis, case['sign'], case['travel'])
            checks['actualBindRebinds'] += 1
        else:
            module.SetTrack(vis, case['offset'])
        if case['retained']:
            assert lua.eval('function(a,b)return a==b end')(saved_rig, vis['rig'])
            checks['retainedRigSteps'] += 1
        for kind, expected in [('pads', case['pads']), ('wheels', case['wheels'])]:
            for i, target in enumerate(expected, 1):
                actual = array(lua.globals().Matrix(vis['rig'][kind][i]['node']))
                wanted = mirror(target)
                error = compare(actual, wanted)
                checks['padMatrices' if kind == 'pads' else 'wheelMatrices'] += 1
                max_error['pad' if kind == 'pads' else 'wheel'] = max(max_error['pad' if kind == 'pads' else 'wheel'], error)
                if kind == 'pads':
                    pad_results.append(actual)
                else:
                    # Off-axis spoke endpoints expose a reversed rotation even on a circular wheel.
                    for spoke in [(-.43, 0, .17), (.21, 0, .61)]:
                        transformed = lambda m: [sum(m[c*4+r]*spoke[c] for c in range(3))+m[12+r] for r in range(3)]
                        assert compare(transformed(actual), transformed(wanted)) <= error*2+1e-12
                        checks['spokePositions'] += 1
                if error > 1e-10:
                    failed.append({'type': case['type'], 'sign': case['sign'], 'step': case['step'], 'kind': kind, 'index': i, 'error': error})
    wheel_outputs = []
    for suspension, steer, roll in [(0, 0, 0), (.12, .27, 1.4), (-.08, -.36, -2.1)]:
        vis = convert(lua, {'data': {'wheel': {'hub': [.3, .2, -.1], 'kingpin': [.2, .1, -.1]}}, 'rig': {'steer': {}, 'spin': {}}})
        vis['rig']['spin']['position'] = lua.globals().Vector3(0, 0, 0)
        module.SetWheel(vis, convert(lua, [0, 1, 0]), suspension, steer, roll)
        wheel_outputs.append([array(lua.globals().Matrix(vis['rig'][k])) for k in ['steer', 'spin']])
    return {'failedMatrices': len(failed), 'failures': failed[:8], 'checks': checks, 'maxError': max_error}, pad_results, wheel_outputs


old, old_pads, old_wheels = check(before_text)
new, new_pads, new_wheels = check(current_text)
assert old_pads == new_pads
assert old_wheels == new_wheels
assert new['failedMatrices'] == 0 and old['failedMatrices'] > 0
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
report = {'result': 'PASS', 'sourceCommit': fixture['sourceCommit'], 'sourceHashes': fixture['hashes'],
          'production': {'scripts/render/PartRig.lua': digest(current_path)},
          'baseline': {'path': str(before_path.relative_to(ROOT)), 'sha256': digest(before_path)},
          'inputs': fixture['inputs'], 'cases': len(fixture['cases']), 'old': old, 'current': new,
          'integrationInputs': {p: digest(ROOT / p) for p in ['scripts/render/DriveView.lua', 'scripts/core/Rotations.lua']},
          'padsByteEquivalentOutputs': True, 'ordinaryWheelFunctionUnchanged': True,
          'ordinaryWheelOutputsUnchanged': True,
          'boundary': 'Offline actual source/Lua transforms; native renderer and visual acceptance not run.',
          'tools': {p: digest(ROOT / p) for p in ['tools/migration/verify-track-spin.py', 'tools/migration/source-track-spin-fixtures.mjs']}}
output = ROOT / 'docs/migration/evidence/track-spin-offline.json'
output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, indent=2))

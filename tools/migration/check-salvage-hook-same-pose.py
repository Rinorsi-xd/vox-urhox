"""Run the actual request-only Lua suffix under Lua 5.4; no game Runtime."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/lifecycle-python'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)


def plain(value):
    if hasattr(value, 'items'):
        items = dict(value.items())
        if items and set(items) == set(range(1, len(items) + 1)):
            return [plain(items[i]) for i in range(1, len(items) + 1)]
        return {str(k): plain(v) for k, v in items.items()}
    return value


messages = []
lua.globals().py_encode = lambda v: json.dumps(plain(v), ensure_ascii=False, separators=(',', ':'))
lua.globals().py_print = messages.append
lua.execute(r'''
print=py_print;cjson={encode=py_encode,decode=function()return {}end}
KEY_F7=7;KEY_F11=11
local key=0;input={GetKeyPress=function(_,wanted)return wanted==key end}
Vector3=function(x,y,z)return {x=x,y=y,z=z}end
local rotation={w=1,x=0,y=0,z=0}
Quaternion=function()return setmetatable({w=1,x=0,y=0,z=0},{__mul=function(a,b)return a end})end
rotation=Quaternion()
local function node()
 local n={enabled=true,worldPosition=Vector3(0,0,0),worldScale=Vector3(1,1,1),worldRotation=rotation,children={}}
 function n:LocalToWorld(v)return Vector3(v.x+self.worldPosition.x,v.y+self.worldPosition.y,v.z+self.worldPosition.z)end
 function n:WorldToLocal(v)return Vector3(v.x-self.worldPosition.x,v.y-self.worldPosition.y,v.z-self.worldPosition.z)end
 function n:GetChildren()return self.children end
 return n
end
local cameraNode=node();local camera={fov=48,nearClip=.1}
local frame=node();local holder=node();local data={models={}}
local view={nodes={frame=frame,holder=holder},hookMin=Vector3(-1,5.3,-.7),hookMax=Vector3(1,5.9,.7),hookHidden=false}
for i=0,31 do
 local n=node();local mesh={enabled=true,model={name='SalvageCine/model-'..i..'.bin'},node=n}
 function n:GetComponent()return mesh end
 function mesh:SetEnabled(v)self.enabled=v end
 frame.children[#frame.children+1]=n
 data.models[#data.models+1]={model=mesh.model.name,motion='frame'}
 if i==15 then view.hookMesh=mesh end
end
function view:GuardCamera(n,active)
 local p=n.worldPosition
 self.hookHidden=active and p.x>1 and p.x<2
 self.hookMesh:SetEnabled(not self.hookHidden)
 return self.hookHidden
end
local position=Vector3(1,2,3)
local body={translation=function()return position end,rotation=function()return {w=1,x=0,y=0,z=0}end}
local session={vehicle={body=body},world={space={world={updateEnabled=false}}},pointer={captured=true}}
session.camera={GetNode=function()return cameraNode end,GetCamera=function()return camera end}
session.salvage={landed=true,rules={time=10},cine={playing=false,view=view}}
local application={mode='trial',loadingFlow={active=false},trial=session}
package.preload['urhox-libs/UI']=function()return {GetViewportSize=function()return 1600,900 end,GetRoot=function()return nil end,GetTopOverlay=function()return nil end}end
package.preload['ui.GarageHud']=function()return {GetState=function()return {tab='salvage'}end}end
package.preload['core.ResourceData']=function()return {Read=function()return data end}end
originalUpdates=0;originalPosts=0
function HandleUpdate()originalUpdates=originalUpdates+1 end
function HandlePostUpdate()originalPosts=originalPosts+1 end
FIXTURE_APP=application
function Press(k)key=k;HandleUpdate();key=0 end
function Post()HandlePostUpdate()end
''')
probe = (root / 'tools/migration/probe-salvage-hook-same-pose.lua').read_text(encoding='utf-8')
lua.execute('local app=FIXTURE_APP\n' + probe)
press, post = lua.globals().Press, lua.globals().Post
press(7)
assert len(messages) > 0
lua.globals().FIXTURE_APP.trial.salvage.cine.playing = True
press(11)
assert lua.globals().originalUpdates == 2
press(7)
assert lua.globals().originalUpdates == 3
lua.globals().FIXTURE_APP.trial.salvage.cine.playing = False
press(7)
initial_updates = lua.globals().originalUpdates
for stage in range(2, 5):
    press(11)
    post()
    press(7)
    assert lua.globals().originalUpdates == initial_updates
    assert lua.globals().originalPosts == 0
press(11)
post()
assert lua.globals().originalPosts == 1
press(7)
assert lua.globals().originalUpdates == initial_updates + 1
streams = {}
for line in messages:
    assert line.startswith('SALVAGE_HOOK_CHUNK ')
    packet = json.loads(line[19:])
    streams.setdefault(packet['kind'], []).append(packet)
states = []
for packets in streams.values():
    packets.sort(key=lambda p: p['index'])
    assert len(packets) == packets[0]['count']
    text = ''.join(p['data'] for p in packets)
    encoded = text.encode('utf-8')
    assert len(encoded) == packets[0]['bytes']
    checksum = 2166136261
    for byte in encoded:
        checksum = ((checksum ^ byte) * 16777619) & 0xffffffff
    assert checksum == packets[0]['checksum']
    states.append(json.loads(text))
by_stage = {state['stage']: state for state in states}
assert sorted(by_stage) == [0, 1, 2, 3, 4, 5]
assert by_stage[1]['pose'] == by_stage[2]['pose'] == by_stage[3]['pose']
assert [by_stage[i]['hook']['visible'] for i in range(1, 5)] == [True, False, True, True]
assert by_stage[5]['pose']['camera'] == by_stage[0]['pose']['camera']
assert by_stage[5]['hook'] == by_stage[0]['hook']
assert by_stage[5]['frozen'] is False
assert any(state['stage'] == 0 and state['pendingAdvance'] and state['run']['playing'] for state in states)
assert not any(state['pendingAdvance'] for state in states if state['stage'] > 0)
print(json.dumps({'result': 'PASS_OFFLINE_ONLY', 'states': len(states), 'stages': 6,
                  'transportPackets': len(messages), 'restoredCamera': True,
                  'frozenUpdateAndPost': True, 'waitsForNaturalCinematicIdle': True}))

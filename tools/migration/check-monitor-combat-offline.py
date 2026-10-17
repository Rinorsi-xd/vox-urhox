"""Exercise the actual observer suffix with engine stubs; no engine/FPS claim."""
from pathlib import Path
import sys
import json

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
prefix = r'''
local ms,frame,fail=0,1,false
Time={GetSystemTime=function()ms=ms+1;return ms end}
GetTime=function()return {frameNumber=frame}end
input={GetKeyPress=function()return false end}
local monitor={}
monitor.Finalize=function()if fail then error('original-error')end;return nil,7,nil end
monitor.Emit=function()return nil,8,nil end
local bindings={Context=function()return {parts=12}end}
local originals={finalize=monitor.Finalize,emit=monitor.Emit,context=bindings.Context}
require=function(name)
 if name=='diagnostics.PerformanceMonitor'then return monitor end
 if name=='diagnostics.PerformanceBindings'then return bindings end
 if name=='core.Math3' then return {Rotate=function(_,v)return v end}end
 if name=='urhox-libs/UI'then return {GetViewportSize=function()return 1920,1080 end,
  GetRoot=function()end,GetTopOverlay=function()end}end
 if name=='ui.GarageHud'then return {GetState=function()return {tab='hangar'}end}end
 return {}
end
local app={mode='hangar',loadingFlow={active=false},
 tutorial={visible=true,page={buttons={{text='SkipTest',x=11,y=12,w=13,h=14}}}},
 trial={pointer={captured=false},world={stats={shots=2,hits=1,damage=3,kills=0}}}}
local performance={enabled=true}
HandleUpdate=function()monitor.Finalize()end
HandleFramePresented=function()bindings.Context(app)end
'''
checks = r'''
local function Up(fn,key)
 for i=1,40 do local n,v=debug.getupvalue(fn,i);if n==key then return v,i end end
 error('Missing upvalue '..key)
end
local function Set(fn,key,value)
 local _,i=Up(fn,key);debug.setupvalue(fn,i,value)
end
-- Inactive wrappers preserve nil-containing return arity exactly.
local returned=table.pack(monitor.Finalize())
assert(returned.n==3 and returned[1]==nil and returned[2]==7 and returned[3]==nil)
assert(bindings.Context(app).parts==12)
Set(monitor.Finalize,'active',true)
HandleUpdate()
local finalized=table.pack(monitor.Finalize())
assert(finalized.n==3 and finalized[2]==7)
local emitted=table.pack(monitor.Emit())
assert(emitted.n==3 and emitted[2]==8)
-- A thrown original closes its pooled guard; next call remains usable.
fail=true
local ok,err=pcall(monitor.Finalize)
assert(not ok and tostring(err):find('original%-error'))
fail=false
assert(select(2,monitor.Finalize())==7)
HandleFramePresented()
frame=2;HandleUpdate();HandleFramePresented()
-- New-frame reset may never silently discard a previous uncommitted row.
frame=3;HandleUpdate();frame=4
local resetOk,resetError=pcall(HandleUpdate)
assert(not resetOk and tostring(resetError):find('previous observer row committed'))
-- Inspect actual retained numeric arrays from Commit's upvalues.
local commit=Up(HandleFramePresented,'Commit')
local ids=Up(commit,'index')
local rows=Up(commit,'rows')
local shots=Up(commit,'shots')
assert(ids==3 and #rows==18 and #shots==2 and shots[1]==2)
assert(rows[2]==4 and rows[5]==1 and rows[8]==1)
local footprint=Up(Up(Up(Up(HandleUpdate,'Place'),'Current'),'Roster'),'Footprint')
assert(footprint({alive=false,vehicle=nil})==nil,'Actual observer accepts dead vehicle without body')
local alive=footprint({vehicle={body={translation=function()return {x=5,z=9}end,
 rotation=function()return {}end}},spec={bounds={min={-2,0,-3},max={4,2,6}}}})
assert(alive[1]==3 and alive[2]==6 and alive[3]==9 and alive[4]==15)
_G.ChunkForTest=Up(Up(HandleUpdate,'Snapshot'),'Chunk')
_G.SnapshotForTest=Up(HandleUpdate,'Snapshot')
_G.TestApp=app
Set(monitor.Finalize,'active',false)
_G.PollForTest=HandleUpdate
return 'PASS: returns/errors/guards/frame commits; actual dead/alive footprint paths'
'''
print(lua.execute(prefix + (root / 'tools/migration/monitor-combat-observer.lua').read_text('utf8') + checks))

stop_checks = r'''
local function Up(fn,key)
 for i=1,40 do local n,v=debug.getupvalue(fn,i);if n==key then return v,i end end
 error('Missing upvalue '..key)
end
local function Set(fn,key,value)
 local _,i=Up(fn,key);debug.setupvalue(fn,i,value)
end
KEY_F9=9;KEY_F7=7;KEY_F11=11
local pressed=nil
input.GetKeyPress=function(_,key)return key==pressed end
local endCapture=Up(HandleFramePresented,'EndCapture')
local exported=nil
Set(endCapture,'Chunk',function(kind,value)
 assert(kind=='result');exported=value
end)
Set(monitor.Finalize,'active',true)
HandleUpdate();HandleFramePresented()
frame=2;pressed=KEY_F9;HandleUpdate();pressed=nil
assert(exported==nil,'Stop input must not serialize a partial frame')
assert(Up(monitor.Finalize,'active')==true,'Final presentation still belongs to capture')
HandleFramePresented()
assert(exported and exported.status=='CAPTURED')
assert(#exported.frameIds==2 and #exported.rows==18)
for _,key in ipairs({'parts','shots','hits','damage','kills','wallMs'})do
 assert(#exported[key]==2,'Complete final '..key..' row')
end
assert(exported.parts[2]==12 and exported.shots[2]==2)
assert(exported.rows[17]==1,'Final Context executes before export')
assert(Up(monitor.Finalize,'active')==false)
HandleFramePresented();assert(#exported.rows==18,'Post-stop presentation cannot append rows')
return 'PASS: F9 defers export through actual Context/Commit; complete final row, no synthetic padding'
'''
stop_lua = LuaRuntime(unpack_returned_tuples=True)
print(stop_lua.execute(prefix + (root / 'tools/migration/monitor-combat-observer.lua').read_text('utf8') + stop_checks))

def convert(value):
    if hasattr(value, 'items'):
        return {str(k): convert(v) for k, v in value.items()}
    return value

lines = []
lua.globals().cjson = lua.table_from({'encode': lambda value: json.dumps(convert(value), ensure_ascii=False, separators=(',', ':')),
    'decode': lambda value: json.loads(value)})
lua.globals().print = lines.append
payload = {'text': ('Chinese \u4e2d\u6587 emoji \U0001f642 and escaped "\\\n' * 600)}
lua.globals().ChunkForTest('state-42', lua.table_from(payload))
parts = [json.loads(line[len('MONITOR_COMBAT_CHUNK '):]) for line in lines]
assert len(parts) > 3
assert all(len(part['data'].encode('utf8')) <= 600 for part in parts)
assert all(part['index'] == i + 1 and part['count'] == len(parts) for i, part in enumerate(parts))
assert json.loads(''.join(part['data'] for part in parts)) == payload
text = ''.join(part['data'] for part in parts)
checksum = 2166136261
for byte in text.encode('utf8'):
    checksum = ((checksum ^ byte) * 16777619) & 0xffffffff
assert all(part['bytes'] == len(text.encode('utf8')) and part['checksum'] == checksum for part in parts)
assert max(len(line.encode('utf8')) for line in lines) < 1500
print('PASS: actual Lua UTF-8-safe 600-byte chunk roundtrip, including quotes/backslashes/newlines')
lines.clear()
lua.globals().SnapshotForTest()
snapshot = json.loads(''.join(json.loads(line[len('MONITOR_COMBAT_CHUNK '):])['data'] for line in lines if line.startswith('MONITOR_COMBAT_CHUNK ')))
assert snapshot['widgets'] == {'1': {'text': 'SkipTest', 'disabled': False,
    'rect': {'1': 11, '2': 12, '3': 13, '4': 14}, 'source': 'TutorialPage.buttons'}}
lua.globals().TestApp.tutorial.visible = False
lines.clear()
lua.globals().SnapshotForTest()
hidden = json.loads(''.join(json.loads(line[len('MONITOR_COMBAT_CHUNK '):])['data'] for line in lines))
assert hidden['widgets'] == {}
print('PASS: actual Snapshot enumerates visible tutorial drawn controls and excludes hidden controls')
lines.clear()
lua.execute("KEY_F7='QA_F7';KEY_F8='PRODUCTION_F8';input.GetKeyPress=function(_,key)return key==KEY_F8 end")
lua.globals().PollForTest()
assert not lines
lua.execute('input.GetKeyPress=function(_,key)return key==KEY_F7 end')
lua.globals().PollForTest()
assert any(line.startswith('MONITOR_COMBAT_CHUNK ') for line in lines)
print('PASS: actual observer accepts F7 state input and ignores production F8')
try:
    lua.globals().ChunkForTest('bad-number', lua.table_from({'number': float('nan')}))
    raise AssertionError('Non-finite input was accepted')
except Exception as error:
    assert 'Non-finite JSON number' in str(error)
original = lua.globals().cjson.encode
lua.globals().cjson.encode = lambda value: '{"incomplete":'
try:
    lua.globals().ChunkForTest('bad-encode', lua.table_from({'number': 1}))
    raise AssertionError('Partial encoder result was accepted')
except Exception as error:
    assert 'Incomplete engine cjson.encode result' in str(error)
lua.globals().cjson.encode = original
print('PASS: non-finite input and partial engine encoding fail before transport')

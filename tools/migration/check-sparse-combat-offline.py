"""Actual Lua core, deterministic clocks and Lua 5.4 unwind; no runtime or FPS claims."""
from pathlib import Path
import sys
import subprocess

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().CORE_SOURCE = (root / 'tools/migration/sparse-combat-core.lua').read_text(encoding='utf-8')
lua.execute(r'''
local ms,calls,prints=0,0,0
Time={GetSystemTime=function() calls=calls+1;return ms end}
local markers={}
print=function(text) prints=prints+1;markers[prints]=text end
local M=assert(load(CORE_SOURCE))()
local api=M.New(30000)
local owner={run=function(v)ms=ms+2;return nil,v,nil end}
api.Wrap(owner,'run',1)
-- Dormant wrappers preserve nil holes, return count and avoid clock/print calls.
local a=table.pack(owner.run(7));assert(a.n==3 and a[2]==7 and calls==0 and prints==0)
ms=0;api.Start()
for frame=1,33 do
 ms=frame<17 and frame*50 or (frame<32 and 10000+(frame-17)*50 or 21000+(frame-32)*50)
 api.Frame(frame)
 local before=calls;local out=table.pack(owner.run(frame))
 assert(out.n==3 and out[2]==frame)
 if frame==17 then assert(calls==before+3 and prints==2)
 else assert(calls==before)end
 api.Commit()
end
local result=api.Stop()
assert(result.sampleCount==1 and #result.frameIds==33 and #result.rows==24)
assert(result.selected[17]==1 and result.phases[1]==1 and result.phases[17]==2 and result.phases[33]==3)
assert(result.rows[1]==2 and result.rows[2]==1 and result.rows[3]==2)
assert(result.markerCount==2)
assert(not pcall(api.Stop))
-- Nested calls, thrown errors, preserved exceptions, and reusable close guards.
local nested=M.New(30000)
local fail=true
local child={go=function()ms=ms+3;if fail then error('actual-original-error')end;return nil,9,nil end}
nested.Wrap(child,'go',2)
local parent={go=function()return child.go()end}
nested.Wrap(parent,'go',1);ms=0;nested.Start()
for frame=1,17 do ms=10001;nested.Frame(frame)
 if frame==17 then
  local ok,err=pcall(parent.go);assert(not ok and err:find('actual%-original%-error'))
  fail=false;local out=table.pack(parent.go());assert(out.n==3 and out[2]==9)
 end
 nested.Commit()
end
local r=nested.Stop();assert(r.rows[2]==2 and r.rows[5]==2 and r.markerCount==8)
-- Uncommitted frames and capacity errors do not silently overwrite evidence.
local limits=M.New(30000);ms=0;limits.Start();limits.Frame(1);assert(not pcall(limits.Frame,2));limits.Commit()
for i=2,4096 do ms=0;limits.Frame(i);limits.Commit()end
assert(not pcall(limits.Frame,4097));assert(#limits.Stop().frameIds==4096)
''')

# Parse the complete generated suffix as Lua 5.4, without engine execution.
generated = subprocess.check_output(
    ['node', '-e', "process.stdout.write(require('./tools/migration/sparse-combat-prepare.cjs').observer())"],
    cwd=root, encoding='utf-8')
lua.globals().OBSERVER_SOURCE = generated
lua.execute("assert(load(OBSERVER_SOURCE))")

# Execute the actual generated observer Frame/Commit/tail with an event bus. The
# UI callback is extracted from the reference library, not rewritten for the test.
ui_source = (root / 'urhox-libs/UI/Core/UI.lua').read_text(encoding='utf-8')
ui_start = ui_source.index('eventScriptObject_:SubscribeToEvent(nvg_, "NanoVGRender", function')
ui_end = ui_source.index('    end)', ui_start) + len('    end)')
lua.globals().UI_SUBSCRIPTION = ui_source[ui_start:ui_end]
core_start = generated.index('local sparse=(function()')
core_end = generated.index('local function Finite(', core_start)
tail_start = generated.index('function HandleUpdate(...)')
tail_end = generated.rindex('\nend\n')
lua.globals().GENERATED_FRAME_CODE = generated[core_start:core_end]
lua.globals().GENERATED_TAIL_CODE = generated[tail_start:tail_end] + '\n'
lua.execute(r'''
local harness=[[
local ms,frame=0,0
Time={GetSystemTime=function()return ms end};GetTime=function()return {frameNumber=frame}end
print=function()end
local events={}
SubscribeToEvent=function(name,callback)events[name]=callback end
local UI={Render=function()ms=ms+4 end}
local eventScriptObject_={SubscribeToEvent=function(_,_,name,callback)events[name]=callback end}
local nvg_={}
]]..UI_SUBSCRIPTION..[[
local active,index,committedIndex,stopRequested=true,0,0,false
local frameIds,shots,hits,damage,kills,parts={},{},{},{},{},{}
local app={trial={fixedSteps=0,world={stats={shots=0,hits=0,damage=0,kills=0}},battle={entries={}}}}
]]..GENERATED_FRAME_CODE..[[
local updateForSparse=function()app.trial.fixedSteps=app.trial.fixedSteps+1 end
local stopped,exported=false,nil
local function EndCapture()exported=sparse.Stop();active=false;stopped=true end
local function StartCapture()error('Unexpected start')end
local function Place()end
local function Snapshot()end
local pressed=false
KEY_F9=9;KEY_F11=11;KEY_F7=7
input={GetKeyPress=function(_,key)return pressed and key==KEY_F9 end}
HandleFramePresented=function()end
]]..GENERATED_TAIL_CODE..[[
SubscribeToEvent('Update',HandleUpdate)
SubscribeToEvent('PostUpdate',function()ms=ms+1 end)
SubscribeToEvent('EndFrame',HandleFramePresented)
sparse.Wrap(UI,'Render',7);sparse.Start()
-- A capture can start partway through Update; its first row is partial.
frame=1;Frame();events.EndFrame();events.NanoVGRender()
for f=2,36 do
 frame=f;ms=f<17 and f*20 or 15001+(f-17)*20
 if f==36 then pressed=true end
 events.Update();events.PostUpdate()
 -- Exercise both render-before-EndFrame and render-after-EndFrame order.
 if f%2==0 then events.NanoVGRender();events.EndFrame()
 else events.EndFrame();events.NanoVGRender()end
end
frame=37;pressed=false;events.Update();assert(stopped and not active)
local result=exported;assert(result.sampleCount==2)
for i=1,2 do assert(result.rows[(i-1)*24+20]==1 and result.rows[(i-1)*24+19]==4)end
assert(index==committedIndex and #result.frameIds==36)
]]
assert(load(harness))()
''')
print('PASS: actual core gating/selection/returns/errors/capacity; generated observer syntax and real UI auto-subscription event order including NanoVG before/after EndFrame. Offline only.')

"""Actual frozen H5 Input events against production Lua event receiver and filter."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
os.chdir(ROOT)
golden=json.loads(subprocess.check_output(['node','tools/migration/source-mouse-delta-golden.cjs'],encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)

def convert(value):
    if isinstance(value,dict): return lua.table_from({k:convert(v) for k,v in value.items()})
    if isinstance(value,list): return lua.table_from([convert(v) for v in value])
    return value

lua.globals().SOURCE_MOUSE=convert(golden)
checks=lua.execute('''
package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(ok,message) assert(ok,message);checks=checks+1 end
local function Near(a,b) return math.abs(a-b)<1e-8 end
MM_ABSOLUTE,MM_RELATIVE=100,101
MOUSEB_LEFT,MOUSEB_RIGHT,MOUSEB_MIDDLE=11,22,33
local created,disposed=0,0
Node=function()
    created=created+1
    local node={events={}}
    function node:CreateScriptObject() return {SubscribeToEvent=function(_,name,callback) node.events[name]=callback end} end
    function node:Dispose() disposed=disposed+1;self.events={} end
    return node
end
Time={GetSystemTime=function() return 100 end}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function() return true end}
local focus=true
input={mouseMode=MM_ABSOLUTE,mouseLocked=false,mouseMoveX=0,mouseMoveY=0,
    GetMouseButtonDown=function() return false end,GetMouseMoveWheel=function() return 0 end}
local Pointer=require 'controls.DrivePointer'
local function New(touch)
    input.mouseMode=MM_ABSOLUTE;input.mouseLocked=false;input.mouseMoveX=0;input.mouseMoveY=0;focus=true
    local s={touch=touch,scope=false,controls={held={},x=0,y=0},HasFocus=function() return focus end}
    function s.controls:Clear() self.held={};self.x=0;self.y=0 end
    function s.controls:Look(dx,dy) self.x=self.x+dx;self.y=self.y+dy end
    function s:Zoom() end
    local p=Pointer.New(s);p:Capture();input.mouseLocked=true;p:Poll(.016);p:Poll(.016)
    return p,s
end
local function Move(p,dx,dy)
    p.eventNode.events.MouseMove({},'MouseMove',{GetInt=function(_,name) return name=='DX' and dx or dy end})
end
for _,scenario in ipairs(SOURCE_MOUSE.scenarios) do
    local p,s=New(false)
    Check(p.eventNode.events.MouseMove~=nil and p.ready,'real receiver owns mouse events')
    for i,frame in ipairs(scenario.frames) do
        if frame.reset then p:Release();input.mouseLocked=false;p:Capture();input.mouseLocked=true;p:Poll(.016);p:Poll(.016) end
        s.controls.x=0;s.controls.y=0
        for _,move in ipairs(frame.moves) do Move(p,move[1],move[2]) end
        input.mouseMoveX=frame.raw[1];input.mouseMoveY=frame.raw[2];p:Poll(.016)
        local e=frame.expected
        Check(Near(s.controls.x,e.delta[1]) and Near(s.controls.y,e.delta[2]),scenario.name..' source frame '..i)
        Check(Near(p.mouse.avgMove,e.avg) and p.mouse.lastSpike==e.lastSpike,scenario.name..' source event history '..i)
        s.controls.x=0;s.controls.y=0;input.mouseMoveX=0;input.mouseMoveY=0;p:Poll(.016)
        Check(s.controls.x==0 and s.controls.y==0,'movement consumed only once')
    end
    p:Release()
end
local p,s=New(false)
Move(p,30,10);s.dialog={};Move(p,1000,1000)
Check(p.mouse.dx==30 and p.mouse.dy==10,'dialog cannot enqueue movement events')
p:Release();p:Poll(.016)
Check(not p.captured and p.eventNode==nil and s.controls.x==0,'host pause releases queued input and event ownership')
s.dialog=nil;p,s=New(false);Move(p,25,3);p:Suppress();Move(p,1000,0);p:Poll(.016)
Check(s.controls.x==0 and s.controls.y==0,'suppression drops queued and pending motion')
Move(p,10,20);p:Poll(.016);Check(s.controls.x==10 and s.controls.y==20,'neutral input resumes movement')
Move(p,99,3);focus=false;p:Poll(.016)
Check(not p.captured and s.controls.x==0 and p.mouse.events==0,'focus loss discards queued input')
p,s=New(false);Move(p,27,1);input.mouseLocked=false;p:Poll(.016)
Check(not p.captured and s.controls.x==0 and p.mouse.events==0,'pointer unlock discards queued input')
p,s=New(false);input.mouseMoveX=900;p:Poll(.016)
Check(s.controls.x==0,'missing-event adapter fallback rejects isolated warp')
input.mouseMoveX=900;p:Poll(.016)
Check(s.controls.x==900,'fallback preserves consecutive large movement')
p:Release()
p,s=New(true)
Check(p.eventNode==nil,'touch does not create PC event receiver')
p:Release();Check(created==disposed,'every owned event receiver disposed exactly once')
return checks
''')
paths=['scripts/controls/DrivePointer.lua','scripts/controls/MouseDeltaFilter.lua']
report={'result':'PASS','checks':checks,'scenarios':len(golden['scenarios']),
        'frames':sum(len(s['frames']) for s in golden['scenarios']),
        'baseline':golden['baseline'],'reference':golden['source'],
        'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
        'boundary':'Actual frozen H5 Input constructor, document mousemove and pointerlock handlers; production Lua filter and DrivePointer event subscriptions/Poll. Engine delivery stubbed. No native, browser, rendered camera or performance acceptance.'}
output=ROOT/'docs/migration/evidence/mouse-delta-offline.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))

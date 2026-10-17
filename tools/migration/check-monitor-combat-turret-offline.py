"""Exercise the suffix against frozen real TurretRange algorithms, without an engine."""
from pathlib import Path
import sys
import subprocess
import json

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime, lua_type

source = (root / '.tmp/monitor-combat-flush-2a92-a/scripts/construction/TurretRange.lua').read_text('utf8')
math_source = (root / '.tmp/monitor-combat-flush-2a92-a/scripts/core/Math3.lua').read_text('utf8')
rotation_source = (root / '.tmp/monitor-combat-flush-2a92-a/scripts/core/Rotations.lua').read_text('utf8')
suffix = (root / 'tools/migration/monitor-combat-turret-observer.lua').read_text('utf8')
source_markers = '--source-markers' in sys.argv
if source_markers:
    suffix = (root / 'tools/migration/monitor-combat-turret-source-observer.lua').read_text('utf8')
    transformed = subprocess.check_output([
        'node', '-e',
        "const fs=require('fs');process.stdout.write(require('./tools/migration/monitor-combat-turret-source-transform.cjs').transform(fs.readFileSync('.tmp/monitor-combat-flush-2a92-a/scripts/construction/TurretRange.lua')).bytes)",
    ], cwd=root).decode('utf8')

dependencies = r'''
local defs={gun={weapon=true,aim={pitch={-15,90}}},block={}}
local assets={Get=function()return {weapon={pivot={0,0,0},muzzle={0,0,2}}}end}
require=function(name)
 if name=='parts.Defs'then return {PARTS=defs}end
 if name=='parts.PartAssets'then return assets end
 if name=='core.Math3'then return ActualMath end
 if name=='core.Rotations'then return ActualRot end
 if name=='construction.TurretRange'then return ProbeTR end
 error('Unexpected dependency '..name)
end
'''
prefix = r'''
local frame,ms=10,0
local key=false
local app={trial={vehicle={}}}
Time={GetSystemTime=function()ms=ms+1;return ms end}
GetTime=function()return {frameNumber=frame}end
KEY_F9=9
input={GetKeyPress=function(_,which)return which==KEY_F9 and key end}
local began,closed=0,0
local labels={}
local performance={enabled=true,Begin=function(_,label)
 began=began+1;labels[#labels+1]=label
 return setmetatable({},{__close=function()closed=closed+1 end})
end}
performance.End=function(_,token)getmetatable(token).__close(token)end
local original=ProbeTR.For
ProbeTR.For=function(...)local token <close> = performance:Begin('flush.turretRange');return original(...)end
local wrappedOriginal=ProbeTR.For
performance.wrapped={[ProbeTR]={For=wrappedOriginal}}
local inspector=debug
local function Named(fn,wanted)
 for i=1,80 do local n,v=inspector.getupvalue(fn,i);if not n then break end;if n==wanted then return v end end
end
local originalPrepare=Named(original,'Prepare')
local originalEvaluate=Named(original,'Evaluate')
local exported=nil
local order={}
local Chunk=function(kind,value)
 assert(kind=='turret-result');order[#order+1]='export';exported=value
end
local Snapshot=function()Chunk('state',{})end
local action=nil
HandleUpdate=function()
 if false then Snapshot()end
 if action then action()end
end
HandleFramePresented=function()order[#order+1]='presented'end
cjson={encode=function(value)assert(value.debugUpvalues and value.sharedHelpers);return 'ready'end}
local ready=0
print=function(value)assert(value=='MONITOR_TURRET_READY ready');ready=ready+1 end
local function Press()key=true;HandleUpdate();key=false;HandleFramePresented();frame=frame+1 end
local function Cycle()HandleUpdate();HandleFramePresented();frame=frame+1 end
local function BP(parts)
 return {parts=parts,List=function(self)return self.parts end}
end
local function Gun()return {id=1,type='gun',rot=0,pos={0,0,0},_cells={{0,0,0}}}end
local function Block(id,x,y,z)return {id=id,type='block',rot=0,pos={x,y,z},_cells={{x,y,z}}}end
local function Serialize(value)
 if type(value)~='table'then return type(value)..':'..tostring(value)end
 local keys={};for k in pairs(value)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={'{'};for _,k in ipairs(keys)do out[#out+1]=Serialize(k)..'='..Serialize(value[k])end
 out[#out+1]='}';return table.concat(out,'|')
end
'''
success = r'''
Cycle();assert(ready==1)
assert(ProbeTR.For~=wrappedOriginal and Named(original,'Prepare')~=originalPrepare)
Press()
local a=BP({Gun(),Block(2,0,0,1)})
local b=BP({Gun(),Block(2,0,0,1)})
local owner={[1]=1,[2]=1}
local expected={}
local function Compare(bp,baseline,owners)
 local produced=table.pack(ProbeTR.For(bp,owners))
 local reference=table.pack(BaselineTR.For(baseline,owners))
 assert(Serialize(produced)==Serialize(reference),'Actual frozen For output changed')
 expected[#expected+1]=Serialize(produced)
end
action=function()Compare(a,b,owner)end;Cycle() -- cold
Cycle() -- unchanged full reuse
a.parts[2]=Block(2,0,0,2);b.parts[2]=Block(2,0,0,2);Cycle() -- warm evaluation
local c,d=BP({Gun()}),BP({Gun()})
action=function()Compare(c,d,owner)end;Cycle() -- cold without occupants
owner={[1]=2};Cycle() -- Prepare needed, identical empty occupancy reuses the range
action=nil
local out=table.pack(ProbeTR.Compute({Gun()},Gun(),{}))
assert(out.n==1 and out[1]==nil,'Real Compute nil return arity changed')
local before=#order
Press()
assert(exported and exported.restored and #exported.errors==0)
assert(order[#order]=='export'and order[#order-1]=='presented','Export must follow original complete-frame presentation')
assert(ProbeTR.For==wrappedOriginal and Named(original,'Prepare')==originalPrepare and Named(original,'Evaluate')==originalEvaluate)
assert(Named(ProbeTR.Compute,'Prepare')==originalPrepare and Named(ProbeTR.Compute,'Evaluate')==originalEvaluate)
assert(#exported.rows==5 and #expected==5)
local rows=exported.rows
assert(rows[1][3]==0 and rows[1][9]==1 and rows[1][5]>0 and rows[1][7]>0,'Actual cold For must prepare/evaluate')
assert(rows[2][3]==1 and rows[2][9]==2 and rows[2][5]==0 and rows[2][7]==0,'Actual unchanged For must fully reuse')
assert(rows[3][3]==1 and rows[3][9]==4 and rows[3][7]>0,'Actual warm edit must evaluate')
assert(rows[4][9]==1 and rows[5][9]==3 and rows[5][5]>0 and rows[5][7]==0,'Actual owner edit can Prepare then reuse range')
assert(began==closed,'All diagnostic and original monitor scopes closed')
for _,row in ipairs(rows)do assert(row[4]>=row[6] and row[4]>=row[8] and row[10]==0)end
assert(ready==1,'Install once')
return 'PASS: frozen real For cold/warm/edit/context-reuse outputs identical; exact classification, shared closures restored; export after presentation'
'''
error_checks = r'''
Cycle();Press()
local bp=BP({Gun(),Block(2,0,0,1)})
local ok,err=pcall(ProbeTR.For,bp,nil,function()error('checkpoint-sentinel')end)
assert(not ok and tostring(err):find('checkpoint%-sentinel'),'Original helper error must propagate')
assert(ProbeTR.For==wrappedOriginal and Named(original,'Prepare')==originalPrepare and Named(original,'Evaluate')==originalEvaluate)
assert(Named(ProbeTR.Compute,'Prepare')==originalPrepare and Named(ProbeTR.Compute,'Evaluate')==originalEvaluate)
assert(began==closed,'Error must close all scopes')
Press()
assert(exported.restored and #exported.errors==1 and exported.rows[1][10]==1)
return 'PASS: real Prepare checkpoint error propagates, all For/Compute shared references restore and scopes close'
'''
negative_checks = r'''
debug=nil
local ok,err=pcall(HandleUpdate)
assert(not ok and tostring(err):find('requires debug upvalue access'))
assert(ProbeTR.For==wrappedOriginal and ready==0,'No debug must fail before replacing functions')
return 'PASS: unavailable debug fails closed before mutation'
'''
ordering_checks = r'''
performance.wrapped={}
Cycle()
assert(ready==0 and ProbeTR.For==wrappedOriginal,'Do not install before the original eight-scope wrapper')
performance.wrapped={[ProbeTR]={For=wrappedOriginal}}
Cycle();assert(ready==1)
Press();Press()
assert(exported.restored and ProbeTR.For==wrappedOriginal,'Restore the existing default monitor wrapper')
return 'PASS: waits for the actual eight-scope For wrapper and restores that exact reference'
'''


def run(checks):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ActualMath = lua.execute(math_source)
    lua.globals().ActualRot = lua.execute(rotation_source)
    lua.execute(dependencies)
    lua.globals().ProbeTR = lua.execute(transformed if source_markers else source)
    lua.globals().BaselineTR = lua.execute(source)
    extension = ''
    if source_markers:
        def to_python(value):
            if lua_type(value) != 'table':
                return value
            keys = list(value.keys())
            if set(keys) == set(range(1, len(keys) + 1)):
                return [to_python(value[i]) for i in range(1, len(keys) + 1)]
            return {key: to_python(value[key]) for key in keys}

        def to_lua(value):
            if isinstance(value, list):
                return lua.table_from([to_lua(item) for item in value])
            if isinstance(value, dict):
                return lua.table_from({key: to_lua(item) for key, item in value.items()})
            return value

        lua.globals().JsonEncode = lambda value: json.dumps(to_python(value), ensure_ascii=False, separators=(',', ':'))
        lua.globals().JsonDecode = lambda value: to_lua(json.loads(value))
        extension = r'''
debug=nil
cjson={encode=JsonEncode,decode=JsonDecode}
local wire={}
print=function(value)
 if value:find('MONITOR_TURRET_READY ',1,true)==1 then
  local data=cjson.decode(value:sub(22));assert(data.sourceMarkers and not data.debugUpvalues);ready=ready+1
 else
  assert(value:find('MONITOR_COMBAT_CHUNK ',1,true)==1)
  local data=cjson.decode(value:sub(22));assert(data.kind=='turret-result'and #data.data<=600)
  wire[data.index]=data;if data.index==1 then order[#order+1]='export'end
 end
end
local function GetExported()
 local all={};for i,item in ipairs(wire)do assert(item.index==i and item.count==#wire);all[#all+1]=item.data end
 local text=table.concat(all);local checksum=2166136261
 for i=1,#text do checksum=((checksum~text:byte(i))*16777619)&0xffffffff end
 assert(#text==wire[1].bytes and checksum==wire[1].checksum,'Exact byte/checksum transport')
 return cjson.decode(text)
end
'''
        checks = checks.replace(
            "assert(ProbeTR.For~=wrappedOriginal and Named(original,'Prepare')~=originalPrepare)",
            "assert(ProbeTR.For==wrappedOriginal and Named(original,'Prepare')==originalPrepare)",
        ).replace('assert(exported and exported.restored', 'exported=GetExported()\nassert(exported and exported.restored')
        checks = checks.replace('assert(exported.restored', 'exported=GetExported()\nassert(exported.restored')
        if checks is not None and "#expected==5" in checks:
            checks = checks.replace("return 'PASS:", r'''
local actualChunk=Named(HandleFramePresented,'Chunk')
wire={}
local utf8text=string.rep('舰船_\\"\n',150)
actualChunk('turret-result',{text=utf8text})
assert(GetExported().text==utf8text and #wire>1,'Actual copied transport preserves UTF-8 across 600-byte chunks')
wire={}
local invalid,why=pcall(actualChunk,'turret-result',{invalid=math.huge})
assert(not invalid and tostring(why):find('Non%-finite')and #wire==0,'Nonfinite rejected before transport')
return 'PASS:''', 1)
    print(lua.execute(prefix + extension + suffix + checks))


run(success)
run(error_checks)
if not source_markers:
    run(negative_checks)
run(ordering_checks)

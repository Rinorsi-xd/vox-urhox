"""Actual asset float bytes, exact Lua interpolation and bounded-cache behavior."""
import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
arguments = argparse.ArgumentParser()
arguments.add_argument('--baseline', default='docs/migration/evidence/heightfield-cache-native-2026-10-17/source-baseline/scripts/core/HeightField.lua')
options = arguments.parse_args()
baseline_path = (ROOT / options.baseline).resolve()
baseline_bytes = baseline_path.read_bytes()
baseline_sha = hashlib.sha256(baseline_bytes).hexdigest()
assert baseline_sha == '9e95855a228e49fd6c3b7fd8b7b7091a713d5478e0e3ca2fc112f1a096b8946a', 'Original pre-adoption HeightField required; never compare the candidate against itself'
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime, LuaError

baseline = baseline_bytes.decode('utf-8-sig')
candidate = ROOT / 'tools/migration/heightfield-cell-cache-candidate.lua'
candidate_source = candidate.read_text(encoding='utf-8-sig')
fixture = r'''
local overrides={};local files={}
local function Buffer(data)
 local b={data=data,position=0,reads=0,seeks=0,clears=0}
 function b:Seek(p)self.seeks=self.seeks+1;self.position=p;return p end
 function b:ReadFloat()
  self.reads=self.reads+1
  if self.failAt and self.reads==self.failAt then error('Injected buffer read failure')end
  local value,nextPosition=string.unpack('<f',self.data,self.position+1);self.position=nextPosition-1;return value
 end
 function b:Clear()self.clears=self.clears+1;self.data=''end
 return b
end
cache={GetFile=function(_,name)
 if name=='missing' then return nil end
 local data=overrides[name]or READ_BIN(name)
 local file={data=data,position=0,size=#data,disposed=0}
 function file:ReadFileID()self.position=4;return self.data:sub(1,4)end
 function file:ReadUInt()local v,p=string.unpack('<I4',self.data,self.position+1);self.position=p-1;return v end
 function file:ReadFloat()local v,p=string.unpack('<f',self.data,self.position+1);self.position=p-1;return v end
 function file:Read(count)local b=Buffer(self.data:sub(self.position+1,self.position+count));self.position=self.position+count;return b end
 function file:Dispose()self.disposed=self.disposed+1 end
 files[#files+1]=file;return file
end}
local old=assert(load(BASE,'HeightOriginal'))();local new=assert(load(CANDIDATE,'HeightCandidate'))()
local checks,collisionChecks,atomicFailureChecks,instanceChecks=0,0,0,0
local function Equal(a,b,path)
 checks=checks+1;assert(string.pack('<d',a)==string.pack('<d',b),'Exact double interpolation '..path)
end
math.randomseed(1017)
local maps={}
for _,name in ipairs({'Crater/VisualHeight.bin','Salvage/Height.bin'})do
 local a,b=old.New(name),new.New(name);maps[#maps+1]={old=a,new=b,name=name}
 local first,second=new.New(name),new.New(name)
 for _,field in ipairs({'cellKeys','cellA','cellB','cellC','cellD'})do
  assert(first[field]~=second[field],'Same-path instances own private cache '..field);instanceChecks=instanceChecks+1
 end
 local x,z=a.x+.3*a.step,a.z+.4*a.step
 Equal(a:Sample(x,z),first:Sample(x,z),name..' first same-path instance')
 Equal(a:Sample(x,z),second:Sample(x,z),name..' second same-path instance')
 first:Dispose()
 local reads=second.buffer.reads
 Equal(a:Sample(x,z),second:Sample(x,z),name..' same-path instance survives peer disposal')
 assert(second.buffer.reads==reads and not second.disposed and second.buffer.clears==0,'Peer disposal preserves live cached cell')
 instanceChecks=instanceChecks+1;second:Dispose()
 local points={{a.x,a.z},{a.x+a.n*a.step,a.z+a.n*a.step},{a.x-1e6,a.z+1e6},
  {a.x+.25*a.step,a.z+.75*a.step},{a.x+math.huge,a.z-math.huge}}
 for i=0,a.n,math.max(1,math.floor(a.n/16))do
  for _,epsilon in ipairs({-1e-10,0,1e-10})do points[#points+1]={a.x+(i+epsilon)*a.step,a.z+(i-epsilon)*a.step}end
 end
 for i=1,12000 do points[#points+1]={a.x+(math.random()*1.4-.2)*a.n*a.step,a.z+(math.random()*1.4-.2)*a.n*a.step}end
 for _,p in ipairs(points)do
  Equal(a:Sample(p[1],p[2]),b:Sample(p[1],p[2]),name)
  Equal(a:Sample(p[1]+.001,p[2]-.001),b:Sample(p[1]+.001,p[2]-.001),name..' nearby')
 end
 local collision=false
 for k=0,a.n*(a.n+1)-4097 do
  local i,j=math.floor(k/(a.n+1)),k%(a.n+1)
  local q=k+4096;local u,v=math.floor(q/(a.n+1)),q%(a.n+1)
  if i<a.n and j<a.n and u<a.n and v<a.n then collision={i,j,u,v};break end
 end
 assert(collision,'Actual map can exercise direct-cache collision')
 local atomic=new.New(name)
 local ax,az=a.x+(collision[1]+.37)*a.step,a.z+(collision[2]+.62)*a.step
 local bx,bz=a.x+(collision[3]+.37)*a.step,a.z+(collision[4]+.62)*a.step
 local key=collision[1]*(a.n+1)+collision[2];local slot=key%4096+1
 Equal(a:Sample(ax,az),atomic:Sample(ax,az),name..' seed atomic cache slot')
 for fail=1,4 do
  local values={atomic.cellA[slot],atomic.cellB[slot],atomic.cellC[slot],atomic.cellD[slot]}
  atomic.buffer.failAt=atomic.buffer.reads+fail
  local ok,why=pcall(atomic.Sample,atomic,bx,bz)
  assert(not ok and tostring(why):find('Injected buffer read failure',1,true),'Conflicting cell fails at intended float '..fail)
  assert(atomic.cellKeys[slot]==key,'Failed collision never publishes a new key')
  for i,field in ipairs({'cellA','cellB','cellC','cellD'})do
   Equal(values[i],atomic[field][slot],name..' failed collision preserves old float '..i)
  end
  atomic.buffer.failAt=nil
  local beforeRetry=atomic.buffer.reads
  Equal(a:Sample(ax,az),atomic:Sample(ax,az),name..' old colliding cell remains exact')
  assert(atomic.buffer.reads==beforeRetry,'Old colliding cell remains a hit after failed replacement')
  Equal(a:Sample(bx,bz),atomic:Sample(bx,bz),name..' failed colliding cell retries exactly')
  Equal(a:Sample(ax,az),atomic:Sample(ax,az),name..' restore old slot for next read failure')
  atomicFailureChecks=atomicFailureChecks+1
 end
 atomic:Dispose()
 for i=1,24 do
  local offset=i%2==0 and 1 or 3;local x,z=a.x+(collision[offset]+.37)*a.step,a.z+(collision[offset+1]+.62)*a.step
  Equal(a:Sample(x,z),b:Sample(x,z),name..' conflicting slot');collisionChecks=collisionChecks+1
 end
 local count=0;for slot in pairs(b.cellKeys)do assert(slot>=1 and slot<=4096 and math.type(slot)=='integer');count=count+1 end
 assert(count<=4096 and count>0,'Bounded retained cache')
 local before=b.buffer.reads;b:Sample(a.x+.4*a.step,a.z+.6*a.step);local afterMiss=b.buffer.reads
 b:Sample(a.x+.3*a.step,a.z+.7*a.step);assert(b.buffer.reads==afterMiss,'Same cell reuses four static floats')
 local doomed=new.New(name);doomed.buffer.failAt=2
 assert(not pcall(doomed.Sample,doomed,doomed.x,doomed.z));assert(next(doomed.cellKeys)==nil,'Incomplete read not cached')
 doomed.buffer.failAt=nil;Equal(a:Sample(a.x,a.z),doomed:Sample(doomed.x,doomed.z),name..' retry after error');doomed:Dispose()
end
for i=1,80 do for _,map in ipairs(maps)do
 local a,b=map.old,map.new;local x,z=a.x+.3*a.step,a.z+.4*a.step
 Equal(a:Sample(x,z),b:Sample(x,z),'Interleaved independent map')
end end
for _,map in ipairs(maps)do
 local a,b=map.old,map.new
 for _,args in ipairs({{nil,0},{0,nil},{'bad',0},{0,'bad'}})do
  assert(not pcall(a.Sample,a,table.unpack(args,1,2)));assert(not pcall(b.Sample,b,table.unpack(args,1,2)))
 end
 a:Dispose();b:Dispose();b:Dispose();assert(b.buffer.clears==1)
 assert(b.cellKeys==nil and b.cellA==nil and b.cellB==nil and b.cellC==nil and b.cellD==nil)
 local good,error=pcall(b.Sample,b,0,0);assert(not good and tostring(error):find('Height field already released',1,true))
end
local valid=READ_BIN('Crater/VisualHeight.bin')
overrides.magic='BAD!'..valid:sub(5)
overrides.short=valid:sub(1,#valid-4)
overrides.invalidN='VHF1'..string.pack('<I4fff',0,0,0,1)
overrides.invalidStep='VHF1'..string.pack('<I4fff',1,0,0,0)
for _,name in ipairs({'missing','magic','short','invalidN','invalidStep'})do
 assert(not pcall(old.New,name));assert(not pcall(new.New,name))
end
for _,file in ipairs(files)do assert(file.disposed==1,'Every opened file disposed including error path')end
return {status='HEIGHTFIELD_EXACT_CACHE_OFFLINE_PASS',checks=checks,collisionChecks=collisionChecks,maps=#maps,
 atomicFailureChecks=atomicFailureChecks,instanceChecks=instanceChecks,cacheSlots=4096,bounded=true,disposeAndErrors=true}
'''


def run(source):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().READ_BIN = lambda name: (ROOT / 'assets' / name).read_bytes()
    lua.globals().BASE = baseline
    lua.globals().CANDIDATE = source
    return dict(lua.execute(fixture))


report = run(candidate_source)
mutations = [
    ('early key publication', '    else\n        buffer:Seek(k*4);a,c=buffer:ReadFloat(),buffer:ReadFloat()',
     '    else\n        self.cellKeys[slot]=k\n        buffer:Seek(k*4);a,c=buffer:ReadFloat(),buffer:ReadFloat()',
     'Failed collision never publishes a new key'),
    ('shared same-path cache', 'local CACHE_SLOTS=4096',
     'local CACHE_SLOTS=4096\nlocal SHARED={keys={},a={},b={},c={},d={}}',
     'Same-path instances own private cache'),
]
negative_controls = []
for name, before, after, assertion in mutations:
    assert candidate_source.count(before) == 1, 'Unique mutation anchor: ' + name
    source = candidate_source.replace(before, after, 1)
    if name == 'shared same-path cache':
        private = 'cellKeys={},cellA={},cellB={},cellC={},cellD={}'
        assert source.count(private) == 1, 'Unique private cache anchor'
        source = source.replace(private, 'cellKeys=SHARED.keys,cellA=SHARED.a,cellB=SHARED.b,cellC=SHARED.c,cellD=SHARED.d', 1)
    try:
        run(source)
    except LuaError as error:
        assert assertion in str(error), 'Negative failed outside intended assertion: ' + str(error)
        negative_controls.append({'name': name, 'rejected': True, 'assertion': assertion})
    else:
        raise AssertionError('Behavioral negative passed: ' + name)
report['negativeControls'] = negative_controls
report['baselinePath'] = str(baseline_path)
report['baselineSha256'] = baseline_sha
report['candidateSha256'] = hashlib.sha256(candidate.read_bytes()).hexdigest()
report['assets'] = {name: {'sha256': hashlib.sha256((ROOT/'assets'/name).read_bytes()).hexdigest(),
                          'gridN': struct.unpack_from('<I', (ROOT/'assets'/name).read_bytes(), 4)[0]}
                    for name in ['Crater/VisualHeight.bin', 'Salvage/Height.bin']}
print(json.dumps(report, indent=2))

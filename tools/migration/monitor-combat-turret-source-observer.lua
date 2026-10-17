-- Three derived-module entry hooks; real algorithms and references remain intact.
do
local installed,recording,stopPending,finished=false,false,false,false
local rows,errors={},{}
local current=nil
local ids=setmetatable({},{__mode='k'})
local nextId=0
local module,forReference=nil,nil
local previousCallback=_G.VOX_TURRET_SOURCE_PROBE
assert(previousCallback==nil,'Keep existing turret callback untouched')
local function Now()return Time:GetSystemTime()end
local function Delta(a,b)return (a-b)&0xffffffff end
local function Restore()_G.VOX_TURRET_SOURCE_PROBE=previousCallback end
local guardMt={__close=function(g,err)
 if g.token then performance:End(g.token)end
 local elapsed=Delta(Now(),g.started)
 if g.row then
  local row=g.row;row[4]=elapsed
  row[9]=row[3]==0 and 1 or (row[7]>0 and 4 or (row[5]>0 and 3 or 2))
  row[10]=err and 1 or 0;current=g.previous
 else g.owner[g.slot+1]=g.owner[g.slot+1]+elapsed end
 if err then
  if g.row or not current then errors[#errors+1]=tostring(err):sub(1,240)end
  Restore()
 end
end}
local callback=function(kind,bp,cachePresent)
 if not recording then return nil end
 if kind=='for' then
  assert(#rows<4096,'Turret diagnostic call capacity')
  local id=ids[bp];if not id then nextId=nextId+1;id=nextId;ids[bp]=id end
  local row={GetTime().frameNumber,id,cachePresent and 1 or 0,0,0,0,0,0,0,0}
  rows[#rows+1]=row
  local previous=current;current=row
  return setmetatable({row=row,previous=previous,started=Now(),
   token=performance:Begin(cachePresent and 'turret.warmFor' or 'turret.coldFor')},guardMt)
 end
 assert(kind=='prepare' or kind=='evaluate','Unexpected turret entry kind')
 if not current then return nil end
 local slot=kind=='prepare' and 5 or 7;local owner=current;owner[slot]=owner[slot]+1
 return setmetatable({owner=owner,slot=slot,started=Now(),token=performance:Begin('turret.'..kind)},guardMt)
end
_G.VOX_TURRET_SOURCE_PROBE=callback
local function Finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function Validate(value,path,seen)
 local t=type(value)
 if t=='number' then assert(Finite(value),'Non-finite JSON number at '..path..': '..tostring(value))
 elseif t=='table' then
  assert(not seen[value],'Cyclic JSON table at '..path);seen[value]=true
  for k,v in pairs(value)do Validate(v,path..'.'..tostring(k),seen)end
  seen[value]=nil
 else assert(t=='nil' or t=='string' or t=='boolean','Unsupported JSON '..t..' at '..path)end
end
local function Checksum(text)
 local hash=2166136261
 for i=1,#text do hash=((hash~text:byte(i))*16777619)&0xffffffff end
 return hash
end
local function Chunk(kind,value)
 Validate(value,kind,{})
 local text=cjson.encode(value)
 local ok,decoded=pcall(cjson.decode,text)
 assert(ok and decoded~=nil,'Incomplete engine cjson.encode result for '..kind..', bytes='..#text..', tail='..text:sub(-120))
 local bytes,checksum=#text,Checksum(text);local chunks={};local first=1
 while first<=#text do
  local last=math.min(first+599,#text)
  while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<192 do last=last-1 end
  chunks[#chunks+1]=text:sub(first,last);first=last+1
 end
 for i,part in ipairs(chunks)do print('MONITOR_COMBAT_CHUNK '..cjson.encode({kind=kind,index=i,count=#chunks,bytes=bytes,checksum=checksum,data=part}))end
end
local update=HandleUpdate
function HandleUpdate(...)
 local pressed=input:GetKeyPress(KEY_F9)
 update(...)
 if not installed and app and app.trial and app.trial.vehicle and performance then
  assert(performance.enabled,'Keep the default production monitor enabled')
  module=module or require 'construction.TurretRange'
  local known=performance.wrapped and performance.wrapped[module]
  if known and known.For==module.For then
   installed=true;forReference=module.For
   print('MONITOR_TURRET_READY '..cjson.encode({frame=GetTime().frameNumber,debugUpvalues=false,sourceMarkers=true}))
  end
 end
 if pressed then
  assert(installed and not finished,'One turret capture requires live default monitor wrappers')
  if recording then stopPending=true else rows={};errors={};recording=true end
 end
end
local presented=HandleFramePresented
function HandleFramePresented(...)
 presented(...)
 if stopPending then
  stopPending=false;recording=false;finished=true;Restore()
  Chunk('turret-result',{columns={'engineFrame','blueprintId','cachePresent','forMs','prepareCalls','prepareMs','evaluateCalls','evaluateMs','class','error'},
   classes={'coldBlueprint','fullReuse','contextRangeReuse','warmEvaluate'},rows=rows,errors=errors,
   restored=_G.VOX_TURRET_SOURCE_PROBE==previousCallback and module.For==forReference,frame=GetTime().frameNumber})
 end
end
end

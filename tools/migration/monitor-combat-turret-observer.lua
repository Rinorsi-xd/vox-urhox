-- Main-only diagnostic: preserve real algorithms and reuse the observer transport.
do
local installed,recording,stopPending,finished=false,false,false,false
local rows,errors={},{}
local current=nil
local ids=setmetatable({},{__mode='k'})
local nextId=0
local bindings={}
local module,oldFor,forWrapper,chunk
local Restore=function()end
local Restored=function()return false end
local installMt={__close=function(_,err)if err then Restore()end end}
local function Named(fn,wanted)
 for i=1,80 do
  local name,value=debug.getupvalue(fn,i)
  if not name then return nil end
  if name==wanted then return value,i end
 end
end
local function RealFor(fn)
 for _=1,8 do
  local value=Named(fn,'cached')
  if type(value)=='table' then return fn,value end
  fn=Named(fn,'original')
  assert(type(fn)=='function','Cannot unwrap actual TurretRange.For')
 end
 error('TurretRange.For wrapper depth')
end
local function ObserverChunk(fn)
 for _=1,8 do
  local snapshot=Named(fn,'Snapshot')
  if type(snapshot)=='function' then
   local out=Named(snapshot,'Chunk')
   assert(type(out)=='function','Missing actual observer Chunk');return out
  end
  fn=Named(fn,'update')
  assert(type(fn)=='function','Cannot locate actual capture observer')
 end
 error('Observer wrapper depth')
end
local function Now()return Time:GetSystemTime()end
local function Delta(a,b)return (a-b)&0xffffffff end
local childMt={__close=function(g)
 local elapsed=Delta(Now(),g.started)
 g.owner[g.slot+1]=g.owner[g.slot+1]+elapsed
end}
local forMt={__close=function(g,err)
 local row=g.row
 row[4]=Delta(Now(),g.started)
 -- 1: cold blueprint, 2: full reuse, 3: context rebuilt/range reused, 4: warm evaluation.
 row[9]=row[3]==0 and 1 or (row[7]>0 and 4 or (row[5]>0 and 3 or 2))
 row[10]=err and 1 or 0
 current=g.previous
 if err then
  errors[#errors+1]=tostring(err):sub(1,240)
  Restore()
 end
end}
local function Install()
 assert(type(debug)=='table' and type(debug.getupvalue)=='function' and type(debug.setupvalue)=='function','Turret diagnostic requires debug upvalue access')
 assert(performance.enabled,'Turret diagnostic requires the default enabled monitor')
 module=require 'construction.TurretRange'
 oldFor=module.For
 local actual,cached=RealFor(oldFor)
 local prepare,prepareIndex=Named(actual,'Prepare')
 local evaluate,evaluateIndex=Named(actual,'Evaluate')
 assert(type(prepare)=='function' and type(evaluate)=='function','Missing actual turret helpers')
 assert(Named(module.Compute,'Prepare')==prepare and Named(module.Compute,'Evaluate')==evaluate,'For/Compute helper references differ')
 chunk=ObserverChunk(HandleUpdate)
 local function Measured(original,slot,label)
  return function(...)
   if not recording or not current then return original(...) end
   local owner=current
   owner[slot]=owner[slot]+1
   local detail <close> = setmetatable({owner=owner,slot=slot,started=Now()},childMt)
   local token <close> = performance:Begin(label)
   return original(...)
  end
 end
 local measuredPrepare=Measured(prepare,5,'turret.prepare')
 local measuredEvaluate=Measured(evaluate,7,'turret.evaluate')
 Restore=function()
  for i=#bindings,1,-1 do local b=bindings[i];debug.setupvalue(b[1],b[2],b[3])end
  bindings={}
  if module.For==forWrapper then module.For=oldFor end
 end
 Restored=function()
  return module.For==oldFor and Named(actual,'Prepare')==prepare and Named(actual,'Evaluate')==evaluate
   and Named(module.Compute,'Prepare')==prepare and Named(module.Compute,'Evaluate')==evaluate
 end
 local failure <close> = setmetatable({},installMt)
 local function Replace(fn,index,before,after)
  assert(debug.getupvalue(fn,index)~=nil)
  bindings[#bindings+1]={fn,index,before,after}
  debug.setupvalue(fn,index,after)
 end
 Replace(actual,prepareIndex,prepare,measuredPrepare)
 Replace(actual,evaluateIndex,evaluate,measuredEvaluate)
 local sharedHelpers=Named(module.Compute,'Prepare')==measuredPrepare and Named(module.Compute,'Evaluate')==measuredEvaluate
 -- Lua normally shares these cells. Preserve both if a runtime uses separate ones.
 for _,entry in ipairs({{'Prepare',prepare,measuredPrepare},{'Evaluate',evaluate,measuredEvaluate}})do
  local value,index=Named(module.Compute,entry[1])
  if value~=entry[3] then assert(value==entry[2]);Replace(module.Compute,index,value,entry[3])end
 end
 forWrapper=function(bp,...)
  if not recording then return oldFor(bp,...) end
  assert(#rows<4096,'Turret diagnostic call capacity')
  local id=ids[bp]
  if not id then nextId=nextId+1;id=nextId;ids[bp]=id end
  local row={GetTime().frameNumber,id,cached[bp] and 1 or 0,0,0,0,0,0,0,0}
  rows[#rows+1]=row
  local previous=current;current=row
  local detail <close> = setmetatable({row=row,previous=previous,started=Now()},forMt)
  local token <close> = performance:Begin(row[3]==0 and 'turret.coldFor' or 'turret.warmFor')
  return oldFor(bp,...)
 end
 module.For=forWrapper;installed=true
 print('MONITOR_TURRET_READY '..cjson.encode({frame=GetTime().frameNumber,debugUpvalues=true,sharedHelpers=sharedHelpers}))
end
local update=HandleUpdate
function HandleUpdate(...)
 local pressed=input:GetKeyPress(KEY_F9)
 update(...)
 if not installed and app and app.trial and app.trial.vehicle and performance then
  module=module or require 'construction.TurretRange'
  local known=performance.wrapped and performance.wrapped[module]
  -- The eight-scope suffix must own For before its wrapper is captured/restored.
  if known and known.For==module.For then Install()end
 end
 if pressed then
  assert(installed,'Turret diagnostic must install before capture')
  assert(not finished,'Turret diagnostic supports one capture per Lua state')
  if recording then stopPending=true else rows={};errors={};recording=true end
 end
end
local presented=HandleFramePresented
function HandleFramePresented(...)
 presented(...)
 if stopPending then
  stopPending=false;recording=false;finished=true;Restore()
  chunk('turret-result',{columns={'engineFrame','blueprintId','cachePresent','forMs','prepareCalls','prepareMs','evaluateCalls','evaluateMs','class','error'},
   classes={'coldBlueprint','fullReuse','contextRangeReuse','warmEvaluate'},rows=rows,errors=errors,
   restored=Restored(),frame=GetTime().frameNumber})
 end
end
end

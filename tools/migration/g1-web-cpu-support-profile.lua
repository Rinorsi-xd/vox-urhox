local SupportScope=(function()
-- SUPPORT_SCOPE_FACTORY
end)()
_G.G1_WEB_CPU_SUPPORT_SCOPE=SupportScope
local SupportRows={}
local SupportPreload={}
local function PrepareSupportResources()
 local Gate=require 'app.ResourceGate'
 local gate=Gate.New();local finished,success,message=false,false,''
 local path='Crater/VisualHeight.bin'
 gate:Start({path},function(ok,detail)finished=true;success=ok;message=detail end)
 local previous=Time:GetSystemTime();local started=previous
 while not finished do
  coroutine.yield()
  local now=Time:GetSystemTime()
  Gate.UpdatePending(((now-previous)&0xffffffff)/1000);previous=now
  assert(((now-started)&0xffffffff)<90000,'Support resource preload timed out')
 end
 assert(success,'Support resource preload failed: '..tostring(message))
 assert(cache:Exists(path),'Support resource absent after preload')
 local file=assert(cache:GetFile(path));local bytes=file.size;local id=file:ReadFileID();file:Dispose()
 assert(bytes==1643544 and id=='VHF1','Support height field identity')
 SupportPreload={path=path,fileBytes=bytes,fileId=id,ready=true}
 gate:Cancel()
 print('G1_WEB_CPU_SUPPORT_PRELOAD '..cjson.encode(SupportPreload))
end
local supportCallers={['suspension.Sample']=true,['leg.Cast']=true,['stability.Step']=true,['hover.Step']=true}
function SupportScope.Caller()
 for i=#SupportScope.stack,1,-1 do
  local name=SupportScope.stack[i].name
  if supportCallers[name]then return name end
 end
 return 'other'
end
local function SupportInstrument(Vehicle,Space,Gait,Legs,Suspension,clock)
 local rows,restores={},{}
 local base={
  {Vehicle,'Step','vehicle.Step'},{Vehicle,'PostStep','vehicle.PostStep'},{Vehicle,'StepRotors','vehicle.StepRotors'},
  {Space,'Step','physics.Step'},{Space,'Raycast','physics.Raycast'},
  {Gait,'Step','gait.Step'},{Gait,'Foothold','gait.Foothold'},
  {Legs,'Step','leg.Step'},{Legs,'Cast','leg.Cast'},{Legs,'Clear','leg.Clear'},
  {Legs,'Reachable','leg.Reachable'},{Legs,'Target','leg.Target'},
  {Suspension,'Sample','suspension.Sample'},{Suspension,'Apply','suspension.Apply'},
 }
 local baseNames={}
 local function Wrap(object,key,name)
  local old=assert(object[key]);SupportScope.Wrap(object,key,name,false)
  restores[#restores+1]=function()object[key]=old end
 end
 for _,entry in ipairs(base)do Wrap(table.unpack(entry));baseNames[entry[3]]=true end
 Wrap(require 'drive.ChassisStability','Step','stability.Step')
 Wrap(require 'drive.HoverControl','Step','hover.Step')
 SupportScope.rows={};SupportScope.stack={};SupportScope.active=true
 return rows,function()
  SupportScope.AssertClosed();SupportScope.active=false
  for _,entry in ipairs(base)do
   local row=SupportScope.rows[entry[3]]or {calls=0,ms=0,selfMs=0,maxMs=0}
   rows[#rows+1]={name=entry[3],calls=row.calls,ms=row.ms,selfMs=row.selfMs,maxMs=row.maxMs}
  end
  local names={};for name in pairs(SupportScope.rows)do if not baseNames[name]then names[#names+1]=name end end
  table.sort(names)
  for _,name in ipairs(names)do
   local row=SupportScope.rows[name]
   SupportRows[#SupportRows+1]={name=name,calls=row.calls,ms=row.ms,selfMs=row.selfMs,maxMs=row.maxMs}
  end
  for _,restore in ipairs(restores)do restore()end
 end
end

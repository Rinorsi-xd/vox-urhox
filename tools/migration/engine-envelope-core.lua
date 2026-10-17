-- QA-only coarse boundaries. No timer, allocation or output in dormant callbacks.
local M={}
function M.New(sparse)
 local names={'PreRenderUpdate','RenderUpdate','PostRenderUpdate','BeginRendering',
  'PreRenderUI','PostPreRenderUI','PostRenderUI','EndRendering','PreEndFrame','EndFrame'}
 local rows={};local count=0;local overflow=false;local captureLog=false
 local dumps={};local currentDump=false
 local capacity=512*32
 for i=1,capacity*3 do rows[i]=0 end
 for id,name in ipairs(names)do
  local eventId=id
  SubscribeToEvent(name,function()
   local enabled,chosen,serial=sparse.EnvelopeState()
   if not enabled or not chosen then return end
   if count>=capacity then overflow=true;return end
   count=count+1;local offset=(count-1)*3
   rows[offset+1]=serial;rows[offset+2]=eventId;rows[offset+3]=Time:GetSystemTime()
  end)
 end
 SubscribeToEvent('LogMessage',function(_,data)
  if not captureLog then return end
  if #currentDump.messages>=4096 then currentDump.overflow=true;return end
  currentDump.messages[#currentDump.messages+1]={level=data:GetInt('Level'),
   message=data:GetString('Message'),customLog=data:GetString('CustomLog')}
 end)
 local api={}
 function api.Dump(label)
  local enabled=sparse.EnvelopeState();assert(not enabled,'Dump outside sparse capture only')
  currentDump={label=label,messages={},overflow=false};dumps[#dumps+1]=currentDump
  captureLog=true
  print('VOX_ENGINE_ENVELOPE_DUMP_CONTROL '..label)
  local ok,err=pcall(function()engine:DumpProfiler()end)
  captureLog=false;currentDump.ok=ok
  if not ok then currentDump.error=tostring(err)end
 end
 function api.Stop()
  local enabled=sparse.EnvelopeState();assert(not enabled,'Stop after sparse capture')
  api.Dump('after')
  for i=capacity*3,count*3+1,-1 do rows[i]=nil end
  return {schema=1,names=names,rows=rows,events=count,overflow=overflow,dumps=dumps,
   rowFormat='serial,eventId,Time.GetSystemTime uint32 milliseconds; chronological event timestamps, not function CPU durations',
   boundary='QA-only sparse selected-frame event callbacks. Native profiler dumps outside capture, no HUD/GPU/GC query. Missing events are unavailable; repeated event boundaries and observer time are retained. Not an optimization A/B or device FPS result.'}
 end
 return api
end
return M

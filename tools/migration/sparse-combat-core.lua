-- Isolated attribution only. Dormant phases retain one frame timestamp/counter row.
local M={}
function M.New(duration)
 local clock=function()return Time:GetSystemTime()end
 local elapsed=function(a,b)return (a-b)&0xffffffff end
 local names={'battle.BeforeStep','world.Step','battle.AfterStep','view.Update','effects.Update','hud.Update','UI.Render','main.Update'}
 local frames,wall,phases,selected,rows,steps={},{},{},{},{},{}
 local totals,calls,maxima,guards={},{},{},{}
 local n,samples,current,phase,last,started,enabled,chosen,serial=0,0,0,0,0,0,false,false,0
 local markerCount=0
 local function mark(kind,owner,ms)
  markerCount=markerCount+1
  print('VOX_SPARSE_SYNC '..serial..' '..kind..' '..owner..' '..ms)
 end
 local mt={__close=function(g,err)
  local finish=clock();local dt=elapsed(finish,g.started)
  totals[g.owner]=totals[g.owner]+dt;calls[g.owner]=calls[g.owner]+1
  maxima[g.owner]=math.max(maxima[g.owner],dt)
  mark(err and 'error' or 'end',g.owner,finish)
  g.busy=false
 end}
 -- Pools and result slots are allocated before recording, never in a timed scope.
 for i=1,8 do
  totals[i]=0;calls[i]=0;maxima[i]=0;guards[i]={}
  for depth=1,8 do guards[i][depth]=setmetatable({owner=i,busy=false},mt)end
 end
 for i=1,4096 do frames[i]=0;wall[i]=0;phases[i]=0;selected[i]=0;steps[i]=0 end
 for i=1,512*24 do rows[i]=0 end
 local api={names=names}
 function api.Start()
  assert(not enabled and n==0,'Single sparse capture');enabled=true;started=clock();last=started
 end
 function api.Frame(id)
  assert(enabled and current==0,'Uncommitted sparse frame')
  assert(n<4096,'Sparse frame capacity');n=n+1;current=id
  local now=clock();wall[n]=elapsed(now,last);last=now;frames[n]=id
  local age=elapsed(now,started);phase=age<duration/3 and 1 or (age<duration*2/3 and 2 or 3)
  phases[n]=phase;chosen=phase==2 and n%17==0
  if chosen then
   assert(samples<512,'Sparse sample capacity');samples=samples+1;serial=serial+1;selected[n]=samples
   for i=1,8 do totals[i]=0;calls[i]=0;maxima[i]=0 end
  end
 end
 function api.Wrap(target,key,owner)
  assert(type(target[key])=='function','Missing actual owner method '..names[owner])
  local original=target[key]
  target[key]=function(...)
   if not enabled or not chosen then return original(...)end
   local pool=guards[owner];local guard=nil
   for i=1,8 do if not pool[i].busy then guard=pool[i];break end end
   assert(guard,'Sparse guard depth capacity');guard.busy=true
   mark('begin',owner,clock());guard.started=clock()
   local scope <close> = guard
   return original(...)
  end
 end
 function api.Commit(fixedSteps)
  if not enabled then return end
  assert(current~=0,'Commit requires actual frame')
  if chosen then local offset=(samples-1)*24
   for i=1,8 do rows[offset+(i-1)*3+1]=totals[i];rows[offset+(i-1)*3+2]=calls[i];rows[offset+(i-1)*3+3]=maxima[i]end
  end
  steps[n]=fixedSteps or 0;current=0;chosen=false
 end
 function api.Stop()
  assert(enabled and current==0,'Stop only after presented complete frame');enabled=false
  for i=4096,n+1,-1 do frames[i]=nil;wall[i]=nil;phases[i]=nil;selected[i]=nil;steps[i]=nil end
  for i=512*24,samples*24+1,-1 do rows[i]=nil end
  return {frameIds=frames,wallMs=wall,phases=phases,selected=selected,rows=rows,names=names,fixedSteps=steps,
   sampleCount=samples,markerCount=markerCount,phaseNames={'dormant-A1','sparse-B','dormant-A2'},
   interval=17,durationMs=duration,clock='Time.GetSystemTime integer uint32 ms',
   boundary='Real full combat; original Monitor disabled from startup. One selected frame per 17 in middle third; nested inclusive scopes. Marker printing is outside measured original calls but inside enclosing scopes. Attribution only, never benefit A/B or target-device acceptance.'}
 end
 return api
end
return M

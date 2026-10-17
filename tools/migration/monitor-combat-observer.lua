-- Appended to the unchanged frozen production main, sharing its lexical locals.
-- Controlled placement is explicitly outside capture. No gameplay function wraps.
_G.VOX_SKIP_TUTORIAL=true
do
local UI=require 'urhox-libs/UI'
local Coord=require 'core.Coord'
local Math3=require 'core.Math3'
local Monitor=require 'diagnostics.PerformanceMonitor'
local Bindings=require 'diagnostics.PerformanceBindings'
local clock=function()return Time:GetSystemTime()end
local elapsed=function(a,b)return (a-b)&0xffffffff end
local active=false
local stopRequested=false
local rows,frameIds,wall,parts,shots,hits,damage,kills={},{},{},{},{},{},{},{}
local index,lastFrame,lastWall,committedIndex=0,0,0,0
local totals={0,0,0};local counts={0,0,0};local maxima={0,0,0}
local setup=nil
local captureBefore=nil
local captureAfter=nil
local latest=nil
local stamp=0
local function Footprint(u)
 if not u.vehicle then return nil end
 local p,q=u.vehicle.body.translation(),u.vehicle.body.rotation();local v=u.spec.bounds
 local out={math.huge,math.huge,-math.huge,-math.huge}
 for _,x in ipairs({v.min[1],v.max[1]})do for _,z in ipairs({v.min[3],v.max[3]})do
  local c=Math3.Rotate(q,{x,0,z})
  out[1]=math.min(out[1],p.x+c[1]);out[2]=math.min(out[2],p.z+c[3])
  out[3]=math.max(out[3],p.x+c[1]);out[4]=math.max(out[4],p.z+c[3])
 end end
 return out
end
local function Roster()
 local out={}
 local battle=app and app.trial and app.trial.battle
 for i,e in ipairs(battle and battle.entries or {})do
  local u=e.unit
  out[i]={name=u.name,team=u.team,role=e.member.role,variant=e.member.variant or 0,
   source=u.source,alive=u.alive,parts=u.bp:Size(),structure=u.struct,hull=u.bodyHp,
   position=u:Position(),size=u.spec.bounds,footprint=Footprint(u),driver=e.driver~=nil}
 end
 return out
end
local function Current()
 local t=app and app.trial
 local battle=t and t.battle
 local stats=t and t.world.stats
 return {roster=Roster(),world=stats and {shots=stats.shots,hits=stats.hits,damage=stats.damage,kills=stats.kills},
  battle=battle and battle:Snapshot(),playerDamage=battle and battle.stats[battle.player].damage,
  monitorEnabled=performance and performance.enabled,
  fixedSteps=t and t.fixedSteps,droppedTime=t and t.droppedTime,
  sceneIsTrial=t and app.scene==t.scene,hangarRetained=app and app.hangar~=nil,
  focus=input.focus,minimized=input.minimized}
end
local function Frame()
 local f=GetTime().frameNumber
 if f~=lastFrame then
  assert(index==committedIndex,'New frame before previous observer row committed')
  assert(index<4096,'Controlled capture exceeds frame capacity')
  index=index+1;frameIds[index]=f;local now=clock()
  wall[index]=lastWall~=0 and elapsed(now,lastWall) or 0;lastWall=now;lastFrame=f
  for n=1,3 do totals[n]=0;counts[n]=0;maxima[n]=0 end
 end
 return index
end
local guardMt={__close=function(g)
 local ms=elapsed(clock(),g.started)
 totals[g.owner]=totals[g.owner]+ms;counts[g.owner]=counts[g.owner]+1
 maxima[g.owner]=math.max(maxima[g.owner],ms);g.busy=false
end}
local guards={{},{},{}}
local function Guard(n)
 Frame()
 -- Each method is synchronous and non-reentrant in this observer contract.
 local g=guards[n][1]
 if not g then g=setmetatable({owner=n},guardMt);guards[n][1]=g end
 assert(not g.busy,'Unexpected reentrant monitored method')
 g.busy=true;g.started=clock();return g
end
local originalFinalize,originalEmit,originalContext=Monitor.Finalize,Monitor.Emit,Bindings.Context
Monitor.Finalize=function(...)
 if not active then return originalFinalize(...)end
 local g <close> = Guard(1);return originalFinalize(...)
end
Monitor.Emit=function(...)
 if not active then return originalEmit(...)end
 local g <close> = Guard(2);return originalEmit(...)
end
Bindings.Context=function(...)
 if not active then return originalContext(...)end
 local g <close> = Guard(3)
 local context=originalContext(...);local i=Frame();parts[i]=context.parts or 0
 return context
end
local function Commit()
 if not active or index==0 then return end
 local offset=(index-1)*9
 for n=1,3 do
  rows[offset+(n-1)*3+1]=totals[n]
  rows[offset+(n-1)*3+2]=counts[n]
  rows[offset+(n-1)*3+3]=maxima[n]
 end
 local stats=app.trial.world.stats
 shots[index]=stats.shots;hits[index]=stats.hits;damage[index]=stats.damage;kills[index]=stats.kills
 committedIndex=index
end
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
  -- Preserve UTF-8 codepoints across transport boundaries.
  while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<192 do last=last-1 end
  chunks[#chunks+1]=text:sub(first,last);first=last+1
 end
 for i,part in ipairs(chunks)do print('MONITOR_COMBAT_CHUNK '..cjson.encode({kind=kind,index=i,count=#chunks,bytes=bytes,checksum=checksum,data=part}))end
end
local codecChecked=false
local function CheckCodec()
 if codecChecked then return end;codecChecked=true
 for _,test in ipairs({{'nan',0/0},{'positiveInfinity',math.huge},{'negativeInfinity',-math.huge}})do
  local ok,encoded=pcall(cjson.encode,{before=1,n=test[2],after=2})
  local decodeOk,decoded=false,nil
  if ok then decodeOk,decoded=pcall(cjson.decode,encoded)end
  print('MONITOR_COMBAT_CODEC '..cjson.encode({case=test[1],encodeOk=ok,encoded=tostring(encoded),decodeOk=decodeOk and decoded~=nil}))
 end
end
local function Center(unit)
 local p=unit.vehicle.body.center();return {p.x,p.y,p.z}
end
local function Visible(a,b)
 local p,q=Center(a),Center(b);local dx,dy,dz=q[1]-p[1],q[2]-p[2],q[3]-p[3]
 local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
 local hit=app.trial.world:CastRay(p,{dx/distance,dy/distance,dz/distance},distance+3,a.vehicle.body)
 return hit and hit.owner and hit.owner.ref==b or false
end
local function Aim(target)
 local t=app.trial;local q=Center(target)
 for i=1,5 do
  local p=t.camera:GetNode().worldPosition
  local dx,dy,dz=q[1]+p.x,q[2]-p.y,q[3]-p.z
  t.yaw=-math.atan(dx,dz)*180/math.pi
  t.pitch=-math.atan(dy,math.sqrt(dx*dx+dz*dz))*180/math.pi
  t:PostUpdate(.016)
 end
end
local function Place()
 assert(not active and not setup,'One controlled setup per process')
 assert(app and app.trial and app.trial.battle and not app.loadingFlow.active,'Setup requires loaded battle')
 local t=app.trial;local b=t.battle
 assert(b.mode=='conquest' and b.rules.state=='live' and #b.entries==8,'Actual live production 4v4 required')
 assert(performance.enabled,'Keep default production monitor enabled')
 local before=Current();local width,depth=0,0
 for _,e in ipairs(b.entries)do
  assert(e.unit.alive and e.unit.vehicle,'All eight actual vehicles must be alive before setup')
  local v=e.unit.spec.bounds
  width=math.max(width,v.max[1]-v.min[1]);depth=math.max(depth,v.max[3]-v.min[3])
 end
 local spacing=math.max(18,width+6);local separation=math.max(40,depth+12)
 -- Original scale-test's known battle area first, then authored road nodes.
 local candidates={{0,-140,'scale-test'}, {95,-172,'nav.sW'}, {-110,-160,'nav.sE'},
  {-190,0,'nav.ch'}, {150,0,'nav.fW'}}
 local chosen=nil
 for _,candidate in ipairs(candidates)do
  local positions={};local okay=true
  for i,e in ipairs(b.entries)do
   local slot=e.slot;local x=candidate[1]+({-.5,.5,1.5,-1.5})[slot]*spacing
   local z=candidate[2]+(e.unit.team==b.player.team and -separation/2 or separation/2)
   local y=t.world:GroundAt(x,z);local v=e.unit.spec.bounds
   -- Reject steep footprint or static geometry around the actual vehicle box.
   for _,dx in ipairs({v.min[1],0,v.max[1]})do for _,dz in ipairs({v.min[3],0,v.max[3]})do
    if math.abs(t.world:GroundAt(x+dx,z+dz)-y)>1.5 then okay=false end
   end end
   local lift=-v.min[2]+.2;local mid=y+lift+(v.min[2]+v.max[2])/2
   local sign=e.unit.team==b.player.team and 1 or -1
   local cx=x+sign*(v.min[1]+v.max[1])/2;local cz=z+sign*(v.min[3]+v.max[3])/2
   for _,axis in ipairs({{1,0,0,(v.max[1]-v.min[1])/2+1},{0,0,1,(v.max[3]-v.min[3])/2+1}})do
    local length=axis[4]*2;local p={cx-axis[1]*axis[4],mid,cz-axis[3]*axis[4]}
    if t.world.space:Raycast(p,{axis[1],0,axis[3]},length,nil,'car',true,1)then okay=false end
   end
   positions[i]={x,y+.05,z}
  end
  if okay then chosen={name=candidate[3],positions=positions};break end
 end
 assert(chosen,'No safe dimension-aware eight-car placement; do not force into walls')
 for i,e in ipairs(b.entries)do
  e.unit.vehicle:Place(chosen.positions[i],e.unit.team==b.player.team and 0 or math.pi)
  e.unit:SavePose();e.unit.previous=e.unit.current
 end
 t.view:ResetPose();t:ResetCamera()
 local enemy=nil
 for _,e in ipairs(b.entries)do if e.unit.team~=b.player.team and Visible(b.player,e.unit)and Visible(e.unit,b.player)then enemy=e.unit;break end end
 assert(enemy,'Controlled setup has no reciprocal actual car ray visibility')
 Aim(enemy)
 setup={before=before,after=Current(),area=chosen.name,spacing=spacing,separation=separation,
  target=enemy.name,reciprocalVisible=true,atWall=clock(),
  source='.tmp/scale-test/check-battle-scale.lua Place coordinates, with current bounds/terrain/static-ray rejection',
  boundary='CONTROLLED DIAGNOSTIC: real vehicles repositioned before timing. No natural-playthrough claim. AI/HP/damage/clock/RNG are untouched.'}
 Chunk('setup',setup)
end
local function StartCapture()
 assert(setup and not active and index==0,'Setup before one capture')
 local b=app.trial.battle;local target=nil
 for _,e in ipairs(b.entries)do if e.unit.name==setup.target then target=e.unit end end
 assert(target and target.alive and b.player.alive,'Player and real target alive at capture start')
 assert(Visible(b.player,target)and Visible(target,b.player),'Both actual car rays remain visible after settle')
 Aim(target);captureBefore=Current();active=true;lastFrame=0;lastWall=0
 print('MONITOR_COMBAT_STARTED '..cjson.encode({atWall=clock(),monitorEnabled=performance.enabled,target=setup.target}))
end
local function EndCapture()
 assert(active and index==committedIndex,'Capture ends only after the complete presented frame');active=false
 captureAfter=Current()
 Chunk('result',{status='CAPTURED',setup=setup,before=captureBefore,after=captureAfter,
  frameIds=frameIds,wallMs=wall,rows=rows,parts=parts,shots=shots,hits=hits,damage=damage,kills=kills,
  names={'monitor.Finalize','monitor.Emit','bindings.Context'},
  rowFormat='9 numbers/frame: Finalize ms/calls/max, Emit ms/calls/max, Context ms/calls/max. Emit is nested inside Finalize; do not sum inclusive times.',
  boundary='Integer wall ms with default production monitor and full real systems. Three coarse diagnostic wrappers only. Observer control/setup/serialization outside capture; not CPU/GPU split, natural combat, FPS A/B or phone acceptance.'})
end
local function Snapshot()
 if not app then return end
 CheckCodec()
 local w,h=UI.GetViewportSize();local home=require('ui.GarageHud').GetState()
 local data={sequence=stamp+1,width=w,height=h,mode=app.mode,tab=home and home.tab,
  loading=app.loadingFlow.active,monitorEnabled=performance.enabled,
  intro=app.trial and app.trial.intro and not app.trial.intro.done,
  battle=app.trial and app.trial.battle and app.trial.battle:Snapshot(),widgets={},invalidWidgets={},setup=setup~=nil,active=active}
 local function Button(text,disabled,x,y,width,height,source)
  if Finite(x)and Finite(y)and Finite(width)and Finite(height)then
   if width>0 and height>0 then data.widgets[#data.widgets+1]={text=text,disabled=disabled,rect={x,y,width,height},source=source}end
  else data.invalidWidgets[#data.invalidWidgets+1]={text=text,rect={tostring(x),tostring(y),tostring(width),tostring(height)},source=source}end
 end
 local function Walk(widget)
  if not widget:IsVisible()then return end
  if widget.props.onClick then local r=widget:GetAbsoluteLayoutForHitTest()
   Button(widget.props.text or '',widget.props.disabled==true,r.x,r.y,r.w,r.h,'widget')end
  for _,child in ipairs(widget.children or {})do Walk(child)end
 end
 local root=UI.GetRoot();if root then Walk(root)end
 local overlay=UI.GetTopOverlay();if overlay then Walk(overlay)
  if overlay.contentContainer_ then Walk(overlay.contentContainer_)end
  if overlay.footerWidget_ then Walk(overlay.footerWidget_)end
 end
 local tutorial=app.tutorial
 if tutorial and tutorial.visible then
  for _,b in ipairs(tutorial.page.buttons or {})do
   Button(b.text,false,b.x,b.y,b.w,b.h,'TutorialPage.buttons')
  end
 end
 if app.trial then data.captured=app.trial.pointer.captured end
 stamp=data.sequence;latest=data;Chunk('state-'..stamp,data)
end
local update=HandleUpdate
function HandleUpdate(...)
 if active then Frame()end
 update(...)
 if input:GetKeyPress(KEY_F11)then Place()end
 if input:GetKeyPress(KEY_F9)then if active then stopRequested=true else StartCapture()end end
 if input:GetKeyPress(KEY_F7)then assert(not active,'No state serialization during capture');Snapshot()end
end
local presented=HandleFramePresented
function HandleFramePresented(...)
 presented(...);Commit()
 if stopRequested then stopRequested=false;EndCapture()end
end
end

-- Isolated QA suffix: wrap and call actual consumers; never replace their output.
_G.VOX_SKIP_TUTORIAL=true
do
local UI=require 'urhox-libs/UI'
local Garage=require 'ui.GarageHud'
local attached=nil;local calls={};local sequence=0;local pending=true;local scrubSite=nil
local function Sound(source)return source and {playing=source.playing,gain=source.gain}or nil end
local function Radio(r)
 local slots={};for i,s in ipairs(r.slots)do slots[i]={id=s.id,order=s.order,source=Sound(s.source)}end
 return {time=r.time,order=r.order,slots=slots,active=r.active}
end
local function Record(kind,fields)
 fields=fields or {};fields.kind=kind;fields.worldTime=app.trial.world.time
 fields.ruleTime=attached.rules.time;fields.site=fields.site or attached.rules:StepSpec()and attached.rules:StepSpec().site
 calls[#calls+1]=fields;assert(#calls<=160,'Capture QA event capacity');pending=true
end
local function Attach(m)
 attached=m
 local say=m.voice.Say;m.voice.Say=function(self,lines,urgent,...)
  local result=say(self,lines,urgent,...)
  Record('say',{lines=lines,urgent=urgent==true,queue=#self.queue,card=self.card and self.card.text})
  return result
 end
 local play=m.radio.Play;m.radio.Play=function(self,cue,...)
  local result=play(self,cue,...);Record('radio',{site=cue=='pickup'and scrubSite or nil,cue=cue,accepted=result==true,after=Radio(self)})
  if cue=='pickup'then scrubSite=nil end
  return result
 end
 for _,name in ipairs({'HideBeacon','SiteCaptured','Scrub'})do
  local fn=m.view[name];m.view[name]=function(self,id,...)
   local result=fn(self,id,...);local site=id and self.sites[id]
   if name=='Scrub'then scrubSite=id end
   Record(name,{id=id,site=id,captured=site and site.captured,scrubbed=site and site.scrubbed,
    beaconEnabled=self.beacon.root.enabled})
   return result
  end
 end
 local objective=m.view.Objective;m.view.Objective=function(self,step,target,...)
  local result=objective(self,step,target,...)
  Record('viewObjective',{cleared=step==nil and target==nil,zoneEnabled=self.zone.enabled,beaconEnabled=self.beacon.root.enabled})
  return result
 end
 local clear=m.ClearEnemies;m.ClearEnemies=function(self,...)
  local result=clear(self,...);Record('ClearEnemies',{remaining=#self.entries-1});return result
 end
 local banner=m.Banner;m.Banner=function(self,kick,title,sub,kind,ms,...)
  local result=banner(self,kick,title,sub,kind,ms,...)
  Record('Banner',{kick=kick,title=title,sub=sub,style=kind,ms=ms});return result
 end
 if m.choiceView then local cancel=m.choiceView.Cancel;m.choiceView.Cancel=function(self,...)
  local result=cancel(self,...);Record('choiceCancel',{on=self.on,choosing=self.choosing});return result
 end end
 if m.objective then local done=m.objective.Done;m.objective.Done=function(self,...)
  local result=done(self,...);Record('objectiveDone',{done=self.done});return result
 end end
 Record('attached',{mission=m.level.id})
end
local function Emit()
 sequence=sequence+1;local t=app and app.trial;local m=t and t.story
 local w,h=UI.GetViewportSize();local r=m and m.rules
 local state={sequence=sequence,width=w,height=h,mode=app and app.mode,
  loading=app and app.loadingFlow.active,widgets={},calls=calls,
  captured=t and t.pointer and t.pointer.captured,intro=t and t.intro and not t.intro.done,
  story=m and {id=m.level.id,index=r.index,step=r:StepSpec()and r:StepSpec().id,time=r.time,stats=r.stats,choice=r.choice,flags=r.flags,
   cap=r.cap and {p=r.cap.p,phase=r.cap.phase,scrub=r.cap.scrub,contested=r.cap.contested},finished=r.finished}}
 local home=Garage.GetState();local holo=home and home.storyHolo
 if holo then local gate=holo.gate
  state.holo={level=holo.level,ready=holo.ready,downloaded=holo.downloaded,disposed=holo.disposed,cursor=holo.cursor,failure=holo.failure,
   gate=gate and {state=gate.state,completed=gate.completed,total=gate.total,activeGroup=gate.group~=nil,failure=gate.failure}}
 end
 if m and m==attached then
  state.consumer={radio=Radio(m.radio),voice={card=m.voice.card and {text=m.voice.card.text,who=m.voice.card.who,
   started=m.voice.card.started,age=m.voice.card.age,pending=m.voice.card.pending},source=Sound(m.voice.source),log=m.voice.log},sites={}}
  for id,s in pairs(m.view.sites)do state.consumer.sites[id]={captured=s.captured,scrubbed=s.scrubbed}end
 end
 local function Walk(widget)
  if not widget:IsVisible()then return end
  if widget.props.onClick then local r=widget:GetAbsoluteLayoutForHitTest()
   if r.x==r.x and r.y==r.y and r.w>0 and r.h>0 and math.abs(r.x)<1e8 and math.abs(r.y)<1e8 then
    state.widgets[#state.widgets+1]={text=widget.props.text or '',disabled=widget.props.disabled==true,rect={r.x,r.y,r.w,r.h}}
   end
  end
  for _,child in ipairs(widget.children or {})do Walk(child)end
 end
 local root=UI.GetRoot();if root then Walk(root)end
 local overlay=UI.GetTopOverlay();if overlay then Walk(overlay)
  if overlay.contentContainer_ then Walk(overlay.contentContainer_)end
  if overlay.footerWidget_ then Walk(overlay.footerWidget_)end
 end
 if app and app.tutorial and app.tutorial.visible then for _,b in ipairs(app.tutorial.page.buttons or {})do
  state.widgets[#state.widgets+1]={text=b.text,rect={b.x,b.y,b.w,b.h}}
 end end
 local text=cjson.encode(state);assert(cjson.decode(text));local hash=2166136261
 for i=1,#text do hash=((hash~text:byte(i))*16777619)&0xffffffff end
 local chunks={};local first=1
 while first<=#text do local last=math.min(first+599,#text)
  while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<192 do last=last-1 end
  chunks[#chunks+1]=text:sub(first,last);first=last+1
 end
 for i,chunk in ipairs(chunks)do print('CAPTURE_CONSUMERS_CHUNK '..cjson.encode({kind='state-'..sequence,index=i,count=#chunks,bytes=#text,checksum=hash,data=chunk}))end
end
local update=HandleUpdate
function HandleUpdate(...)
 update(...)
 local m=app and app.trial and app.trial.story
 if m and m~=attached then assert(m.level.id=='s4','Capture QA requires public S4 entry');Attach(m)end
 if input:GetKeyPress(KEY_F7)then pending=true end
 if input:GetKeyPress(KEY_F10)then
  assert(m and m==attached and not app.loadingFlow.active)
  local s=m.rules:StepSpec();assert(s and s.kind=='capture')
  m:Place({pos={s.pos[1],s.pos[2]+1.5,s.pos[3]},yaw=0})
  Record('explicit-qa-place',{id=s.site})
 end
 if input:GetKeyPress(KEY_F9)then
  assert(m and m==attached and not app.loadingFlow.active)
  local count=0
  for _,entry in ipairs(m.entries)do local unit=entry.unit
   if unit~=m.player and unit.alive then local core
    for id,p in pairs(unit.bp.parts)do if p.type=='core'then core=id;break end end
    assert(core);unit:Destroy(core);unit:Flush();assert(not unit.alive);count=count+1
   end
  end
  Record('explicit-qa-destroy',{count=count})
 end
end
local post=HandlePostUpdate
function HandlePostUpdate(...)
 post(...);if pending then pending=false;Emit()end
end
end

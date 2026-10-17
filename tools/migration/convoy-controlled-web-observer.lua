-- Isolated QA suffix. Explicit placement, real Rules updates and original consumers.
_G.VOX_SKIP_TUTORIAL=true
do
local UI=require 'urhox-libs/UI'
local Garage=require 'ui.GarageHud'
local attached=nil;local worldRef=nil;local missionRef=nil;local generation=0
local calls={};local checkpoints={};local preparations={};local sequence=0;local frame=0;local pending=true
local open=nil;local disposed=nil
local function Copy(value)
 if type(value)~='table'then return value end
 local out={};for key,child in pairs(value)do out[key]=Copy(child)end;return out
end
local function Truck(t)
 return t and {d=t.d,v=t.v,hp=t.hp,cp=t.cp,cpD=t.cpD,cpHp=t.cpHp,total=t.total,
  pos=Copy(t.pos),yaw=t.yaw,far=t.far,blocked=t.blocked}
end
local function Radio(r)
 local slots={};for i,s in ipairs(r.slots)do slots[i]={order=s.order,playing=s.source and s.source.playing==true}end
 return {time=r.time,order=r.order,active=r.active,slots=slots}
end
local function Voice(v)
 local card=v.card
 return {queue=Copy(v.queue),card=card and {text=card.text,who=card.who,age=card.age,started=card.started,pending=card.pending},
  playing=v.source and v.source.playing==true,log=Copy(v.log)}
end
local function Record(kind,fields)
 fields=fields or {};fields.kind=kind;fields.frame=frame
 fields.ruleTime=attached and attached.rules.time;fields.worldTime=worldRef and worldRef.time
 calls[#calls+1]=fields;assert(#calls<180,'Convoy QA event capacity')
 if open then open.calls[#open.calls+1]=Copy(fields)end
 pending=true;return fields
end
local function Attach(m)
 attached=m;missionRef=m;worldRef=app.trial.world;generation=generation+1
 local banner=m.Banner;m.Banner=function(self,kick,title,sub,kind,ms,...)
  local result=banner(self,kick,title,sub,kind,ms,...)
  if kick=='检查点'then
   assert(not open,'Checkpoint dispatch spans unexpected nested checkpoint')
   local t=self.convoy
   open={mission=self.level.id,checkpoint=t.cp,sequence=#checkpoints+1,frame=frame,generation=generation,
    failures=self.rules.stats.fails,d=t.d,total=t.total,hp=t.hp,cpD=t.cpD,cpHp=t.cpHp,
    saved=Copy(self.rules.checkpoint),calls={}}
   checkpoints[#checkpoints+1]=open
  end
  Record('Banner',{kick=kick,title=title,sub=sub,style=kind,ms=ms,banner=Copy(self.banner)})
  return result
 end
 local play=m.radio.Play;m.radio.Play=function(self,cue,...)
  local result=play(self,cue,...);local playing=false
  for _,slot in ipairs(self.slots)do if slot.order==self.order and slot.source and slot.source.playing then playing=true end end
  Record('radio',{cue=cue,accepted=result==true,playing=playing,radio=Radio(self)});return result
 end
 local say=m.voice.Say;m.voice.Say=function(self,lines,urgent,...)
  local before=Voice(self);local result=say(self,lines,urgent,...)
  Record('say',{lines=Copy(lines or {}),urgent=urgent==true,before=before,after=Voice(self)})
  return result
 end
 local dispose=m.Dispose;m.Dispose=function(self,...)
  local before={generation=generation,truck=Truck(self.convoy),worldTime=worldRef.time}
  local result=dispose(self,...)
  disposed={before=before,missionDisposed=self.disposed==true,voiceReleased=self.voice==nil,
   radioReleased=self.radio==nil,viewReleased=self.view==nil,convoyReleased=self.convoy==nil,entries=#self.entries}
  pending=true;return result
 end
 Record('attached',{mission=m.level.id,generation=generation})
end
local function Prepare(m)
 assert(m==attached and not app.loadingFlow.active and not app.trial.dialog,'Unblocked actual mission required')
 local r=m.rules;local s=r:StepSpec();assert(s)
 local before={truck=Truck(m.convoy),index=r.index,progress=r.progress,time=r.time,stats=Copy(r.stats),
  checkpoint=Copy(r.checkpoint),beats=Copy(r.beatsFired),voice=Voice(m.voice),player=Copy(m.player:Position())}
 local kind;local requested
 if s.kind=='reach'then
  assert(s.id=='meet');kind='meet';requested={pos={s.pos[1],s.pos[2]+1.5,s.pos[3]},yaw=0}
 else
  assert(s.kind=='escort');local t=m.convoy;assert(t.cp<2)
  kind='checkpoint-'..(t.cp+1)
  t.d=s.checkpoints[t.cp+1]*t.total-.001;t.v=s.speed;t.pos,t.yaw=t:Along(t.d)
  requested={pos={t.pos[1],t.pos[2]+1.5,t.pos[3]},yaw=t.yaw}
 end
 m:Place(requested)
 local after={truck=Truck(m.convoy),index=r.index,progress=r.progress,time=r.time,stats=Copy(r.stats),
  checkpoint=Copy(r.checkpoint),beats=Copy(r.beatsFired),voice=Voice(m.voice),player=Copy(m.player:Position())}
 local record=Record('explicit-qa-place',{placement=kind,requestedPlace=Copy(requested),before=before,after=after})
 preparations[#preparations+1]=Copy(record)
end
local function Emit()
 sequence=sequence+1;local t=app and app.trial;local m=t and t.story;local r=m and m.rules
 local w,h=UI.GetViewportSize()
 local state={sequence=sequence,frame=frame,width=w,height=h,mode=app and app.mode,loading=app and app.loadingFlow.active,
  widgets={},captured=t and t.pointer and t.pointer.captured,intro=t and t.intro and not t.intro.done,
  dialog=t and t.dialog~=nil,unified=t and t.dialog and t.dialog.unifiedSettings==true,
  generation=generation,sameMission=m~=nil and m==missionRef,checkpoints=checkpoints,preparations=preparations,
  calls=calls,disposed=disposed,worldReleased=worldRef and worldRef.disposed==true,
  terrainReleased=worldRef and worldRef.disposed==true and worldRef.visualGround==nil}
 if m then
  local s=r:StepSpec();state.story={id=m.level.id,index=r.index,step=s and s.id,time=r.time,progress=r.progress,
   stats=Copy(r.stats),choice=Copy(r.choice),flags=Copy(r.flags),checkpoint=Copy(r.checkpoint),finished=r.finished,
   failing=r.failAt~=nil,truck=Truck(m.convoy),voice=Voice(m.voice),banner=Copy(m.banner),radio=Radio(m.radio),
   alive=m.player.alive,worldTime=worldRef.time}
 end
 local home=Garage.GetState();local holo=home and home.storyHolo
 if holo then local gate=holo.gate
  state.holo={level=holo.level,ready=holo.ready,downloaded=holo.downloaded,disposed=holo.disposed,failure=holo.failure,
   gate=gate and {state=gate.state,activeGroup=gate.group~=nil,failure=gate.failure}}
 end
 local function Walk(widget)
  if not widget:IsVisible()then return end
  if widget.props.onClick then local rect=widget:GetAbsoluteLayoutForHitTest()
   if rect.x==rect.x and rect.y==rect.y and rect.w>0 and rect.h>0 and math.abs(rect.x)<1e8 and math.abs(rect.y)<1e8 then
    state.widgets[#state.widgets+1]={text=widget.props.text or '',disabled=widget.props.disabled==true,rect={rect.x,rect.y,rect.w,rect.h}}
   end
  end
  for _,child in ipairs(widget.children or {})do Walk(child)end
 end
 local root=UI.GetRoot();if root then Walk(root)end
 local overlay=UI.GetTopOverlay();if overlay then Walk(overlay)
  if overlay.contentContainer_ then Walk(overlay.contentContainer_)end
  if overlay.footerWidget_ then Walk(overlay.footerWidget_)end
 end
 if app and app.tutorial and app.tutorial.visible then for _,button in ipairs(app.tutorial.page.buttons or {})do
  state.widgets[#state.widgets+1]={text=button.text,rect={button.x,button.y,button.w,button.h}}
 end end
 local text=cjson.encode(state);assert(cjson.decode(text));local hash=2166136261
 for i=1,#text do hash=((hash~text:byte(i))*16777619)&0xffffffff end
 local chunks={};local first=1
 while first<=#text do local last=math.min(first+599,#text)
  while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<192 do last=last-1 end
  chunks[#chunks+1]=text:sub(first,last);first=last+1
 end
 for i,chunk in ipairs(chunks)do print('CONVOY_CONTROLLED_CHUNK '..cjson.encode({kind='state-'..sequence,index=i,count=#chunks,bytes=#text,checksum=hash,data=chunk}))end
end
local update=HandleUpdate
function HandleUpdate(...)
 frame=frame+1;open=nil;update(...)
 local m=app and app.trial and app.trial.story
 if m and m~=attached then assert(m.level.id=='s2','Convoy QA requires public S2 entry');Attach(m)end
 if input:GetKeyPress(KEY_F7)then pending=true end
 if input:GetKeyPress(KEY_F10)then assert(m);Prepare(m)end
end
local post=HandlePostUpdate
function HandlePostUpdate(...)
 post(...);open=nil;if pending then pending=false;Emit()end
end
end

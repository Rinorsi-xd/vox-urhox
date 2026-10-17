-- Isolated controlled S5 consumer check; all impact methods call production code.
_G.VOX_SKIP_TUTORIAL=true
do
local UI=require 'urhox-libs/UI'
local sequence,frame=0,0
local pending=true
local missionRef,worldRef,bossRef=nil,nil,nil
local cases,actions={},{}
local setup,disposed=nil,nil
local function Copy(value)
 if type(value)~='table'then return value end
 local out={};for key,child in pairs(value)do out[key]=Copy(child)end;return out
end
local function Player(u)
 return {alive=u.alive,position=Copy(u:Position()),health=u:Health(),structure=u.struct,
  parts=#u.bp:List()}
end
local function Attach(m)
 assert(m.level.id=='s5','Boss missile QA requires actual S5')
 missionRef=m;worldRef=m.world
 local dispose=m.Dispose
 m.Dispose=function(self,...)
  local result=dispose(self,...)
  disposed={mission=self.disposed==true,boss=bossRef and bossRef.disposed==true,
   voice=self.voice==nil,radio=self.radio==nil,view=self.view==nil,entries=#self.entries}
  pending=true;return result
 end
end
local function Exercise(session)
 assert(#cases==0 and not setup,'One controlled Boss check per process')
 local m=session.story;assert(m==missionRef and m.rules.begun and m.player.alive)
 local before={index=m.rules.index,time=m.rules.time,stats=Copy(m.rules.stats),player=Player(m.player)}
 m.rules:Go(2);m:Events()
 local boss=assert(m.boss,'Actual Mission.Events must create Boss');bossRef=boss
 assert(#boss.pending==0 and #boss.missiles==0 and boss.raid==nil,'Fresh actual Boss required')
 boss.rules:Go('fight');boss.flow.stage='fight'
 setup={before=before,index=m.rules.index,time=m.rules.time,mission=m.level.id,
  bossParts=#boss.unit.bp:List(),bossAlive=boss.unit.alive,flow=boss.flow.stage,
  authoredOutsideAbsent=boss.step.lines.outside==nil,
  boundary='Explicit QA Rules.Go(2)/Events and Boss fight state, no natural encounter or cinematic claim'}
 local player=m.player
 local explode,flush,ray,fx=player.Explode,player.Flush,worldRef.CastRay,boss.Fx
 local active=nil
 player.Explode=function(self,at,radius,damage,...)
  assert(active);active.explodeCalls=active.explodeCalls+1
  active.explosion={at=Copy(at),radius=radius,damage=damage,attackerIsBoss=worldRef.attacker==boss.unit}
  local result=explode(self,at,radius,damage,...);active.dealt=(active.dealt or 0)+(result or 0);return result
 end
 player.Flush=function(self,...)
  assert(active);active.flushCalls=active.flushCalls+1;return flush(self,...)
 end
 worldRef.CastRay=function(self,origin,direction,length,exclude,...)
  local hit=ray(self,origin,direction,length,exclude,...)
  if active then active.rays[#active.rays+1]={origin=Copy(origin),direction=Copy(direction),length=length,
   excludesPlayer=exclude==player.vehicle.body,hit=hit~=nil,dist=hit and hit.dist,
   ownerIsPlayer=hit and hit.owner and hit.owner.ref==player or false,
   ownerIsBoss=hit and hit.owner and hit.owner.ref==boss.unit or false}end
  return hit
 end
 boss.Fx=function(self,...)
  assert(active);active.fxCalls=active.fxCalls+1;return fx(self,...)
 end
 local function Impact(name,offset,trauma)
  local pos=player:Position();local at={pos[1]+offset,pos[2]+1.2,pos[3]}
  local hitBefore=m.rules.stats.missileHits or 0
  local record={name=name,frame=frame,offset=offset,traumaBefore=trauma,before=Player(player),
   hitsBefore=hitBefore,missilesBefore=#boss.missiles,explodeCalls=0,flushCalls=0,fxCalls=0,rays={}}
  active=record;session.trauma=trauma
  boss:AddMissile(at,at,at,1,7.5,5,false)
  record.enqueued=#boss.missiles
  boss:Projectiles(1)
  record.hitsAfter=m.rules.stats.missileHits or 0;record.hitDelta=record.hitsAfter-hitBefore
  record.traumaAfter=session.trauma;record.remaining=#boss.missiles;record.after=Player(player)
  record.attackerCleared=worldRef.attacker==nil
  cases[#cases+1]=record;active=nil
 end
 local ok,err=pcall(function()
  Impact('player-impact',0,0)
  Impact('stronger-impact',0,.8)
  Impact('distant-miss',50,0)
 end)
 player.Explode=explode;player.Flush=flush;worldRef.CastRay=ray;boss.Fx=fx
 setup.wrappersRestored=player.Explode==explode and player.Flush==flush and worldRef.CastRay==ray and boss.Fx==fx
 setup.afterTime=m.rules.time;setup.finalMissiles=#boss.missiles
 assert(ok,tostring(err));pending=true
end
local function Emit()
 sequence=sequence+1
 local trial=app and app.trial;local m=trial and trial.story
 local w,h=UI.GetViewportSize()
 local state={sequence=sequence,frame=frame,width=w,height=h,mode=app and app.mode,
  loading=app and app.loadingFlow.active,releaseWaiting=app and app.pendingAssetRelease~=nil,
  appReady=app~=nil,trial=trial~=nil,widgets={},captured=trial and trial.pointer and trial.pointer.captured==true,
  intro=trial and trial.intro and not trial.intro.done,dialog=trial and trial.dialog~=nil,
  unified=trial and trial.dialog and trial.dialog.unifiedSettings==true,
  actions=actions,setup=setup,cases=cases,disposed=disposed,sameMission=m~=nil and m==missionRef,
  worldReleased=worldRef and worldRef.disposed==true,
  terrainReleased=worldRef and worldRef.disposed==true and worldRef.visualGround==nil,
  warmFrames=app and app.loadingFlow.warmFrames}
 if m then state.story={id=m.level.id,begun=m.rules.begun,index=m.rules.index,time=m.rules.time,
  alive=m.player.alive,boss=m.boss~=nil,bossFlow=m.boss and m.boss.flow.stage}end
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
 local text=cjson.encode(state);assert(cjson.decode(text));local hash=2166136261
 for i=1,#text do hash=((hash~text:byte(i))*16777619)&0xffffffff end
 local chunks={};local first=1
 while first<=#text do local last=math.min(first+599,#text)
  while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<192 do last=last-1 end
  chunks[#chunks+1]=text:sub(first,last);first=last+1
 end
 for i,chunk in ipairs(chunks)do print('BOSS_MISSILE_CHUNK '..cjson.encode({kind='state-'..sequence,index=i,count=#chunks,bytes=#text,checksum=hash,data=chunk}))end
end
local update=HandleUpdate
function HandleUpdate(...)
 frame=frame+1;update(...)
 local m=app and app.trial and app.trial.story
 if m and m~=missionRef then Attach(m)end
 if input:GetKeyPress(KEY_F7)then pending=true end
 if input:GetKeyPress(KEY_F4)then
  assert(app and not app.trial and not app.loadingFlow.active,'Actual hall required')
  local result=app:EnterTrial('story5');actions[#actions+1]={kind='EnterTrial',map='story5',accepted=result==true,frame=frame}
  assert(result==true,'Actual production story5 loading request');pending=true
 end
 if input:GetKeyPress(KEY_F10)then assert(app and app.trial and not app.loadingFlow.active);Exercise(app.trial)end
end
local post=HandlePostUpdate
function HandlePostUpdate(...)
 post(...);if pending then pending=false;Emit()end
end
end

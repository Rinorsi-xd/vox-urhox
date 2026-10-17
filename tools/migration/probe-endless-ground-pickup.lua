-- Request-only controlled pickup check: real enemy death and real Run inventory.
do
local UI=require 'urhox-libs/UI'
local Garage=require 'ui.GarageHud'
local stage,serial=0,0
local frozen=false
local selected=nil ---@type table|nil
local checks={}
local function Check(ok,label)assert(ok,label);checks[#checks+1]=label end
local function Context()local s=app and app.trial;return s,s and s.endless end
local function Emit(data)
 local text=cjson.encode(data);assert(cjson.decode(text),'Complete pickup JSON')
 local hash=2166136261;for i=1,#text do hash=((hash~text:byte(i))*16777619)&0xffffffff end
 local chunks={};local first=1
 while first<=#text do local last=math.min(first+599,#text)
  while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<192 do last=last-1 end
  chunks[#chunks+1]=text:sub(first,last);first=last+1
 end
 for i,part in ipairs(chunks)do print('ENDLESS_PICKUP_CHUNK '..cjson.encode({kind='state-'..data.sequence,index=i,count=#chunks,bytes=#text,checksum=hash,data=part}))end
end
local function Snapshot()
 if not app then return end
 serial=serial+1;local s,e=Context();local w,h=UI.GetViewportSize();local home=Garage.GetState()
 local data={sequence=serial,stage=stage,frozen=frozen,width=w,height=h,mode=app.mode,tab=home and home.tab,loading=app.loadingFlow.active,widgets={},checks=checks,
  boundary='CONTROLLED PICKUP: real spawned enemy destroyed above terrain; vehicle teleports and temporary simulation freeze. No natural-play or FPS acceptance.'}
 data.captured=s and s.pointer and s.pointer.captured==true or false
 local function Button(text,disabled,x,y,width,height)
  if width and height and width>0 and height>0 then data.widgets[#data.widgets+1]={text=text,disabled=disabled,rect={x,y,width,height}}end
 end
 local function Walk(widget)
  if not widget:IsVisible()then return end
  if widget.props.onClick then local r=widget:GetAbsoluteLayoutForHitTest();Button(widget.props.text or '',widget.props.disabled==true,r.x,r.y,r.w,r.h)end
  for _,child in ipairs(widget.children or {})do Walk(child)end
 end
 local root=UI.GetRoot();if root then Walk(root)end
 local overlay=UI.GetTopOverlay();if overlay then Walk(overlay);if overlay.contentContainer_ then Walk(overlay.contentContainer_)end;if overlay.footerWidget_ then Walk(overlay.footerWidget_)end end
 if app.tutorial and app.tutorial.visible then for _,b in ipairs(app.tutorial.page.buttons or {})do Button(b.text,false,b.x,b.y,b.w,b.h)end end
 if e then
  local alive=0;for _ in pairs(e.run.alive)do alive=alive+1 end
  data.run={state=e.run.state,wave=e.run.wave,enemies=alive,pending=#e.run.queue,credits=e.run.credits,player=e.player:Position()}
  if selected then
   local item=e.view.drops[selected.id]
   data.selected={id=selected.id,death=selected.death,ground=selected.ground,amount=selected.amount,before=selected.before,
    pending=e.run.pendingDrops[selected.id]~=nil,visual=item~=nil,worldTime=e.world.time}
   if item then local p=item.root.position;data.selected.root={-p.x,p.y,p.z};data.selected.collecting=item.collectedAt~=nil end
  end
 end
 Emit(data)
end
local function Place(unit,target)
 local body=unit.vehicle.body;local q=body.rotation()
 local yaw=math.atan(2*(q.w*q.y+q.x*q.z),1-2*(q.y*q.y+q.x*q.x))
 unit.vehicle:Place(target,yaw)
 -- Vehicle.Place anchors the lowest shape, while pickup uses the body's COM.
 local before=unit:Position();local p=body.translation()
 body.setTranslation({x=p.x+target[1]-before[1],y=p.y+target[2]-before[2],z=p.z+target[3]-before[3]})
 unit:SavePose();unit.previous=unit.current
end
local function Advance()
 local s,e=Context();assert(e and not app.loadingFlow.active,'Production endless required')
 if stage==0 then
  Check(e.run.state=='combat' and #e.run.queue>0 and e.entries[2] and e.entries[2].unit.alive,'Natural first enemy before wave clear')
  local u=e.entries[2].unit;local p=e.player:Position();local x,z=p[1]+24,p[3]
  local ground=e.world:GroundAt(x,z);ground=type(ground)=='table'and ground.h or ground;assert(type(ground)=='number','Actual ground height')
  local before=e.run.credits;local first=e.run.dropSerial;Place(u,{x,ground+40,z})
  local core=assert(u.bp:CoreParts()[1],'Actual enemy core');u:Damage(core.id,1e9,u:Position());u:Flush();Check(not u.alive,'Actual spawned enemy destroyed')
  e:AfterStep(0);Check(e.run.state=='combat','Other wave enemies retained')
  for i=first+1,e.run.dropSerial do local id='drop-'..i;local drop=e.run.pendingDrops[id]
   if drop and drop.credits then selected={id=id,death=drop.pos,ground=ground,amount=drop.credits,before=before};break end
  end
  Check(selected~=nil,'Actual Run.EnemyKilled generated credit drop')
  local item=assert(e.view.drops[selected.id]);Check(math.abs(item.root.position.y-ground-.1)<.001,'Visible root projected to ground plus .1m')
  Check(e.run.credits==before,'Distant drop has not modified wallet');frozen=true;stage=1
 elseif stage==1 then
  Place(e.player,selected.death);e:SyncPlayer();e.view:Update(e,0);e:Events()
  Check(e.run.pendingDrops[selected.id]~=nil and e.run.credits==selected.before,'Original airborne death point cannot pick up ground loot');stage=2
 elseif stage==2 then
  Place(e.player,{selected.death[1]+1,selected.ground+.1,selected.death[3]});e:SyncPlayer();e.view:Update(e,0);e:Events()
  Check(e.run.pendingDrops[selected.id]==nil,'Actual displayed ground drop picked up within source radius')
  Check(e.run.credits==selected.before+selected.amount,'Actual Run pickup credits wallet exactly once')
  Check(e.view.drops[selected.id].collectedAt~=nil,'Same-frame pickup event starts absorption');stage=3
 elseif stage==3 then frozen=false;stage=4
 else error('One pickup sequence per process')end
 Snapshot()
end
local update=HandleUpdate
function HandleUpdate(...)
 if not frozen then update(...)end
 if input:GetKeyPress(KEY_F10)then app:SelectEndless()end
 if input:GetKeyPress(KEY_F11)then Advance()end
 if input:GetKeyPress(KEY_F7)then Snapshot()end
end
local post=HandlePostUpdate
function HandlePostUpdate(...)if not frozen then post(...)end end
end

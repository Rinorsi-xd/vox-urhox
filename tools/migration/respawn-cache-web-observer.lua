-- Explicit isolated integration input, appended to frozen production main.
_G.VOX_SKIP_TUTORIAL=true
do
local UI=require 'urhox-libs/UI'
local Garage=require 'ui.GarageHud'
local cache,target=nil,nil
local initial,death=nil,nil
local pending=false
local sequence=0
local function Chunk(value)
 local text=cjson.encode(value)
 assert(cjson.decode(text),'Complete state JSON')
 local hash=2166136261
 for i=1,#text do hash=((hash~text:byte(i))*16777619)&0xffffffff end
 local parts={};local first=1
 while first<=#text do
  local last=math.min(first+599,#text)
  while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<192 do last=last-1 end
  parts[#parts+1]=text:sub(first,last);first=last+1
 end
 for i,p in ipairs(parts)do print('RESPAWN_CACHE_WEB_CHUNK '..cjson.encode({kind='state-'..value.sequence,index=i,count=#parts,bytes=#text,checksum=hash,data=p}))end
end
local function CacheState()
 if not cache then return nil end
 return {prepared=cache.prepared,hits=cache.hits,misses=cache.misses,disposed=cache.disposed,empty=next(cache.entries)==nil}
end
local function Snapshot()
 if not app then return end
 local t=app.trial;local b=t and t.battle
 if b and b.rules and b.entries and #b.entries==8 and not app.loadingFlow.active and not cache then
  cache=b.spawnSpecCache
  assert(cache and #b.entries==8,'Actual production eight-car battle/cache required')
  initial=CacheState()
 end
 sequence=sequence+1
 local w,h=UI.GetViewportSize();local home=Garage.GetState()
 local state={sequence=sequence,width=w,height=h,mode=app.mode,tab=home and home.tab,
  loading=app.loadingFlow.active,widgets={},intro=t and t.intro and not t.intro.done,
  captured=t and t.pointer and t.pointer.captured,battle=b and b.rules and {state=b.rules.state,mode=b.mode,count=#(b.entries or {})},
  cache=CacheState(),initial=initial,death=death,target=target and {alive=target.alive,deadAt=target.deadAt,parts=target.bp:Size()},worldTime=t and t.world and t.world.time}
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
 if app.tutorial and app.tutorial.visible then for _,v in ipairs(app.tutorial.page.buttons or {})do
  state.widgets[#state.widgets+1]={text=v.text,disabled=false,rect={v.x,v.y,v.w,v.h}}
 end end
 Chunk(state)
end
local function Kill()
 assert(not death,'One explicit isolated QA death per process')
 local b=app and app.trial and app.trial.battle
 assert(b and b.rules.state=='live' and b.mode=='conquest' and cache and not cache.disposed)
 for _,e in ipairs(b.entries)do if e.unit~=b.player and e.unit.alive then target=e.unit;break end end
 assert(target,'Live actual NPC required')
 local count=target.bp:Size();local core=nil
 for id,p in pairs(target.bp.parts)do if p.type=='core' then core=id;break end end
 assert(core,'Actual core required')
 local before=cache.hits
 target:Destroy(core);target:Flush()
 assert(not target.alive and target.deadAt==app.trial.world.time,'Actual Destroy/Flush/Die required')
 death={parts=count,deadAt=target.deadAt,hits=before,respawnSeconds=b.rules.cfg.respawn,
  boundary='Explicit isolated QA core destruction; actual production Die and BeforeStep respawn, no clock/deadAt edits; not natural death or performance evidence.'}
 pending=true
end
local update=HandleUpdate
function HandleUpdate(...)
 update(...)
 if input:GetKeyPress(KEY_F10)then Kill()end
 if input:GetKeyPress(KEY_F7)then pending=true end
end
local post=HandlePostUpdate
function HandlePostUpdate(...)
 post(...)
 if pending then pending=false;Snapshot()end
end
end

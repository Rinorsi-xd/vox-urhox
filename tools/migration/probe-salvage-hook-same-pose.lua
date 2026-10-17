-- Request-only diagnostic suffix. Freeze simulation for a strict visibility ABA.
do
local UI=require 'urhox-libs/UI'
local Garage=require 'ui.GarageHud'
local serial,stage=0,0
local frozen=false
local pendingAdvance=false
local saved=nil ---@type table|nil
local modelData=require('core.ResourceData').Read('SalvageCine/Manifest.json')
local function V(p)return {p.x,p.y,p.z}end
local function Q(q)return {q.w,q.x,q.y,q.z}end
local function Node(n)return {position=V(n.worldPosition),rotation=Q(n.worldRotation),scale=V(n.worldScale),enabled=n.enabled}end
local function Context()
 local s=app and app.trial
 local c=s and s.salvage and s.salvage.cine
 return s,c,c and c.view
end
local function Checksum(text)
 local hash=2166136261
 for i=1,#text do hash=((hash~text:byte(i))*16777619)&0xffffffff end
 return hash
end
local function Emit(value)
 local text=cjson.encode(value);assert(cjson.decode(text),'Incomplete JSON encoding')
 local chunks={};local first=1
 while first<=#text do
  local last=math.min(first+599,#text)
  while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<192 do last=last-1 end
  chunks[#chunks+1]=text:sub(first,last);first=last+1
 end
 for i,part in ipairs(chunks)do
  print('SALVAGE_HOOK_CHUNK '..cjson.encode({kind='state-'..value.sequence,index=i,count=#chunks,bytes=#text,checksum=Checksum(text),data=part}))
 end
end
local function Snapshot()
 if not app then return end
 serial=serial+1
 local w,h=UI.GetViewportSize();local home=Garage.GetState();local s,c,v=Context()
 local data={sequence=serial,width=w,height=h,mode=app.mode,tab=home and home.tab,loading=app.loadingFlow.active,
  stage=stage,frozen=frozen,pendingAdvance=pendingAdvance,widgets={},run=c and {playing=c.playing,time=s.salvage.rules.time,
   name=c.current and c.current.name,shotTime=c.current and c.current.t,landed=s.salvage.landed==true},
  result=app.pendingSalvageResult and {shown=app.pendingSalvageResult.shown},captured=s and s.pointer.captured,
  boundary='CONTROLLED DIAGNOSTIC: simulation frozen during ABA; not natural gameplay or FPS evidence'}
 local function Button(text,disabled,x,y,width,height)
  if width and height and width>0 and height>0 then data.widgets[#data.widgets+1]={text=text,disabled=disabled,rect={x,y,width,height}}end
 end
 local function Walk(widget)
  if not widget:IsVisible()then return end
  if widget.props.onClick then local r=widget:GetAbsoluteLayoutForHitTest();Button(widget.props.text or '',widget.props.disabled==true,r.x,r.y,r.w,r.h)end
  for _,child in ipairs(widget.children or {})do Walk(child)end
 end
 local root=UI.GetRoot();if root then Walk(root)end
 local overlay=UI.GetTopOverlay();if overlay then
  Walk(overlay);if overlay.contentContainer_ then Walk(overlay.contentContainer_)end
  if overlay.footerWidget_ then Walk(overlay.footerWidget_)end
 end
 if app.tutorial and app.tutorial.visible then
  for _,b in ipairs(app.tutorial.page.buttons or {})do Button(b.text,false,b.x,b.y,b.w,b.h)end
 end
 if c then
  local camera=s.camera:GetCamera();local n=s.camera:GetNode();local body=s.vehicle.body
  data.pose={camera=Node(n),fov=camera.fov,near=camera.nearClip,vehicle={position=V(body.translation()),rotation=body.rotation()},
   holder=Node(v.nodes.holder),frame=Node(v.nodes.frame),runTime=s.salvage.rules.time}
  data.hook={visible=v.hookMesh.enabled,guarded=v.hookHidden==true,localCamera=V(v.hookMesh.node:WorldToLocal(n.worldPosition))}
  data.meshes={}
  -- Deterministic identity/order from the frozen source manifest, all 32 batches.
  for i,d in ipairs(modelData.models)do
   local node=v.nodes[d.motion];local found=nil
   for _,child in ipairs(node:GetChildren())do
    local mesh=child:GetComponent('StaticModel')
    if mesh and mesh.model.name==d.model then found=mesh;break end
   end
   assert(found,'Missing cinematic batch '..d.model)
   data.meshes[i]={model=d.model,motion=d.motion,visible=found.enabled,node=Node(found.node)}
  end
 end
 Emit(data)
end
local function Advance()
 local s,c,v=Context();assert(c and s.salvage.landed and not c.playing and not app.loadingFlow.active,'Require natural completed deployment')
 local camera=s.camera:GetCamera();local n=s.camera:GetNode();local frame=v.nodes.frame
 if stage==0 then
  assert(v.hookMesh and v.hookMin and v.hookMax,'Actual candidate guard required')
  assert(not s.world.space.world.updateEnabled,'Physics must be explicitly stepped by gameplay')
  saved={position=n.worldPosition,rotation=n.worldRotation,fov=camera.fov,near=camera.nearClip,
   hookVisible=v.hookMesh.enabled,hookHidden=v.hookHidden}
  frozen=true
  -- Replay the actual brown screenshot's frame-local pose. Relative yaw was -90deg.
  n.worldPosition=frame:LocalToWorld(Vector3(1.2348492713317207,5.801732063293457,.13478404482002687))
  n.worldRotation=frame.worldRotation*Quaternion(6.875493541569878,-90,0)
  v.hookMesh:SetEnabled(true);v.hookHidden=false;stage=1
 elseif stage==1 then
  assert(v:GuardCamera(n,true),'Near replay must activate actual candidate guard');stage=2
 elseif stage==2 then
  v.hookMesh:SetEnabled(true);v.hookHidden=false;stage=3
 elseif stage==3 then
  n.worldPosition=frame:LocalToWorld(Vector3(0,6,-12));n.worldRotation=frame.worldRotation
  assert(not v:GuardCamera(n,true) and v.hookMesh.enabled,'Distant hook must remain visible');stage=4
 elseif stage==4 then
  -- Restore exact saved chase pose/state before public abandonment.
  n.worldPosition=saved.position;n.worldRotation=saved.rotation;camera.fov=saved.fov;camera.nearClip=saved.near
  v.hookMesh:SetEnabled(saved.hookVisible);v.hookHidden=saved.hookHidden
  stage=5;frozen=false;saved=nil
 else error('One diagnostic sequence per process')end
 Snapshot()
end
local update=HandleUpdate
function HandleUpdate(...)
 if input:GetKeyPress(KEY_F11)then pendingAdvance=true end
 if not frozen then update(...)end
 if pendingAdvance then
  local s,c=Context()
  if c and s.salvage.landed and not c.playing and not app.loadingFlow.active then pendingAdvance=false;Advance()end
 end
 if input:GetKeyPress(KEY_F7)then Snapshot()end
end
local post=HandlePostUpdate
function HandlePostUpdate(...)if not frozen then post(...)end end
end

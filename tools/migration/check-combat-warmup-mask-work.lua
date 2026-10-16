-- Compare complete presented state of actual old/new modules, not a copied planner.
COMBAT_WARMUP_TEST_HELPERS=true
local helpers=assert(loadfile('tools/migration/check-combat-warmup.lua'))()
graphics={GetHeight=function()return 2160 end,GetDPR=function()return 2 end}
local Node=helpers.Node
local Create=Node.CreateComponent
local writes=0
function Node:CreateComponent(kind)
 local d=Create(self,kind);local mask=d.viewMask;d.viewMask=nil
 local original=getmetatable(d).__index
 local identity=(self.name or 'scene')..'/'..kind..'/'..#self.components
 setmetatable(d,{__tostring=function()return identity end,__index=function(t,key)if key=='viewMask'then return mask end;return original(t,key)end,
  __newindex=function(t,key,value)if key=='viewMask'then mask=value;writes=writes+1 else rawset(t,key,value)end end})
 return d
end
local Old=assert(load(OLD_SOURCE))()
local Current=assert(load(CURRENT_SOURCE))()
local checks=0
local function check(ok,label)assert(ok,label);checks=checks+1 end
local function same(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function value(v)
 if type(v)=='table'then
  if v.x~=nil then return table.concat({v.x,v.y,v.z},',')end
  if v.r~=nil then return table.concat({v.r,v.g,v.b,v.a},',')end
 end
 return tostring(v)
end
local function fixture(groups,disabled,aim,flash)
 local s=helpers.session()
 for i=1,groups do
  local n=s.scene:CreateChild('extra'..i);n.position=Vector3(i%8,0,10)
  local d=n:CreateComponent(i%9==0 and 'CustomGeometry'or'StaticModel')
  if d.kind=='StaticModel'then d.model=cache:GetResource('Model','group-'..i);d.material={tag='material-'..i}end
  d.viewMask=i%7==0 and 13 or 7
 end
 for i=1,disabled do
  local n=s.scene:CreateChild('disabled'..i);n.enabled=false
  local d=n:CreateComponent('StaticModel');d.viewMask=i%2==0 and 0 or 19
  d.model=cache:GetResource('Model','hidden');d.material={tag='hidden'}
 end
 if aim then s.aimLines=require('render.AimLines').New(s.scene)end
 if flash then
  local source=s.scene:GetComponents('StaticModel',true)[1]
  local m=Material:new();m:SetSurfaceShader('Shaders/BLGL/RestoreFlash.shader');m:SetShaderParameter('joined_alpha',Variant(-1))
  s.restoreFlash={material=m};s.view={view={visuals={[1]={joined=false,models={source}}}}}
 end
 return s
end
local function collect(node,path,rows)
 path=path..'/'..(node.name or 'scene')
 rows[#rows+1]=table.concat({path,'node',value(node.position),value(node.scale),tostring(node.enabled),tostring(node.disposed)},'|')
 for i,d in ipairs(node.components)do
  rows[#rows+1]=table.concat({path,i,d.kind,d.viewMask,tostring(d.enabled),tostring(d.enabledEffective),
   d.vertices or 0,d.commits or 0,value(d.instanceColor),tostring(d.useInstanceColor),
   d.model and d.model.name or '',d.material and(d.material.tag or d.material.shader)or ''},'|')
 end
 for _,child in ipairs(node.children)do collect(child,path,rows)end
end
local function state(session,warm)
 local rows={};collect(session.scene,'',rows)
 rows[#rows+1]=table.concat({warm.phase or '',warm.index,warm.frames,tostring(warm.singleWorld),tostring(warm.singleVolume),
  tostring(warm.disposed),tostring(warm.completed),#warm.groups,#warm.proxies},'|')
 local fx=session.effects
 rows[#rows+1]=table.concat({fx.light.light.range,fx.light.light.brightness,tostring(fx.light.light.enabled),fx.missiles.view and fx.missiles.view.count or -1},'|')
 for name,batch in pairs(fx.batches)do rows[#rows+1]=table.concat({name,batch.count,tostring(batch.mesh.enabled),value(batch.material:GetShaderParameter('clock').value)},'|')end
 for _,name in ipairs({'beams','flares','rings','particles','smoke','flashes','zaps','trails'})do same(#fx[name],0,'no gameplay FX event '..name)end
 table.sort(rows);return rows
end
local function compare(a,b,label)
 same(#a,#b,'same scene graph size '..label)
 for i=1,#a do same(a[i],b[i],'same rendered/lifetime state '..label..'/'..i)end
end
local scenarios={}
local function run(groups,disabled,aim,flash,cancelAt,failAt,module)
 local a,b=fixture(groups,disabled,aim,flash),fixture(groups,disabled,aim,flash)
 local before=writes;local old=Old.New(a,{batchSize=8});local oldWrites=writes-before
 before=writes;local current=(module or Current).New(b,{batchSize=8});local currentWrites=writes-before
 local stages={};local frame=0
 while true do
  compare(state(a,old),state(b,current),'frame '..frame)
  stages[#stages+1]={phase=old.phase,index=old.index,proxies=#old.proxies}
  if old.disposed then break end
  if cancelAt==frame then
   before=writes;old:Dispose();oldWrites=oldWrites+writes-before
   before=writes;current:Dispose();currentWrites=currentWrites+writes-before
   compare(state(a,old),state(b,current),'cancel '..frame);break
  end
  if failAt==frame then
   a.effects.batches.Glow.mesh.Commit=function()error('injected upload failure')end
   b.effects.batches.Glow.mesh.Commit=function()error('injected upload failure')end
  end
  before=writes;local okOld,doneOld=pcall(old.Presented,old);oldWrites=oldWrites+writes-before
  before=writes;local okNew,doneNew=pcall(current.Presented,current);currentWrites=currentWrites+writes-before
  same(okNew,okOld,'same failure boundary')
  if okOld then same(doneNew,doneOld,'same completion frame')
  else
   check(tostring(doneOld):find('injected upload failure')~=nil,'actual injected failure');check(current.disposed,'error releases ownership')
   compare(state(a,old),state(b,current),'error '..frame);break
  end
  frame=frame+1;check(frame<1000,'bounded original schedule')
 end
 before=writes;old:Dispose();same(writes,before,'old disposal idempotent')
 before=writes;current:Dispose();same(writes,before,'current disposal idempotent')
 return {groups=#old.groups,disabled=disabled,frames=frame+1,oldWrites=oldWrites,currentWrites=currentWrites,stages=stages}
end
if rawget(_G,'ONLY_WORKLOAD')then return run(180,2800,true,true,nil,nil,Current)end
for _,spec in ipairs({{0,0,false,false},{1,3,true,false},{12,12,true,true},{18,40,false,true}})do
 scenarios[#scenarios+1]=run(table.unpack(spec))
end
local complete=run(12,10,true,true)
for frame=0,complete.frames-1 do scenarios[#scenarios+1]=run(12,10,true,true,frame)end
for frame=0,2 do scenarios[#scenarios+1]=run(12,10,true,true,nil,frame)end
for _,fault in ipairs({'reserve','upload','flash'})do
 local a,b=fixture(12,10,true,true),fixture(12,10,true,true)
 for _,s in ipairs({a,b})do
  if fault=='reserve'then s.effects.chips.Reserve=function()error('construction failure reserve')end
  elseif fault=='upload'then s.effects.batches.Glow.mesh.Commit=function()error('construction failure upload')end
  else s.restoreFlash.material.Clone=function()error('construction failure flash')end end
 end
 local okOld,errOld=pcall(Old.New,a);local okNew,errNew=pcall(Current.New,b)
 check(not okOld and not okNew,'both actual constructors fail '..fault)
 check(tostring(errOld):find('construction failure '..fault)~=nil and tostring(errNew):find('construction failure '..fault)~=nil,'real construction failure boundary '..fault)
 local disposed={phase='construction-failed',index=0,frames=0,disposed=true,completed=false,groups={},proxies={}}
 compare(state(a,disposed),state(b,disposed),'construction cleanup '..fault)
end
local large=run(180,2800,true,true)
check(large.currentWrites<large.oldWrites*.08,'mask-work budget: avoid full-scene setters on every batch')
return {checks=checks,scenarios=#scenarios+5,cancellationFrames=complete.frames,initializationFailures=3,workload=large}

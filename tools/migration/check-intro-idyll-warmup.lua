-- Execute production warmup and batching with CPU-only scene/camera adapters.
package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(ok,label)assert(ok,label);checks=checks+1 end
local function Vec(x,y,z)return{x=x,y=y,z=z}end
local function Sub(a,b)return Vec(a.x-b.x,a.y-b.y,a.z-b.z)end
local function Dot(a,b)return a.x*b.x+a.y*b.y+a.z*b.z end
local function Cross(a,b)return Vec(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x)end
local function Norm(a)local n=math.sqrt(Dot(a,a));return Vec(a.x/n,a.y/n,a.z/n)end
local noop=function()end
OUTSIDE=-1
package.loaded['core.Coord']={Vec=function(x,y,z)return Vec(-x,y,z)end}
local function Camera()
 local c={node={position=Vec(1,2,3),rotation={original=true}},fov=48}
 function c.node:LookAt(p)self.rotation={look=p}end
 c.frustum={IsInsideFast=function(_,box)
  if not box.real then return 1 end
  local f=Norm(Sub(c.node.rotation.look,c.node.position));local r=Norm(Cross(Vec(0,1,0),f));local u=Cross(f,r)
  local ty=math.tan(math.rad(c.fov/2));local tx=ty*16/9
  local maximum={-math.huge,-math.huge,-math.huge,-math.huge,-math.huge,-math.huge}
  for _,x in ipairs({box.min[1],box.max[1]})do for _,y in ipairs({box.min[2],box.max[2]})do for _,z in ipairs({box.min[3],box.max[3]})do
   local d=Sub(Vec(x,y,z),c.node.position);local a,b,v=Dot(d,r),Dot(d,u),Dot(d,f)
   local planes={a+v*tx,v*tx-a,b+v*ty,v*ty-b,v-.05,320-v}
   for i,n in ipairs(planes)do maximum[i]=math.max(maximum[i],n)end
  end end end
  for _,n in ipairs(maximum)do if n<0 then return OUTSIDE end end;return 1
 end}
 return c
end
local function Root(enabled)return{enabled=enabled,SetEnabledRecursive=function(self,on)self.enabled=on end}end
local material={};local common={numGeometries=1};local fixture
local function Drawable(model,mask,real)
 return{model=model,viewMask=mask,enabledEffective=true,worldBoundingBox=real or {},zone='zone',lightMask=3,shadowMask=5,zoneMask=7,
  castShadows=true,maxLights=4,useInstanceColor=false,useInstanceCustomData=false,GetMaterial=function()return material end}
end
local function Scene(glass)
 local d={};for i=1,9 do d[#d+1]=Drawable(common,11)end
 for i=1,9 do d[#d+1]=Drawable({numGeometries=1},13)end
 if glass then local box={real=true,min=GLASS_BOUNDS.min,max=GLASS_BOUNDS.max};d[#d+1]=Drawable({numGeometries=1},17,box);d[#d].glass=true end
 local cg=Drawable(nil,19);d[#d+1]=cg
 local dark=Drawable(common,0);d[#d+1]=dark
 local hidden=Drawable(common,23);hidden.enabledEffective=false;d[#d+1]=hidden
 local scene={drawables=d,cg=cg,lights={{enabled=true,node={enabled=true},lightType='Rect',castShadows=false,lightMask=3}}}
 function scene:GetComponents(kind)
  if kind=='Light' then return self.lights end
  if kind=='StaticModel' then local list={};for _,v in ipairs(d)do if v.model then list[#list+1]=v end end;return list end
  if kind=='CustomGeometry' then return{cg}end;return{}
 end
 return scene
end
local RealWarm=require 'render.SceneWarmup'
package.loaded['render.SceneWarmup']={New=function(scene,size,camera,accept)
 local batch=RealWarm.New(scene,size,camera,accept);local rec={sample=fixture.warm.sample,phase=fixture.warm.phase,index=fixture.warm.index,
  x=camera.node.position.x,y=camera.node.position.y,z=camera.node.position.z,fov=camera.fov,time=fixture.state.garage.time,
  common=0,glass=0,cg=0}
 for _,item in ipairs(batch.items)do local d=item.drawable
  if d.model==common then rec.common=rec.common+1 end
  if d.glass then rec.glass=rec.glass+1 end
  if d==scene.cg then rec.cg=rec.cg+1 end
 end
 fixture.records[#fixture.records+1]=rec;return batch
end}
local function Owned(kind)
 local o={kind=kind,Dispose=function(self)self.disposals=(self.disposals or 0)+1 end,Update=noop}
 fixture.owned[#fixture.owned+1]=o;return o
end
package.loaded['intro.IntroStrike']={New=function()return Owned('strike')end}
package.loaded['intro.IntroEquipmentWarmup']={New=function()local o=Owned('equipment');o.Single=function(self)self.single=true end;return o end}
package.loaded['render.CombatEffects']={New=function()
 local o=Owned('effects');o.light={light={}};o.chips={slots={{node={}},{node={}},{node={}},{node={}}}}
 o.Consume=function(_,events)fixture.effectEvents=#events end
 o.Update=function(_,_,missiles)fixture.missiles=#missiles end
 return o
end}
package.loaded['render.EffectBatch']={New=function(_,kind)
 local o=Owned(kind);o.Begin=noop;o.Disc=noop;o.Finish=noop;return o
end}
local Warm=require 'intro.IntroWarmup'
local function Fresh(props,hero,capture)
 local hall,crater=Camera(),Camera();local scenes={Scene(true),Scene(false)}
 local state={hall=scenes[1],scene=scenes[2],hallCamera=hall,garage={root=Root(props),time=0},hallActor={root=Root(hero)},
  assembly={WarmFlash=function(_,on)fixture.flash=on end},app={graphicsSettings={PostUpdate=noop},car={SetVisible=function(_,on)fixture.car=on end}}}
 state.hallActor.SetVisible=function(self,on)self.root.enabled=on end
 state.garage.Update=function(self,dt)self.time=self.time+dt end
 state.session={camera={GetCamera=function()return crater end},environment={Update=noop},combat={player={Position=function()return{0,1,2}end},montage={SetWarmVisible=function(_,on)fixture.montage=on end}}}
 local f={state=state,records={},owned={},done=0,scenes=scenes,poses={{hall.node.position,hall.node.rotation,hall.fov},{crater.node.position,crater.node.rotation,crater.fov}},masks={},props=props,hero=hero}
 fixture=f
 for _,scene in ipairs(scenes)do for _,d in ipairs(scene.drawables)do f.masks[d]=d.viewMask end end
 local host={UseScene=function(name)f.scene=name end,GroundAt=function()return 0 end}
 if capture then
  host.BeginLeaveCapture=function()
   Check(not state.garage.root.enabled and not state.hallActor.root.enabled and f.car==false,'capture excludes original props and both vehicle actors')
   local p=hall.node.position;local look=hall.node.rotation.look
   Check(p.x==-4 and p.y==1.6 and p.z==-34 and look.x==-7 and look.y==9 and look.z==-90 and hall.fov==56,'capture uses original leave background camera')
   for d,mask in pairs(f.masks)do Check(d.viewMask==mask,'capture sees full original masks')end
   f.captureBegins=(f.captureBegins or 0)+1;f.captureFrames=0
  end
  host.PresentLeaveCapture=function()f.captureFrames=f.captureFrames+1;return f.captureFrames==3 end
  host.CancelLeaveCapture=function()f.captureCancels=(f.captureCancels or 0)+1 end
 end
 f.warm=Warm.New(state,host,function()f.done=f.done+1 end)
 f.warm:Next();return f
end
local function Restored(f)
 for d,mask in pairs(f.masks)do Check(d.viewMask==mask,'exact original viewMask restored')end
 for i,c in ipairs({f.state.hallCamera,f.state.session.camera:GetCamera()})do local p=f.poses[i]
  Check(c.node.position==p[1] and c.node.rotation==p[2] and c.fov==p[3],'both original camera poses restored')
 end
 Check(f.state.garage.root.enabled==f.props and f.state.garage.time==0 and f.state.hallActor.root.enabled==f.hero,'original props visibility and clock restored')
 Check(f.flash==false and f.montage==false and f.car==false and f.scene=='garage','original warm visibility and host scene restored')
 for _,o in ipairs(f.owned)do Check(o.disposals==1,'private owner disposed exactly once')end
end
local f=Fresh(false,true);local warm=f.warm
Check(warm.phase=='idyll' and warm.sample=='idyll-start' and warm.index==1,'first original camera subpass stays within idyll phase')
Check(f.records[1].glass==1,'actual architecture glass AABB enters first camera batching')
local frames=0;local restSamples={}
repeat
 if warm.rest>0 then restSamples[warm.sample]=(restSamples[warm.sample] or 0)+1
  for d,mask in pairs(f.masks)do Check(d.viewMask==mask,'full original masks during presented rest frames')end
 end
 warm:Presented();frames=frames+1;Check(frames<300,'bounded presented progression')
until warm.completed
Check(f.done==1 and warm.index==8 and #warm.phases==7,'seven original phases and final callback preserved')
local expected={'idyll-start','idyll','idyll-crossing','build','brief','drive','effects','effects-single'}
Check(#f.records==#expected,'one added sample and all seven original samples')
for i,id in ipairs(expected)do local rec=f.records[i]
 Check(rec.sample==id,'original sample order '..id)
 Check(restSamples[id]==2,'two full-mask presented rest frames '..id)
 Check(rec.common==(id=='effects-single' and 1 or 4),'original four-copy and single-copy quotas '..id)
 if i<=3 then
  Check(rec.time==({0,3,6})[i],'first and original prop-time samples retained')
  Check(rec.x==({-7,-2,-2})[i] and rec.y==({1,5,5})[i] and rec.z==({-28,-40,-40})[i] and rec.fov==({52,46,46})[i],'exact original camera samples retained')
 end
end
Check(f.records[1].cg==1 and f.records[2].cg==1,'new sample cannot consume original custom-geometry deduplication')
Check(f.records[2].glass==0 and f.records[3].glass==0 and f.records[4].glass==0,'historical terminal and build glass exclusion reproduced')
Check(f.effectEvents==10 and f.missiles==1 and #f.owned==7,'all original effects and single-effect ownership retained')
Restored(f);warm:Dispose();warm:Presented();Check(f.done==1,'completed warmup remains idempotent');Restored(f)
for _,stop in ipairs({'new','active','first-rest','terminal','terminal-rest','effects','single'})do
 for _,enabled in ipairs({false,true})do
  local c=Fresh(enabled,not enabled);local w=c.warm;local n=0
  local function At()
   if stop=='new' then return true end
   if stop=='active' then return w.sample=='idyll-start' and w.batch and w.batch.batches>1 end
   if stop=='first-rest' then return w.sample=='idyll-start' and w.rest==1 end
   if stop=='terminal' then return w.sample=='idyll' and w.batch end
   if stop=='terminal-rest' then return w.sample=='idyll' and w.rest==1 end
   if stop=='effects' then return w.sample=='effects' and w.batch end
   return w.sample=='effects-single' and w.batch
  end
  while not At()do w:Presented();n=n+1;Check(n<300,'cancel checkpoint reachable '..stop)end
  w:Dispose();w:Dispose();w:Presented();Check(w.disposed and not w.completed and c.done==0,'cancel never completes narrative '..stop)
  Restored(c)
 end
end
for _,stopAt in ipairs({0,1,2,3})do
 local c=Fresh(false,true,true);local w=c.warm;local n=0
 while not w.leaveCapture do w:Presented();n=n+1;Check(n<300,'leave capture follows all original warmup samples')end
 Check(#c.records==8 and w.index==8 and c.done==0 and c.captureBegins==1,'leave capture is after all seven phases and before reveal')
 for i=1,stopAt do w:Presented();Check((c.done==1)==(i==3),'capture waits exactly three presented frames')end
 if stopAt<3 then
  w:Dispose();w:Dispose();w:Presented();Check(c.captureCancels==1 and c.done==0,'partial leave capture cancellation owns cleanup once')
 else Check(w.completed and w.disposed and c.done==1 and not c.captureCancels,'successful leave capture remains available to narrative')end
 Restored(c)
end
return{checks=checks,result='PASS',samples=expected,addedSample='idyll-start',originalPhases=7,cancellationCases=17,leaveCaptureCases=4}

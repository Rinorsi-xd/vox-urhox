-- Real loading, scene batching, grid visibility and reflection update modules.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks=0
local function check(v,label)assert(v,label);checks=checks+1 end
local web=true
package.loaded['urhox-libs/UI']={}
package.loaded['urhox-libs/UI/Core/ImageCache']={Release=function()end}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function()return web end}
package.loaded['app.ResourceGate']={New=function()return {Start=function(_,_,cb)cb(true)end,Cancel=function()end}end}
package.loaded['ui.LoadingPage']={New=function()return {Open=function()end,Close=function()end,Dispose=function()end}end}
for _,id in ipairs({'combat.ArenaData','combat.Matchmaker','app.DriveMaps','audio.BattleFlow','ui.MatchLobby',
 'scene.HangarPanels','render.RenderTargetLifetime','scene.HangarMotion','scene.HangarBuffers','Config'})do package.loaded[id]={}end
package.loaded['scene.HangarConfig']={room={},layout={}}
package.loaded['scene.HangarMaterials']={Set=function(mat,key,value)mat[key]=value end}
package.loaded['render.Quality']={current={reflectionHz=30}}
package.loaded['render.CombatWarmup']={New=function()error('hall must never warm combat')end}
local fxNew,fxPresented,fxDisposed,commsNew,commsPresented,commsDisposed=0,0,0,0,0,0
local portraitWanted=false
local failAt
package.loaded['story.TutorialFirstLine']={Pick=function()if portraitWanted then return 'nono','nono_smile' end end}
package.loaded['render.HangarFxWarmup']={New=function()
 if failAt=='fx-new'then error('fx-new')end
 fxNew=fxNew+1;local w={}
 function w:Presented()fxPresented=fxPresented+1;if failAt=='fx-present'then error('fx-present')end;self:Dispose();return true end
 function w:Dispose()if not self.disposed then self.disposed=true;fxDisposed=fxDisposed+1 end end
 return w
end}
package.loaded['ui.CommsWarmup']={Begin=function(who,face)
 check(who=='nono'and face=='nono_smile','actual first face passed through')
 if failAt=='comms-new'then return nil,'comms-new'end
 commsNew=commsNew+1;local w={frames=0}
 function w:Presented()
  commsPresented=commsPresented+1
  if failAt=='comms-present'then return false,'comms-present'end
  self.frames=self.frames+1;return self.frames>=2
 end
 function w:Dispose()if not self.disposed then self.disposed=true;commsDisposed=commsDisposed+1 end end
 return w
end}
Time={GetSystemTime=function()return 100 end}
Variant=function(value)return value end
OUTSIDE=0
local Hangar=require'scene.Hangar'
local Flow=FLOW_SOURCE and assert(load(FLOW_SOURCE))() or require'app.LoadingFlow'
local function fresh(kind)
 fxNew,fxPresented,fxDisposed,commsNew,commsPresented,commsDisposed=0,0,0,0,0,0
 web=kind~='native'
 local boundary={enabled=false};local guides={enabled=false}
 local nodes={{enabled=true},boundary,guides};local drawables={}
 for i,node in ipairs(nodes)do
  local d={viewMask=i*7,worldBoundingBox={}}
  setmetatable(d,{__index=function(_,key)if key=='enabledEffective'then return node.enabled end end})
  drawables[i]=d
 end
 local scene={GetComponents=function(_,id)if id=='CustomGeometry'then return drawables else return {}end end}
 local cam={fov=53,nearClip=.2,farClip=310,frustum={IsInsideFast=function()return 1 end}}
 renderer={GetViewport=function()return {camera=cam}end}
 local queueCount,resizeCount,gridCount=0,0,0
 local h=setmetatable({scene=scene,root={enabled=true},boundary=boundary,guides=guides,padMat={},guideMat={},
  grid=1,gridTarget=.3,frame=1,frameTarget=.8,time=0,greet=3.2,nextReflection=99,
  reflNode={SetWorldTransform=function(self,pos,rot)self.position=pos;self.rotation=rot end},
  reflCam={GetProjection=function()return 3 end,GetView=function()return 5 end},reflAspect=1.8},Hangar)
 function h.padMat:SetShaderParameter(key,value)self[key]=value end
 function h:ResizeReflection(actual)check(actual==cam,'reflection uses actual camera');resizeCount=resizeCount+1 end
 local app={scene=scene,hangar=h,camera={node={worldPosition='position',worldRotation='rotation'},camera=cam},
  graphicsSettings={SetSceneVisible=function()end}}
 local f=Flow.New(app)
 local function queue()
  check(f.active and f.warmFrames==0,'reflection remains under loading')
  for i,d in ipairs(drawables)do check(d.viewMask==i*7,'full masks restored before reflection')end
  check(h.reflNode.position=='position'and h.reflNode.rotation=='rotation','actual reflected view')
  queueCount=queueCount+1
 end
 h.reflTex={renderSurface={QueueUpdate=queue}};h.reflFilter={Queue=queue}
 function h:UpdateGrid(dt)check(dt==0,'zero-dt grid preparation');gridCount=gridCount+1;Hangar.UpdateGrid(self,dt)end
 if kind=='disabled'then h.root.enabled=false
 elseif kind=='foreign'then h.scene={}
 elseif kind=='disposed'then h.disposed=true
 elseif kind=='no-camera'then app.camera=nil
 elseif kind=='no-hangar'then app.hangar=nil
 elseif kind=='preview'then app.scene={GetComponents=scene.GetComponents}end
 f:Open({id=kind,boot=true});f:Finish()
 return f,h,drawables,function()return queueCount,resizeCount,gridCount end
end
do
 local f,h,drawables,counts=fresh('hall')
 check(#f.renderWarmup.items==3,'first-frame boundary and guide participate in warmup')
 check(h.boundary.enabled and h.guides.enabled,'first-frame visibility applied')
 check(h.grid==1 and h.frame==1 and h.time==0 and h.greet==3.2,'no animation advancement')
 check(counts()==0,'real reflection waits until masks restored')
 f:Rendered()
 local queues,resizes,grids=counts()
 check(queues==2 and resizes==1 and grids==1,'one actual reflection plus filter submission')
 check(h.padMat.refl_matrix==15 and h.nextReflection==1/30,'normal reflection state preserved')
 check(f.warmFrames==0,'restoration frame stays covered')
 f:Advance(1);check(f.phase=='loading','cannot reveal immediately')
 check(fxNew==1 and fxPresented==0,'FX submitted only after scene masks restored')
 f:Rendered();f:Advance(1);check(f.phase=='loading'and f.warmFrames==0,'FX presentation stays covered')
 check(fxPresented==1 and fxDisposed==1 and not f.hangarFxWarmup,'FX disposed after actual view presentation')
 f:Rendered();f:Advance(1);check(f.phase=='loading','one full frame insufficient')
 f:Rendered();f:Advance(0);check(f.phase=='ready','two full frames permit reveal')
 f:Close();check(counts()==2,'close does not requeue reflection')
end
do
 local f,h,drawables,counts=fresh('hall');f:Close()
 for i,d in ipairs(drawables)do check(d.viewMask==i*7,'cancellation restores masks')end
 f:Rendered();check(counts()==0,'cancel does not submit reflection')
 f:Open({id='return-hall',boot=true});f:Finish();f:Rendered()
 check(counts()==2,'return hall warms actual reflection again');f:Close()
end
for _,kind in ipairs({'native','disabled','foreign','disposed','no-camera','no-hangar','preview'})do
 local f,h,drawables,counts=fresh(kind)
 if kind=='native'then check(f.renderWarmup==nil,'native retains original warmup policy')end
 f:Rendered();f:Rendered();f:Rendered()
 local queues,resizes,grids=counts()
 check(queues==0 and resizes==0 and grids==0,kind..' does not update unrelated or invalid hall')
 check(fxNew==0 and commsNew==0,kind..' does not allocate unrelated warmup')
 f:Close()
end
do
 portraitWanted=true
 local f=fresh('hall');f:Rendered()
 check(commsNew==1 and commsPresented==0,'first actual portrait prepared under cover')
 f:Rendered();check(commsPresented==0,'FX presented before portrait gate')
 f:Rendered();check(f.warmFrames==0 and commsPresented==1,'one portrait submission insufficient')
 f:Rendered();check(f.warmFrames==0 and commsDisposed==1 and not f.commsWarmup,'portrait handed off before final frames')
 f:Rendered();f:Advance(1);check(f.phase=='loading','one final covered frame insufficient after both probes')
 f:Rendered();f:Advance(0);check(f.phase=='ready','two final frames still required')
 f:Close();check(commsDisposed==1 and fxDisposed==1,'completed owners not disposed twice')
end
for _,phase in ipairs({'fx-new','fx-present','comms-new','comms-present'})do
 local f=fresh('hall');failAt=phase
 for _=1,6 do f:Rendered()end
 check(f.failed and f.error:find(phase,1,true),'probe failure reaches loading error: '..phase)
 check(f.warmFrames==0 and not f.hangarFxWarmup and not f.commsWarmup,'failed probes cannot reveal or survive')
 check(fxDisposed==fxNew and commsDisposed==commsNew,'failed owners released exactly once')
 f:Close();failAt=nil
end
do
 local f=fresh('hall');f:Rendered();f:Close()
 check(fxNew==fxDisposed and commsNew==commsDisposed,'cancel releases both pending owners')
 f:Open({id='return-hall',boot=true});f:Finish();f:Rendered()
 check(fxNew==2 and commsNew==2,'return creates fresh loading ownership')
 f.map.boot=false;f.finished=false
 f.onBack=function()check(not f.hangarFxWarmup and not f.commsWarmup,'back disposes before scene callback')end
 f:Back();check(fxDisposed==2 and commsDisposed==2,'back releases both owners')
 f:Close()
end
print('LoadingFlow real hall warmup: '..checks..' checks PASS')

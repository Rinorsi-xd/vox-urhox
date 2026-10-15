local Settings=require 'render.GraphicsSettings'
local Viewports=require 'render.WindowViewports'
local Lifetime=require 'render.RenderTargetLifetime'
local settings,hall,crater,hallCamera,craterCamera,post,graph,texture
local host,car,hero
local function SceneCamera(graded)
    local scene=Scene();scene:CreateComponent('Octree');scene:CreateComponent('Zone')
    if graded then scene:SetVar('VoxColorGrade',Variant('crater')) end
    return scene,scene:CreateChild('Camera'):CreateComponent('Camera')
end
V.atFrame(3,function()
    hall,hallCamera=SceneCamera(false);crater,craterCamera=SceneCamera(true)
    settings=Settings.New({isValidation=true,ownsScene=true,store={Write=function() return true end}})
    settings:RetainPost(crater,craterCamera);settings:Show(crater,craterCamera)
    post=settings.post;graph=post.graph;texture=graph.textures[1]
    V.assert(graph.passCount==29,'real original default post chain has all 29 passes')
    settings:Show(crater,craterCamera)
    V.assert(settings.post==post and post.graph==graph,'showing same active camera reuses actual graph')
end)
V.atFrame(8,function()
    settings:Show(hall,hallCamera)
    V.assert(not settings.post and settings.retainedPost.post==post,'garage parks only opening-owned crater graph')
    V.assert(graph.textures[1]==texture and texture:GetWidth()>0,'parked actual render targets remain allocated')
    V.assert(Viewports.Get(0)~=graph.output,'parked graph is removed from screen rendering')
    local calls=0;local update=post.Update;post.Update=function(self,dt) calls=calls+1;return update(self,dt) end
    settings:Update(1/60);settings:PostUpdate()
    V.assert(calls==0,'inactive retained scene is not updated or queued each frame')
    post.Update=update
    settings.data.exposure=1.2;settings:Show(crater,craterCamera)
    V.assert(settings.post==post and post.graph==graph and post.data.exposure==1.2,'return reuses graph and applies current preferences')
    V.assert(Viewports.Get(0)==graph.output,'return displays actual retained output')
    local ticks,poses=0,0;local step,pose=post.Update,post.PostUpdate
    post.Update=function() ticks=ticks+1 end;post.PostUpdate=function() poses=poses+1 end
    car=require('render.VehicleView').New(hall,'OpeningFixtureCar');hero=require('render.VehicleView').New(hall,'OpeningFixtureHero')
    host=require('app.OpeningHost').New({graphicsSettings=settings,car=car});host.state.hallActor=hero
    host.Shot('familiar',{});settings:Update(1/60);settings:PostUpdate()
    V.assert(Viewports.Get(0)==nil and settings.suspendedViewport==graph.output,'opaque original comic suspends actual output without discarding it')
    V.assert(ticks==0 and poses==0,'covered scene does not update adaptive resolution or queue the 29-pass graph')
    host.Shot('galaxy',{});settings:Update(1/60);settings:PostUpdate()
    V.assert(Viewports.Get(0)==nil and ticks==0 and poses==0,'actual familiar then galaxy host hooks keep the real retained graph suspended')
    host.Shot('payslip',{});settings:SetSceneVisible(true)
    V.assert(settings.post==post and post.graph==graph and Viewports.Get(0)==graph.output,'repeated covered/uncovered restores the same actual graph and camera')
    settings:Update(1/60);settings:PostUpdate()
    V.assert(ticks==1 and poses==1,'uncovered scene resumes the active post graph exactly once')
    post.Update=step;post.PostUpdate=pose
    local delta;host.state.session={Tick=function(_,dt)delta=dt end};host.state.activeScene='crater'
    local narrative={ready=true,shot='payslip',time=13,age=2};host.Update(.7,narrative)
    V.assert(delta==.05 and narrative.time==13 and narrative.age==2,'actual opening host caps only simulation input to frozen main.js .05 without modifying narrative clocks')
end)
V.atFrame(13,function()
    settings:Show(hall,hallCamera);settings:Show(crater,craterCamera)
    V.assert(settings.post==post and post.graph.textures[1]==texture,'repeated narrative cuts do not allocate a new chain')
    settings:SetSceneVisible(false);settings:ReleasePost(crater)
    V.assert(not settings.post and not settings.retainedPost and not settings.suspendedViewport,'release clears active and suspended ownership')
    V.assert(not post.graph and next(graph.textures)==nil,'release explicitly disposes actual graph before scene camera')
    settings:ReleasePost(crater)
    settings:Show(hall,hallCamera)
end)
V.atFrame(18,function()
    settings:Show(crater,craterCamera);local temporary=settings.post
    settings:Show(hall,hallCamera)
    V.assert(not temporary.graph and not settings.post,'ordinary map transitions continue releasing unretained graphs')
    settings:RetainPost(crater,craterCamera);settings:Show(crater,craterCamera)
    local retained=settings.post;settings:Show(hall,hallCamera);settings:Dispose();settings:Dispose()
    V.assert(not retained.graph and not settings.retainedPost,'app shutdown also releases parked graph once')
    car:Dispose();hero:Dispose();Viewports.Set(0,nil);hall:Dispose();crater:Dispose();Lifetime.Flush()
end)
V.atFrame(25,function()
    Lifetime.Flush();V.assert(Lifetime.PendingCount()==0,'all owned textures retire after renderer releases surfaces')
    Viewports.Stop();V.finish()
end)

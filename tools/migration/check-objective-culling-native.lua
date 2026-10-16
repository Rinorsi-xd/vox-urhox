-- Validate real Camera.frustum and CustomGeometry; no full map or mock backend.
---@type Scene|nil
local scene=nil
local function Run()
    print('[ObjectiveCullingNative] started')
    scene=Scene();scene:CreateComponent('Octree')
    local node=scene:CreateChild('ObjectiveCullingCamera')
    local camera=node:CreateComponent('Camera')
    camera.autoAspectRatio=false;camera.aspectRatio=16/9;camera.fov=60;camera.nearClip=.1;camera.farClip=500
    local View=require 'render.ObjectiveView'
    local mode={id='conquest',points={{pos={100,3,25},radius=22}},bases={blue={aim={100,8,25}},red={aim={-100,8,25}}}}
    local rules={points={{v=.5,owner='blue'}},score={blue=100,red=100},shield={blue=true,red=false}}
    local view=View.New({scene=scene},mode)
    local builds=0;local begin=view.Begin
    view.Begin=function(self,...)builds=builds+1;return begin(self,...)end
    local bounds=BoundingBox(Vector3(-122,3,3),Vector3(-78,93,47))
    node.position=Vector3(0,10,0);node:LookAt(Vector3(0,10,-100))
    V.assert(camera.frustum:IsInsideFast(bounds)==OUTSIDE,'real camera classifies entire target behind view')
    view:Update(.1,rules,node)
    V.assert(builds==0 and next(view.batches)==nil,'offscreen first update creates no real CustomGeometry')
    node.position=Vector3(-100,15,-80);node:LookAt(Vector3(-100,3,25))
    V.assert(camera.frustum:IsInsideFast(bounds)~=OUTSIDE,'real camera sees point volume after turn')
    view:Update(.001,rules,node)
    V.assert(view.batches.PointRing1~=nil and view.batches.PointVolume1~=nil,'reentry creates native point geometry before 10Hz deadline')
    local volume=view.batches.PointVolume1.mesh
    V.assert(volume:GetNumVertices(0)>0 and volume.enabled,'real CustomGeometry has committed enabled vertices')
    V.assert(view.batches.Reactorblue.mesh:GetNumVertices(0)==20*24+72,'native full reactor uses current 100 score')
    local count=builds
    node:LookAt(Vector3(-100,15,-180));view:Update(.11,rules,node)
    V.assert(builds==count and not volume.enabled,'offscreen existing batches stop rebuilding and disable actual drawable')
    rules.score.blue=5;rules.points[1]={v=-1,owner='red'}
    node:LookAt(Vector3(-100,3,25));view:Update(.001,rules,node)
    V.assert(builds>count and volume.enabled,'actual drawable recovers immediately on reentry')
    V.assert(view.batches.Reactorblue.mesh:GetNumVertices(0)==24+72,'reactor reentry commits latest rule state')
    view:Dispose()

    -- The ring is outside this narrow high view, but the 90m column intersects.
    camera.fov=8;node.position=Vector3(-100,85,-80);node:LookAt(Vector3(-100,85,25))
    local floor=BoundingBox(Vector3(-122,3,3),Vector3(-78,3.3,47))
    V.assert(camera.frustum:IsInsideFast(floor)==OUTSIDE and camera.frustum:IsInsideFast(bounds)~=OUTSIDE,'real frustum distinguishes column top from floor ring')
    local top=View.New({scene=scene},mode);top:Update(.1,rules,node)
    V.assert(top.batches.PointRing1==nil and top.batches.PointVolume1~=nil,'actual upper column survives floor culling')
    local mesh=top.batches.PointVolume1.mesh;local highest=0
    for i=0,mesh:GetNumVertices(0)-1 do highest=math.max(highest,mesh:GetVertex(0,i).position.y)end
    V.assert(highest>=89.9,'native committed column retains full source height')
    top:Dispose()

    camera.fov=60;node.position=Vector3(0,15,-80);node:LookAt(Vector3(0,0,25))
    local payload={id='escort',path={},tuning={checkpoints={}},At=function(_,s)return {pos={s,0,25}}end}
    local escort=View.New({scene=scene},payload);local rule={s=0,idle=0,pushing=1,contested=false}
    escort:Update(.1,rule,node)
    local halo=escort.batches.PayloadHalo.mesh
    V.assert(halo:GetNumVertices(0)==128*6 and halo.enabled,'real moving payload halo is committed')
    rule.s=2000;escort:Update(.11,rule,node)
    V.assert(not halo.enabled,'offscreen moving halo disables its actual old drawable')
    rule.s=0;escort:Update(.001,rule,node)
    V.assert(halo.enabled and halo:GetNumVertices(0)==128*6,'moving halo recovers before next deadline')
    escort:Dispose()
    local conservative=View.New({scene=scene},mode);conservative:Update(.1,rules,nil)
    V.assert(conservative.batches.PointRing1~=nil and conservative.batches.PointVolume1~=nil and conservative.batches.Reactorblue~=nil and conservative.batches.Reactorred~=nil,'missing camera conservatively commits all real objective drawables')
    conservative:Dispose();scene:Dispose();scene=nil
    print('[ObjectiveCullingNative] completed 16 checks; real Camera.frustum / CustomGeometry; no full-match pixels or performance acceptance')
end
-- The helper is loaded after logical frame 1; frame 2 matches the native body fixtures.
V.atFrame(2,function()
    local ok,err=xpcall(Run,debug.traceback)
    if scene then scene:Dispose();scene=nil end
    if not ok then V.assert(false,'objective native fixture completed: '..tostring(err)) end
    V.finish()
end)

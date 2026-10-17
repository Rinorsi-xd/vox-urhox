-- Dedicated rendered fixture; no normal App, inventory, save or live battle.
local View=require 'render.ObjectiveView'
local Objectives=require 'combat.BattleObjectives'
local Rules=require 'combat.ConquestRules'
local Data=require 'combat.ArenaData'
local scene=nil ---@type Scene?
local worker=nil ---@type thread?
local view=nil ---@type table?
local finished=false
local updateCallbacks=0
local snapshots={}
local function Vec(v)return {v.x,v.y,v.z}end
local function Emit(kind,row)print('REACTOR_FEEDBACK_'..kind..' '..cjson.encode(row))end
local function Run()
    scene=Scene();scene:CreateComponent('Octree')
    local cameraNode=scene:CreateChild('ReactorFixtureCamera')
    local camera=cameraNode:CreateComponent('Camera');camera.nearClip=.1;camera.farClip=150
    cameraNode.position=Vector3(0,5,-20);cameraNode:LookAt(Vector3(0,0,0))
    renderer:SetViewport(0,Viewport:new(scene,camera))
    local mode={id='conquest',points={},bases={blue={aim={-6,0,0}},red={aim={6,0,0}}}}
    local rule=Rules.New(Data.modes.conquest,Data.conquest)
    rule.state='live';rule.score.blue=50;rule.score.red=50;rule.shield.red=false
    view=View.New({scene=scene},mode)
    local objectives=setmetatable({id='conquest',battle={rules=rule},bases=mode.bases,view=view},Objectives)
    local unit={team='blue'}
    local function Advance(count)
        for _=1,count do view:Update(1/60,rule,cameraNode);coroutine.yield()end
    end
    local function Snapshot(stage)
        -- One rendered engine frame after the last actual Commit, before readback.
        coroutine.yield()
        local row={stage=stage,fixture=true,updateCallbacks=updateCallbacks,age=view.age,score={blue=rule.score.blue,red=rule.score.red},
            shield={blue=rule.shield.blue,red=rule.shield.red},camera=Vec(cameraNode.position),reactors={}}
        for _,team in ipairs({'blue','red'})do
            local batch=assert(view.batches['Reactor'..team]);local mesh=batch.mesh
            local color=Color();local raw=mesh:GetVertex(0,0).color;color:FromUInt(raw)
            row.reactors[team]={position=Vec(batch.node.position),enabled=mesh.enabled,culled=view.culled['Reactor'..team]==true,
                flash=view.reactorFlash[team]or 0,vertexCount=mesh:GetNumVertices(0),firstVertexColor=raw,
                rgba={color.r,color.g,color.b,color.a}}
        end
        snapshots[#snapshots+1]=row;Emit('SNAPSHOT',row)
        repeat coroutine.yield()until input:GetKeyPress(KEY_F8)
    end
    Advance(60);Snapshot('before')
    assert(objectives:Hit(unit,{owner={type='reactor',team='red'},point=mode.bases.red.aim},300))
    view:Update(0,rule,cameraNode);Snapshot('hit')
    Advance(18);Snapshot('decayed')
    objectives:Explode(unit,mode.bases.red.aim,4,300)
    view:Update(0,rule,cameraNode);Snapshot('explosion-hit')
    -- Wait beyond the normal 10 Hz gate, including the unhit blue reactor.
    cameraNode:LookAt(Vector3(0,5,-100));Advance(7);Snapshot('culled')
    cameraNode:LookAt(Vector3(0,0,0));view:Update(0,rule,cameraNode);Snapshot('cull-return')
    Advance(18);rule.shield.red=true
    local score=rule.score.red
    objectives:Hit(unit,{owner={type='reactor',team='red'},point=mode.bases.red.aim},300)
    objectives:Explode(unit,mode.bases.red.aim,4,300)
    assert(rule.score.red==score and view.reactorFlash.red==0,'Shielded fixture cannot steal/flash')
    Advance(7);Snapshot('shielded')
    view:Dispose();view=nil;renderer:SetViewport(0,nil);scene:Dispose();scene=nil
    finished=true;Emit('DONE',{status='PASS',stages=#snapshots,fixture=true,released=true,
        boundary='Actual frozen modules and engine geometry/color/node readback with synthetic rules. Fixed dt stages, not natural combat or FPS acceptance.'})
end
function Start()
    worker=coroutine.create(Run);SubscribeToEvent('Update','ReactorFeedbackUpdate')
end
function ReactorFeedbackUpdate()
    if finished or not worker or coroutine.status(worker)=='dead'then return end
    updateCallbacks=updateCallbacks+1
    local ok,message=coroutine.resume(worker)
    if not ok then finished=true;Emit('DONE',{status='FAIL',error=tostring(message),fixture=true})end
end
function Stop()
    UnsubscribeFromEvent('Update')
    if view then view:Dispose();view=nil end
    if scene then renderer:SetViewport(0,nil);scene:Dispose();scene=nil end
end

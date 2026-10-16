-- Reuse module loading/goldens, then independently trap every retired-node access.
local setup=dofile('tools/migration/check-endless-spawn.lua')
local checks={}
local function Check(value,name) assert(value,name);checks[#checks+1]=name end
local Trial=require 'app.TrialSession'
local Endless=require 'app.EndlessSession'
local Spawn=require 'endless.SpawnPresentation'
package.loaded['ui.DialogHost'].Dispose=dofile('scripts/ui/DialogHost.lua').Dispose
local order={}
local function Node(name)
    local state={position=Vector3(3,22,9),rotation={},scale=Vector3(1,1,1),enabled=true,children={},disposed=false}
    local methods={}
    function methods:GetChildren() return state.children end
    function methods:SetEnabledRecursive(on) state.enabled=on end
    function methods:Dispose() Check(not state.disposed,name..' is disposed once');state.disposed=true;order[#order+1]=name end
    local node=setmetatable({},{__index=function(_,key)
        assert(not state.disposed,'read disposed '..name..'.'..key)
        return methods[key] or state[key]
    end,__newindex=function(_,key,value)
        assert(not state.disposed,'write disposed '..name..'.'..key);state[key]=value
    end})
    return node,state
end
local function Case(editing)
    local root,state=Node('battle-car');local flash,flashState=Node('restore-flash')
    local world={time=.12,RecordDamage=function() end,Dispose=function() order[#order+1]='world' end}
    local s=setmetatable({view={view={root=root},Dispose=function() root:Dispose() end},world=world,
        restoreFlash={root=flash,items={},Dispose=function() flash:Dispose() end},app={}},Trial)
    local e=setmetatable({session=s,world=world,run={state=editing and 'editing' or 'combat'},player={alive=true},entries={},
        view={Dispose=function() order[#order+1]='endless-view' end},audio={Dispose=function() end},
        baseDamage=function() end,spawnPresentation=Spawn.New()},Endless)
    s.endless=e;s.combat=e
    e.spawnPresentation:Rise(0);e.spawnPresentation:Apply(root,.12,20.5,3)
    Check(math.abs(state.position.y-4)<1e-10,'pre-exit root has actual rise offset')
    if editing then
        package.loaded['endless.Inventory']={}
        package.loaded['Config']={TIERS={[5]={test=true}}}
        local ui=package.loaded['urhox-libs/UI'];ui.SetRoot=function(value) order[#order+1]='restore-ui';Check(value.node==true,'actual editor restores original mounted UI root') end
        package.loaded['render.WindowViewports']={Set=function() order[#order+1]='restore-viewport' end}
        package.loaded['controls.TouchMode']={Apply=function(value) Check(value=='drive','actual editor returns drive touch context') end}
        local Edit=require 'endless.Edit'
        local editorNode=Node('editor-root');local cameraNode=Node('editor-camera')
        e.edit=setmetatable({controller=e,sourceTier={},root=editorNode,build={Dispose=function() order[#order+1]='editor-build' end},
            host={car={Dispose=function() order[#order+1]='editor-car' end},camera={node=cameraNode}},
            originalRoot={node=true},originalViewport={}},Edit)
    end
    local held=e.spawnPresentation
    s:Dispose()
    Check(state.disposed and flashState.disposed,'actual session retires both player and flash roots')
    Check(held.root==nil and held.basePosition==nil,'presentation disposal only drops retired native references')
    Check(s.endless==nil and e.session==nil,'actual session and controller clear mutual ownership')
    local before=#order;s:Dispose();e:Dispose();s:Update(1/60);s:PostUpdate(1/60)
    Check(#order==before,'late update/post/dispose are inert after owner disposal')
    if editing then
        local restored,carIndex
        for i,name in ipairs(order) do if name=='restore-viewport' then restored=i elseif name=='battle-car' then carIndex=i end end
        Check(restored and restored<carIndex,'actual Edit.Leave restores viewport while battle root is alive')
    end
    order={}
end
Case(false);Case(true)

local root,state=Node('death-root');local flash=Node('death-flash')
local motion=Spawn.New();motion:Rise(0);motion:Apply(root,.12,20.5,3)
local seen={}
local s=setmetatable({endless={run={state='combat'},RestorePresentation=function() motion:Restore() end},
    view={view={root=root}},combat={player={alive=false},entries={}},restoreFlash={root=flash},
    cameraFeedback={Discard=function() end},drillSpeed={Clear=function() end},
    chase={Pose=function(_,_,pos) seen.target=pos;return {} end},camera={},target={},yaw=0,pitch=0},Trial)
package.loaded['controls.ChaseCamera'].Apply=function() seen.y=state.position.y end
s:PostUpdate(1/60)
Check(seen.target[2]==22 and seen.y==22,'actual death PostUpdate restores last visual frame before spectator camera')
Check(motion.root==nil and motion.basePosition==nil,'death leaves no pending restore reference')
Check(not flash.enabled,'actual death branch hides independent restore flashes')
return {checks=checks,setupChecks=#setup.checks}

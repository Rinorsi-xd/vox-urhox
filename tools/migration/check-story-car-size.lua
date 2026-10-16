package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'story.MissionData','combat.ArenaData','combat.CarUnit','combat.EnemyDriver','core.Math3','drive.SpawnSpecCache'}) do
    package.preload[name]=function()return {}end
end
package.preload.Config=function()return {CELL=SOURCE.cell}end
local Mission=require 'story.Mission'
local Rules=require 'story.MissionRules'
local old=assert(load(OLD_MISSION,'actual-45f-Mission'))()
local checks,frames=0,0
local function Check(actual,expected,message)
    checks=checks+1
    if type(expected)=='number' then assert(math.abs(actual-expected)<1e-9,message..': '..tostring(actual)..' ~= '..expected)
    else assert(actual==expected,message..': '..tostring(actual)..' ~= '..tostring(expected)) end
end
local function Run(module,test,verify)
    local roots,measurements,statsCalls={},0,0
    local state={count=0,pos={},bb={}}
    local bp={Size=function()return state.count end,Stats=function()statsCalls=statsCalls+1;return {bb=state.bb}end}
    local self=setmetatable({player={bp=bp,Position=function()return state.pos end},session={}},{__index=module})
    local differences=0
    for i,action in ipairs(test.actions) do
        state.count=action.count;state.pos=action.pos;state.bb=action.bb
        if state.bb and state.bb.minX=='Infinity' then state.bb={minX=math.huge}end
        if action.retire then roots[action.retire].retired=true end
        if action.root then
            local root=roots[action.root]or {};roots[action.root]=root;root.box=action.box
            self.session.view={view={root=root,GetWorldBounds=function()
                assert(not root.retired,'Retired root read');measurements=measurements+1
                return {min=root.box.min,max=root.box.max,Defined=function()return root.box.min~=nil end}
            end}}
        else self.session.view=nil end
        local size=self:CarSize();local expected=test.expected[i]
        local same=true
        for _,key in ipairs({'w','below','above'}) do
            if verify then Check(size[key],expected.size[key],test.name..'/'..i..'/'..key)
            elseif not size or math.abs(size[key]-expected.size[key])>1e-9 then same=false end
        end
        if verify then
            Check(measurements,expected.measurements,test.name..' measurements')
            Check(statsCalls,expected.statsCalls,test.name..' statsCalls')
            for j,probe in ipairs(SOURCE.probes) do Check(Rules.Near({},state.pos,probe.target,probe.r,probe.up,self:CarSize()),expected.near[j],test.name..' near/'..probe.kind..'/'..j)end
            frames=frames+1
        elseif not same then differences=differences+1 end
    end
    return differences
end
local oldFailures=0
for _,test in ipairs(SOURCE.sequences)do Run(Mission,test,true);oldFailures=oldFailures+Run(old,test,false)end
assert(oldFailures>=8,'Actual old function must reproduce the differences')
return {pass=true,checks=checks,frames=frames,sequences=#SOURCE.sequences,oldFailingFrames=oldFailures}

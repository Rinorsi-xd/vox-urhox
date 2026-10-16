-- Same actual SceneLoader, different opening-private cooperative CPU budgets.
package.path='scripts/?.lua;'..package.path
local wall=0;local activeTrace={}
local function Record(text) activeTrace[#activeTrace+1]=text end
Time={GetSystemTime=function()return wall end}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function()return false end}
package.loaded['app.ResourceGate']={New=function()return {
    Start=function(_,_,done)Record('download');done(true)end,Cancel=function()end}end}
cache={GetFile=function()Record('file');return {Dispose=function()Record('file-dispose')end}end}
Scene=function()return {
    asyncLoading=false,asyncProgress=1,
    LoadAsyncXML=function()Record('parse');return true end,
    GetComponents=function()return {}end,
    StopAsyncLoading=function()Record('scene-stop')end,
    Dispose=function()Record('scene-dispose')end,
}end
LOAD_SCENE_AND_RESOURCES='all'
local Loader=require 'app.SceneLoader'
package.loaded['construction.Blueprint']={}
package.loaded['core.Coord']={}
local beforeHost=assert(load(OPENING_BEFORE_SOURCE,'@frozen5487/OpeningHost.lua'))()
local afterHost=assert(load(OPENING_AFTER_SOURCE,'@production/OpeningHost.lua'))()
local beforeBudget=beforeHost.New({}).state.loader.prepareBudgetMs
local afterBudget=afterHost.New({}).state.loader.prepareBudgetMs
assert(beforeBudget==3 and afterBudget==5,'actual host budgets must be frozen 3 and production 5')
assert(Loader.New().prepareBudgetMs==3,'shared loader default remains 3')
local checks=0
local function Check(ok,text)checks=checks+1;assert(ok,text)end
local function Run(budget,scenario)
    wall=0;activeTrace={}
    local loader=Loader.New();loader.prepareBudgetMs=budget
    local completed,failed=false,false
    loader:Load('scene.xml',function()completed=true;Record('ready')end,
        function()failed=true;Record('failed')end,{
        resources={},cleanup=function()Record('cleanup')end,
        prepare=function(_,checkpoint)
            for i=1,31 do
                Record('step:'..i)
                wall=wall+(i==11 and 77 or 1)
                if scenario=='failure' and i==17 then error('authored-step-failure')end
                checkpoint(i/31,'step:'..i)
                -- A deterministic semantic cancellation fence, independent of
                -- wall-clock timing or where each budget otherwise yields.
                if scenario=='cancel-fence' and i==10 then coroutine.yield('cancel-fence')end
            end
        end})
    if scenario=='cancel-before' then loader:Cancel()end
    local fence=false;local ticks=0
    while loader.state=='loading' do
        ticks=ticks+1;Check(ticks<100,'bounded fixture')
        loader:Update(1/60)
        if scenario=='cancel-fence' then
            for _,text in ipairs(activeTrace)do if text=='step:10' then fence=true end end
            if fence then loader:Cancel()end
        end
        wall=wall+16
    end
    if scenario=='complete' then
        Check(completed and not failed and loader.state=='ready','completed once')
        Check(loader.pending==nil and loader.job==nil and loader.options==nil,'completion relinquishes candidate')
        Check(loader.maxPrepareMs>=77,'indivisible 77ms stage remains visible')
        Check(activeTrace[#activeTrace]=='ready','completion callback is last')
    elseif scenario=='failure' then
        Check(failed and not completed and loader.state=='failed','failure callback after cleanup')
        Check(loader.pending==nil and loader.job==nil and loader.options==nil,'failure clears owners')
        Check(loader.maxPrepareMs>=77,'failure includes indivisible stage')
        local tail=table.concat(activeTrace,',',#activeTrace-3)
        Check(tail=='cleanup,scene-stop,scene-dispose,failed','failure cleanup before callback')
    else
        Check(not completed and not failed and loader.state=='idle','cancellation never activates or fails')
        Check(loader.pending==nil and loader.job==nil and loader.options==nil,'cancellation clears owners')
        if scenario=='cancel-before' then Check(table.concat(activeTrace,',')=='cleanup','early cancel calls cleanup')
        else Check(table.concat(activeTrace,',',#activeTrace-2)=='cleanup,scene-stop,scene-dispose','semantic cancel cleanup order')end
    end
    return {trace=table.concat(activeTrace,','),resumes=loader.prepareFrames,maxSliceMs=loader.maxPrepareMs,ticks=ticks}
end
local rows={}
for _,scenario in ipairs({'complete','failure','cancel-before','cancel-fence'})do
    local before=Run(beforeBudget,scenario);local after=Run(afterBudget,scenario)
    Check(before.trace==after.trace,'same actual step and cleanup order '..scenario)
    if scenario=='complete' then Check(after.resumes<before.resumes,'larger budget reduces actual coroutine resumes')end
    rows[#rows+1]={scenario=scenario,before=before,after=after}
end
return {checks=checks,rows=rows}

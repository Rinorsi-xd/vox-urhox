local Loader=require 'app.SceneLoader'
V.atFrame(2,function()
    local resources={}
    for i=1,4 do resources[i]={type='Model',name='Models/Box.mdl'} end
    local warm=Loader.New();warm.state='loading';warm.phase='resources';warm.options={webWarmup=resources}
    for _=1,16 do warm:Update(20) end
    V.assert(warm.state=='loading' and warm.warmIndex==5,'native resource preparation progressing over 320 simulated seconds stays live')
    warm:Cancel()
    local calls=0
    local stalled=Loader.New();stalled.state='loading';stalled.phase='resources';stalled.warmWait=100
    stalled.options={webWarmup=resources};stalled.onError=function() calls=calls+1 end
    stalled:Update(91);stalled:Update(91)
    V.assert(stalled.state=='failed' and calls==1,'actual resource watchdog still fails a stalled preparation exactly once')
    local function Preparing(advancing)
        local scene=Scene();scene:CreateComponent('Octree')
        local job=Loader.New()
        local options={prepare=function(candidate,checkpoint)
            for i=1,8 do
                candidate:CreateChild('Prepared'..i)
                checkpoint(advancing and i/8 or .1,'objects')
                coroutine.yield()
            end
        end}
        job:Load('fixture.xml',function(candidate) candidate:Dispose() end,function() end,options)
        job.beginDownload=nil;job.phase='scene';job.pending=scene
        job:Update(0)
        return job
    end
    local progress=Preparing(true)
    for _=1,9 do progress:Update(20) end
    progress:Update(0)
    V.assert(progress.state=='ready','real native candidate and advancing coroutine checkpoints complete beyond a 90 second total duration')
    local noProgress=Preparing(false)
    for _=1,7 do noProgress:Update(20) end
    V.assert(noProgress.state=='failed' and not noProgress.pending and not noProgress.job,'repeated identical checkpoints do not hide a stalled coroutine and release the candidate')
    local async=Loader.New();async.state='loading';async.phase='scene';async.elapsed=80
    async.pending={asyncLoading=true,asyncProgress=.2,StopAsyncLoading=function() end,Dispose=function() end}
    async:Update(20)
    V.assert(async.state=='loading' and async.elapsed==0,'advancing native asyncProgress refreshes scene idle deadline')
    async:Update(91)
    V.assert(async.state=='failed','unchanged native asyncProgress retains scene idle timeout')
    V.finish()
end)

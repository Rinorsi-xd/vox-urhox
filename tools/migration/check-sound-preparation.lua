package.path='scripts/?.lua;'..package.path
local requested,checkpoints,initialized={},{},0
local paths={
    ['audio.WeaponAudio']={'shot.wav','shared.wav'},
    ['audio.DrivingAudio']={'engine.wav','shared.wav'},
    ['audio.CombatFeedbackAudio']={'kill.wav','score.wav'},
}
for name,items in pairs(paths) do
    package.loaded[name]={Dependencies=function()return items end}
end
cache={GetResource=function(_,kind,path)
    assert(kind=='Sound');requested[#requested+1]=path;return {path=path}
end}
local prepare=require('audio.SoundPreparation').Prepare
local worker=coroutine.create(function()
    local count=prepare(function(p,stage)
        assert(stage=='audio-resources');checkpoints[#checkpoints+1]=p
        coroutine.yield()
    end)
    assert(count==5);initialized=initialized+1
end)
for i=1,5 do
    assert(coroutine.resume(worker));assert(#requested==i and #checkpoints==i)
    assert(checkpoints[i]==i/5 and initialized==0)
end
assert(coroutine.resume(worker));assert(initialized==1 and coroutine.status(worker)=='dead')
assert(table.concat(requested,',')=='shot.wav,shared.wav,engine.wav,kill.wav,score.wav')
local cancelled=coroutine.create(function()prepare(function()coroutine.yield()end);initialized=initialized+1 end)
assert(coroutine.resume(cancelled));assert(coroutine.close(cancelled));assert(initialized==1)
cache.GetResource=function()return nil end
local ok,err=pcall(prepare);assert(not ok and tostring(err):find('Cannot prepare sound: shot.wav',1,true))
print('Sound preparation: incremental decode, deduplication, progress, cancellation and missing-resource checks PASS')

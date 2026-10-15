local names={'audio.WeaponAudio','audio.DrivingAudio','audio.CombatFeedbackAudio'}
local sounds,paths,players,slices={},{},{},{}
local scene=Scene()
local worker=nil ---@type thread|nil
local previous=0
local started=0
local completed=false
V.atFrame(2,function()
    for _,name in ipairs(names) do
        for _,path in ipairs(require(name).Dependencies()) do
            if not sounds[path] then paths[#paths+1]=path;sounds[path]=true end
        end
    end
    worker=coroutine.create(function()
        local count=require('audio.SoundPreparation').Prepare(function(progress,stage)
            local elapsed=Time:GetSystemTime()-started
            slices[#slices+1]=elapsed
            V.assert(stage=='audio-resources' and progress>previous,'incremental real sound checkpoint '..#slices)
            previous=progress
            coroutine.yield()
        end)
        V.assert(count==#paths and #slices==#paths and previous==1,'all unique sound resources prepared')
        for _,path in ipairs(paths) do
            local sound=cache:GetExistingResource('Sound',path)
            V.assert(sound~=nil and sound:GetFrequency()>0 and sound:GetLength()>0,'decoded real sound '..path)
            sounds[path]=sound
        end
        local before=cache:GetMemoryUse(StringHash('Sound'))
        local constructionStart=Time:GetSystemTime()
        for _,name in ipairs(names) do
            local player=require(name).New(scene);players[#players+1]=player
            for _,sound in pairs(player.sounds) do
                local found=false
                for _,path in ipairs(paths) do if sounds[path]==sound then found=true;break end end
                V.assert(found,'constructor reuses prepared Sound')
            end
        end
        local constructionMs=Time:GetSystemTime()-constructionStart
        V.assert(cache:GetMemoryUse(StringHash('Sound'))==before,'cached constructors do not decode additional Sound resources')
        for _,player in ipairs(players) do
            player:Dispose()
            V.assert(player.disposed and next(player.sounds)==nil,'audio player releases its ownership')
        end
        print('SOUND_PREPARATION_NATIVE '..cjson.encode({resources=#paths,sliceMs=slices,constructorMs=constructionMs,memoryBytes=before}))
        scene:Dispose();completed=true;V.finish()
    end)
end)
local function Step()
    if completed or not worker then return end
    started=Time:GetSystemTime()
    local ok,err=coroutine.resume(worker)
    if not ok then V.assert(false,tostring(err));completed=true;scene:Dispose();V.finish() end
end
for frame=3,220 do V.atFrame(frame,Step) end
V.atFrame(225,function() V.assert(completed,'real sound preparation completed');V.finish() end)

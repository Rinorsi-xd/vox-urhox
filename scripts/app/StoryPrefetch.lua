-- Story page downloads shared by the mode page prefetch and StoryHolo.
-- Download only: parsing and GPU uploads stay with StoryHolo on tab entry.
local ResourceGate=require("app.ResourceGate")
local ResourceData=require("core.ResourceData")
local M={}
---@type table|nil
local gate=nil
local state='idle'
local listeners={}
local function Paths()
    local data=ResourceData.Read('Story/Manifest.json');local paths={}
    for _,m in ipairs(data.models) do paths[#paths+1]=m.model end
    for _,m in ipairs(data.materials) do
        paths[#paths+1]='Shaders/BLGL/Story/'..(m.story=='Edges' and 'Solid' or m.story)..'.shader'
    end
    for _,l in ipairs(ResourceData.Read('UI/Outgame.json').levels) do paths[#paths+1]='Story/Page/Faces/'..l.nono[1]..'.png' end
    return paths
end
function M.Start(listener)
    if state=='ready' then if listener then listener(true,'') end;return end
    if listener then listeners[listener]=true end
    if state=='loading' then return end
    gate=gate or ResourceGate.New();state='loading'
    print('[StoryPrefetch] Start')
    gate:Start(Paths(),function(ok,message)
        -- Failure returns to idle so the next page visit retries.
        state=ok and 'ready' or 'idle'
        print('[StoryPrefetch] '..(ok and 'Ready' or ('Failed '..tostring(message))))
        local pending=listeners;listeners={}
        for fn in pairs(pending) do fn(ok,message) end
    end)
end
function M.Remove(listener) listeners[listener]=nil end
-- Map loads own the bandwidth; an open story page keeps its download.
function M.Cancel()
    if state~='loading' or next(listeners) then return end
    gate:Cancel();state='idle';print('[StoryPrefetch] Cancelled for map load')
end
function M.Progress()
    if state=='ready' then return 1,1 end
    return gate and gate.completed or 0,gate and gate.total or 0
end
return M

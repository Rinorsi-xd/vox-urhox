-- QA only. Time the real bindings without replacing their results or scheduling.
local metrics={}
local function Measure(label,path,fn,...)
    local start=Time:GetSystemTime()
    local values=table.pack(fn(...))
    local elapsed=Time:GetSystemTime()-start
    local item=metrics[label] or {calls=0,totalMs=0,maxMs=0}
    metrics[label]=item;item.calls=item.calls+1;item.totalMs=item.totalMs+elapsed
    item.maxMs=math.max(item.maxMs,elapsed)
    if elapsed>=50 then print('G0_BINDING '..cjson.encode({label=label,path=path,ms=elapsed,at=Time:GetSystemTime()})) end
    return table.unpack(values,1,values.n)
end
local Gate=require 'app.ResourceGate'
local init=Gate.init
function Gate:init(backend)
    backend=backend or cache
    local proxy={}
    function proxy:Exists(path) return Measure('Exists',path,backend.Exists,backend,path) end
    if backend.DownloadResources then
        function proxy:DownloadResources(...) return Measure('DownloadResources','',backend.DownloadResources,backend,...) end
        function proxy:CancelDownloadGroup(...) return backend:CancelDownloadGroup(...) end
    end
    init(self,proxy)
end
local getManager=GetDownloadManager
local manager=getManager()
if manager then
    local before=manager:GetConcurrency()
    if G0_DOWNLOAD_CONCURRENCY then manager:SetConcurrency(G0_DOWNLOAD_CONCURRENCY) end
    print('G0_DOWNLOAD_CONFIG '..cjson.encode({before=before,after=manager:GetConcurrency()}))
end
function GetDownloadManager()
    local manager=getManager();if not manager then return nil end
    return {
        DownloadResources=function(_,paths) return Measure('LegacyDownloadResources',#paths,manager.DownloadResources,manager,paths) end,
        GetResourceTaskState=function(_,path) return Measure('GetResourceTaskState',path,manager.GetResourceTaskState,manager,path) end,
        CancelGroup=function(_,id) return manager:CancelGroup(id) end,
    }
end
local update=HandleUpdate
function HandleUpdate(eventType,eventData)
    update(eventType,eventData)
    if input:GetKeyPress(KEY_F8) then print('G0_BINDINGS '..cjson.encode(metrics)) end
end

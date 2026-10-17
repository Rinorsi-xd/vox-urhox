-- Diagnostic-only derivative of scaffold-3d-scene.lua; no gameplay or GPU queries.
---@type Scene|nil
local scene = nil
local frame = 0
local finished = false
local captureLogs = false
local output
for _, arg in ipairs(GetArguments()) do output = arg:match('^%-probe%-output=(.+)$') or output end
local report = {status='CAPABILITY_NOT_RUN',dumpCalls=0,dumpMessages={},logOverflow=false}

local function finish(reason)
    if finished then return end
    finished = true
    report.frames = frame
    report.exitReason = reason
    report.status = 'CAPABILITY_COLLECTED_NOT_TIMING_ACCEPTANCE'
    local file = assert(io.open(assert(output,'Missing -probe-output'),'wb'))
    file:write(cjson.encode(report))
    file:close()
    print('VOX_ENGINE_PROFILER_CAPABILITY '..cjson.encode(report))
    engine:Exit()
end

function Start()
    scene = Scene()
    scene:CreateComponent('Octree')
    local camera = scene:CreateChild('CapabilityCamera'):CreateComponent('Camera')
    renderer:SetViewport(0,Viewport:new(scene,camera))
    report.context = 'Empty Octree scene and camera; capability only, no combat/render budget result'
    SubscribeToEvent('LogMessage',function(_, data)
        if not captureLogs then return end
        if #report.dumpMessages >= 4096 then report.logOverflow=true;return end
        report.dumpMessages[#report.dumpMessages+1] = {
            level=data:GetInt('Level'),message=data:GetString('Message'),customLog=data:GetString('CustomLog')}
    end)
    SubscribeToEvent('Update','HandleCapabilityUpdate')
    print('VOX_ENGINE_PROFILER_CAPABILITY_START')
end

function HandleCapabilityUpdate()
    frame = frame+1
    if frame == 20 then
        print('VOX_ENGINE_DUMP_BEGIN')
        captureLogs = true
        print('VOX_ENGINE_DUMP_CAPTURE_CONTROL')
        local ok, err = pcall(function() engine:DumpProfiler() end)
        captureLogs = false
        report.dumpCalls = 1
        report.dumpOk = ok
        if not ok then report.dumpError = tostring(err) end
        print('VOX_ENGINE_DUMP_END',ok,err)
    elseif frame >= 22 then
        finish('frame-limit')
        return
    end
end

function Stop()
    if scene then scene:Dispose();scene=nil end
end

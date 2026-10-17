-- Invoke the production disable flag without changing the engine URL parser.
local monitorDisabledStart=Start
function Start()
    local previous=GetArguments
    GetArguments=function()
        local arguments={}
        for _,argument in ipairs(previous()) do arguments[#arguments+1]=argument end
        arguments[#arguments+1]='-vox-perf=0'
        return arguments
    end
    local ok,message=pcall(monitorDisabledStart)
    GetArguments=previous
    if not ok then error(message,0) end
end

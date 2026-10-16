-- 渲染目标能否同步读回 CPU（Texture2D:GetImage）。WebGPU 只有异步读回，同步调用会报错并返回 nil，
-- 需要读回像素的功能在这里先判断，不支持时直接走各自的降级路径。
local M={}
function M.Sync()
    local api=graphics and graphics.apiName or ''
    return not tostring(api):lower():find('webgpu',1,true)
end
return M

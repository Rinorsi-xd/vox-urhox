-- 前向管线里的「环境光遮蔽」就是渲染路径里的 compute-ssao 命令（参数写死在
-- RenderPaths/CEMapSSAO.xml，Zone 上的 ssaoRadius/ssaoIntensity 只对延迟管线生效）。
-- 所以 AO 开关做成渲染路径切换：其余命令原样保留，只摘掉 SSAO 那一条。
-- 换掉 renderer 的默认路径后，所有没显式设置路径的视口下一帧就跟着变。
-- 移动前向路径（CEMap.xml）本来就没有这条命令，那里 Available() 为假，不提供开关。
local M={}
local base,off,missing,applied
---带 AO 的基准路径。默认路径可能已经被本模块换成无 AO 版本，所以只取一次。
local function Base()
    if not base then base=renderer:GetDefaultRenderPath() end
    return base
end
---返回 SSAO 命令的索引和命令总数；引擎的 unsigned 索引在 Lua 里是 0 基。
local function Index(path)
    if not path then return nil end
    local count=path:GetNumCommands()
    for i=0,count-1 do
        local ok,command=pcall(path.GetCommand,path,i)
        if ok and command and (command.role==RP_ROLE_COMPUTE_SSAO or command.pass=='ssao') then return i,count end
    end
end
---摘掉 SSAO 的那条路径，第一次用到时才克隆
local function Off()
    if off or missing then return off end
    local index,count=Index(Base())
    if not index then missing=true;return nil end
    local path=Base():Clone();path:RemoveCommand(index)
    -- 索引基准对不上时宁可不支持，也不能删错命令。
    off=path:GetNumCommands()==count-1 and path or nil
    if not off then missing=true end
    return off
end
---当前这台机器的前向管线里有没有可摘的 SSAO 命令
function M.Available() return Off()~=nil end
---按开关取路径：显式持有一条路径的视口（后处理源、离屏抓帧）用它绑定
---@return RenderPath
function M.PathFor(enabled)
    if enabled then return Base() end
    return Off() or Base()
end
---自己持有一条显式路径的视口在切换后要重新绑定
function M.Rebind(viewport,enabled)
    if viewport then viewport:SetRenderPath(M.PathFor(enabled):Clone()) end
end
function M.Apply(enabled)
    if not enabled and not Off() then return false end
    local path=M.PathFor(enabled)
    if applied~=path then renderer:SetDefaultRenderPath(path);applied=path end
    return true
end
return M

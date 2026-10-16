-- Frozen EndlessSession.events and EndlessHud.announce/update semantics.
local Data=require("endless.Data")
local Config=require("Config")

local M={}
local function Now() return Time:GetSystemTime() end
function M.Event(e,announcement)
    if e.type=='tierUp' then
        if Data.config.tierLimits then
            local tier=Config.TIERS[e.tier]
            announcement='阶位提升：'..tier.name..' · 预算 '..tier.budget
        else announcement='敌人升到 T'..e.tier end
        return announcement,announcement
    elseif e.type=='waveClear' then return '第 '..e.wave..' 波完成'..(announcement~='' and ' · '..announcement or ''),announcement
    elseif e.type=='waveStart' then return '第 '..e.wave..' 波'..(e.boss and ' · Boss 来袭' or ' · 敌人出击'),announcement
    elseif e.type=='charge' then return '敌人冲锋！',announcement
    elseif e.type=='shieldDown' then return '基地护盾被击破 · 本波停止维修',announcement end
    return nil,announcement
end
function M.Push(owner,text,ms) owner.banner={text=text,untilAt=Now()+(ms or 3500)} end
function M.Update(owner,run)
    local respawn=math.max(0,(run.respawnAt or 0)-run.time)
    if respawn>0 then
        owner.banner=owner.banner or {}
        owner.banner.text='战车被摧毁 · '..math.ceil(respawn)..' 秒后复原'
    elseif owner.banner and owner.banner.untilAt and Now()>owner.banner.untilAt then owner.banner=nil end
    return owner.banner and owner.banner.text or ''
end
return M

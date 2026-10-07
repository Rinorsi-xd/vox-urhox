-- Source vehicle telemetry text; no mobile/portrait layout branches.
local M={}
function M.Speed(v) return (v.telemetry.totalSpeed or math.abs(v.speed))*3.6 end
function M.Motion(v)
    local t=v.telemetry;local rows={}
    if (t.liftRatio or 0)>0 then
        rows[#rows+1]=string.format('升重比 %.2f · %s%s',t.liftRatio,t.flightHold and string.format('定高 %.1f / %.1f m',t.altitude or 0,t.altitudeTarget or 0) or '升力待机',
            t.liftRatio<1 and ' · 升力不足，无法起飞' or (t.liftBalanceError or 0)>.12 and ' · 升力偏心，调平受限' or '')
    end
    if (t.hoverCount or 0)>0 then
        rows[#rows+1]=string.format('悬浮支撑 %d/%d · %s%s · 托力 %.1f kN',t.hovers or 0,t.hoverCount,t.hoverHeight and string.format('离地 %.2f m',t.hoverHeight) or '失去地面',
            t.hoverHeightTarget and string.format(' / 目标 %.2f m',t.hoverHeightTarget) or '',(t.hoverForce or 0)/1000)
    end
    if (t.legCount or 0)>0 then
        local grip=t.legCresting and '翻越边缘' or t.legClimbing and '贴墙攀爬 · 松开方向键停在墙上' or t.legWallPending and '前方是墙 · 继续前进就爬上去' or (t.legAvailable or 0)>0 and '抓地' or '腾空'
        local jump=t.legJumpReady and '就绪' or (t.legCooldown or 0)>0 and string.format('冷却 %.1f s',t.legCooldown) or t.legCount<4 and '需要至少 4 条腿' or '等待站稳'
        rows[#rows+1]=string.format('%s · 着地 %d/%d · 跳跃%s%s · 朝墙按 W 爬墙；空格跳（按着方向键就朝那边跳，空中靠近墙会吸附上去）；A/D 转向，Q/E 横移',
            grip,t.legContacts or 0,t.legCount,jump,t.legGrip==false and ' · 超载或腿不够，爬不了墙' or '')
    end
    return table.concat(rows,'\n')
end
return M

-- Frozen H5 inventory._detail row order and text; shared by the UI and offline parity checks.
local M={}
local function Number(value) return string.format('%.15g',value) end
function M.Build(d,ws)
    local rows={{'chip','预算',d.budget==0 and '免费' or Number(d.budget)..' 点','budget',d.budget},
        {'weight','质量',Number(d.mass)..' kg','mass',d.mass},{'shield','耐久',Number(d.hp),'hp',d.hp}}
    local function Row(icon,label,text) rows[#rows+1]={icon,label,text} end
    if d.load and d.load~=0 then Row('weight','承载',Number(d.load)..' kg');Row('gauge','基础速度',Number(d.speed)..' km/h') end
    if d.speedLimit and d.speedLimit~=0 then Row('gauge','参考限速（不叠加）',Number(d.speedLimit)..' km/h') end
    if d.wheel then Row('wheel','转向',d.steer and ('会转向，最大 '..Number(d.steerAngle)..'°') or '不转向（动力轮）') end
    if d.track then Row('wheel','转向','原地差速转向，不需要转向轮') end
    if d.wtier and d.wtier~=0 then Row(d.weapon and 'crosshair' or 'wheel',d.weapon and '武器阶位' or '阶位','T'..Number(d.wtier)..'（车辆档位不能更低）') end
    if ws and ws.drill then
        Row('crosshair',ws.boreHits and '满蓄力全段基础伤害' or '满蓄力伤害',ws.boreHits and (Number(ws.damage+(ws.boreHits-1)*ws.boreDamage)..'（'..Number(ws.boreHits)..' 段）') or Number(ws.damage))
        Row('gauge','蓄力 / 冷却',Number(ws.chargeTime)..' 秒 / '..Number(ws.interval)..' 秒')
        Row('gauge','突进时长',Number(ws.dashTime)..' 秒');Row('chip','每次耗能',Number(ws.energy))
        if not ws.easter then Row('crosshair','命中后钻削',Number(ws.boreTime)..' 秒打满，每 '..Number(ws.boreTick)..' 秒一段，需持续接触') end
        if ws.chargeEnergyFraction and ws.chargeEnergyFraction~=0 then
            Row('chip','蓄力 / 释放耗能',Number(ws.energy*ws.chargeEnergyFraction)..' / '..Number(ws.energy*(1-ws.chargeEnergyFraction))..'（尾款不足也释放）')
            Row('chip','满蓄力维持',Number(ws.holdEnergy)..' / 秒，耗尽自动释放')
        end
        if ws.easter then Row('gauge','彩蛋','命中咬住 · 车体旋转 · 甩飞') end
    elseif ws then
        local n=math.floor(1/ws.share+.5)
        Row('gauge','火力',n==1 and '1 份（一把就满）' or ('1/'..Number(n)..' 份（'..Number(n)..' 把同类凑满）'))
        local dps=ws.rate and ws.rate~=0 and ws.damage*ws.rate or ws.damage/ws.interval
        Row('crosshair','单把秒伤',Number(math.floor(dps+.5))..(ws.spinUp and '（转满后）' or ''))
        Row('chip','每发耗能',Number(tonumber(string.format('%.2f',ws.energy))))
    end
    Row('build','占用',Number(#d.cells)..' 格');Row('lock','解锁',d.unlock..'（原型已全部开放）')
    return rows
end
return M

-- Authored resultRows from the frozen five missions, wrapped by StoryHud.result.
local M={}
function M.Build(level,rules)
    local s=rules.stats
    local rows={{'用时','TIME',string.format('%d:%02d',math.floor(rules.time/60),math.floor(rules.time%60))}}
    local function Row(label,en,value) rows[#rows+1]={label,en,value} end
    local policy=level.resultPolicy
    if policy=='truck' then
        Row('运输车耐久','CARGO HP',string.format('%d%%',math.floor((s.truckHp or 0)*100+.5)))
        Row('检查点','CHECKPOINT',(s.checkpoints or 0)..' / 3')
        Row('击退海盗','WRECKED',s.kills)
    elseif policy=='shield' then
        Row('护盾剩余','SHIELD',string.format('%d%%',math.floor(math.max(0,s.shield or 0)*100+.5)))
        Row('击退海盗','WRECKED',s.kills)
        Row('重来次数','RETRIES',s.fails)
    elseif policy=='sites' then
        Row('夺回采集器','RECLAIMED',(s.sites or 0)..' / 3')
        Row('你的留言','TAG',({'机修师到此一游','狐狐是笨蛋','（没写，很专业）'})[((rules.flags or {}).tag or 2)+1])
        Row('击退海盗','WRECKED',s.kills)
    elseif policy=='boss' then
        Row('让它跪下','KNEELS',(s.kneels or 0)..' 次')
        Row('吃了几发导弹','MISSILE HITS',(s.missileHits or 0)..' 发')
    else
        local intelTotal,collectorTotal=0,0
        for _ in pairs(level.intel or {}) do intelTotal=intelTotal+1 end
        for _,step in ipairs(level.steps or {}) do if step.kind=='install' then collectorTotal=collectorTotal+1 end end
        Row('情报','INTEL',s.intel..' / '..intelTotal)
        Row('采集器','COLLECTOR',s.collectors..' / '..collectorTotal)
        Row('击退海盗','WRECKED',s.kills)
    end
    Row('战车损毁','LOSSES',s.deaths..' 次')
    return rows
end
return M

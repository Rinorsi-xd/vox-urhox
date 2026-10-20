local Nav=require 'combat.EnemyDriverNav'
local TouchMode=require 'controls.TouchMode'
local M={}
function M.Pick(battle,entry)
    local now=battle.world.time
    local cached=entry.pick
    if cached and now<cached.untilAt and cached.unit and cached.unit.alive then return cached end
    local unit=entry.unit;local p=unit:Position();local eye={p[1],p[2]+2,p[3]}
    local best=false;local seen,bestScore=false,math.huge
    for _,other in ipairs(battle.entries) do
        local enemy=other.unit
        if enemy.alive and enemy.team~=unit.team and not battle.objectives:Ignore(enemy) then
            local q=enemy:Position();local dx,dz=p[1]-q[1],p[3]-q[3]
            local distance=math.sqrt(dx*dx+dz*dz)
            local visible=distance<260 and Nav.Visible(battle.world,eye,{q[1],q[2]+1,q[3]},unit.vehicle.body,enemy)
            local score=distance-(visible and 120 or 0)-(1-enemy:Health())*40
            if score<bestScore then best,seen,bestScore=enemy,visible,score end
        end
    end
    -- 手机端首次选目标时按车位错开缓存到期时间，避免所有 AI 每 0.5 s 同一步一起打可见性射线
    local hold=.5;if not cached and TouchMode.Enabled() then hold=hold+((entry.slot or 1)%4)*.125 end
    entry.pick={unit=best,seen=seen,untilAt=now+hold}
    return entry.pick
end
return M

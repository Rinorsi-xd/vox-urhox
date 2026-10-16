-- Match-specific input, exit accounting and source spectator framing.
local M={}
function M.Key(b,key)
    if key==KEY_TAB then b.boardOn=not b.boardOn;return true end
    if not b.player.alive then
        if key==KEY_A or key==KEY_LEFT then b.spectate=(b.spectate or 0)-1;return true end
        if key==KEY_D or key==KEY_RIGHT then b.spectate=(b.spectate or 0)+1;return true end
    end
    return key==KEY_T or key==KEY_N or key==KEY_BACKSPACE
end
function M.Leave(b)
    if b.leaving then return end
    b.leaving=true
    if b.rules.state~='over' and not b.result then
        b.result=require('combat.Matchmaker').Record(b.session.app.store,'red',b.roster.rating.red,0,false)
    end
    b.session.wantsReturn=true
end
function M.ConfirmLeave(b)
    if b.leaving then return end
    if b.rules.state=='over' then M.Leave(b);return end
    if b.session.dialog and b.session.dialog.matchLeave then return end
    b.session:Pause()
    local modal=require('ui.DialogHost').Confirm(b.session,'退出对局','退出这局对战？本局按失败计算。',function() M.Leave(b) end)
    modal.matchLeave=true
end
function M.Again(b)
    if b.rules.state~='over' or b.leaving then return end
    b.session.app.restartBattle=b.mode
    M.Leave(b)
end
function M.Watched(b)
    local allies,alive={},{}
    for _,entry in ipairs(b.entries) do
        local u=entry.unit
        if u.alive then
            alive[#alive+1]=u
            if u.team=='blue' and u~=b.player then allies[#allies+1]=u end
        end
    end
    local list=#allies>0 and allies or alive
    if #list==0 then return nil end
    return list[(b.spectate or 0)%#list+1]
end
function M.Pose(b,eye,dt)
    local u=M.Watched(b);if not u then return nil end
    local p=u:Position();local yaw=u.vehicle and u.vehicle:Yaw() or 0
    local want={p[1]-math.sin(yaw)*16,p[2]+7,p[3]-math.cos(yaw)*16}
    local k=math.min(1,dt*4);local out={}
    for i=1,3 do out[i]=eye[i]+(want[i]-eye[i])*k end
    return {eye=out,target={p[1],p[2]+1.5,p[3]},name=u.name}
end
return M

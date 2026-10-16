-- Frozen testDrive._hud and _viewAngle; presentation only, in source metres.
local M={}
function M.ViewAngle(node,point)
    local camera=node.worldPosition
    local forward=node.worldRotation*Vector3.FORWARD
    local length=math.sqrt(forward.x^2+forward.z^2)
    if length==0 then length=1 end
    local fx,fz=-forward.x/length,forward.z/length
    local dx,dz=point[1]+camera.x,point[3]-camera.z
    return math.atan(-dx*fz+dz*fx,dx*fx+dz*fz)
end
function M.Apply(session,feedback,event,killed)
    local player=session.combat.player
    local total=player.feedbackOriginalHp
    local fraction=(event.amount or 0)/math.max(1,total and total~=0 and total or 3000)
    local add=killed and .7 or math.min(.3,.03+fraction*6)
    local now=session.world.time
    if not killed and now-(session.hurtShakeAt or -9)<.1 then add=add*.2
    else session.hurtShakeAt=now end
    session.trauma=math.min(1,(session.trauma or 0)+add)
    if (event.amount or 0)>0 then
        local from=event.source and event.source:Position() or event.point
        if from then feedback:Hit(M.ViewAngle(session.camera:GetNode(),from),fraction*4) end
    end
end
return M

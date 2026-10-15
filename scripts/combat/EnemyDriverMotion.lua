local A=require 'combat.EnemyDriverMath'
local N=require 'combat.EnemyDriverNav'
local M={}
local function Position(u) return u.Position and u:Position() or u.pos end
function M.Run(s,c,dt,bearing)
    local nav,pos,v=s.nav,c.pos,c.vehicle;local crowd=s.world.units or {};local yaw=c.yaw;local ws=c.weapons
    local waypoint=#s.route>0 and nav.nodes[s.route[1]] or s.navigationBlocked and pos or s.goal or c.targetPos
    while #s.route>1 do
        local nxt=nav.nodes[s.route[2]];local prev=nav.nodes[s.previousNode];local near=A.Distance(pos,waypoint)<math.max(8,s.width*.5)
        local ex,ez=prev and waypoint[1]-prev[1] or 0,prev and waypoint[3]-prev[3] or 0;local len=math.sqrt(ex^2+ez^2);if len==0 then len=1 end
        local passed=prev and((pos[1]-waypoint[1])*ex+(pos[3]-waypoint[3])*ez)>=0 and math.abs((pos[1]-waypoint[1])*ez-(pos[3]-waypoint[3])*ex)/len<s.width*.5+1
        if not near and not passed then break end
        local nl=A.Distance(pos,nxt);local mix=math.min(1,35/math.max(1,nl));local toward={pos[1]+(nxt[1]-pos[1])*mix,pos[2]+(nxt[2]-pos[2])*mix,pos[3]+(nxt[3]-pos[3])*mix};local key=s.route[1]..'>'..s.route[2]
        if not s.cornerCheck or s.cornerCheck.key~=key or s.time>=s.cornerCheck.expires then
            local cur,after,before=nav.nodes[s.route[1]],nav.nodes[s.route[3]],nav.nodes[s.previousNode]
            local slope=math.abs(nxt[2]-cur[2])>.5 or after and math.abs(after[2]-nxt[2])>.5 or before and math.abs(before[2]-cur[2])>.5;local clear=true
            if not slope and s.world.space then
                local dx,dz=toward[1]-pos[1],toward[3]-pos[3];local flat=math.sqrt(dx^2+dz^2);if flat==0 then flat=1 end
                -- Three footprint rays reject corner cuts through walls while allowing ramps.
                for _,side in ipairs({-1,0,1}) do local from={pos[1]+dz/flat*s.width*.5*side,c.bottom+1.5,pos[3]-dx/flat*s.width*.5*side}
                    local dy=cur[2]+(nxt[2]-cur[2])*mix+1.5-from[2];local ray=math.sqrt(dx^2+dy^2+dz^2)
                    if ray>.0001 then local hit=N.StaticRay(s.world,from,{dx/ray,dy/ray,dz/ray},ray,v.body);if hit and math.abs(hit.normal[2])<.65 then clear=false;break end end
                end
            end;s.cornerCheck={key=key,expires=s.time+.2,clear=clear}
        end
        if not s.cornerCheck.clear then break end
        if prev and math.abs(A.Wrap(math.atan(nxt[1]-waypoint[1],nxt[3]-waypoint[3])-math.atan(ex,ez)))>.5 then s.cornerSpeedUntil=s.time+3 end
        s.previousNode=table.remove(s.route,1);waypoint=nav.nodes[s.route[1]]
    end
    if not s.launchInitialized then s.launchInitialized=true
        for _,ids in ipairs({{'ebP','nD'},{'bP','sD'}}) do local pad,foot=nav and nav.nodes[ids[1]],nav and nav.nodes[ids[2]]
            if pad and foot and A.Distance(pos,pad)<30 then local dir=A.Sign(foot[3]-pad[3]);s.launch={x=A.Clamp(pos[1],-20,20),z=foot[3]+6*dir,dir=dir} end
        end
    end
    if s.launch and(pos[3]-s.launch.z)*s.launch.dir>=0 then s.launch=nil end
    local laneBlocked=false
    if s.launch then waypoint={s.launch.x,pos[2],s.launch.z}
        for _,u in ipairs(crowd) do if u.alive and u.vehicle and u.vehicle~=v and s:IsAlly(u) then local p=Position(u);local along=(p[3]-pos[3])*s.launch.dir
            if math.abs(p[1]-pos[1])<s.width+1.5 and along>0 and along<A.Extent(v,0)+A.Extent(u.vehicle,0)+6 then laneBlocked=true end
        end end
    end
    local start,finish=nav and nav.nodes[s.previousNode],nav and nav.nodes[s.route[1]];local edge=N.EdgeBetween(nav,s.previousNode,s.route[1])
    if not s.launch and start and finish and edge and edge[3]<20 then
        local dx,dz=finish[1]-start[1],finish[3]-start[3];local len=math.sqrt(dx^2+dz^2);if len==0 then len=1 end
        local along=((pos[1]-start[1])*dx+(pos[3]-start[3])*dz)/len;local mix=A.Clamp((along+math.max(7,s.width*1.3))/len,0,1)
        waypoint={start[1]+dx*mix,start[2]+(finish[2]-start[2])*mix,start[3]+dz*mix}
    end
    if not s.launch and #crowd>2 and s.width<=12 and #s.route>1 and not(edge and edge[3]<20) then
        local nxt=nav.nodes[s.route[2]];local e=N.EdgeBetween(nav,s.route[1],s.route[2]);local allowance=math.max(0,math.min(7,((e and e[3] or s.width+1)-s.width)/2-1))
        local dx,dz=nxt[1]-waypoint[1],nxt[3]-waypoint[3];local len=math.sqrt(dx^2+dz^2);if len==0 then len=1 end
        waypoint={waypoint[1]+dz/len*s.lane*allowance,waypoint[2],waypoint[3]-dx/len*s.lane*allowance}
    end
    local desired=math.atan(waypoint[1]-pos[1],waypoint[3]-pos[3]);local angle=A.Wrap(desired-yaw);local velocity=v.body.linvel();local speed=math.sqrt(velocity.x^2+velocity.z^2)
    local forward=velocity.x*math.sin(yaw)+velocity.z*math.cos(yaw);local function brake(k)return -A.Sign(forward)*k end
    local immobilized=v.capabilities and v.capabilities.totalLoad==0
    local hold=s.hold or immobilized or s.time<(s.holdUntil or 0) or laneBlocked
    local steer=A.Clamp(angle*1.7,-1,1);local throttle=hold and 0 or math.abs(angle)>1.1 and .12 or math.abs(angle)>.5 and .42 or 1
    local strafing=A.Strafing(s.mode);local heavy=s.role=='heavy' or s.role=='boss' or s.role=='sniper'
    local limit=strafing and math.min(s.combatSpeed or 10,s.width>12 and 7 or 99) or s.mode=='orbit' and 7 or s.width>12 and 7 or s.role=='hover' and A.Distance(pos,c.targetPos)<100 and 10 or s.role=='hover' and 15 or heavy and 12 or 18
    if speed>limit*(math.abs(angle)>(strafing and .9 or .4) and .5 or 1) then throttle=brake(.35) end
    if heavy then
        if #s.route>1 then local nxt=nav.nodes[s.route[2]];local bend=A.Wrap(math.atan(nxt[1]-waypoint[1],nxt[3]-waypoint[3])-desired)
            if math.abs(bend)>.35 and A.Distance(pos,waypoint)<math.max(14,speed*speed/10+8) and speed>4.5 then throttle=brake(.6) end
        end
        local turn=math.min(1,28/(speed*speed+1));steer=A.Clamp(steer,-turn,turn)
        if s.time<(s.cornerSpeedUntil or 0) then throttle=math.min(throttle,.3);if speed>4.5 then throttle=brake(.65) end end
    end
    if strafing and s.ledge and not hold then throttle=brake(.8)
    elseif strafing and not hold and s.width<=12 then
        s.strafeReverse=s.time>=(s.noReverseUntil or 0) and math.abs(angle)>(s.strafeReverse and 1.2 or 1.9)
        if s.strafeReverse then local back=A.Wrap(angle-math.pi);steer=-A.Clamp(back*1.7,-1,1);throttle=math.abs(back)>1.1 and -.12 or math.abs(back)>.5 and -.42 or -.85
            if -forward>limit*.75 then throttle=brake(.35) end
            local fx,fz=math.sin(yaw),math.cos(yaw);local ownLength,ownSide=A.Extent(v,yaw),A.Extent(v,yaw+math.pi/2)
            for _,u in ipairs(crowd) do if u.alive and u.vehicle and u.vehicle~=v and s:IsAlly(u) then local p=Position(u);local ox,oz=p[1]-pos[1],p[3]-pos[3];local along=-(ox*fx+oz*fz);local lateral=ox*fz-oz*fx
                if along>0 and along-ownLength-A.Extent(u.vehicle,yaw)<6+math.max(0,-forward) and math.abs(lateral)<ownSide+A.Extent(u.vehicle,yaw+math.pi/2)+1 then throttle=brake(.6);s.noReverseUntil=s.time+1.5;break end
            end end
        end
    else s.strafeReverse=false end
    if hold then steer=s.role=='sniper' and 0 or A.Clamp(A.Wrap(math.atan(c.targetPos[1]-pos[1],c.targetPos[3]-pos[3])-yaw)*1.7,-1,1) end
    if s.mode=='retreat' and math.abs(angle)>math.pi/2 and(s.tactic~='retreat' or A.Distance(pos,waypoint)<30) then throttle=-.7;steer=-A.Clamp(A.Wrap(angle-math.pi)*1.7,-1,1) end
    if not hold and not s.launch and s.width<=12 and s.time>=s.reverseUntil and not(strafing and s.strafeReverse) then
        hold,steer,throttle=M.Crowd(s,c,waypoint,speed,steer,throttle,hold,brake)
    end
    if strafing and not hold and math.abs(throttle)>.3 and speed<1.2 then s.bumpT=(s.bumpT or 0)+dt
        if s.bumpT>1 then s.bumpT=0;if s.strafeReverse then s.noReverseUntil=s.time+1.5 end;s.circle=-s.circle;s.flippedAt=s.time;s.nextThink=s.time end
    else s.bumpT=0 end
    local reset,flip=M.Recover(s,c,dt,waypoint,desired,hold,immobilized)
    if s.rejoinReverseNode and s.route[1]==s.rejoinReverseNode and not hold then
        throttle=forward>1 and brake(.65) or speed>4 and brake(.5) or -.45;steer=A.Clamp(-A.Wrap(desired-yaw-math.pi)*1.7,-1,1)
    else s.rejoinReverseNode=nil end
    if s.navigationBlocked then throttle=brake(.5);steer=0 end
    if s.time<s.reverseUntil and not immobilized then throttle=-.7;steer=s.reverseSteer;s.mode='unstick' end
    if immobilized then throttle=0;steer=0;reset=nil;s.mode='disabled';s.reverseUntil=0 end
    return {throttle=throttle,steer=steer,handbrake=hold==true,jump=false,climb=0,strafe=0,cutLift=false,aimYaw=bearing},reset,flip
end
function M.Crowd(s,c,waypoint,speed,steer,throttle,hold,brake)
    local pos,v,yaw=c.pos,c.vehicle,c.yaw;local fx,fz=math.sin(yaw),math.cos(yaw);local ownLength,ownSide=A.Extent(v,yaw),A.Extent(v,yaw+math.pi/2)
    local lookahead=math.max(18,math.min(40,ownLength+speed*1.8));local closest
    for _,u in ipairs(s.world.units or {}) do if u.alive and u.vehicle and u.vehicle~=v and s:IsAlly(u) then local p=Position(u);local dx,dz=p[1]-pos[1],p[3]-pos[3];local along,lateral=dx*fx+dz*fz,dx*fz-dz*fx
        if math.abs(p[2]-pos[2])<=math.max(4,v.spec.bounds.max[2]-v.spec.bounds.min[2],u.spec.bounds.max[2]-u.spec.bounds.min[2]) then
            local otherLength,otherSide=A.Extent(u.vehicle,yaw),A.Extent(u.vehicle,yaw+math.pi/2);local gap=along-ownLength-otherLength
            if along>0 and gap<lookahead and math.abs(lateral)<ownSide+otherSide+1 and(not closest or gap<closest.gap) then closest={u=u,along=along,lateral=lateral,gap=gap,otherSide=otherSide} end
        end
    end end
    local canFire=not c.weapons;for _,g in ipairs(c.weapons and c.weapons.groups or {}) do for _,w in ipairs(g.weapons) do if c.weapons:Aligned(w) and A.Distance(pos,c.targetPos)<(w.stats.range or 0) then canFire=true end end end
    if closest and c.charge and s.visible and canFire and A.Distance(pos,c.targetPos)<40 and closest.gap<8 then hold=true;s.mode='attack';throttle=0;steer=0
    elseif closest then
        local side=s.passing and s.passing.u==closest.u and s.passing.side or math.abs(closest.lateral)>.3 and -A.Sign(closest.lateral) or s.circle
        local lateral=ownSide+closest.otherSide+2;local p=Position(closest.u)
        if not s.detour or s.detour.u~=closest.u or s.time>s.detour.expires or A.Distance(pos,s.detour.pos)<3 then
            local choices={};for _,dir in ipairs({side,-side}) do local point={p[1]+fx*6+fz*dir*lateral,pos[2],p[3]+fz*6-fx*dir*lateral};choices[#choices+1]={side=dir,pos=point,cost=A.Distance(pos,point)+A.Distance(point,waypoint)} end
            if choices[2].cost<choices[1].cost then choices[1],choices[2]=choices[2],choices[1] end
            local pick=choices[1];for _,choice in ipairs(choices) do if N.Direct(s.world,pos,choice.pos,v,s.width) then pick=choice;break end end
            s.detour={u=closest.u,expires=s.time+5,pos=pick.pos,side=pick.side}
        end
        side=s.detour.side;s.passing={u=closest.u,side=side};local bypass=s.detour.pos
        if not s.bypassCheck or s.time>=s.bypassCheck.expires or s.bypassCheck.side~=side or s.bypassCheck.u~=closest.u then
            local a,b=s.nav and s.nav.nodes[s.previousNode],s.nav and s.nav.nodes[s.route[1]];local edge=N.EdgeBetween(s.nav,s.previousNode,s.route[1]);local within=true
            if a and b and edge and edge[3]<20 then local dx,dz=b[1]-a[1],b[3]-a[3];local len=math.sqrt(dx^2+dz^2);if len==0 then len=1 end
                local offset=math.abs((bypass[1]-a[1])*dz-(bypass[3]-a[3])*dx)/len;within=offset+s.width*.5+.5<=edge[3]*.5
            end;s.bypassCheck={side=side,u=closest.u,expires=s.time+.2,allowed=within and N.Direct(s.world,pos,bypass,v,s.width)}
        end
        if s.bypassCheck.allowed then local angle=A.Wrap(math.atan(bypass[1]-pos[1],bypass[3]-pos[3])-yaw);steer=A.Clamp(angle*1.7,-1,1);throttle=math.abs(angle)>1.1 and .12 or math.abs(angle)>.5 and .42 or .7
            if speed>math.max(3,math.sqrt(math.max(0,closest.gap)*6)) then throttle=brake(.6) end
        else throttle=closest.gap<5 and brake(.35) or math.min(throttle,.15) end
    end;return hold,steer,throttle
end
function M.Recover(s,c,dt,waypoint,desired,hold,immobilized)
    local v,pos=c.vehicle,c.pos;local q=v.body.rotation and v.body.rotation();local up=q and 1-2*(q.x*q.x+q.z*q.z) or 1;local flip=false;local reset
    if up<.35 and not v.airdropActive then s.flippedFor=(s.flippedFor or 0)+dt;if s.flippedFor>=1.5 then flip=true;s.flippedFor=0;s.sample=nil end else s.flippedFor=0 end
    local navigating=#s.route>0 and(s.mode=='approach' or s.mode=='seek-vantage' or s.mode=='retreat' or s.mode=='reposition');local key=s.route[1] or 'direct'
    local distance=A.Distance(pos,#s.route>0 and s.nav.nodes[s.route[1]] or waypoint)
    if not navigating or not s.progress or s.progress.key~=key or distance<s.progress.best-1 then s.progress={key=key,best=distance,at=s.time} end
    local noProgress=navigating and s.time-s.progress.at>10
    if not hold and s.time>=s.reverseUntil then
        if not s.sample then s.sample=A.Copy(pos);s.sampleTime=s.time end
        if s.time-s.sampleTime>=3 then
            local stalled=A.Distance(s.sample,pos)<1 or noProgress
            if stalled and(s.canEngage or A.Strafing(s.mode) and not s.strafeStalled) and not s.navigationBlocked then
                if A.Strafing(s.mode) then s.circle=-s.circle;s.flippedAt=s.time;s.strafeStalled=not s.canEngage else s.holdUntil=s.time+2.5 end;s.consecutiveStuck=0
            elseif stalled then
                s.strafeStalled=false;s.stuckCount=s.stuckCount+1;s.consecutiveStuck=s.consecutiveStuck+1;s.reverseUntil=s.time+1.5;s.reverseSteer=s.random()<.5 and -1 or 1
                s.route={};s.previousNode=nil;s.rejoinReverseNode=nil;s.progress={key=key,best=distance,at=s.time}
                if s.consecutiveStuck>=3 then
                    local radius=math.sqrt(s.width^2+(v.spec.bounds.max[3]-v.spec.bounds.min[3])^2)/2
                    local id=N.Nearest(s.nav,pos,s.width,function(p)
                        for _,u in ipairs(s.world.units or {}) do if u.alive and u.vehicle~=v and u.spec then local upos=Position(u)
                            if math.abs(upos[2]-p[2])<math.max(4,(u.spec.bounds.max[2]-u.spec.bounds.min[2])+(v.spec.bounds.max[2]-v.spec.bounds.min[2])) and A.Distance(upos,p)<radius+math.sqrt((u.spec.bounds.max[1]-u.spec.bounds.min[1])^2+(u.spec.bounds.max[3]-u.spec.bounds.min[3])^2)/2+1 then return false end
                        end end;return true
                    end)
                    if id then reset={pos=A.Copy(s.nav.nodes[id]),yaw=desired};s.resets=s.resets+1 end;s.consecutiveStuck=0
                end
            else s.consecutiveStuck=0;s.strafeStalled=false end
            s.sample=A.Copy(pos);s.sampleTime=s.time
        end
    elseif hold then s.sample=nil;s.consecutiveStuck=0 end
    return reset,flip
end
return M

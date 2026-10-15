local A=require 'combat.EnemyDriverMath'
local N=require 'combat.EnemyDriverNav'
local M={}
function M.Choose(s,r,near,far,engaged,canRetreat,cornered)
    local C=A.C;local life=s.life or 1;local prev=s.tactic;local scores={};local order={}
    if canRetreat then
        local retreating=prev=='retreat';local age=retreating and s.time-s.retreatSince or 0
        local cooled=retreating or s.time>=(s.retreatCooldownUntil or -math.huge)
        scores.retreat=cooled and 1.4*A.Utility({1-A.Sigmoid(life,25,retreating and C.recoverAbove or C.retreatBelow),A.Ramp(age,C.retreatTimeout,C.retreatTimeout-3),cornered and .1 or 1}) or 0;order[#order+1]='retreat'
    end
    if engaged then
        scores.strafe=A.Utility({A.Smooth(A.Ramp(r,near-10,near))*A.Smooth(A.Ramp(r,far+15,far)),.95})
        scores.push=A.Utility({A.Smooth(A.Ramp(r,far-3,far+20)),A.Sigmoid(life,10,.3)})
        scores.backoff=A.Utility({A.Smooth(A.Ramp(r,near,near-12)),1});for _,name in ipairs({'strafe','push','backoff'}) do order[#order+1]=name end
    end
    if scores.retreat and scores.retreat<.5 then scores.retreat=0 end
    local best,score=nil,.05
    for _,name in ipairs(order) do local v=scores[name]+(name==prev and C.inertia or 0)+s.random()*.03;if v>score then best,score=name,v end end
    if prev and prev~=best and best~='retreat' and prev~='retreat' and s.time<(s.tacticUntil or 0) and (scores[prev] or 0)>.05 then best=prev end
    if best~=prev then
        s.tacticUntil=s.time+C.commit
        if best=='retreat' then s.retreatSince=s.time-(s.time-(s.retreatLeft or -math.huge)<4 and math.min(s.retreatAge or 0,C.retreatTimeout) or 0);s.cover=nil;s.coverCheckAt=0 end
        if prev=='retreat' then s.retreatLeft=s.time;s.retreatAge=s.time-s.retreatSince;if not cornered then s.retreatCooldownUntil=s.time+(life>=C.recoverAbove and 3 or C.retreatCooldown) end end
    end
    s.tactic=best;s.scores=scores;return best
end
function M.Cover(s,c)
    if s.time<(s.coverCheckAt or 0) then return s.cover end;s.coverCheckAt=s.time+A.C.coverEvery
    local h=1;for _,w in ipairs(c.targetUnit and c.targetUnit.vehicle.spec.weapons or {}) do h=math.max(h,w.pivot and w.pivot[2] or 0) end
    local eye={c.targetPos[1],c.targetPos[2]+h,c.targetPos[3]};local exclude=c.targetUnit and c.targetUnit.vehicle.body
    local function hidden(p) return not N.Visible(s.world,eye,{p[1],p[2]+c.shootHeight,p[3]},exclude) end
    if s.cover and A.Distance(s.cover.threat,c.targetPos)<6 and (not s.cover.hidden or hidden(s.cover.p)) then return s.cover end
    if not s.nav then s.cover=nil;return nil end
    local g=s:Graph();local ax,az=c.pos[1]-c.targetPos[1],c.pos[3]-c.targetPos[3];local al=math.sqrt(ax*ax+az*az);if al==0 then al=1 end;local candidates={}
    for _,id in ipairs(g.ids) do local p=g.nodes[id];local d0,dT=A.Distance(p,c.pos),A.Distance(p,c.targetPos)
        if d0<=90 and dT>=math.max(25,c.r*.8) and not(c.zone and N.Inside(c.zone,p,c.zonePad)) then
            local along=d0>1 and ((p[1]-c.pos[1])*ax+(p[3]-c.pos[3])*az)/(d0*al) or 0
            candidates[#candidates+1]={id=id,p=p,pre=A.Utility({A.Ramp(d0,90,8),A.Ramp(dT,25,110),.35+.65*(along+1)/2}),order=#candidates+1}
        end
    end
    table.sort(candidates,function(a,b) return a.pre>b.pre or a.pre==b.pre and a.order<b.order end)
    local best
    for i=1,math.min(10,#candidates) do local v=candidates[i];local hid=hidden(v.p);local score=v.pre*(hid and 1 or .25)
        if not best or score>best.score then v.hidden=hid;v.score=score;v.threat=A.Copy(c.targetPos);best=v end
    end;s.cover=best;return best
end
function M.Firing(s,c)
    if s.firing and s.time<s.firingCheckAt and A.Distance(s.firing.threat,c.targetPos)<8 and (not s.firing.p or A.Distance(c.pos,s.firing.p)>=6) then return s.firing.p and s.firing or nil end
    s.firingCheckAt=s.time+1;s.firing={threat=A.Copy(c.targetPos)};if not s.nav then return nil end
    local candidates={};for _,id in ipairs(s:Graph().ids) do local p=s.nav.nodes[id];local dT,d0=A.Distance(p,c.targetPos),A.Distance(p,c.pos)
        if dT>=c.near-5 and dT<=c.far+10 and d0>=8 and d0<=120 and not(c.zone and N.Inside(c.zone,p,c.zonePad)) then candidates[#candidates+1]={id=id,p=p,cost=d0+math.abs(dT-(c.near+c.far)/2)*.5,order=#candidates+1} end
    end
    table.sort(candidates,function(a,b) return a.cost<b.cost or a.cost==b.cost and a.order<b.order end)
    for i=1,math.min(8,#candidates) do local n=candidates[i];local from={n.p[1],n.p[2]+c.shootHeight,n.p[3]}
        if N.Visible(s.world,from,c.aimFrom(from),c.vehicle.body,c.targetUnit) then n.threat=A.Copy(c.targetPos);s.firing=n;return n end
    end
end
function M.Strafe(s,c)
    local theta=math.atan(c.dx,c.dz);local step=A.Clamp(16/math.max(c.radius,8),.18,.8);local giant=s.width>12;local best
    local v=c.vehicle.body.linvel();local overshoot=A.Clamp(math.sqrt(v.x*v.x+v.z*v.z)*.8,3,9);local settled=s.time-(s.flippedAt or -math.huge)<2.5
    for _,side in ipairs({s.circle,-s.circle}) do for _,k in ipairs({0,-6,6}) do
        if side~=s.circle and settled and best then break end
        local rad=math.max(6,c.radius+k);local a=theta+side*step;local p={c.targetPos[1]+math.sin(a)*rad,c.pos[2],c.targetPos[3]+math.cos(a)*rad}
        if c.zone and N.Inside(c.zone,p,c.zonePad) then p=N.Edge(c.zone,p,c.zonePad+2,c.pos) end
        if c.clear(p) then
            if giant then return {p=p,s=side} end
            local len=A.Distance(c.pos,p);if len==0 then len=1 end
            local beyond={p[1]+(p[1]-c.pos[1])/len*overshoot,p[2],p[3]+(p[3]-c.pos[3])/len*overshoot}
            if N.Direct(s.world,c.pos,beyond,c.vehicle,s.width) then
                local from={p[1],c.pos[2]+c.muzzleHeight,p[3]};local los=N.Visible(s.world,from,c.aimFrom(from),c.vehicle.body,c.targetUnit)
                local score=(los and 4 or 0)+(not N.Narrow(s.nav,p,s.width) and 2 or 0)+(side==s.circle and 3.5 or 0)+(k==0 and .5 or 0)
                if not best or score>best.score then best={p=p,s=side,score=score} end;if score>=9.5 then break end
            end
        end
    end end
    if best then s.checkedDirect=best.p end;return best
end
function M.Slide(s,c)
    local ax,az=c.zone.rx+c.zonePad+2,c.zone.rz+c.zonePad+2;local phi=math.atan((c.pos[1]-c.zone.pos[1])/ax,(c.pos[3]-c.zone.pos[3])/az);local step=14/((ax+az)/2)
    for _,side in ipairs({s.circle,-s.circle}) do local p={c.zone.pos[1]+ax*math.sin(phi+side*step),c.pos[2],c.zone.pos[3]+az*math.cos(phi+side*step)}
        if N.Direct(s.world,c.pos,p,c.vehicle,s.width) then s.circle=side;s.checkedDirect=p;return p end
    end
end
return M

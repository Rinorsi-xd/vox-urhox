local A=require 'combat.EnemyDriverMath'
local N=require 'combat.EnemyDriverNav'
local T=require 'combat.EnemyDriverTactics'
local M={}
function M.Run(s,c)
    local pos,target,v=c.pos,c.targetPos,c.vehicle;local ws=c.weapons;local motion=v.body.linvel();local arrival=math.sqrt(motion.x^2+motion.z^2)
    s.nextThink=s.time+A.T.thinkInterval;s.visible=N.Visible(s.world,c.shootFrom,c.targetAim,v.body,c.targetUnit)
    if s.visible then if not s.visibleSince then s.visibleSince=s.time end;s.lastSeen=s.time else s.visibleSince=nil end
    local r=A.Distance(pos,target);c.r=r;c.dx=(pos[1]-target[1])/math.max(.01,r);c.dz=(pos[3]-target[3])/math.max(.01,r)
    local tv=c.targetUnit and c.targetUnit.vehicle and c.targetUnit.vehicle.body.linvel();local omega=0
    if tv then local x,z=tv.x-motion.x*.5,tv.z-motion.z*.5;local along=-(x*c.dx+z*c.dz);omega=math.sqrt((x+c.dx*along)^2+(z+c.dz*along)^2)/math.max(8,r) end
    local tierAim=1-.04*(s.tier-1);s.omega=omega
    s.error=(s.random()*2-1)*(A.T.aimErrorDegrees*(1-.1*(s.tier-1))*s.skill*math.pi/180+A.T.aimMotionK*omega*tierAim)
    s.lag=s.random()*A.T.trackLag*tierAim
    local inRange=not ws;for _,g in ipairs(ws and ws.groups or {}) do for _,w in ipairs(g.weapons) do if r<=(w.stats.range or 0) then inRange=true end end end
    local engage=s.visible and inRange;s.canEngage=engage;s.life=A.Life(s.unit)
    local stamp=s.unit.hitAt or s.unit._hurtAt;if stamp~=nil and stamp~=s.hitStamp then if s.hitStamp~=nil and stamp>=0 then s.hurtAt=s.time end;s.hitStamp=stamp end
    c.zone=c.shield and c.shield.zone;c.zonePad=math.sqrt(s.width^2+(v.spec.bounds.max[3]-v.spec.bounds.min[3])^2)/2+4
    c.shootHeight=math.max(.6,c.muzzleHeight-v.spec.bounds.min[2]);local approach=math.atan(target[1]-pos[1],target[3]-pos[3])
    local separation=math.max(8,A.Extent(v,approach)+A.Extent(c.targetUnit and c.targetUnit.vehicle,approach)+2)
    local P=A.C.roles[c.charge and s.role=='sniper' and 'assault' or s.role] or A.C.roles.assault
    c.near=math.max(separation,c.charge and P.near*.5 or P.near);c.far=math.max(c.near+8,c.charge and P.far*.6 or P.far);s.combatSpeed=P.speed
    local mobile=not v.capabilities or v.capabilities.totalLoad~=0;local attacking=c.targetUnit or not c.target.radius
    local cornered=s.visible and r<14;local ownStyle=not c.charge and(s.role=='sniper' or s.role=='hover' and r<100)
    local engaged=(engage or inRange and A.Strafing(s.mode) and s.time-s.lastSeen<2.5) and r<c.far+30 and mobile and not ownStyle
    local tactic;if attacking then tactic=T.Choose(s,r,c.near,c.far,engaged,mobile and c.targetUnit~=nil and s.role~='boss',cornered) else s.tactic=nil end
    local goal=A.Copy(target);s.mode='approach';s.hold=false
    if not c.targetUnit and c.target.radius then
        if r<c.target.radius*.6 then s.mode='guard';s.hold=true;goal=A.Copy(pos) end
    elseif tactic=='retreat' then
        s.mode='retreat';local cover=T.Cover(s,c)
        if cover then goal=A.Copy(cover.p);if A.Distance(pos,cover.p)<math.max(6,s.width*.6) then
            if cover.hidden and not s.visible then s.hold=true;goal=A.Copy(pos) elseif not cover.hidden then s.cover=nil;s.coverCheckAt=0 end
        end else goal={pos[1]+c.dx*30,pos[2],pos[3]+c.dz*30} end
    elseif not c.charge and s.role=='sniper' then goal=M.Sniper(s,c,goal)
    elseif not c.charge and s.role=='hover' and r<100 then
        s.mode=s.time%10<4 and 'pass' or 'withdraw';local radius=s.mode=='pass' and 8 or 28
        if s.mode=='withdraw' then goal={target[1]+c.dx*radius-c.dz*s.circle*18,pos[2],target[3]+c.dz*radius+c.dx*s.circle*18}
        else goal={target[1]+c.dx*8-c.dz*s.circle*10,pos[2],target[3]+c.dz*8+c.dx*s.circle*10} end
        if s.blockedOrbitTarget and(not engage or A.Distance(target,s.blockedOrbitTarget)>8) then s.blockedOrbitTarget=nil end
        if engage and r<38 and(s.blockedOrbitTarget or not N.Direct(s.world,pos,goal,v,s.width)) then goal=A.Copy(pos);s.mode='hold';s.hold=true;s.blockedOrbitTarget=s.blockedOrbitTarget or A.Copy(target) end
    elseif tactic then
        if not s.weave then s.weave=s.random()<.5 and -1 or 1 end
        local mid=(c.near+c.far)/2+s.lane*(c.far-c.near)*.15+s.weave*(c.far-c.near)*.25
        c.radius=tactic=='push' and math.max(c.near,math.min(r-14,mid)) or tactic=='backoff' and math.min(c.far,r+14) or A.Clamp(mid,r-6,r+6)
        local neighbours={};for _,u in ipairs(s.world.units or {}) do if u.alive and u.vehicle and u.vehicle~=v and s:IsAlly(u) then neighbours[#neighbours+1]=u end end
        if not s.flipAt then s.flipAt=s.time+3+s.random()*2 end
        local juke=(s.hurtAt or -math.huge)>s.time-.2-1e-6 and s.time-(s.flippedAt or -math.huge)>2.5 and s.random()<.35
        local nearby=false;for _,u in ipairs(neighbours) do if A.Distance(u:Position(),pos)<25 then nearby=true end end
        if(s.time>=s.flipAt or juke) and not nearby then if juke or s.random()<(P.reverse or .35) then s.circle=-s.circle;s.flippedAt=s.time else s.weave=-s.weave end;s.flipAt=s.time+3+s.random()*2 end
        c.clear=function(p) for _,u in ipairs(neighbours) do local up=u:Position();local axis=math.atan(p[1]-up[1],p[3]-up[3]);if A.Distance(p,up)<A.Extent(u.vehicle,axis)+s.width*.55+2 then return false end end;return true end
        local pick=T.Strafe(s,c)
        if pick then goal=pick.p;s.mode=tactic;if pick.s~=s.circle then s.circle=pick.s;s.flippedAt=s.time end
        else local node=T.Firing(s,c);if node then goal=A.Copy(node.p);s.mode='reposition' elseif s.visible then goal=A.Copy(pos);s.mode='hold';s.hold=true else goal=A.Copy(target);s.mode='approach' end end
        if pick and s.width<=12 and arrival>3 then local k=math.max(4,arrival*.9)/arrival;s.ledge=not N.Direct(s.world,pos,{pos[1]+motion.x*k,pos[2],pos[3]+motion.z*k},v,s.width) else s.ledge=false end
    end
    if c.zone and(N.Inside(c.zone,goal,c.zonePad) or N.Inside(c.zone,pos,c.zonePad)) then
        goal=N.Edge(c.zone,pos,c.zonePad,goal)
        if A.Distance(pos,goal)<8 and s.visible then local slide=s.mode~='retreat' and T.Slide(s,c);s.mode='siege';if slide then goal=slide else s.hold=true end end
    end
    M.Route(s,c,goal)
end
function M.Sniper(s,c,goal)
    local pos,target=c.pos,c.targetPos;local L=s.relocating
    if L and(s.time>L.expires or(L.shuffle and A.Distance(pos,L.shuffle)<5 or not L.shuffle and s.vantage and A.Distance(pos,s.vantage)<10 and A.Distance(pos,L.from)>20)) then s.relocating=nil end
    if c.r>=(s.sniping and 115 or 120) and c.r<=(s.sniping and 205 or 200) and s.visible and not s.relocating then
        if not s.sniping then s.sniping=true;s.plantAt=s.time;s.plantUntil=s.time+3+s.random()*2 end
        if s.time>=s.plantUntil or(s.hurtAt or -math.huge)>s.plantAt+.3 then s.relocating={from=A.Copy(pos),expires=s.time+15};s.vantage=nil;s.sniping=false
        else s.hold=true;s.mode='snipe';goal=A.Copy(pos) end
    end
    if s.hold then return goal end;s.sniping=false;s.mode=c.r<40 and 'retreat' or 'seek-vantage'
    local nodes={};for id,p in pairs(s.nav and s.nav.nodes or {}) do local d=A.Distance(p,target);local from={p[1],p[2]+c.shootHeight,p[3]}
        if d>=125 and d<=190 and N.Visible(s.world,from,c.aimFrom(from),c.vehicle.body,c.targetUnit) then
            local flat=N.HasFlatEdge(s.nav,id)
            nodes[#nodes+1]={id=id,p=p,cost=A.Distance(p,pos)-p[2]*.2+(flat and 0 or 150)}
        end
    end
    table.sort(nodes,function(a,b) return a.cost<b.cost or a.cost==b.cost and a.id<b.id end)
    local moved={};if s.relocating then for _,n in ipairs(nodes) do if A.Distance(n.p,s.relocating.from)>=30 then moved[#moved+1]=n end end else moved=nodes end
    local pool=#moved>0 and moved or nodes
    if s.relocating and #moved==0 and c.r>=40 then
        if not s.relocating.shuffleChecked then s.relocating.shuffleChecked=true;s.circle=-s.circle;c.radius=c.r;c.clear=function()return true end
            local pick=T.Strafe(s,c);s.relocating.shuffle=pick and(pick.score or 0)>=4 and pick.p or nil;s.relocating.expires=s.time+6;if pick then s.circle=pick.s end
        end
        if s.relocating.shuffle then goal=s.relocating.shuffle;s.checkedDirect=goal;s.mode='reposition'
        else s.relocating=nil;s.sniping=true;s.plantAt=s.time;s.plantUntil=s.time+3;s.hold=s.visible;s.mode=s.visible and 'snipe' or 'seek-vantage';goal=s.visible and A.Copy(pos) or s.vantage or goal end
    else
        local found=false;for _,n in ipairs(pool) do if n.p==s.vantage then found=true end end;if not found then s.vantage=pool[1] and pool[1].p end
        local cover=not s.vantage and T.Cover(s,c);goal=s.vantage or cover and cover.p or {target[1]+c.dx*155,pos[2],target[3]+c.dz*155}
        if cover and A.Distance(pos,cover.p)<math.max(6,s.width*.6) then s.hold=true;goal=A.Copy(pos) end
    end;return goal
end
function M.Route(s,c,goal)
    local nav,pos,v=s.nav,c.pos,c.vehicle;local changed=not s.goal or A.Distance(s.goal,goal)>20;s.goal=goal
    local checked=s.checkedDirect==goal;s.checkedDirect=nil
    local roadExit=checked or #s.route==0 or A.Distance(pos,nav.nodes[s.route[#s.route]])<15
    local direct=roadExit and s.width<=12 and(checked or not(s.role=='sniper' and not s.hold)) and(checked or N.Direct(s.world,pos,goal,v,s.width))
    if direct then s.route={};s.navigationBlocked=false
    elseif changed or #s.route==0 then
        local keep=changed and #s.route>0;local start=keep and s.route[1] or N.Nearest(nav,pos,s.width,function(p)return N.Direct(s.world,pos,p,v,s.width)end)
        s.navigationBlocked=not start and #s.route==0
        if start then s.route=N.Path(nav,start,goal,s.width,s.jitter);if not keep then s.previousNode=nil end end
        if c.zone then for i,id in ipairs(s.route) do if N.Inside(c.zone,nav.nodes[id],c.zonePad) then for j=#s.route,i,-1 do s.route[j]=nil end;break end end end
        if not keep and #s.route>1 then
            local a,b=nav.nodes[s.route[1]],nav.nodes[s.route[2]];local e=N.EdgeBetween(nav,s.route[1],s.route[2]);local dx,dz=b[1]-a[1],b[3]-a[3];local len=math.sqrt(dx^2+dz^2);if len==0 then len=1 end
            local mix=((pos[1]-a[1])*dx+(pos[3]-a[3])*dz)/(len*len);local lateral=math.abs((pos[1]-a[1])*dz-(pos[3]-a[3])*dx)/len
            local j=A.Clamp(mix+math.min(15/len,.5),0,1);local join={a[1]+(b[1]-a[1])*j,a[2]+(b[2]-a[2])*j,a[3]+(b[3]-a[3])*j}
            if mix>=-1e-5 and mix<1 and lateral<math.max(1,((e and e[3] or 0)-s.width)/2-.5) and math.abs(c.bottom-(a[2]+(b[2]-a[2])*mix))<3 and(mix>.001 or N.Direct(s.world,pos,join,v,s.width)) then s.previousNode=table.remove(s.route,1) end
        end
        if not keep then local n=nav and nav.nodes[s.route[1]];s.rejoinReverseNode=n and A.Distance(pos,n)<45 and math.abs(A.Wrap(math.atan(n[1]-pos[1],n[3]-pos[3])-c.yaw))>2.1 and s.route[1] or nil end
    end
    while #s.route>1 and A.Distance(pos,nav.nodes[s.route[1]])<math.max(5,s.width*.5) do local a,b,d=nav.nodes[s.route[1]],nav.nodes[s.route[2]],nav.nodes[s.route[3]]
        if math.abs(a[2]-b[2])<.5 and(not d or math.abs(b[2]-d[2])<.5) then break end;s.previousNode=table.remove(s.route,1)
    end
end
return M

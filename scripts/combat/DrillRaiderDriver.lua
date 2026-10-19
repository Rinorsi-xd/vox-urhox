-- Frozen shared/ai/drillRaider.js. Fixed nose weapon steers the whole chassis.
local Base=require('combat.EnemyDriver')
local V=require('core.Math3')
local M={RAIDER={near=20,far=32,aimTolerance=.055,chargeTolerance=.16,flingDelay=.2}}
M.__index=function(_,key) return M[key] or Base[key] end
local C=M.RAIDER
local function Wrap(a) return math.atan(math.sin(a),math.cos(a)) end
local function Hypot(x,y)
    local scale=math.max(math.abs(x),math.abs(y));if scale==0 then return 0 end
    return scale*math.sqrt((x/scale)^2+(y/scale)^2)
end
function M.New(world,unit,role,index,member)
    return setmetatable(Base.New(world,unit,role,index,member),M)
end
function M:Direct(from,to)
    local v=self.unit.vehicle;local dx,dz=to[1]-from[1],to[3]-from[3];local length=math.sqrt(dx*dx+dz*dz)
    if length>65 then return false end
    local function Height(x,z,above)
        local h=self.world.space:Raycast({x,above,z},{0,-1,0},12,v.body,nil,true)
        return h and h.point[2] or nil
    end
    local start=Height(from[1],from[3],from[2]+v.spec.bounds.min[2]+3);if not start then return false end
    local count=math.max(1,math.ceil(length/5));local step=length/count;local x,z=dx/math.max(1,length),dz/math.max(1,length);local previous=start
    for i=1,count do
        local px,pz=from[1]+dx*i/count,from[3]+dz*i/count;local y=Height(px,pz,previous+3)
        if not y or math.abs(y-previous)>step*.3+.25 then return false end
        for _,sign in ipairs({-1,1}) do local side=Height(px+z*self.width*.45*sign,pz-x*self.width*.45*sign,y+3)
            if not side or math.abs(side-y)>math.max(.5,self.width*.18) then return false end
        end
        previous=y
    end
    local delta={dx,previous-start,dz};local len=V.Length(delta)
    if len>.1 and self.world.space:Raycast({from[1],start+.5,from[3]},V.Scale(delta,1/len),len-.05,v.body,nil,true) then return false end
    return true
end
function M:Policy(dt,state,ctx)
    local v,aim,sys=ctx.vehicle,ctx.aim,ctx.system;local drill=sys and sys.drill;local group=sys and sys:Group();local w=group and group.weapons[1]
    state.trigger=false
    if not v or not aim or not w or not w.stats.drill or v.airdropActive or state.mode=='landing' or state.flip or state.reset then
        if drill and drill.held then drill:Cancel() end;return state
    end
    local p=v.body.translation();local pos={p.x,p.y,p.z};local q=v.body.rotation();local muzzle=sys:Muzzle(w,{pos=pos,quat=q})
    local delta=V.Sub(aim,muzzle.pos);local range=Hypot(delta[1],delta[3])
    local angle=Wrap(math.atan(delta[1],delta[3])-math.atan(muzzle.dir[1],muzzle.dir[3]))
    local yaw=v:Yaw();local vel=v.body.linvel();local forward=vel.x*math.sin(yaw)+vel.z*math.cos(yaw);local speed=math.sqrt(vel.x^2+vel.z^2)
    local clear=self:Visible(muzzle.pos,aim,ctx.target);local shield=ctx.shield;local protected=shield and shield.active and shield.contains and shield.contains(aim)
    local reachable=range<C.far+10 and self:Direct(pos,aim)
    if protected or not clear or not reachable or 1-2*(q.x*q.x+q.z*q.z)<.75 then
        if drill.held then drill:Cancel() end;self.chargeWait=0;return state
    end
    self.chargeWait=drill.held and (self.chargeWait or 0)+dt or 0
    if self.chargeWait>4 then drill:Cancel();self.chargeWait=0 end
    local throttle,steer,handbrake=0,V.Clamp(angle*3,-1,1),false
    if range<C.near then
        local back={pos[1]-math.sin(yaw)*5,pos[2],pos[3]-math.cos(yaw)*5}
        if self:Direct(pos,back) then throttle=forward>1 and -.6 or forward<-3 and .3 or -.3;steer=-steer else handbrake=true end
    elseif range>C.far then throttle=speed>5 and -.4 or speed<1 and .85 or .35
    elseif math.abs(angle)>C.aimTolerance then
        local reverse=range<(C.near+C.far)/2;local direction=reverse and -4 or 4;local nextPos={pos[1]+math.sin(yaw)*direction,pos[2],pos[3]+math.cos(yaw)*direction}
        if self:Direct(pos,nextPos) then throttle=reverse and (forward<-2 and .2 or -.22) or (forward>2 and -.2 or .22);if reverse then steer=-steer end else handbrake=true end
    else local sign=forward>0 and 1 or forward<0 and -1 or 0;throttle=speed>.6 and -sign*.6 or 0;handbrake=true end
    local inRange=range>=C.near and range<=C.far;local facing=math.abs(angle)<C.aimTolerance
    local ready=false
    if inRange and facing and speed<1.5 and drill.held and w.windup>=1 then
        local radius=ctx.target and ctx.target.spec and ctx.target.spec.bounds.radius or 0
        local hit=drill:TraceLaunch(w,{pos=pos,quat=q,aim=aim,body=v.body},self.world,range+radius)
        ready=hit and hit.owner and hit.owner.ref==ctx.target or false
    end
    local trigger=drill.held and not(w.windup>=1 and ready) or not drill.held and inRange and math.abs(angle)<C.chargeTolerance and w.cool<=0 and not sys.offline
    self.sample=nil;self.progress=nil;self.reverseUntil=0;self.mode=drill.held and 'drill-charge' or inRange and 'drill-align' or 'drill-spacing'
    self.command={};for key,value in pairs(state.command) do self.command[key]=value end
    self.command.throttle=throttle;self.command.steer=steer;self.command.handbrake=handbrake
    state.command=self.command;state.aim=aim;state.trigger=trigger;state.reset=nil;state.flip=false;state.mode=self.mode;return state
end
function M:Step(dt,target,charge,shield)
    local u=self.unit;local aim=target and target:Position();local sys=u.weapons
    if sys.drill.active then self.sample=nil;self.progress=nil;self.mode='drill-active';return {throttle=0,steer=0,handbrake=false},aim,false,{salvo=false,mode=self.mode} end
    local command,baseAim,fire,info=Base.Step(self,dt,target,true)
    if target and target.passive then
        if sys.drill.held then sys.drill:Cancel() end
        return command,baseAim,false,info
    end
    info=info or {};info.command=command;info.aim=baseAim;info.trigger=fire;info.mode=self.mode
    local out=self:Policy(dt,info,{vehicle=u.vehicle,aim=aim,system=sys,target=target,shield=shield})
    return out.command,out.aim,out.trigger,out
end
function M.ArmExplosion(unit,fx)
    if (unit.team=='red' or unit.team=='enemy') and unit.endless and unit.endless.flingSelfDestruct and fx.type=='drill' and fx.stage=='fling' then unit.raiderFuse=C.flingDelay end
end
function M.StepExplosion(unit,dt)
    if unit.raiderFuse==nil or not unit.alive then return false end
    unit.raiderFuse=unit.raiderFuse-dt
    if unit.raiderFuse<=1e-8 then
        local core=unit.bp:CoreParts()[1]
        if core then unit.env.fx[#unit.env.fx+1]={type='explode',pos={table.unpack(unit.pos)},radius=3,remote=true};unit:Damage(core.id,1e9,unit.pos);unit:Flush() end
        unit.raiderFuse=nil
    end
    return true
end
return M

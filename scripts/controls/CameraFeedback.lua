-- Frozen testDrive._effects camera response. The host exposes stompV for story
-- and salvage impulses; feedback never changes aim input or the physics body.
local M={};M.__index=M
local DEG=180/math.pi
local function Wave(t,seed) return .6*math.sin(t+seed)+.4*math.sin(t*2.31+seed*1.7) end
function M.New(host)
    local self=setmetatable({host=host},M);self:Reset();return self
end
function M:Reset()
    local s=self.host
    s.trauma=0;s.drillImpact=0;s.shakeT=0;s.rumble=0;s.rumbleTo=0;s.rumbleK=1
    s.rumbleAt=-9;s.rumbleT=0;s.thump=0;s.stompY=0;s.stompV=0;s.nodY=0;s.nodV=0;s.mechSpeed=0
    self.events={};self.remote={};self.count=0
end
function M:Queue(e,remote)
    self.count=self.count+1;self.events[self.count]=e;self.remote[self.count]=remote==true
end
function M:Flush(com)
    for i=1,self.count do self:Event(self.events[i],self.remote[i],com);self.events[i]=nil;self.remote[i]=nil end
    self.count=0
end
function M:Discard()
    for i=1,self.count do self.events[i]=nil;self.remote[i]=nil end
    self.count=0
end
function M:Event(e,remote,com)
    local s=self.host
    if e.type=='drill' then
        if e.stage=='impact' then s.trauma=math.max(s.trauma,.85);s.drillImpact=1
        elseif e.stage=='grind' then s.trauma=math.max(s.trauma,.36);s.drillImpact=math.max(s.drillImpact,.28)
        else s.trauma=math.max(s.trauma,e.stage=='fling' and .65 or .25) end
    end
    if e.type=='shot' and not remote and not e.remote then
        if e.kind=='mg' then
            s.rumbleTo=math.max(s.rumbleTo,(e.spin or 1)^2);s.rumbleK=.8+.1*((e.tier or 3)-3)
            s.rumbleAt=s.rumbleT;s.thump=1
        else s.trauma=math.max(s.trauma,math.min(e.shake or 1,s.trauma+(e.kick or 0))) end
    elseif (e.type=='explode' or e.type=='blast') and e.pos then
        local d=math.sqrt((e.pos[1]-com[1])^2+(e.pos[2]-com[2])^2+(e.pos[3]-com[3])^2)
        s.trauma=math.min(1,s.trauma+math.max(0,e.type=='blast' and .3-d/250 or .9-d/30))
    end
end
function M:Apply(dt,node,vehicle,onFootfall)
    local s=self.host
    local function Local(x,y,back)
        node.position=node.position+node.rotation*Vector3(x,y,-back)
    end
    local function Pitch(radians) node.rotation=node.rotation*Quaternion(-radians*DEG,Vector3.RIGHT) end
    if s.drillImpact>.001 then
        Local(0,0,s.drillImpact^2*.48);Pitch(-s.drillImpact*.012)
        s.drillImpact=s.drillImpact*math.exp(-dt*17)
    end
    if s.trauma>.001 then
        local amp=s.trauma^2;s.shakeT=s.shakeT+dt;local t=s.shakeT*26
        Local(Wave(t,1)*.32*amp,Wave(t*1.13,4)*.32*.8*amp,0)
        node.rotation=node.rotation*Quaternion(Wave(t*.8,7)*.03*amp*DEG,Vector3.FORWARD)
        s.trauma=math.max(0,s.trauma-dt*1.3)
    end
    local mech=vehicle and vehicle.mechControl
    if mech then
        for _,f in ipairs(mech.footfalls) do
            local k=f.strength
            if f.kind=='launch' then s.stompV=s.stompV+4.2*.45*k
            else
                local land=f.kind=='land';s.stompV=s.stompV-4.2*k*(land and 1.6 or 1)
                s.nodV=s.nodV-.02*2*math.pi*3.2*k*(land and 1.8 or 1)
                s.trauma=math.min(1,math.max(s.trauma,(land and .85 or .3)*k))
            end
            if onFootfall then onFootfall(f,mech) end
        end
        mech.footfalls={}
    end
    s.mechSpeed=s.mechSpeed+((mech and math.abs(vehicle.speed) or 0)-s.mechSpeed)*(1-math.exp(-dt))
    if math.abs(s.stompY)>1e-4 or math.abs(s.stompV)>1e-3 or math.abs(s.nodY)>1e-5 or math.abs(s.nodV)>1e-4 then
        local w=2*math.pi*3.2;local h=math.min(dt,1/30)
        s.stompV=s.stompV+(-w*w*s.stompY-2*.42*w*s.stompV)*h;s.stompY=s.stompY+s.stompV*h
        s.nodV=s.nodV+(-w*w*s.nodY-2*.5*w*s.nodV)*h;s.nodY=s.nodY+s.nodV*h
        node.position=node.position+Vector3(0,s.stompY,0);Pitch(s.nodY)
    end
    s.rumbleT=s.rumbleT+dt
    if s.rumbleT-s.rumbleAt>.12 then s.rumbleTo=0 end
    s.rumble=s.rumble+(s.rumbleTo-s.rumble)*math.min(1,dt*(s.rumbleTo>s.rumble and 5 or 12))
    s.thump=math.max(0,s.thump-dt*12)
    if s.rumble>.002 or s.thump>0 then
        local r=s.rumble*s.rumbleK;local t=s.rumbleT*95
        local buzz=.6*math.sin(t)+.4*math.sin(t*1.73+1.3)
        local side=.6*math.sin(t*.83+2.1)+.4*math.sin(t*1.41+.4)
        local dip=-.018*s.thump^2*(1-s.rumble)*s.rumbleK
        Local(side*.022*.4*r,buzz*.022*r+dip,.14*r)
    end
end
return M

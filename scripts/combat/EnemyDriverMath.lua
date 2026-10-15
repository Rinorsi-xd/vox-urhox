-- Frozen shared/ai/driver.js response curves and deterministic RNG.
local M={}
M.T={thinkInterval=.2,stuckWindow=3,stuckDistance=1,reverseTime=1.5,resetAfter=3,reactionMin=.25,reactionMax=.65,aimErrorDegrees=3,trackLag=.5,aimMotionK=.3,engagedHold=2.5,flipUp=.35,flipAfter=1.5}
M.C={retreatBelow=.35,recoverAbove=.7,retreatTimeout=14,retreatCooldown=18,cornered=14,coverRange=90,coverEvery=1,commit=1.2,inertia=.1,flipMin=3,flipMax=5,missileReload=8,
roles={assault={near=25,far=45,speed=8},heavy={near=20,far=35,speed=7,reverse=.2},boss={near=24,far=36,speed=6,reverse=.2},hover={near=12,far=32,speed=12},sniper={near=120,far=200,speed=12,plantMin=3,plantMax=5}}}
function M.Clamp(x,a,b) return math.max(a,math.min(b,x)) end
function M.Wrap(x) return math.atan(math.sin(x),math.cos(x)) end
function M.Sign(x) return x>0 and 1 or x<0 and -1 or 0 end
function M.Distance(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
function M.Spatial(a,b) return math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2) end
function M.Copy(p) return {p[1],p[2],p[3]} end
function M.Ramp(x,a,b) if a==b then return x>=b and 1 or 0 end;return M.Clamp((x-a)/(b-a),0,1) end
function M.Smooth(t) t=M.Clamp(t,0,1);return t*t*(3-2*t) end
function M.Sigmoid(t,k,mid) return 1/(1+math.exp(-k*(t-mid))) end
function M.Utility(fs) local p=1;for _,f in ipairs(fs) do p=p*M.Clamp(f,0,1) end;local n=#fs;return n<2 and p or p+(1-p)*(1-1/n)*p end
function M.Life(u)
    if not u then return 1 end
    local c=u.Core and u:Core() or u.core;local core=c and c.max>0 and c.hp/c.max or 1
    local ratio=u.Integrity and u:Integrity() or u.integrity
    local integrity=type(ratio)=='number' and (ratio-.15)/.85 or 1
    return M.Clamp(math.min(core,integrity),0,1)
end
function M.Extent(vehicle,axis)
    local b=vehicle and vehicle.spec and vehicle.spec.bounds;if not b then return 0 end
    local yaw=vehicle.Yaw and vehicle:Yaw() or vehicle.yaw or 0;local a=axis-yaw
    return math.abs(math.sin(a))*(b.max[1]-b.min[1])*.5+math.abs(math.cos(a))*(b.max[3]-b.min[3])*.5
end
function M.Seeded(seed)
    local s=seed or 1
    if type(s)~='number' then local h=2166136261;for i=1,#tostring(s) do h=((h~string.byte(tostring(s),i))*16777619)&0xffffffff end;s=h end
    s=math.floor(s)&0xffffffff
    return function()
        s=(s+0x6D2B79F5)&0xffffffff;local t=((s~(s>>15))*(s|1))&0xffffffff
        t=(t~((t+(((t~(t>>7))*(t|61))&0xffffffff))&0xffffffff))&0xffffffff
        return ((t~(t>>14))&0xffffffff)/4294967296
    end
end
function M.Strafing(mode) return mode=='strafe' or mode=='push' or mode=='backoff' or mode=='siege' end
return M

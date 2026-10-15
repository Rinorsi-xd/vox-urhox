-- Frozen salvageCine.js shots in source coordinates. The renderer mirrors X.
local M={}
local pi=math.pi
function M.Ease(t) t=math.max(0,math.min(1,t));return t*t*(3-2*t) end
function M.New() return {pos=Vector3.ZERO,tgt=Vector3.ZERO,ship=Vector3.ZERO,holder=Vector3.ZERO} end
function M.Drop(r,t,S,yaw,car)
    local e=M.Ease;local f,s=Vector3(math.sin(yaw),0,math.cos(yaw)),Vector3(math.cos(yaw),0,-math.sin(yaw))
    local ts=math.min(1,t/3);local air=S+Vector3(0,110,0);local from=S-s*420-f*180+Vector3(0,150,0)
    r.ship=from:Lerp(air,e(ts))
    if t>3.4 then r.ship=r.ship+s*((t-3.4)^2*6)+Vector3(0,(t-3.4)^2*5,0) end
    r.rx=0;r.ry=yaw;r.rz=t<3 and -.12*(1-ts) or .08
    local u=math.max(0,t-3.4)/3.2
    r.holder=t<3.4 and r.ship-Vector3(0,12,0) or Vector3(S.x,S.y+98*(1-e(u)),S.z)
    r.door=-e((t-6.9)/.6)*pi/2*.98;r.frameFire=u>.45 and u<1;r.landed=u>=1
    r.hold=t<7.3 and r.holder+Vector3(0,.5,0) or nil
    r.throttle=t<7.3 and 0 or t<=8.3 and .7 or nil
    local airborne=r.ship+s*36-f*14+Vector3(0,4,0)
    if t<3.4 then r.pos=airborne;r.tgt=r.ship-Vector3(0,7,0);r.fov=50;r.w=1
    else
        r.pos=airborne:Lerp(S+s*26+f*22+Vector3(0,2.4,0),e((t-3.4)/1.2))
        r.tgt=r.holder+Vector3(0,3,0)
        if t>7.3 then r.tgt=r.tgt:Lerp(car+Vector3(0,1.5,0),e((t-7.3)/.6)) end
        r.fov=t<5.6 and 32 or 48;r.w=1-e((t-8.1)/1.4)
    end
    return r
end
function M.Approach(r,t,E,wait)
    local k=M.Ease(t/math.max(3,math.min(6,wait)))
    r.ship=(E+Vector3(260,140,-120)):Lerp(E+Vector3(0,16,0),k)+Vector3(0,math.sin(t*2)*.4,0)
    r.rx=0;r.ry=.6;r.rz=.06*(1-k);r.dust=k>.95;return r
end
function M.Extract(r,t,E,car)
    local climb=math.max(0,t-1.2)
    r.ship=E+Vector3(climb^2*5,16+climb^2*7+math.sin(t*2)*.3,-climb^2*2)
    r.rx=climb*.04;r.ry=.6;r.rz=-climb*.03
    r.hold=car:Lerp(r.ship-Vector3(0,10,0),M.Ease(t/1.2))-Vector3(0,1,0)
    local a,rad=1.2+t*.32,34+t*18
    r.pos=E+Vector3(math.cos(a)*rad,6+t*9,math.sin(a)*rad);r.tgt=r.ship-Vector3(0,6,0);r.fov=50;r.w=M.Ease(t/.6)
    return r
end
function M.Death(r,t,P)
    local a,rad=.6+t*.35,14+t*2
    r.pos=P+Vector3(math.cos(a)*rad,8+t*9,math.sin(a)*rad);r.tgt=P;r.fov=50;r.w=M.Ease(t/.5);return r
end
function M.Elite(r,t,car,elite)
    local e=M.Ease;local delta=car-elite;local back=Vector3(delta.x,0,delta.z):Normalized()
    r.pos=car+back*12+Vector3(0,6,0);r.tgt=(car+Vector3(0,2,0)):Lerp(elite+Vector3(0,2,0),e(t/.6))
    r.fov=56-24*e((t-.3)/.6)*(1-e((t-2.4)/.6));r.w=e(t/.35)*(1-e((t-2.5)/.7));return r
end
return M

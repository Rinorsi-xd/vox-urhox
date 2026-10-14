-- Frozen H5 chassisStability.js; source-space metres and axial angular velocity.
--       COM o
--           | cgH + reach + 2 m support ray (ignores sensors/medium obstacles)
-- wheel ____v____ wheel     normal n controls pitch/roll; yaw remains free.
-- Near ground: hug uphill impulses and limit tipping. Inverted on ground stays
-- inverted; hover, legs and lift jets retain their own support controllers.
local Math=require 'core.Math3'
local C=Math.Clamp
local M={TUNING={coyote=.45,reach=1.4,hugK=9,hugMax=2.2,airG=.7,levelK=9,levelD=3.5,
    levelSettle=.3,tipStart=.45,tipK=14,maxW=3.2}}
local S=M.TUNING
local function Vec(a) return {x=a[1],y=a[2],z=a[3]} end
function M.Wants(v)
    if #v.wheels==0 or v.hoverMode or v.legMode then return false end
    for _,t in ipairs(v.spec.thrusters or {}) do if t.dir[2]>.7 then return false end end
    return true
end
function M.Step(v,dt,frame,contact)
    local body,up,q=v.body,frame.up,frame.q
    local nW=math.max(1,#v.wheels);local grip=contact/nW
    v.airT=contact>0 and 0 or (v.airT or 0)+dt
    local near=v.airT<S.coyote
    local t=body.translation();local p=Math.Add({t.x,t.y,t.z},Math.Rotate(q,v.com))
    local hit=v.space:Raycast(p,{0,-1,0},v.cgH+S.reach+2,body,nil,false,0x7fff)
    local n=hit and hit.normal or {0,1,0}
    local gap=hit and hit.dist-v.cgH or math.huge
    local hugging=near and gap<S.reach
    local force={0,0,0}
    if hugging then
        local vn=Math.Dot(frame.vel,n)
        if vn>0 then
            local a=math.min(vn*S.hugK,S.hugMax*9.81)*C(1-gap/S.reach,.3,1)
            force=Math.Scale(n,-v.mass*a)
        end
    end
    if contact==0 then force[2]=force[2]-v.mass*S.airG*9.81 end
    if Math.Length(force)>0 then body.addForce(Vec(force),true) end
    local w0=body.angvel();local w={w0.x,w0.y,w0.z}
    local wy=Math.Dot(w,up);local wp=Math.Sub(w,Math.Scale(up,wy))
    local target=(hugging or grip>0) and n or {0,1,0}
    local axis=Math.Cross(up,target);local s=Math.Length(axis)
    local angle=math.atan(s,Math.Dot(up,target))
    local function State() v.stability={gap=gap,hugging=hugging,tilt=angle,air=v.airT} end
    if angle>1.75 and gap<.6 then State();return end
    local kP,kD
    if grip<1 then
        local k=grip>0 and math.max(S.levelSettle,1-grip) or ((near or hit) and 1 or .6)
        kP=S.levelK*k;kD=S.levelD*k
    else kP=S.levelK*S.levelSettle*.3;kD=S.levelD*S.levelSettle end
    local tip=math.atan(v.halfTrack,v.cgH);local over=angle-tip*S.tipStart
    if over>0 and (grip>0 or hugging) then kP=kP+S.tipK*math.min(1,over/(tip*.4)) end
    if kP>0 or kD>0 then
        local e=s>1e-6 and angle/s or 0
        local dw=Math.Scale(Math.Sub(Math.Scale(axis,kP*e),Math.Scale(wp,kD)),dt)
        local nw=Math.Add(w,dw)
        if hugging or grip>0 then
            local ny=Math.Dot(nw,up);local np=Math.Sub(nw,Math.Scale(up,ny));local length=Math.Length(np)
            if length>S.maxW then nw=Math.Add(Math.Scale(up,ny),Math.Scale(np,S.maxW/length)) end
        end
        body.setAngvel(Vec(nw),true)
    end
    State()
end
return M

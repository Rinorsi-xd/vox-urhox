-- Blueprint -> weapon simulation contract, matching shared/drive/vehicleSpec.js.
local Assets=require "parts.PartAssets"
local Defs=require "parts.Defs"
local Rot=require "core.Rotations"
local Config=require "Config"
local Math=require "core.Math3"
local M={}
local function QuaternionFromMatrix(m)
    local trace=m[1]+m[5]+m[9]
    if trace>0 then
        local s=0.5/math.sqrt(trace+1)
        return {x=(m[8]-m[6])*s,y=(m[3]-m[7])*s,z=(m[4]-m[2])*s,w=0.25/s}
    elseif m[1]>m[5] and m[1]>m[9] then
        local s=2*math.sqrt(1+m[1]-m[5]-m[9])
        return {x=0.25*s,y=(m[2]+m[4])/s,z=(m[3]+m[7])/s,w=(m[8]-m[6])/s}
    elseif m[5]>m[9] then
        local s=2*math.sqrt(1+m[5]-m[1]-m[9])
        return {x=(m[2]+m[4])/s,y=0.25*s,z=(m[6]+m[8])/s,w=(m[3]-m[7])/s}
    else
        local s=2*math.sqrt(1+m[9]-m[1]-m[5])
        return {x=(m[3]+m[7])/s,y=(m[6]+m[8])/s,z=0.25*s,w=(m[4]-m[2])/s}
    end
end
function M.Part(p)
    if not Defs.PARTS[p.type].weapon then return nil end
    local t=Assets.Get(p.type,p.rot).weapon
    local origin={p.pos[1],p.pos[2]+0.5,p.pos[3]}
    local function ToBody(v) return Math.Scale(Math.Add(origin,Rot.ApplyRot(p.rot,v)),Config.CELL) end
    if not t then return {partId=p.id,type=p.type,muzzle=ToBody({0,2.5,0}),dir=Rot.ApplyRot(p.rot,{0,1,0})} end
    local off=Math.Scale(Math.Sub(t.muzzle,t.pivot),Config.CELL)
    local result={partId=p.id,type=p.type,pivot=ToBody(t.pivot),muzzle=ToBody(t.muzzle),off=off,
        quat=QuaternionFromMatrix(Rot.ROTATIONS[p.rot].m),elev=t.elev,
        dir=Rot.ApplyRot(p.rot,{0,math.sin(t.elev or 0),math.cos(t.elev or 0)})}
    if t.muzzles then
        result.offs={}
        for _,muzzle in ipairs(t.muzzles) do result.offs[#result.offs+1]=Math.Scale(Math.Sub(muzzle,t.pivot),Config.CELL) end
    end
    return result
end
function M.Build(blueprint)
    local conn=blueprint:Connectivity()
    if not conn.coreId then return {ok=false,reason="车上没有核心驾驶舱，无法试车",weapons={}} end
    local weapons={}
    for _,p in ipairs(blueprint:List()) do
        if conn.reached[p.id] then local w=M.Part(p);if w then weapons[#weapons+1]=w end end
    end
    return {ok=true,weapons=weapons}
end
return M

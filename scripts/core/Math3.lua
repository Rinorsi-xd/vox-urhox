-- Simulation ABI: source right-handed metres and {x,y,z,w} quaternions.
-- Mirror X only at the engine boundary (core.Coord); Lua vector arrays are 1-based.
local M={}
function M.Add(a,b) return {a[1]+b[1],a[2]+b[2],a[3]+b[3]} end
function M.Sub(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
function M.Scale(a,k) return {a[1]*k,a[2]*k,a[3]*k} end
function M.Dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
function M.Length(a) return math.sqrt(M.Dot(a,a)) end
function M.Normalize(a) local l=M.Length(a);return M.Scale(a,l>0 and 1/l or 1) end
function M.Cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
function M.Clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
function M.Approach(cur,target,step) return cur+M.Clamp(target-cur,-step,step) end
function M.Mix(a,b,t) return M.Add(a,M.Scale(M.Sub(b,a),t)) end
function M.Reject(a,n) return M.Sub(a,M.Scale(n,M.Dot(a,n))) end
function M.Array(v) return {v.x,v.y,v.z} end
function M.Vec(v) return {x=v[1],y=v[2],z=v[3]} end
function M.Inverse(q) return {x=-q.x,y=-q.y,z=-q.z,w=q.w} end
-- Source legMath uses the unit-quaternion cross-product form. Keep its rounding
-- separate from the older vehicle/weapon quaternion sandwich implementation.
function M.RotateUnit(q,v)
    local u={q.x,q.y,q.z};local uv=M.Cross(u,v)
    return M.Add(v,M.Add(M.Scale(uv,2*q.w),M.Scale(M.Cross(u,uv),2)))
end
function M.QMul(a,b)
    local v=M.Add(M.Add(M.Scale(M.Array(a),b.w),M.Scale(M.Array(b),a.w)),M.Cross(M.Array(a),M.Array(b)))
    return {x=v[1],y=v[2],z=v[3],w=a.w*b.w-M.Dot(M.Array(a),M.Array(b))}
end
function M.Rotate(q,v)
    local x,y,z,w=q.x,q.y,q.z,q.w
    local ix=w*v[1]+y*v[3]-z*v[2]
    local iy=w*v[2]+z*v[1]-x*v[3]
    local iz=w*v[3]+x*v[2]-y*v[1]
    local iw=-x*v[1]-y*v[2]-z*v[3]
    return {ix*w-iw*x-iy*z+iz*y,iy*w-iw*y-iz*x+ix*z,iz*w-iw*z-ix*y+iy*x}
end
function M.Unrotate(q,v) return M.Rotate({x=-q.x,y=-q.y,z=-q.z,w=q.w},v) end
function M.Turret(v,yaw,pitch)
    local cp,sp,cy,sy=math.cos(pitch),math.sin(pitch),math.cos(yaw),math.sin(yaw)
    local y,z=v[2]*cp+v[3]*sp,-v[2]*sp+v[3]*cp
    return {v[1]*cy+z*sy,y,-v[1]*sy+z*cy}
end
function M.Jitter(dir,spread,random)
    if not (spread>0) then return dir end
    local a=random()*math.pi*2
    local r=math.sqrt(random())*math.tan(spread)
    local up=math.abs(dir[2])<0.9 and {0,1,0} or {1,0,0}
    local u=M.Normalize(M.Cross(up,dir));local v=M.Cross(dir,u)
    return M.Normalize(M.Add(dir,M.Scale(M.Add(M.Scale(u,math.cos(a)),M.Scale(v,math.sin(a))),r)))
end
return M

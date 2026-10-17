-- Isolated candidate: arithmetic and hit ordering match VehicleRay.Cylinder.
local function Cylinder(origin,dir,axis,radius,halfWidth,maxDist)
    local o=origin[1]*axis[1]+origin[2]*axis[2]+origin[3]*axis[3]
    local d=dir[1]*axis[1]+dir[2]*axis[2]+dir[3]*axis[3]
    local rx,ry,rz=origin[1]-axis[1]*o,origin[2]-axis[2]*o,origin[3]-axis[3]*o
    local dx,dy,dz=dir[1]-axis[1]*d,dir[2]-axis[2]*d,dir[3]-axis[3]*d
    if math.abs(o)<=halfWidth and rx*rx+ry*ry+rz*rz<=radius*radius then
        return 0,{dir[1]*-1,dir[2]*-1,dir[3]*-1}
    end
    local best=maxDist+1;local nx,ny,nz=0,0,0
    local a=dx*dx+dy*dy+dz*dz
    local b=2*(rx*dx+ry*dy+rz*dz)
    local c=rx*rx+ry*ry+rz*rz-radius*radius
    local discriminant=b*b-4*a*c
    if a>1e-12 and discriminant>=0 then
        local root=math.sqrt(discriminant)
        local first,second=(-b-root)/(2*a),(-b+root)/(2*a)
        for index=1,2 do
            local t=index==1 and first or second
            if t>=0 and t<best and math.abs(o+d*t)<=halfWidth then
                best=t
                local x,y,z=rx+dx*t,ry+dy*t,rz+dz*t
                local length=math.sqrt(x*x+y*y+z*z)
                local scale=length>0 and 1/length or 1
                nx,ny,nz=x*scale,y*scale,z*scale
            end
        end
    end
    if math.abs(d)>1e-9 then for sign=-1,1,2 do
        local t=(sign*halfWidth-o)/d
        local x,y,z=rx+dx*t,ry+dy*t,rz+dz*t
        if t>=0 and t<best and x*x+y*y+z*z<=radius*radius then
            best=t;nx,ny,nz=axis[1]*sign,axis[2]*sign,axis[3]*sign
        end
    end end
    if best<=maxDist then return best,{nx,ny,nz} end
end
return Cylinder

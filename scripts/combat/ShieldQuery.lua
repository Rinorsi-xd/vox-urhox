local V=require 'core.Math3'
local M={}
function M.Contains(shield,p)
    local d=V.Sub(p,shield.pos)
    return d[2]>=0 and (d[1]/shield.rx)^2+(d[2]/shield.h)^2+(d[3]/shield.rz)^2<=1
end
function M.Ray(shield,from,dir,length)
    local radii={shield.rx,shield.h,shield.rz};local a,b,c=0,0,-1
    for i=1,3 do local o=(from[i]-shield.pos[i])/radii[i];local d=dir[i]/radii[i];a=a+d*d;b=b+2*d*o;c=c+o*o end
    local disc=b*b-4*a*c;if disc<0 or a==0 then return nil end
    for _,dist in ipairs({(-b-math.sqrt(disc))/(2*a),(-b+math.sqrt(disc))/(2*a)}) do
        if dist>=0 and dist<=length then
            local point=V.Add(from,V.Scale(dir,dist))
            if point[2]>=shield.pos[2] then
                local normal={};for i=1,3 do normal[i]=(point[i]-shield.pos[i])/radii[i]^2 end
                return {dist=dist,point=point,normal=V.Normalize(normal)}
            end
        end
    end
end
return M

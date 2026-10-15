-- Source RouteLine: build once, with local bounds for every segment and post.
local Coord=require 'core.Coord'
local M={}
function M.New(root,mode,material,color)
    local function Mesh(name,pos)
        local node=root:CreateChild(name);node.position=Coord.Vec(table.unpack(pos))
        local mesh=node:CreateComponent('CustomGeometry');mesh.castShadows=false;mesh.occluder=false;mesh.material=material
        mesh:BeginGeometry(0,TRIANGLE_LIST);return mesh
    end
    local function Vertex(mesh,x,y,z,alpha)
        mesh:DefineVertex(Coord.Vec(x,y,z));mesh:DefineNormal(Vector3.UP);mesh:DefineColor(Color(color[1],color[2],color[3],alpha))
    end
    local arc=0
    for i=2,#mode.path do
        local a,b=mode.path[i-1],mode.path[i]
        local length=math.sqrt((b[1]-a[1])^2+(b[2]-a[2])^2+(b[3]-a[3])^2)
        if length>.00001 then
            local mesh=Mesh('Route'..i,{a[1],a[2]+.4,a[3]})
            local dx,dy,dz=(b[1]-a[1])/length,(b[2]-a[2])/length,(b[3]-a[3])/length
            local flat=math.sqrt(dx*dx+dz*dz);local sx,sz=-dz/math.max(flat,.00001)*.06,dx/math.max(flat,.00001)*.06
            local d=0
            while d<length do
                local cycle=(arc+d)%5;local stop=math.min(length,d+(cycle<3 and 3-cycle or 5-cycle))
                if cycle<3 then
                    local function V(t,side) Vertex(mesh,dx*t+sx*side,dy*t,dz*t+sz*side,.85) end
                    V(d,1);V(d,-1);V(stop,-1);V(d,1);V(stop,-1);V(stop,1)
                end
                d=math.max(stop,d+.000001)
            end
            mesh:Commit()
        end
        arc=arc+length
    end
    for i,k in ipairs(mode.tuning.checkpoints) do
        local index=1;while index<#mode.cum and mode.cum[index]<k*mode.length do index=index+1 end
        local mesh=Mesh('Checkpoint'..i,mode.path[index])
        for j=0,9 do
            local a,b=j/10*math.pi*2,(j+1)/10*math.pi*2
            local function V(angle,y) Vertex(mesh,math.cos(angle)*.5,y,math.sin(angle)*.5,.5) end
            V(a,0);V(b,0);V(b,30);V(a,0);V(b,30);V(a,30)
            Vertex(mesh,0,0,0,.5);V(b,0);V(a,0);Vertex(mesh,0,30,0,.5);V(a,30);V(b,30)
        end
        mesh:Commit()
    end
    return true
end
return M

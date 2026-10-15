-- Frozen boundaryFx.js: one immutable wall mesh and optional ceiling mesh.
-- Source coordinates are mirrored only when emitting vertices and focus uniforms.
local Coord=require 'core.Coord'
local Visibility=require 'render.NodeVisibility'
local M={};M.__index=M
local function Vertex(mesh,p,u,v,base)
    mesh:DefineVertex(Coord.Vec(p[1],p[2],p[3]))
    mesh:DefineNormal(Vector3(0,base,0));mesh:DefineTexCoord(Vector2(u,v))
end
local function Mesh(root,name,ceiling)
    local node=root:CreateChild(name);local mesh=node:CreateComponent('CustomGeometry')
    mesh.castShadows=false;mesh.occluder=false;mesh:BeginGeometry(0,TRIANGLE_LIST)
    local material=Material:new();assert(material:SetSurfaceShader('Shaders/BLGL/Boundary.shader'))
    material:SetShaderParameter('ceiling',Variant(ceiling and 1 or 0));material.renderOrder=145
    mesh.material=material;return mesh,material
end
function M.Square(half,y0,y1)
    local p={{-half,-half},{half,-half},{half,half},{-half,half}};local walls={}
    for i,a in ipairs(p) do walls[i]={a=a,b=p[i%4+1],y0=y0,y1=y1} end
    return {walls=walls,ceiling={y=200,poly=p}}
end
function M.ForWorld(world,map)
    if map=='crater' then return M.Square(301.5,-20,200) end
    if map=='salvage' and world.layout.salvage and world.layout.salvage.gameplay then
        local walls,poly={},{}
        for _,s in ipairs(world.layout.salvage.gameplay.walls or {}) do
            -- Exported salvage plan already uses metres; planToGame mirrors X.
            local a,b={-s.a[1],s.a[2]},{-s.b[1],s.b[2]}
            walls[#walls+1]={a=a,b=b,y0=-20,y1=math.max(200,world:GroundAt((a[1]+b[1])/2,(a[2]+b[2])/2)+160)}
            poly[#poly+1]=a
        end
        return {walls=walls,ceiling={y=200,poly=poly}}
    end
    return nil
end
function M.New(scene,spec,ground)
    local self=setmetatable({},M);self.root=scene:CreateChild('MapBoundaryFx');self.materials={};self.spec=spec
    if #(spec.walls or {})>0 then
        local mesh,material=Mesh(self.root,'Walls',false);self.materials[#self.materials+1]=material
        local run=0
        for _,w in ipairs(spec.walls) do
            local ax,az,bx,bz=w.a[1],w.a[2],w.b[1],w.b[2]
            local length=math.sqrt((bx-ax)^2+(bz-az)^2)
            if length>=.1 then
                local n=math.max(1,math.ceil(length/8))
                for i=1,n do
                    local k0,k1=(i-1)/n,i/n
                    local x0,z0,x1,z1=ax+(bx-ax)*k0,az+(bz-az)*k0,ax+(bx-ax)*k1,az+(bz-az)*k1
                    local g0,g1=ground and ground(x0,z0) or w.y0,ground and ground(x1,z1) or w.y0
                    local p={{x0,math.min(w.y0,g0-4),z0},{x0,w.y1,z0},{x1,math.min(w.y0,g1-4),z1},{x1,w.y1,z1}}
                    local uv={{run+length*k0,p[1][2],g0},{run+length*k0,w.y1,g0},{run+length*k1,p[3][2],g1},{run+length*k1,w.y1,g1}}
                    for _,j in ipairs({1,4,3,1,2,4}) do Vertex(mesh,p[j],uv[j][1],uv[j][2],uv[j][3]) end
                end
            end
            run=run+length
        end
        mesh:Commit()
    end
    local c=spec.ceiling
    if c and #c.poly>=3 then
        local mesh,material=Mesh(self.root,'Ceiling',true);self.materials[#self.materials+1]=material
        local x,z=0,0;for _,p in ipairs(c.poly) do x=x+p[1]/#c.poly;z=z+p[2]/#c.poly end
        for i,a in ipairs(c.poly) do local b=c.poly[i%#c.poly+1]
            Vertex(mesh,{x,c.y,z},x,z,-10000);Vertex(mesh,{b[1],c.y,b[2]},b[1],b[2],-10000);Vertex(mesh,{a[1],c.y,a[2]},a[1],a[2],-10000)
        end
        mesh:Commit()
    end
    self:Update(0,{0,-100000,0});return self
end
function M:Update(time,focus)
    for _,material in ipairs(self.materials) do
        material:SetShaderParameter('clock',Variant(time))
        if focus then material:SetShaderParameter('focus',Variant(Coord.Vec(focus[1],focus[2],focus[3]))) end
    end
end
function M:SetVisible(on) Visibility.Set(self.root,on) end
function M:Dispose() self.root:Dispose();for _,m in ipairs(self.materials) do m:Dispose() end;self.materials={} end
return M

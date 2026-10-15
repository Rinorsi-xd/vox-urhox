-- Two bounded source bursts. Quads upload once; GPU handles drift/fade/size.
local M={};M.__index=M
local corners={{0,0},{1,0},{0,1},{0,1},{1,0},{1,1}}
function M.New(scene)
    local self=setmetatable({bursts={},uploads=0},M);self.root=scene:CreateChild('CineDust')
    for _,approach in ipairs({false,true}) do
        local count=approach and 12 or 18;local node=self.root:CreateChild(approach and 'HoverDust' or 'LandingDust')
        local b={node=node,age=100,life=approach and 2.2 or 2.6,materials={}};self.bursts[#self.bursts+1]=b
        local g=node:CreateComponent('CustomGeometry');g.dynamic=false;g:SetNumGeometries(2)
        for index=0,1 do
            local mat=Material:new();assert(mat:SetSurfaceShader('Shaders/BLGL/Salvage/CineDust.shader'));mat.renderOrder=129
            mat:SetSurfaceTexture('smoke_map',assert(cache:GetResource('Texture2D','SalvageCine/smoke-'..index..'.png')))
            mat:SetShaderParameter('approach',Variant(approach and 1.0 or 0.0));b.materials[#b.materials+1]=mat
            g:BeginGeometry(index,TRIANGLE_LIST)
            for i=index,count-1,2 do
                local angle=i/count*math.pi*2;local spin=(math.random()*2-1)*.4;local rot=math.random()*math.pi*2
                for _,uv in ipairs(corners) do
                    g:DefineVertex(Vector3.ZERO);g:DefineNormal(Vector3(angle,rot,spin));g:DefineTexCoord(Vector2(uv[1],uv[2]))
                end
            end
            for _,p in ipairs({Vector3(-30,0,-30),Vector3(30,20,30)}) do for _=1,3 do
                g:DefineVertex(p);g:DefineNormal(Vector3.ZERO);g:DefineTexCoord(Vector2.ZERO)
            end end
            g:SetMaterial(index,mat)
        end
        g:Commit();self.uploads=self.uploads+1;node.enabled=false
    end
    self.ring=self.root:CreateChild('LandingRing');self.ring.enabled=false
    local ring=self.ring:CreateComponent('CustomGeometry');ring:BeginGeometry(0,TRIANGLE_LIST)
    for i=0,47 do
        local a,b=i/48*math.pi*2,(i+1)/48*math.pi*2
        for _,v in ipairs({{a,.8},{a,1},{b,1},{a,.8},{b,1},{b,.8}}) do
            ring:DefineVertex(Vector3(math.cos(v[1])*v[2],0,math.sin(v[1])*v[2]));ring:DefineNormal(Vector3.UP);ring:DefineTexCoord(Vector2.ZERO)
        end
    end
    ring:Commit();self.ringMaterial=Material:new();assert(self.ringMaterial:SetSurfaceShader('Shaders/BLGL/Salvage/CineFlame.shader'));ring.material=self.ringMaterial
    return self
end
function M:Burst(at,approach)
    local b=self.bursts[approach and 2 or 1];b.age=0;b.node.position=Vector3(-at.x,at.y,at.z);b.node.enabled=true
    if not approach then self.ring.position=Vector3(-at.x,at.y+.4,at.z);self.ringAge=0;self.ring.enabled=true end
end
function M:Update(dt)
    if self.ring.enabled then
        self.ringAge=self.ringAge+dt;local u=math.min(1,self.ringAge/.6);local size=1+math.sqrt(u)*10
        self.ring.scale=Vector3(size,size,size);self.ring.enabled=u<1
        self.ringMaterial:SetShaderParameter('tint',Variant(Vector4(1,.6866853,.3515326,(1-u)*.45)))
    end
    for _,b in ipairs(self.bursts) do if b.node.enabled then
        b.age=b.age+dt;b.node.enabled=b.age<b.life
        if b.node.enabled then for _,m in ipairs(b.materials) do m:SetShaderParameter('age',Variant(b.age)) end end
    end end
end
function M:Snapshot() return {uploads=self.uploads,landingAge=self.bursts[1].age,hoverAge=self.bursts[2].age} end
function M:Dispose() self.root:Dispose();self.ringMaterial:Dispose();for _,b in ipairs(self.bursts) do for _,m in ipairs(b.materials) do m:Dispose() end end;self.bursts={} end
return M

local ResourceData=require("core.ResourceData")
local MvpBanner=require("render.MvpBanner")
local VehicleView=require("render.VehicleView")
local Config=require("Config")

local Data=require('core.ResourceData').Read('Mvp/Manifest.json')
local Motion=require 'combat.MvpMotion'
local Music=require 'audio.MvpMusic'
local M={};M.__index=M
function M.Dependencies()
    local paths={'Mvp/Manifest.json','Mvp/Beats.json','Mvp/VehicleShaders.json','Mvp/Cues.json','Mvp/title.png'}
    if Music.MUSIC_PATH then paths[#paths+1]=Music.MUSIC_PATH end
    for _,d in pairs(ResourceData.Read('Mvp/Cues.json')) do paths[#paths+1]=d.path end
    for _,d in ipairs(Data.models) do paths[#paths+1]=d.model end
    for _,d in ipairs(Data.materials) do for _,id in ipairs({d.map,d.emissiveMap}) do if type(id)=='number' then paths[#paths+1]='Mvp/texture-'..id..'.png' end end end
    return paths
end
function M.New(scene,bp,name)
    local self=setmetatable({},M);self:init(scene,bp,name);return self
end
function M:init(scene,bp,name)
    self.scene=scene;self.nodes={};self.materials={};self.carMaterials={};self.root=scene:CreateChild('MvpStage')
    for _,d in ipairs(Data.motion) do
        local node=(d.parent and self.nodes[d.parent] or self.root):CreateChild(d.id);self.nodes[d.id]=node
        node.position=Vector3(-d.position[1],d.position[2],d.position[3]);local q=d.quaternion;node.rotation=Quaternion(q[4],q[1],-q[2],-q[3])
    end
    for i,d in ipairs(Data.materials) do
        local m=Material:new();self.materials[i]=m
        local flag=d.name=='MvpBanner';local shader=flag and 'Banner' or d.additive and 'Glow' or (d.transparent or d.opacity<1) and 'Alpha' or d.unlit and 'Unlit' or 'Stage'
        assert(m:SetSurfaceShader('Shaders/BLGL/Mvp/'..shader..'.shader'))
        m:SetShaderParameter('tint',Variant(Vector4(d.color[1],d.color[2],d.color[3],d.opacity)))
        m:SetShaderParameter('emission_color',Variant(Vector3(table.unpack(d.emission))))
        m:SetShaderParameter('roughness_value',Variant(d.roughness));m:SetShaderParameter('metallic_value',Variant(d.metallic))
        local map=type(d.emissiveMap)=='number' and d.emissiveMap or d.map
        if type(map)=='number' then m:SetSurfaceTexture('albedo_map',assert(cache:GetResource('Texture2D','Mvp/texture-'..map..'.png')));m:SetShaderParameter('has_map',Variant(1.0)) end
        if type(d.emissiveMap)=='number' then m:SetShaderParameter('band',Variant(1.0)) end
        if d.name=='MvpSpiral' then self.spiral=m;m:SetShaderParameter('spiral',Variant(1.0)) end
        if flag then self.banner=m end
    end
    self.awardBanner=MvpBanner.New(name,self.banner)
    for _,d in ipairs(Data.models) do local model=self.nodes[d.motion]:CreateChild('Batch'):CreateComponent('StaticModel')
        model.model=assert(cache:GetResource('Model',d.model));model.material=self.materials[d.material+1];model.castShadows=false
    end
    self.pivot=self.nodes.pod:CreateChild('CarPivot');self.view=VehicleView.New(self.pivot,'MvpCar');self.view:Rebuild(bp)
    local box=self.view:GetWorldBounds();local size,center=box.size,box.center
    self.height=math.max(.6,size.y);self.S=math.min(5,math.max(1.8,math.max(size.x,size.z)*.5*1.15))
    self.view.root.position=Vector3(-center.x,-box.min.y,-center.z)
    self.root.scale=Vector3(self.S,self.S,self.S);self.pivot.scale=Vector3(1/self.S,1/self.S,1/self.S)
    local variants={};for _,name in ipairs(ResourceData.Read('Mvp/VehicleShaders.json')) do variants[name]=true end
    local clones={}
    for _,kind in ipairs({'StaticModel','CustomGeometry'}) do for _,mesh in ipairs(self.view.root:GetComponents(kind,true)) do
        for slot=0,mesh:GetNumGeometries()-1 do
            local original=mesh:GetMaterial(slot);local shader=original and original:GetSurfaceShader();local name=shader and shader.name:match('([^/]+)$')
            if name and variants[name] then
                local copy=clones[original]
                if not copy then copy=original:Clone();assert(copy:SetSurfaceShader('Shaders/BLGL/Mvp/Vehicle/'..name));clones[original]=copy;self.carMaterials[#self.carMaterials+1]=copy end
                mesh:SetMaterial(slot,copy)
            elseif name then mesh.enabled=false end
        end
    end end
    self:Floor();self:Confetti();self:Smoke()
    self.nodes.flag.enabled=false;self.nodes.column.enabled=false
end
function M:Smoke()
    local node=self.root:CreateChild('CannonSmoke');local g=node:CreateComponent('CustomGeometry');g.dynamic=false;g:BeginGeometry(0,TRIANGLE_LIST)
    for side=0,1 do
        local tilt=self.nodes['tilt'..side];local center=self.nodes['cannon'..side].position+tilt.position+tilt.rotation*Vector3(0,.9,0)
        local direction=tilt.rotation*Vector3.UP
        for _=1,6 do
            local speed=1.5+math.random()*2.5;local v=direction*speed+Vector3(math.random()*1.2-.6,math.random()*.6,math.random()*1.2-.6)
            for _,uv in ipairs({{0,0},{1,0},{0,1},{0,1},{1,0},{1,1}}) do g:DefineVertex(center);g:DefineNormal(v);g:DefineTexCoord(Vector2(uv[1],uv[2])) end
        end
    end
    for _,p in ipairs({Vector3(-10,0,-10),Vector3(10,10,10)}) do for _=1,3 do g:DefineVertex(p);g:DefineNormal(Vector3.ZERO);g:DefineTexCoord(Vector2.ZERO) end end
    g:Commit();local mat=Material:new();assert(mat:SetSurfaceShader('Shaders/BLGL/Mvp/Smoke.shader'));g.material=mat
    self.smoke=node;self.smokeMaterial=mat;self.smokeUploads=1;node.enabled=false
end
function M:Floor()
    local node=self.scene:CreateChild('MvpFloor');local g=node:CreateComponent('CustomGeometry');g:BeginGeometry(0,TRIANGLE_LIST)
    for _,p in ipairs({{-300,-300},{-300,300},{300,300},{-300,-300},{300,300},{300,-300}}) do g:DefineVertex(Vector3(p[1],-.02,p[2]));g:DefineNormal(Vector3.UP);g:DefineTexCoord(Vector2(p[1]/4,p[2]/4)) end
    g:Commit();local mat=Material:new();assert(mat:SetSurfaceShader('Shaders/BLGL/Mvp/Floor.shader'));g.material=mat;self.floorMaterial=mat
end
function M:Confetti()
    local node=self.root:CreateChild('Confetti');local g=node:CreateComponent('CustomGeometry');g.dynamic=false;g:BeginGeometry(0,TRIANGLE_LIST)
    local colors={0xff4d6d,0xffc93c,0x3ec7ff,0x7cf27c,0xff8a3d,0xc77dff,0xffffff,0xf2c14e}
    local seedValue=90862445
    local function R(a,b) seedValue=(seedValue*1664525+1013904223)&0xffffffff;return a+(b-a)*seedValue/4294967296 end
    for i=0,899 do
        local side=i<300 and -1 or 1;local v=i>=600 and Vector3(0,-R(.5,1.5),0) or Vector3(-side*.4+R(-.45,.45),.9+R(-.2,.3),-.18+R(-.45,.45)):Normalized()*R(5,15)
        local seed=R(0,6);local color=Config.HexLinear(colors[i%8+1])
        for _,q in ipairs({{0,0},{1,0},{0,1},{0,1},{1,0},{1,1}}) do
            g:DefineVertex(Vector3(-side,i,seed));g:DefineNormal(v);g:DefineColor(color);g:DefineTexCoord(Vector2(q[1],q[2]))
        end
    end
    -- Degenerate triangles bound all shader displacement without per-frame uploads.
    for _,p in ipairs({Vector3(-30,-2,-30),Vector3(30,45,30)}) do for _=1,3 do g:DefineVertex(p);g:DefineNormal(Vector3.ZERO);g:DefineColor(Color.BLACK);g:DefineTexCoord(Vector2.ZERO) end end
    g:Commit();local m=Material:new();assert(m:SetSurfaceShader('Shaders/BLGL/Mvp/Confetti.shader'));g.material=m
    self.confetti=node;self.confettiMaterial=m;self.confettiUploads=1
end
local function Set(m,key,v) m:SetShaderParameter(key,Variant(v)) end
function M:Update(t,deform,jumped)
    local S=self.S;local y,rot=Motion.PodY(t,S,self.height),Motion.PodRot(t)
    self.nodes.pod.position=Vector3(0,y/S,0);self.nodes.pod.rotation=Quaternion(-math.deg(rot),Vector3.UP)
    self.nodes.column.enabled=t>=2.55;self.nodes.column.position=Vector3(0,(y-S*.81)/2/S,0);self.nodes.column.scale=Vector3(1,math.max(.01,y-S*.81)/S,1);self.nodes.column.rotation=self.nodes.pod.rotation
    Set(self.spiral,'age',t);Set(self.banner,'age',t)
    self.awardBanner:Update()
    self.nodes.flag.enabled=t>=4.9
    if self.nodes.flag.enabled then
        local k=Motion.Back((t-4.9)/.55,1.2);local hang=S*3.1+self.height+S*4.2*.76
        self.nodes.flag.position=Vector3(0,(hang+(1-k)*S*6)/S,-2.4)
        Set(self.banner,'unroll',jumped and 1.0 or math.max(.001,math.min(1,Motion.Back((t-5.35)/1.55,.6))))
        for i=0,1 do self.nodes['tassel'..i].rotation=Quaternion(-math.deg(math.sin(t*1.6+i)*.12),Vector3.FORWARD) end
    end
    for i=0,1 do local kick=math.max(0,1-math.max(0,t-2.4)*3);self.nodes['tilt'..i].scale=Vector3(1,1-.25*math.sin(kick*math.pi),1) end
    local origin=self.pivot.worldPosition
    for _,m in ipairs(self.carMaterials) do
        Set(m,'mvp_origin',origin);Set(m,'mvp_yaw',rot);Set(m,'mvp_height',self.height);Set(m,'mvp_sy',deform.sy)
        Set(m,'mvp_twist',-deform.twist);Set(m,'mvp_lean',Vector2(-deform.lx,deform.lz));Set(m,'mvp_bulge',deform.bulge)
    end
    Set(self.confettiMaterial,'age',t);Set(self.confettiMaterial,'top',3.1+self.height/S)
    self.confetti.enabled=not jumped or t>=7.1
    self.smoke.enabled=not jumped and t>=2.4 and t<3.6
    if self.smoke.enabled then Set(self.smokeMaterial,'age',t-2.4) end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self.view:Dispose();self.root:Dispose()
    self.awardBanner:Dispose();self.smokeMaterial:Dispose()
    for _,m in ipairs(self.materials) do m:Dispose() end;for _,m in ipairs(self.carMaterials) do m:Dispose() end
    self.confettiMaterial:Dispose();self.floorMaterial:Dispose()
    for _,path in ipairs(M.Dependencies()) do if path:match('%.bin$') then cache:ReleaseResource('Model',path) elseif path:match('%.png$') then cache:ReleaseResource('Texture2D',path) end end
end
return M

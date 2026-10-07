-- Source dust.js: camera-centred 90x24x90 m particle volume and 26 wind strips.
local Coord=require 'core.Coord'
local M={};M.__index=M
local wx,wz=.9161573349,.400818834
local corners={{-1,-1,0,0},{1,-1,1,0},{-1,1,0,1},{-1,1,0,1},{1,-1,1,0},{1,1,1,1}}
local function Batch(root,name,shader)
    local n=root:CreateChild(name);local g=n:CreateComponent('CustomGeometry');g.dynamic=true
    local mat=Material:new();assert(mat:SetSurfaceShader('Shaders/BLGL/Crater/'..shader..'.shader'));g.material=mat;mat.renderOrder=141
    return g,mat
end
function M.New(root,owner)
    local self=setmetatable({owner=owner,streaks={}},M)
    self.g,self.material=Batch(root,'WindMotes','Mote');self.streak,self.streakMaterial=Batch(root,'GroundWind','Streak')
    self.streakMaterial:SetShaderParameter('uWind',Variant(Vector2(wx,wz)))
    self.streakMaterial:SetShaderParameter('uColor',Variant(Vector3(.4969,.3968,.2747)))
    -- CPU sampling needs decoded pixels. Keep this PNG payload outside the
    -- publisher's GPU texture cooker: ASTC KTX cannot be read by Image.
    self.ground=assert(cache:GetResource('Image','Crater/texture-0.bin'),'Missing CPU-readable crater ground mask')
    assert(not self.ground.compressed,'Crater ground mask must retain CPU-readable PNG pixels')
    -- Static seed positions and full-precision random value in NORMAL.x. All six
    -- vertices of a particle share the seed; the shader supplies its billboard.
    local g=self.g;g.dynamic=false;g:BeginGeometry(0,TRIANGLE_LIST)
    for i=1,1600 do
        local x,y,z,seed=math.random()*90,math.random()*24,math.random()*90,math.random()
        for _,q in ipairs(corners) do
            g:DefineVertex(Coord.Vec(x-45,y-6,z-45));g:DefineNormal(Vector3(seed,0,0));g:DefineTexCoord(Vector2(q[3],q[4]))
        end
    end
    -- Two degenerate triangles enclose every GPU-displaced billboard for CPU
    -- culling. The node follows the camera; seeds never need uploading again.
    for _,p in ipairs({Vector3(-46,-7,-46),Vector3(46,19,46)}) do for i=1,3 do
        g:DefineVertex(p);g:DefineNormal(Vector3.ZERO);g:DefineTexCoord(Vector2.ZERO)
    end end
    g:Commit()
    for i=1,26 do self.streaks[i]={placed=false,visible=false,x=0,y=0,z=0} end
    return self
end
function M:Blocked(x,z,r)
    local function AO(a,b)
        local u=math.floor((a+320)/640*self.ground.width);local v=math.floor((b+320)/640*self.ground.height)
        if u<0 or v<0 or u>=self.ground.width or v>=self.ground.height then return 1 end
        return self.ground:GetPixel(u,v).r
    end
    return AO(x,z)<.82 or AO(x+r,z)<.82 or AO(x-r,z)<.82 or AO(x,z+r)<.82 or AO(x,z-r)<.82
end
function M:Flat(x,z,threshold)
    local dx=(self.owner:Height(x+2,z)-self.owner:Height(x-2,z))/4
    local dz=(self.owner:Height(x,z+2)-self.owner:Height(x,z-2))/4
    return 1/math.sqrt(1+dx*dx+dz*dz)>threshold
end
function M:Place(s,cx,cz)
    -- Failed placement stays hidden until the camera leaves this region. Keeping
    -- the previous location would repeat all terrain/AO probes every frame.
    s.placed=true;s.visible=false;s.x=cx;s.z=cz
    for i=1,12 do
        local a=math.random()*math.pi*2;local r=8+math.random()*90;local x,z=cx+math.cos(a)*r,cz+math.sin(a)*r
        if self:Flat(x,z,.97) and not self:Blocked(x,z,8) and not self:Blocked(x,z,17) then
            s.x=x;s.y=self.owner:Height(x,z)+.35+math.random()*.5;s.z=z;s.visible=true;return
        end
    end
end
function M:Update(t,camera)
    local p=camera.position;local cx,cz=-p.x,p.z
    self.g.node.position=p;self.material:SetShaderParameter('uTime',Variant(t))
    local dirty=false
    for _,s in ipairs(self.streaks) do
        if not s.placed or (s.x-cx)^2+(s.z-cz)^2>110^2 then self:Place(s,cx,cz);dirty=true end
    end
    if dirty then
        local g=self.streak;g:BeginGeometry(0,TRIANGLE_LIST)
        for _,s in ipairs(self.streaks) do
            if s.visible then for _,q in ipairs(corners) do
                local x=s.x+wx*q[1]*17-wz*q[2]*4.5;local z=s.z+wz*q[1]*17+wx*q[2]*4.5
                g:DefineVertex(Coord.Vec(x,s.y,z));g:DefineNormal(Vector3.UP);g:DefineTexCoord(Vector2(q[3],q[4]))
            end end
        end
        g:Commit()
    end
    self.streakMaterial:SetShaderParameter('uTime',Variant(t))
end
function M:Dispose() self.ground=nil;self.owner=nil;self.streaks={} end
return M

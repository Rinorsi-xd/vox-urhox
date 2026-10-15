-- Frozen salvageFx.js marker and loot pools; no per-frame geometry rebuild.
local Coord=require 'core.Coord'
local Items=require('core.ResourceData').Read('UI/Outgame.json')
local M={};M.__index=M
local tier={0xc9c1b2,0x3ddc84,0x3ea8ff,0xc46bff}
local function Linear(c) c=c/255;return c<=.04045 and c/12.92 or ((c+.055)/1.055)^2.4 end
local function RGB(hex) return Vector3(Linear((hex>>16)&255),Linear((hex>>8)&255),Linear(hex&255)) end
local function NewMaterial(shader)
    local m=Material:new();assert(m:SetSurfaceShader('Shaders/BLGL/Salvage/'..shader..'.shader'));m.renderOrder=147;return m
end
local function Vertex(g,x,y,z,color,u)
    g:DefineVertex(Coord.Vec(x,y,z));g:DefineColor(color);g:DefineTexCoord(Vector2(u or 0,0))
end
local function Ring(g,inner,outer,arc)
    local color=arc and Color(0,0,1) or Color(0,1,0)
    for i=0,47 do
        local ua,ub=i/48,(i+1)/48
        local a,b=arc and math.pi/2-ua*math.pi*2 or ua*math.pi*2,arc and math.pi/2-ub*math.pi*2 or ub*math.pi*2
        local ax,az,bx,bz=math.cos(a),-math.sin(a),math.cos(b),-math.sin(b)
        Vertex(g,ax*inner,0,az*inner,color,ua);Vertex(g,ax*outer,0,az*outer,color,ua);Vertex(g,bx*outer,0,bz*outer,color,ub)
        Vertex(g,ax*inner,0,az*inner,color,ua);Vertex(g,bx*outer,0,bz*outer,color,ub);Vertex(g,bx*inner,0,bz*inner,color,ub)
    end
end
function M.Dependencies() return {'Shaders/BLGL/Salvage/Marker.shader','Shaders/BLGL/Salvage/LootBeam.shader','Shaders/BLGL/Salvage/LootCube.shader'} end
function M.New(scene,rand)
    local self=setmetatable({root=scene:CreateChild('SalvageFx'),beams={},cubes={},bi=1,ci=1,rand=rand or math.random},M)
    self.mark=self.root:CreateChild('InteractionMarker');self.mark.enabled=false
    self.markMaterial=NewMaterial('Marker');local g=self.mark:CreateComponent('CustomGeometry');g:BeginGeometry(0,TRIANGLE_LIST)
    Ring(g,2.6,3,false);Ring(g,3.2,3.8,true)
    local color=Color(1,0,0)
    for i=0,3 do
        local a,b=i*math.pi/2,(i+1)*math.pi/2
        Vertex(g,0,-.7,0,color);Vertex(g,math.cos(a)*.6,.7,-math.sin(a)*.6,color);Vertex(g,math.cos(b)*.6,.7,-math.sin(b)*.6,color)
        Vertex(g,0,.7,0,color);Vertex(g,math.cos(b)*.6,.7,-math.sin(b)*.6,color);Vertex(g,math.cos(a)*.6,.7,-math.sin(a)*.6,color)
    end
    g:Commit();g.material=self.markMaterial;g.drawDistance=500
    for i=1,4 do
        local n=self.root:CreateChild('LootBeam'..i);n.enabled=false;local geom=n:CreateComponent('CustomGeometry');geom:BeginGeometry(0,TRIANGLE_LIST)
        for j=0,17 do
            local a,b=j*math.pi/9,(j+1)*math.pi/9;local ax,az,bx,bz=math.cos(a),math.sin(a),math.cos(b),math.sin(b)
            Vertex(geom,ax*1.4,0,az*1.4,Color.WHITE);Vertex(geom,ax*.7,70,az*.7,Color.WHITE);Vertex(geom,bx*.7,70,bz*.7,Color.WHITE)
            Vertex(geom,ax*1.4,0,az*1.4,Color.WHITE);Vertex(geom,bx*.7,70,bz*.7,Color.WHITE);Vertex(geom,bx*1.4,0,bz*1.4,Color.WHITE)
        end
        geom:Commit();local material=NewMaterial('LootBeam');geom.material=material;geom.drawDistance=700
        self.beams[i]={node=n,material=material,t=9}
    end
    self.cubeMaterial=NewMaterial('LootCube');local model=assert(cache:GetResource('Model','Models/Box.mdl'))
    for i=1,16 do local n=self.root:CreateChild('LootCube'..i);n.enabled=false
        local sm=n:CreateComponent('StaticModel');sm.model=model;sm.material=self.cubeMaterial;sm.useInstanceColor=true;sm.castShadows=false;sm.drawDistance=500
        self.cubes[i]={node=n,model=sm,t=9}
    end
    return self
end
function M.Color(o)
    if o.kind=='kill' then return 0xff8a6a end
    if o.kind=='crate' or o.kind=='cache' then return tier[(o.tier or 0)+1] or tier[1] end
    return o.model=='core' and 0xffb21e or 0xc9c1b2
end
function M:Target(o,progress,cracking)
    self.mark.enabled=o~=nil;if not o then return end
    self.mark.position=Coord.Vec(o.g[1],o.g[2]+.3,o.g[3]);local radius=o.model=='core' and 6 or o.kind=='crate' and 2.4 or 4
    self.mark.scale=Vector3.ONE*(radius/3)
    local color=cracking and 0xffb21e or M.Color(o)
    self.markMaterial:SetShaderParameter('uColor',Variant(RGB(color)))
    self.markMaterial:SetShaderParameter('uProgress',Variant(math.floor(math.max(0,math.min(1,progress or 0))*60+.5)/60))
end
function M:Loot(pos,color,n)
    local b=self.beams[self.bi];self.bi=self.bi%4+1;b.t=0;b.node.position=Coord.Vec(table.unpack(pos));b.node.enabled=true
    b.material:SetShaderParameter('uColor',Variant(RGB(color)))
    for i=1,math.min(6,n or 0) do
        local c=self.cubes[self.ci];self.ci=self.ci%16+1;c.t=-(i-1)*.08;c.from={pos[1],pos[2]+1.5,pos[3]};c.seed=self.rand()*6
        local rgb=RGB(i==1 and color or 0xffffff);c.model.instanceColor=Color(rgb.x,rgb.y,rgb.z,1);c.node.enabled=false
    end
end
function M:Reveal(e)
    local it=Items.items[e.item.id];local hex=tonumber(Items.rarity[(it.rarity or 0)+1].color:sub(2),16)
    self:Loot(e.at,hex,1)
end
function M:Update(dt,clock,pos)
    self.markMaterial:SetShaderParameter('uClock',Variant(clock))
    for _,b in ipairs(self.beams) do b.t=b.t+dt;b.node.enabled=b.t<=1.6
        if b.node.enabled then local u=b.t/1.6;b.node.scale=Vector3(1+u,1,1+u);b.material:SetShaderParameter('uOpacity',Variant(math.min(1,u*6)*(1-u)*.55)) end
    end
    for _,c in ipairs(self.cubes) do c.t=c.t+dt;c.node.enabled=c.from~=nil and c.t>=0 and c.t<=.75
        if c.node.enabled then local u=c.t/.75;local k=u*u;local a=c.from
            c.node.position=Coord.Vec(a[1]+(pos[1]-a[1])*k,a[2]+(pos[2]+1.5-a[2])*k+math.sin(u*math.pi)*4,a[3]+(pos[3]-a[3])*k)
            c.node.rotation=Quaternion((clock*5+c.seed)*180/math.pi,-clock*3*180/math.pi,0);c.node.scale=Vector3.ONE*(.5*(1-u*.6))
        end
    end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.root:Dispose();self.markMaterial:Dispose();self.cubeMaterial:Dispose();for _,b in ipairs(self.beams) do b.material:Dispose() end
    self.root=nil;self.markMaterial=nil;self.cubeMaterial=nil;self.beams={};self.cubes={}
end
return M

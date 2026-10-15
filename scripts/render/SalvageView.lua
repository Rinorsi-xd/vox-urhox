local Coord=require 'core.Coord'
local M={};M.__index=M
local function Linear(c) return c<=.04045 and c/12.92 or ((c+.055)/1.055)^2.4 end
local function RGB(r,g,b) return Vector3(Linear(r/255),Linear(g/255),Linear(b/255)) end
function M.New(run)
    local self=setmetatable({run=run,root=run.session.scene:CreateChild('SalvageObjects'),crates={},exits={}},M)
    self.data=run.world.physicsData
    for _,o in ipairs(run.rules.objects) do if o.kind=='crate' then self:Crate(o) end end
    for _,e in ipairs(run.rules.extracts) do
        local n=self.root:CreateChild(e.id);n.position=Coord.Vec(e.g[1],e.g[2]+.4,e.g[3])
        local g=n:CreateComponent('CustomGeometry');g:BeginGeometry(0,TRIANGLE_LIST)
        local color=Color(62/255,230/255,1,.16)
        local function Vertex(x,y,z,c) g:DefineVertex(Vector3(x,y,z));g:DefineColor(c) end
        local r=e.radius
        for i=0,23 do
            local a,b=i*math.pi/12,(i+1)*math.pi/12;local ax,az=math.sin(a),math.cos(a);local bx,bz=math.sin(b),math.cos(b)
            Vertex(ax*r,-2.4,az*r,color);Vertex(bx*r,257.6,bz*r,color);Vertex(bx*r,-2.4,bz*r,color)
            Vertex(ax*r,-2.4,az*r,color);Vertex(ax*r,257.6,az*r,color);Vertex(bx*r,257.6,bz*r,color)
        end
        for i=0,63 do
            local a,b=i*math.pi/32,(i+1)*math.pi/32;local ax,az=math.sin(a),math.cos(a);local bx,bz=math.sin(b),math.cos(b)
            local ring=Color(62/255,230/255,1,.7)
            Vertex(ax*r,0,az*r,ring);Vertex(bx*r,0,bz*r,ring);Vertex(ax*(r-.6),0,az*(r-.6),ring)
            Vertex(bx*r,0,bz*r,ring);Vertex(bx*(r-.6),0,bz*(r-.6),ring);Vertex(ax*(r-.6),0,az*(r-.6),ring)
        end
        local material=Material:new();assert(material:SetSurfaceShader('Shaders/BLGL/Salvage/Signal.shader'));material.renderOrder=145
        material:SetShaderParameter('uPhase',Variant(e.x or -e.g[1]))
        g:Commit();g.material=material;self.exits[#self.exits+1]={node=n,exit=e,material=material}
    end
    self:Update()
    return self
end
function M:Crate(o)
    local n=self.root:CreateChild(o.id);n.position=Coord.Vec(table.unpack(o.g));n.rotation=Quaternion(-(o.yaw or 0)*180/math.pi,Vector3.UP)
    for _,d in ipairs(self.data.lootModels[math.max(1,math.min(4,(o.tier or 0)+1))]) do
        local sm=n:CreateChild('Part'):CreateComponent('StaticModel');sm.model=assert(cache:GetResource('Model',d.model))
        sm.material=assert(cache:GetResource('Material','Salvage/material-'..d.material..'.xml'));sm.castShadows=true;sm.shadowDistance=100;sm.drawDistance=450
    end
    self.crates[o.id]=n
end
function M:Hide(id) local node=self.crates[id];if node then node.enabled=false end end
function M:Update()
    local rules=self.run.rules
    for _,e in ipairs(self.exits) do
        local closed=e.exit.openAt and rules.time<e.exit.openAt
        local state=closed and 'closed' or rules.ex and rules.ex.e==e.exit and 'extracting' or 'open'
        if state~=e.state then
            local color=state=='closed' and RGB(255,90,60) or state=='extracting' and RGB(61,220,132) or RGB(62,230,255)
            e.material:SetShaderParameter('uColor',Variant(color));e.material:SetShaderParameter('uBeamOpacity',Variant(closed and .07 or .16));e.state=state
        end
    end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.root:Dispose();for _,e in ipairs(self.exits) do e.material:Dispose() end
    self.crates={};self.exits={};self.root=nil;self.run=nil;self.data=nil
end
return M

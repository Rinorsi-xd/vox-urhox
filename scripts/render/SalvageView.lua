local Coord=require 'core.Coord'
local M={};M.__index=M
function M.New(run)
    local self=setmetatable({run=run,root=run.session.scene:CreateChild('SalvageObjects'),crates={},exits={}},M)
    self.data=run.world.physicsData
    for _,o in ipairs(run.rules.objects) do if o.kind=='crate' then self:Crate(o) end end
    self.beamMaterial=Material:new();assert(self.beamMaterial:SetSurfaceShader('Shaders/BLGL/Combat/Objective.shader'));self.beamMaterial.renderOrder=145
    for _,e in ipairs(run.rules.extracts) do
        local n=self.root:CreateChild(e.id);n.position=Coord.Vec(e.g[1],e.g[2]+.4,e.g[3])
        local g=n:CreateComponent('CustomGeometry');g:BeginGeometry(0,TRIANGLE_LIST)
        local color=Color(62/255,230/255,1,.16)
        local function Vertex(x,y,z,c) g:DefineVertex(Vector3(x,y,z));g:DefineColor(c) end
        for i=0,31 do
            local a,b=i*math.pi/16,(i+1)*math.pi/16;local ax,az=math.sin(a),math.cos(a);local bx,bz=math.sin(b),math.cos(b)
            local r=e.radius
            Vertex(ax*r,0,az*r,color);Vertex(bx*r,260,bz*r,color);Vertex(bx*r,0,bz*r,color)
            Vertex(ax*r,0,az*r,color);Vertex(ax*r,260,az*r,color);Vertex(bx*r,260,bz*r,color)
            local ring=Color(62/255,230/255,1,.7)
            Vertex(ax*r,0,az*r,ring);Vertex(bx*r,0,bz*r,ring);Vertex(ax*(r-.6),0,az*(r-.6),ring)
            Vertex(bx*r,0,bz*r,ring);Vertex(bx*(r-.6),0,bz*(r-.6),ring);Vertex(ax*(r-.6),0,az*(r-.6),ring)
        end
        g:Commit();g.material=self.beamMaterial;self.exits[#self.exits+1]={node=n,exit=e}
    end
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
    for _,e in ipairs(self.exits) do e.node.enabled=not e.exit.openAt or self.run.rules.time>=e.exit.openAt end
end
function M:Dispose() self.root:Dispose();if self.beamMaterial then self.beamMaterial:Dispose() end;self.crates={};self.exits={} end
return M

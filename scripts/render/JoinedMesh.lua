-- One exact exterior surface per material, rebuilt only after an edit. Empty
-- per-part nodes remain the common attachment/persistence boundary.
local Surface=require 'render.JoinedSurface'
local Materials=require 'parts.Materials'
local Coord=require 'core.Coord'
local Config=require 'Config'
local M={};M.__index=M
local winding={0,6,3}
function M.New(root)
    local self=setmetatable({},M);self:init(root);return self
end
function M:init(root)
    self.root=root:CreateChild('JoinedBlocks');self.parts={};self.meshes={};self.outlines={};self.groups={};self.outlinesDirty=false;self.dirty=false;self.rebuilds=0
end
function M:Add(p) self.parts[p.id]=p;self.dirty=true end
function M:Remove(id) if self.parts[id] then self.parts[id]=nil;self.dirty=true end end
function M:Repaint(p) if self.parts[p.id] then self.parts[p.id]=p;self.dirty=true end end
function M:SetXray(on)
    self.xray=on
    for slot,mesh in pairs(self.meshes) do mesh.geometry:SetMaterial(Materials.Joined(slot,on));mesh.geometry.castShadows=not on end
    if on then self:UpdateOutlines() end
    for _,line in pairs(self.outlines) do line.node.enabled=on==true end
end
function M:Update()
    if not self.dirty then return end;self.dirty=false;self.rebuilds=self.rebuilds+1
    local parts={};for _,p in pairs(self.parts) do parts[#parts+1]=p end;table.sort(parts,function(a,b) return a.id<b.id end)
    local surfaces,groups=Surface.Build(parts)
    for slot,mesh in pairs(self.meshes) do if not surfaces[slot] then mesh.node:Dispose();self.meshes[slot]=nil end end
    self.vertices=0;local colors={}
    for slot,surface in pairs(surfaces) do
        local mesh=self.meshes[slot]
        if not mesh then local node=self.root:CreateChild(slot);mesh={node=node,geometry=node:CreateComponent('CustomGeometry')};self.meshes[slot]=mesh end
        local geometry=mesh.geometry;geometry:BeginGeometry(0,TRIANGLE_LIST)
        for i=1,#surface.position,9 do for _,offset in ipairs(winding) do local j=i+offset
            geometry:DefineVertex(Coord.Vec(surface.position[j],surface.position[j+1],surface.position[j+2]))
            geometry:DefineNormal(Coord.Vec(surface.normal[j],surface.normal[j+1],surface.normal[j+2]))
            local hex=surface.colors[(j+2)//3];local color=colors[hex]
            if not color then color=Config.HexLinear(hex,.5);colors[hex]=color end
            geometry:DefineColor(color)
        end end
        geometry:Commit();geometry:SetMaterial(Materials.Joined(slot,self.xray));geometry.castShadows=not self.xray
        mesh.vertices=#surface.position/3;self.vertices=self.vertices+mesh.vertices
    end
    self.groups=groups;self.outlinesDirty=true
    -- Group edges are visible only in the builder's x-ray view.
    if self.xray then self:UpdateOutlines() end
end
function M:UpdateOutlines()
    if not self.outlinesDirty then return end
    self.outlinesDirty=false
    for g,line in pairs(self.outlines) do if not self.groups[g] then line.node:Dispose();self.outlines[g]=nil end end
    for g,pos in pairs(self.groups) do
        local line=self.outlines[g]
        if not line then local node=self.root:CreateChild('Group'..g);line={node=node,geometry=node:CreateComponent('CustomGeometry')};self.outlines[g]=line end
        local vertices=Surface.Edges(pos);line.vertices=vertices
        line.geometry:BeginGeometry(0,LINE_LIST)
        for _,v in ipairs(vertices) do line.geometry:DefineVertex(Coord.Vec(table.unpack(v)));line.geometry:DefineColor(Config.HexLinear(0x334b60,.8)) end
        line.geometry:Commit();line.geometry:SetMaterial(Materials.JoinedOutline());line.geometry.castShadows=false;line.node.enabled=self.xray==true
    end
end
function M:Clear()
    for _,mesh in pairs(self.meshes) do mesh.node:Dispose() end
    for _,line in pairs(self.outlines) do line.node:Dispose() end
    self.parts={};self.meshes={};self.outlines={};self.groups={};self.outlinesDirty=false;self.dirty=false;self.vertices=0
end
function M:Dispose() self:Clear();self.root:Dispose() end
return M

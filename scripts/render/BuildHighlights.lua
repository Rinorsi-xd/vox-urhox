-- Source diagnostic overlays: 1.04-cell translucent boxes, at most 1024 per
-- color. Two batches updated only when diagnostics/focus change; no per-cell nodes.
local Coord=require 'core.Coord'
local M={};M.__index=M
local faces={{1,3,4,2},{5,6,8,7},{1,5,7,3},{2,4,8,6},{1,2,6,5},{3,7,8,4}}
function M.New(parent)
    local self=setmetatable({limit=1024,counts={}},M)
    self.node=parent:CreateChild('BuildDiagnostics');self.node:SetScale(require('Config').CELL)
    self.material=Material:new();assert(self.material:SetSurfaceShader('Shaders/BLGL/BuildDiagnostic.shader'));self.material.renderOrder=141
    self.red=self.node:CreateChild('Disconnected'):CreateComponent('CustomGeometry');self.red.dynamic=true;self.red.material=self.material
    self.orange=self.node:CreateChild('Warning'):CreateComponent('CustomGeometry');self.orange.dynamic=true;self.orange.material=self.material
    return self
end
function M:Fill(mesh,bp,ids,color)
    mesh:BeginGeometry(0,TRIANGLE_LIST);local count=0;local order={};for id in pairs(ids) do order[#order+1]=id end;table.sort(order)
    for _,id in ipairs(order) do local p=bp.parts[id]
        if p then for _,c in ipairs(p._cells) do
            if count>=self.limit then break end;count=count+1
            local v={};for i=0,7 do v[i+1]=Coord.CellPos(c[1]+((i&1)~=0 and .52 or -.52),c[2]+.5+((i&2)~=0 and .52 or -.52),c[3]+((i&4)~=0 and .52 or -.52)) end
            for _,face in ipairs(faces) do for _,i in ipairs({1,3,2,1,4,3}) do mesh:DefineVertex(v[face[i]]);mesh:DefineColor(color) end end
        end end
    end
    mesh.enabled=count>0;if count>0 then mesh:Commit() end;return count
end
function M:Update(bp,diag,focus)
    local red=diag.conn.coreId and diag.conn.floating or {};local orange={}
    for id in pairs(diag.outside) do orange[id]=true end
    for _,id in ipairs(focus or {}) do if bp.parts[id] then orange[id]=true end end
    self.counts.red=self:Fill(self.red,bp,red,Color(.8,.06,.05,.35))
    self.counts.orange=self:Fill(self.orange,bp,orange,Color(.8,.35,.025,.3))
end
function M:Dispose() self.node:Dispose();self.material:Dispose() end
return M

-- Render real drawables in small batches while the loading page covers the scene.
-- Restore their exact masks before exposing the scene or cancelling a load.
---@class SceneWarmup
---@field items table[]
---@field all table[]
---@field next integer
---@field batches integer
---@field batchSize integer
---@field first integer|nil
---@field last integer|nil
---@field skipped integer
---@field disabled integer|nil
local M={};M.__index=M
local kinds={'StaticModel','StaticModelGroup','AnimatedModel','CustomGeometry','BillboardSet','Terrain','Skybox'}
function M.New(scene,batchSize,camera,accept)
    local self=setmetatable({items={},next=1,batches=0,batchSize=batchSize or 8,skipped=0,disabled=0},M)
    local seen={}
    local frustum=camera and camera.frustum
    for _,kind in ipairs(kinds) do
        for _,drawable in ipairs(scene:GetComponents(kind,true)) do
            if drawable.viewMask~=0 and not seen[drawable] then
                seen[drawable]=true
                -- Off-screen batches never submit geometry to the renderer.
                -- They only delay reveal; the full restored frame still warms shadows.
                if drawable.enabledEffective==false then
                    self.disabled=self.disabled+1
                elseif frustum and kind~='Skybox' and frustum:IsInsideFast(drawable.worldBoundingBox)==OUTSIDE then
                    self.skipped=self.skipped+1
                elseif not accept or accept(drawable,kind) then self.items[#self.items+1]={drawable=drawable,mask=drawable.viewMask} end
            end
        end
    end
    self.all={}
    for drawable in pairs(seen) do self.all[#self.all+1]={drawable=drawable,mask=drawable.viewMask} end
    for _,item in ipairs(self.all) do item.drawable.viewMask=0 end
    self:Batch()
    return self
end
function M:Batch()
    if self.first then
        for i=self.first,self.last do self.items[i].drawable.viewMask=0 end
    end
    self.first=self.next;self.last=math.min(#self.items,self.next+self.batchSize-1)
    for i=self.first,self.last do
        local item=self.items[i];item.drawable.viewMask=item.mask
    end
    self.next=self.last+1;self.batches=self.batches+1
end
function M:TotalBatches()
    return math.max(1,math.ceil(#self.items/self.batchSize))
end
function M:Rendered()
    if self.next>#self.items then self:Restore();return true end
    self:Batch();return false
end
function M:Restore()
    for _,item in ipairs(self.all) do item.drawable.viewMask=item.mask end
end
return M

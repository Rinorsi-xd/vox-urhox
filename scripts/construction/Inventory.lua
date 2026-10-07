-- Source inventory/hotbar rules, independent of widgets and GPU assets.
local Defs=require 'parts.Defs'
local M={};M.__index=M
M.materials=require('core.ResourceData').Read('Parts/BuildRules.json').blockMaterials
M.defaults={'cube','slope','corner','heavy','glass','drive3','steer3','mg3','laser3','light'}
function M.New(settings)
    local self=setmetatable({category='all',material='light',query='',active=1,hotbar={},revision=0},M)
    local saved=settings and settings.hotbar
    for i=1,10 do
        local value=saved and saved[i] or not saved and M.defaults[i]
        value=Defs.RETIRED_TYPES[value] or value
        self.hotbar[i]=Defs.PARTS[value] and value or false
    end
    if settings and type(settings.active)=='number' then self.active=math.max(1,math.min(10,math.floor(settings.active))) end
    return self
end
function M:Current() return self.hotbar[self.active] end
function M:Select(slot) self.active=math.max(1,math.min(10,slot));self.revision=self.revision+1 end
function M:Pick(type)
    if not Defs.PARTS[type] then return false end
    for i,t in ipairs(self.hotbar) do if t==type then self:Select(i);return true end end
    self.hotbar[self.active]=type;self.revision=self.revision+1;return true
end
function M:Assign(slot,type)
    if not Defs.PARTS[type] or slot<1 or slot>10 then return false end
    for i,t in ipairs(self.hotbar) do if t==type and i~=slot then self.hotbar[i]=self.hotbar[slot];break end end
    self.hotbar[slot]=type;self:Select(slot);return true
end
function M:Clear(slot) self.hotbar[slot]=false;self.revision=self.revision+1 end
function M:CycleMaterial()
    for i,m in ipairs(M.materials) do if m.id==self.material then self.material=M.materials[i%#M.materials+1].id;return end end
end
function M:CycleBlock()
    local def=Defs.PARTS[self:Current()];if not def or not def.shape then return false end
    self.material=def.mat;self:CycleMaterial()
    for _,d in ipairs(Defs.LIST) do if d.shape==def.shape and d.mat==self.material then return self:Pick(d.id) end end
end
function M:List()
    local out={};local q=self.query:match('^%s*(.-)%s*$'):lower()
    for _,p in ipairs(Defs.LIST) do
        local found=q~='' and ((p.name:lower():find(q,1,true)) or ((p.desc or ''):lower():find(q,1,true)) or p.id:lower():find(q,1,true))
        if q~='' and found or q=='' and not p.hidden and not p.panel and (self.category=='all' or p.cat==self.category) and (not p.shape or p.mat==self.material) then out[#out+1]=p end
    end
    return out
end
function M:Settings() return {v=1,hotbar={table.unpack(self.hotbar)},active=self.active} end
function M.ValidSettings(s)
    return type(s)=='table' and s.v==1 and type(s.hotbar)=='table' and #s.hotbar==10 and type(s.active)=='number' and s.active%1==0 and s.active>=1 and s.active<=10
end
return M

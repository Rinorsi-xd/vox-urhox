-- Diagnostic cache and camera focus are owned by the current build session.
local BuildHighlights=require("render.BuildHighlights")

local Config=require 'Config'
local M={};M.__index=M
function M.New(session)
    return setmetatable({session=session,revision=-1,tier=-1,focus={},computations=0,
        view=BuildHighlights.New(session.app.scene)},M)
end
function M:Get()
    local e=self.session.editor;local tier=self.session.app.tier
    if self.revision~=e.history.revision or self.tier~=tier then
        self.revision=e.history.revision;self.tier=tier;self.focus={}
        self.diag=e.bp:Diagnose(Config.TIERS[tier]);self.computations=self.computations+1
        self.view:Update(e.bp,self.diag,self.focus)
    end
    return self.diag
end
function M:Focus(warning,move)
    local diag=self:Get();self.focus=warning and warning.ids or {};local bp=self.session.editor.bp
    self.view:Update(bp,diag,self.focus)
    if not move or #self.focus==0 then return false end
    local min={math.huge,math.huge,math.huge};local max={-math.huge,-math.huge,-math.huge}
    for _,id in ipairs(self.focus) do local p=bp.parts[id]
        if p then for _,c in ipairs(p._cells) do for a=1,3 do local v=(c[a]+(a==2 and .5 or 0))*Config.CELL;min[a]=math.min(min[a],v);max[a]=math.max(max[a],v) end end end
    end
    if min[1]>max[1] then return false end
    local center=Vector3(-(min[1]+max[1])*.5,(min[2]+max[2])*.5,(min[3]+max[3])*.5)
    local size=Vector3(max[1]-min[1],max[2]-min[2],max[3]-min[3])
    self.session.buildCamera:FocusAt(center,math.max(4,size.length*1.6+3));return true
end
function M:Dispose() self.view:Dispose() end
return M

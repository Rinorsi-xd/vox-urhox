-- Frozen H5 touchControls.js: owned contacts, CSS-pixel gestures, no global keys.
local M={};M.__index=M
function M.New(adapter) local self=setmetatable({},M);self:Init(adapter);return self end
function M:Init(adapter) self.adapter=adapter;self.pointers={} end
function M:Down(action,id,x,y,rect)
    if self.pointers[id] then return false end
    for _,p in pairs(self.pointers) do if p.action==action and action~='look' then return false end end
    local held=action~='move' and action~='look' and self.adapter.Hold(action,true) or false
    self.pointers[id]={action=action,x=x,y=y,ox=x,oy=y,rect=rect,held=held}
    if action=='move' then self:Stick(x,y,rect) end
    return true
end
function M:Stick(x,y,r)
    local radius=r.w*.36;local dx,dy=(x-r.x-r.w/2)/radius,(y-r.y-r.h/2)/radius
    local length=math.sqrt(dx*dx+dy*dy);local power=math.min(1,math.max(0,(length-.12)/.88))
    if length>0 then dx,dy=dx/length*power,dy/length*power else dx,dy=0,0 end
    self.adapter.Move(dx,-dy)
end
function M:Move(id,x,y)
    local p=self.pointers[id];if not p then return end
    if p.action=='move' then self:Stick(x,y,p.rect) end
    if p.action=='look' or p.action=='primary' and self.adapter.mode=='drive' then
        local other=false
        if p.action=='look' then for otherId,q in pairs(self.pointers) do if otherId~=id and q.action=='look' then other=q;break end end end
        local dx,dy=x-p.x,y-p.y
        if other then
            local before=math.sqrt((p.x-other.x)^2+(p.y-other.y)^2);local after=math.sqrt((x-other.x)^2+(y-other.y)^2)
            if before>8 and after>8 then self.adapter.Zoom(math.log(before/after)/math.log(1.0012)) end
            if self.adapter.mode=='edit' then self.adapter.Pan(dx/2,dy/2) end
        else
            local gain=math.min(3,600/math.max(240,math.min(self.adapter.width,self.adapter.height)))
            self.adapter.Look(dx*gain,dy*gain)
        end
    end
    p.x=x;p.y=y
end
function M:Up(id,x,y,cancelled)
    local p=self.pointers[id];if not p then return end
    self.pointers[id]=nil
    if p.action=='move' then self.adapter.Move(0,0)
    elseif p.held then self.adapter.Hold(p.action,false,cancelled)
    elseif p.action~='look' and not cancelled then
        local r=p.rect
        if x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h and (x-p.ox)^2+(y-p.oy)^2<14^2 then self.adapter.Action(p.action) end
    end
end
function M:Reset()
    for id,p in pairs(self.pointers) do
        self.pointers[id]=nil
        if p.held then self.adapter.Hold(p.action,false,true) end
    end
    self.adapter.Move(0,0)
end
function M:Held(action) for _,p in pairs(self.pointers) do if p.action==action then return true end end;return false end
return M

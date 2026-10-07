-- Source effects.js Chips: short-lived colored cubes, not physical debris.
-- Nodes are allocated only as needed, reused within this scene, then disposed.
local Coord=require "core.Coord"
local Config=require "Config"
local V=require "core.Math3"
local M={};M.__index=M
function M.New(root,limit,groundAt)
    local self=setmetatable({root=root,slots={},limit=limit,sequence=0,groundAt=groundAt or function() return 0 end},M)
    self.material=Material:new();assert(self.material:SetSurfaceShader("Shaders/BLGL/Combat/Chip.shader"))
    self.model=assert(cache:GetResource("Model","Models/Box.mdl"));return self
end
function M:Emit(p,v,size,color,life)
    local slot=nil ---@type table|nil
    for _,s in ipairs(self.slots) do if not s.active then slot=s;break end end
    if not slot and #self.slots<self.limit then
        local node=self.root:CreateChild("Chip");local model=node:CreateComponent("StaticModel")
        model.model=self.model;model.material=self.material;model.castShadows=true
        slot={node=node,model=model};self.slots[#self.slots+1]=slot
    end
    if not slot then
        slot=self.slots[1];for _,s in ipairs(self.slots) do if s.sequence<slot.sequence then slot=s end end
    end
    local axis=V.Normalize({math.random()-.5,math.random()-.5,math.random()-.5})
    slot.axis=Vector3(axis[1],-axis[2],-axis[3])
    local u,a,b=math.random(),math.random()*math.pi*2,math.random()*math.pi*2
    slot.rotation=Quaternion(math.sqrt(u)*math.cos(b),math.sqrt(1-u)*math.sin(a),-math.sqrt(1-u)*math.cos(a),-math.sqrt(u)*math.sin(b))
    slot.pos=p;slot.vel=v;slot.spin=6+math.random()*14;slot.size=size;slot.life=life;slot.age=0;slot.active=true
    self.sequence=self.sequence+1;slot.sequence=self.sequence;slot.model.instanceColor=Config.HexLinear(color)
    slot.node.enabled=true
end
function M:Break(e)
    local d=e.dir or {0,0,0}
    for _=1,math.min(14,4+e.cells*2) do
        local p={};for i=1,3 do p[i]=e.pos[i]+(math.random()-.5)*.35 end
        self:Emit(p,{d[1]*3+(math.random()-.5)*5,2+math.random()*4,d[3]*3+(math.random()-.5)*5},
            .07+math.random()*.12,e.color,1.2+math.random()*.8)
    end
end
function M:Update(dt)
    for _,c in ipairs(self.slots) do if c.active then
        c.age=c.age+dt
        if c.age>=c.life then c.active=false;c.node.enabled=false
        else
            c.vel[2]=c.vel[2]-9.81*dt
            for i=1,3 do c.pos[i]=c.pos[i]+c.vel[i]*dt end
            -- Chip centre >= terrain(x,z) + half size; clamp first, then bounce.
            -- Negative pits, slopes and clamped map edges use the same surface.
            local floor=self.groundAt(c.pos[1],c.pos[3])+c.size*.5
            if c.pos[2]<floor then
                c.pos[2]=floor;c.vel[2]=c.vel[2]*-.3;c.vel[1]=c.vel[1]*.6;c.vel[3]=c.vel[3]*.6;c.spin=c.spin*.6
            end
            c.rotation=Quaternion(c.spin*dt*180/math.pi,c.axis)*c.rotation
            c.node.position=Coord.Vec(table.unpack(c.pos));c.node.rotation=c.rotation
            c.node:SetScale(c.size*math.min(1,(c.life-c.age)/.3))
        end
    end end
end
function M:Clear() for _,c in ipairs(self.slots) do c.active=false;c.node.enabled=false end end
function M:Dispose()
    for _,c in ipairs(self.slots) do c.node:Dispose() end
    self.slots={};self.material:Dispose();self.model=nil;self.groundAt=nil
end
return M

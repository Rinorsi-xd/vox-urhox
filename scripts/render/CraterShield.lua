-- Presentation contract from three/src/battle/shieldFx.js. This is not a
-- damage rule: the source supplies no shield HP pool, collision or team filter.
-- Hit positions use the same H5 world coordinates as combat events (metres).
local Coord=require 'core.Coord'
local M={};M.__index=M
local function Linear(v)
    v=v/255;return v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4
end
function M.New(parent,shield,team)
    local self=setmetatable({},M)
    self:init(parent,shield,team)
    return self
end
function M:init(parent,shield,team)
    self.node=parent:CreateChild(team=='own' and 'BaseShield1' or 'BaseShield2')
    self.node.position=Coord.Vec(table.unpack(shield.pos));self.node:SetScale(Vector3(shield.rx,shield.h,shield.rz))
    local geometry=self.node:CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
    local function Vertex(u,v)
        local a=u*math.pi*2;local p=v*math.pi*.5
        local vertex=Vector3(math.cos(a)*math.sin(p),math.cos(p),math.sin(a)*math.sin(p))
        geometry:DefineVertex(vertex);geometry:DefineNormal(vertex)
    end
    for a=0,127 do for b=0,39 do
        Vertex(a/128,b/40);Vertex((a+1)/128,b/40);Vertex(a/128,(b+1)/40)
        Vertex((a+1)/128,b/40);Vertex((a+1)/128,(b+1)/40);Vertex(a/128,(b+1)/40)
    end end
    geometry:Commit()
    self.material=Material:new()
    assert(self.material:SetSurfaceShader('Shaders/BLGL/Crater/Shield.shader'))
    local color=team=='own' and Vector3(Linear(76),Linear(184),1) or Vector3(1,Linear(64),Linear(80))
    self.material:SetShaderParameter('uColor',Variant(color*.9))
    self.material:SetShaderParameter('uHeight',Variant(shield.h))
    self.material.renderOrder=139;geometry.material=self.material
    self.hits={};self.hitBuffer=VectorBuffer();self.uploads=0
    for i=1,8 do self.hits[i]={0,0,0,-1} end
    self:Reset()
end
function M:UploadHits()
    self.hitBuffer:Clear()
    for _,h in ipairs(self.hits) do for i=1,4 do self.hitBuffer:WriteFloat(h[i]) end end
    self.material:SetShaderParameter('uHits',Variant(self.hitBuffer));self.uploads=self.uploads+1
end
function M:Reset()
    self.time=0;self.nextHit=1;self.hp=1;self.down=0;self.raise=1
    self.animation=nil ---@type table|nil
    for _,h in ipairs(self.hits) do h[1]=0;h[2]=0;h[3]=0;h[4]=-1 end
    self:UploadHits();self:Update(0)
end
function M:Hit(point)
    local h=self.hits[self.nextHit]
    h[1],h[2],h[3],h[4]=point[1],point[2],point[3],self.time
    self.nextHit=self.nextHit%8+1;self:UploadHits()
end
function M:SetHP(fraction)
    self.hp=fraction;self.material:SetShaderParameter('uHP',Variant(fraction))
end
function M:Down(duration)
    self.animation={field='down',from=self.down,to=1,start=self.time,duration=duration or 1.6}
end
function M:Raise(duration)
    self.down=0;self.raise=0
    self.material:SetShaderParameter('uDown',Variant(0.0));self.material:SetShaderParameter('uRaise',Variant(0.0))
    self.animation={field='raise',from=0,to=1,start=self.time,duration=duration or 2.2}
end
function M:Update(time)
    self.time=time
    local a=self.animation
    if a then
        local k=math.min(1,(time-a.start)/a.duration)
        self[a.field]=a.from+(a.to-a.from)*k
        if k>=1 then self.animation=nil end
    end
    self.material:SetShaderParameter('uTime',Variant(time))
    self.material:SetShaderParameter('uHP',Variant(self.hp))
    self.material:SetShaderParameter('uDown',Variant(self.down))
    self.material:SetShaderParameter('uRaise',Variant(self.raise))
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.node:Dispose();self.material:Dispose();self.hitBuffer=nil;self.animation=nil;self.hits={}
end
return M

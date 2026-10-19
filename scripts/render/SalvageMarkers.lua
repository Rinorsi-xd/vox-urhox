-- Persistent loot/scan signals. One mesh per live marker, reused until consumed.
local Coord=require 'core.Coord'
local Loot=require 'salvage.Loot'
local Items=require('core.ResourceData').Read('UI/Outgame.json')
local M={};M.__index=M
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
local function RGB(hex)
    local function Linear(c) c=c/255;return c<=.04045 and c/12.92 or ((c+.055)/1.055)^2.4 end
    return Vector3(Linear((hex>>16)&255),Linear((hex>>8)&255),Linear(hex&255))
end
function M.New(run)
    local self=setmetatable({},M);self:init(run);return self
end
function M:init(run)
    self.run=run;self.root=run.session.scene:CreateChild('SalvageMarkers');self.entries={};self.combatUntil=0;self.puffs={}
end
function M:Beam(key,o)
    local entry=self.entries[key];if entry then return entry end
    local node=self.root:CreateChild(key);node.position=Coord.Vec(o.g[1],o.g[2]+.12,o.g[3])
    local geo=node:CreateComponent('CustomGeometry');geo:BeginGeometry(0,TRIANGLE_LIST)
    local function Vertex(angle,r,y) geo:DefineVertex(Vector3(math.cos(angle)*r,y,math.sin(angle)*r));geo:DefineTexCoord(Vector2(0,y/40)) end
    for i=0,15 do
        local a,b=i*math.pi/8,(i+1)*math.pi/8
        Vertex(a,.85,0);Vertex(a,.25,40);Vertex(b,.25,40);Vertex(a,.85,0);Vertex(b,.25,40);Vertex(b,.85,0)
        Vertex(a,1.6,0);Vertex(b,2,0);Vertex(b,1.6,0);Vertex(a,1.6,0);Vertex(a,2,0);Vertex(b,2,0)
    end
    geo:Commit();geo.drawDistance=300
    local mat=Material:new();assert(mat:SetSurfaceShader('Shaders/BLGL/Salvage/PersistentMarker.shader'));mat.renderOrder=146;geo.material=mat
    entry={node=node,material=mat,opacity=0};self.entries[key]=entry;return entry
end
function M:Sphere(name,color,alpha)
    local node=self.root:CreateChild(name);local sm=node:CreateComponent('StaticModel')
    sm.model=assert(cache:GetResource('Model','Models/Sphere.mdl'));sm.castShadows=false
    local mat=Material:new();assert(mat:SetSurfaceShader('Shaders/BLGL/Outgame/Alpha.shader'))
    mat:SetShaderParameter('tint',Variant(Vector4(color[1],color[2],color[3],alpha)));sm.material=mat
    return {node=node,material=mat,diameter=sm.model.boundingBox.size.y}
end
function M:Update(dt)
    local run=self.run;local r=run.rules;local p=run.player:Position();local gear=run.gear;local active={}
    local threat=false
    for i=2,#run.entries do local e=run.entries[i]
        if e.unit.alive and e.engagingPlayer then threat=true;break end
    end
    if run.session.firing or run.player.weapons.sinceUse<.2 or run.world.time-run.player.hitAt<.2 or threat then self.combatUntil=r.time+5 end
    local hidden=r.time<self.combatUntil or not run.landed or not run.player.alive or r.ex or run.cine.playing
    for _,o in ipairs(r.objects) do
        local key=o.id;local isDrop=o.kind=='kill' or o.kind=='cache';local scan=gear.scans[key]~=nil
        local station=o.kind=='station';local opened=r.opened[key];local remaining
        if isDrop and r.sessions[key] then
            for _,it in ipairs(r.sessions[key].items) do if it.state=='full' and (it.left or 0)>0 then opened=false;break end end
        end
        if not opened and not o.robbed and (isDrop or scan or station) then
            local distance=Flat(o.g,p);local strength=distance>200 and 0 or 1-.7*(math.max(0,(distance-100)/100)^2)*(3-2*math.max(0,(distance-100)/100))
            local visible=station or scan or not hidden
            if strength>0 and visible or self.entries[key] then
                local rarity=math.min(3,o.tier or 0)
                if isDrop then
                    if not r.sessions[key] then
                        r.sessions[key]={o=o,title=r:Title(o),i=1,p=0,wait=0,value=0,done=false,items=Loot.FromTable(o.loot,r.rand)}
                    end
                    remaining=false;rarity=0
                    for _,it in ipairs(r.sessions[key].items) do
                        if it.state=='hidden' or it.state=='scan' or it.state=='full' and (it.left or 0)>0 then remaining=true;rarity=math.max(rarity,it.r) end
                    end
                end
                if remaining~=false then
                    local e=self:Beam(key,o);active[key]=true
                    local color=station and 0x3ddc84 or tonumber(Items.rarity[rarity+1].color:sub(2),16)
                    e.opacity=visible and e.opacity+((strength or 0)-e.opacity)*(1-math.exp(-10*dt)) or 0
                    e.node.enabled=e.opacity>.002;e.node.scale=Vector3(1,station and .7 or strength,1)
                    e.material:SetShaderParameter('uColor',Variant(RGB(color)));e.material:SetShaderParameter('uOpacity',Variant(e.opacity*.55))
                end
            end
        end
    end
    for key,e in pairs(self.entries) do if not active[key] then e.node:Dispose();e.material:Dispose();self.entries[key]=nil end end
    if gear.shield>0 and run.player.alive then
        self.shield=self.shield or self:Sphere('Shield',{.05,.35,1},.16)
        self.shield.node.enabled=true;self.shield.node.position=Coord.Vec(table.unpack(p));self.shield.node.scale=Vector3.ONE*((run.player.spec.bounds.radius+1.2)*2/self.shield.diameter)
    elseif self.shield then self.shield.node.enabled=false end
    if gear.smoke then
        local g=gear.smoke.g;local age=14-gear.smoke.t;local fade=math.min(1,age*2,gear.smoke.t/2)
        for i=1,9 do
            local puff=self.puffs[i] or self:Sphere('Smoke'..i,{.35,.36,.38},.25);self.puffs[i]=puff
            local angle=i*2.39996;local radius=i==1 and 0 or 7+3*math.sin(i)
            puff.node.enabled=true;puff.node.position=Coord.Vec(g[1]+math.cos(angle)*radius,g[2]+3+math.sin(i+age*.2)*1.5,g[3]+math.sin(angle)*radius)
            puff.node.scale=Vector3(23,13,23)*(math.min(1,age*.6+.2)/puff.diameter)
            puff.material:SetShaderParameter('tint',Variant(Vector4(.35,.36,.38,.28*fade)))
        end
    else for _,puff in ipairs(self.puffs) do puff.node.enabled=false end end
end
function M:Dispose()
    self.root:Dispose();for _,e in pairs(self.entries) do e.material:Dispose() end
    if self.shield then self.shield.material:Dispose() end;for _,puff in ipairs(self.puffs) do puff.material:Dispose() end
    self.entries={};self.run=nil
end
return M

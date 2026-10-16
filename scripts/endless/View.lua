local ObjectiveView=require("render.ObjectiveView")
local Blueprint=require("construction.Blueprint")
local VehicleView=require("render.VehicleView")
local Coin=require("endless.Coin")
local Defs=require("parts.Defs")

local Coord=require('core.Coord')
local D=require('endless.Data')
local M={};M.__index=M
local colors={weapon={1,.64,.27},movement={.30,.73,1},['function']={.38,.93,.69},credits={1,.76,.1}}
function M.New(scene,shield)
    local self=setmetatable({drops={},warnings={},time=0},M)
    self.root=scene:CreateChild('EndlessEffects');self.geometry=ObjectiveView.Geometry(scene)
    self.geometry:Begin('Endless',{0,0,0},false);self.geometry.mesh.enabled=false
    return self
end
function M:Warn(id,pos) self.warnings[id]=pos end
function M:ClearWarning(id) self.warnings[id]=nil end
function M:Event(e)
    if e.type=='drop' then self:Add(e.drop)
    elseif e.type=='dropCollected' then local item=self.drops[e.drop.id];if item then item.collectedAt=self.time;item.duration=e.reason=='waveClear' and D.config.clearPickupDuration or D.config.pickupDuration;item.start=item.root.position end end
end
function M:Add(drop)
    local root=self.root:CreateChild(drop.id);local pivot=root:CreateChild('Model');root.position=Coord.Vec(table.unpack(drop.pos));local visual
    if drop.type then
        local bp=Blueprint.New();bp:Add({type=drop.type,pos={0,0,0}})
        visual=VehicleView.New(pivot);visual:Rebuild(bp)
        local size=0;local min,max=Vector3(math.huge,math.huge,math.huge),Vector3(-math.huge,-math.huge,-math.huge)
        for _,v in pairs(visual.visuals) do for _,model in ipairs(v.models) do local b=model.worldBoundingBox
            min=Vector3(math.min(min.x,b.min.x),math.min(min.y,b.min.y),math.min(min.z,b.min.z));max=Vector3(math.max(max.x,b.max.x),math.max(max.y,b.max.y),math.max(max.z,b.max.z))
        end end
        if min.x<max.x then local span=max-min;size=math.max(span.x,span.y,span.z);local k=1.2/math.max(.001,size);pivot:SetScale(k);visual.root.position=((min+max)*.5-root.worldPosition)*(-1) end
    else
        self.coinMaterial=self.coinMaterial or Material:new();self.coinMaterial:SetTechnique(0,cache:GetResource('Technique','Techniques/PBR/PBRNoTexture.xml'));self.coinMaterial:SetShaderParameter('MatDiffColor',Variant(Color(1,.76,.1)));self.coinMaterial:SetShaderParameter('MatEmissiveColor',Variant(Color(.35,.266,.035)));self.coinMaterial:SetShaderParameter('Roughness',Variant(.25));self.coinMaterial:SetShaderParameter('Metallic',Variant(.9))
        for i=0,2 do Coin.Add(pivot,self.coinMaterial,i) end
    end
    self.drops[drop.id]={root=root,pivot=pivot,visual=visual,drop=drop}
end
function M:Update(session,dt)
    self.time=session.world.time;local now=self.time;local geom=self.geometry;geom:Begin('Endless',{0,0,0},false)
    for _,p in pairs(self.warnings) do geom:Beam(p,3,2,40,{1,.61,.27},.22) end
    for id,item in pairs(self.drops) do
        local drop=item.drop;local cat=drop.type and Defs.PARTS[drop.type].cat or 'credits';local color=colors[cat] or colors['function']
        item.pivot.rotation=Quaternion(math.deg(now*.9),Vector3.UP)
        if not item.collectedAt then
            local ground=session.world:GroundAt(drop.pos[1],drop.pos[3]);local y=type(ground)=='table' and ground.h or ground or drop.pos[2];item.root.position=Coord.Vec(drop.pos[1],y+.1,drop.pos[3]);item.pivot.position=Vector3(0,1.1+math.sin(now*2)*.12,0)
            geom:Beam({drop.pos[1],y+.1,drop.pos[3]},.55,.15,3.2,color,drop.credits and .14 or .12)
        else
            local t=math.min(1,(now-item.collectedAt)/item.duration);local target=Coord.Vec(table.unpack(session.player.pos or drop.pos));item.root.position=item.start+(target-item.start)*(t*t);item.root:SetScale(1-t*.85)
            if t>=1 then if item.visual then item.visual:Dispose() end;item.root:Dispose();self.drops[id]=nil end
        end
    end
    local elite=false
    for i=2,#session.entries do local u=session.entries[i].unit;if u.alive and u.endless.elite then elite=true;local p=u:Position();geom:Ring({p[1],p[2]+.1,p[3]},u.spec.bounds.radius+.25,u.spec.bounds.radius+.4,0,math.pi*2,{1,.81,.33},.85) end end
    if elite or next(self.warnings) or next(self.drops) then geom.mesh:Commit();geom.mesh.enabled=true else geom.mesh.enabled=false end
    local env=session.session.environment
    if env and env.effects and env.effects.shields then
        local sh=env.effects.shields[1];local enemy=env.effects.shields[2];if enemy then enemy.node.enabled=false end
        if sh then
            if self.shieldHp~=session.run.shield.hp then self.shieldHp=session.run.shield.hp;if sh.SetHP then sh:SetHP(session.run.shield.hp/session.run.shield.max) end end
            if session.run.shield.hp<=0 and not self.shieldDown then sh:Down();self.shieldDown=true
            elseif session.run.shield.hp>0 and self.shieldDown then sh:Raise();self.shieldDown=false end
        end
    end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    for _,item in pairs(self.drops) do if item.visual then item.visual:Dispose() end end
    self.geometry:Dispose();self.root:Dispose();if self.coinMaterial then self.coinMaterial:Dispose() end
    self.drops={};self.warnings={};self.geometry=nil;self.root=nil;self.coinMaterial=nil
end
return M

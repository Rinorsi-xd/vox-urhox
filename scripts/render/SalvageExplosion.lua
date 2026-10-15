-- Fixed source pools; GPU billboards/ramps replace sprite material rewrites.
local Coord=require 'core.Coord'
local Rules=require 'salvage.ExplosionRules'
local M={};M.__index=M
local corners={{-.5,-.5,0,0},{.5,-.5,1,0},{-.5,.5,0,1},{-.5,.5,0,1},{.5,-.5,1,0},{.5,.5,1,1}}
local function Plane(root)
    local n=root:CreateChild('SourcePuffModel');local g=n:CreateComponent('CustomGeometry');g:BeginGeometry(0,TRIANGLE_LIST)
    for _,v in ipairs(corners) do g:DefineVertex(Vector3(v[1],v[2],0));g:DefineNormal(Vector3.BACK);g:DefineTexCoord(Vector2(v[3],v[4])) end
    g:Commit();local model=Model:new();g:FillModel(model);model.boundingBox=BoundingBox(Vector3(-.708,-.708,-.708),Vector3(.708,.708,.708));n:Dispose();return model
end
local function MaterialFor(shader,texture,kind)
    local m=Material:new();assert(m:SetSurfaceShader('Shaders/BLGL/Salvage/'..shader..'.shader'))
    if texture then assert(m:SetSurfaceTexture('puff_map',assert(cache:GetResource('Texture2D','Salvage/Fx/'..texture..'.png')))) end
    m:SetShaderParameter('uKind',Variant(kind or 0));m.renderOrder=shader=='Puff' and 146 or 147;return m
end
function M.Dependencies()
    local t={'Shaders/BLGL/Salvage/Puff.shader','Shaders/BLGL/Salvage/AdditivePuff.shader','Shaders/BLGL/Salvage/ImpactRing.shader'}
    for _,s in ipairs({'fire-0','fire-1','fire-2','smoke-0','smoke-1','dot'}) do t[#t+1]='Salvage/Fx/'..s..'.png' end;return t
end
function M.New(scene,rand,options)
    local self=setmetatable({root=scene:CreateChild('SalvageExplosions'),materials={},pools={},rings={},lights={},warmT=3},M)
    if options and options.retain then options.retain(self) end
    local ok,err=pcall(self.Init,self,rand,options and options.checkpoint)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:Init(rand,checkpoint)
    self.model=Plane(self.root);local created=0
    local function Progress() created=created+1;if checkpoint and created%32==0 then checkpoint(created/1086) end end
    local defs={{'fire',240,'Puff','fire',3,0},{'core',40,'AdditivePuff','fire',3,0},{'smoke',200,'Puff','smoke',2,1},{'embers',600,'AdditivePuff','dot',1,1}}
    for _,d in ipairs(defs) do
        local mats={};for i=1,d[5] do local texture=d[4]=='dot' and 'dot' or d[4]..'-'..(i-1);local m=MaterialFor(d[3],texture,d[6]);mats[i]=m;self.materials[#self.materials+1]=m end
        local list={};self.pools[d[1]]=list
        for i=1,d[2] do local n=self.root:CreateChild(d[1]..i);n.enabled=false;local sm=n:CreateComponent('StaticModel');sm.model=self.model;sm.material=mats[(i-1)%#mats+1]
            sm.useInstanceColor=true;sm.useInstanceCustomData=true;sm.castShadows=false;sm.drawDistance=700;list[i]={node=n,model=sm};Progress()
        end
    end
    for i=1,4 do
        local n=self.root:CreateChild('ImpactRing'..i);n.enabled=false;local g=n:CreateComponent('CustomGeometry');g:BeginGeometry(0,TRIANGLE_LIST)
        for j=0,47 do local a,b=j*math.pi/24,(j+1)*math.pi/24
            local points={{math.cos(a)*.8,math.sin(a)*.8},{math.cos(a),math.sin(a)},{math.cos(b),math.sin(b)},{math.cos(a)*.8,math.sin(a)*.8},{math.cos(b),math.sin(b)},{math.cos(b)*.8,math.sin(b)*.8}}
            for _,p in ipairs(points) do g:DefineVertex(Coord.Vec(p[1],0,p[2]));g:DefineNormal(Vector3.UP) end
        end
        g:Commit();local m=MaterialFor('ImpactRing');g.material=m;g.drawDistance=700;self.rings[i]={node=n,material=m};self.materials[#self.materials+1]=m;Progress()
    end
    local function Linear(v) v=v/255;return v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end
    for i=1,2 do local n=self.root:CreateChild('ExplosionFlash'..i);local l=n:CreateComponent('Light');l.lightType=LIGHT_POINT;l.range=70;l.color=Color(1,Linear(138),Linear(48));l.useTemperature=false;l.castShadows=false;l.brightness=0;self.lights[i]=l;Progress() end
    self.rules=Rules.New(rand,self);if checkpoint then checkpoint(1) end
end
function M:Spawn(kind,index,q,clock)
    local p=self.pools[kind][index];p.node.enabled=false;p.node.position=Coord.Vec(table.unpack(q.p))
    local s0,s1=kind=='embers' and .55 or q.s0,kind=='embers' and .55 or q.s1
    p.node.scale=Vector3.ONE*math.max(s0,s1);p.model.instanceCustomData=Vector4(clock-q.life,q.max,s0,s1)
    p.model.instanceColor=Color(kind=='smoke' and q.dark or q.heat or 0,q.op or 1,q.rotation or 0,q.spin or 0)
end
function M:Activate(kind,index,q) self.pools[kind][index].model.instanceColor=Color(kind=='smoke' and q.dark or q.heat,q.op,q.rotationBase,q.spin) end
function M:Move(kind,index,q) local p=self.pools[kind][index];p.node.position=Coord.Vec(table.unpack(q.p));p.node.enabled=true end
function M:Hide(kind,index) self.pools[kind][index].node.enabled=false end
function M:Ring(index,q)
    local p=self.rings[index];p.node.enabled=q.visible==true
    if q.visible then p.node.position=Coord.Vec(table.unpack(q.p));p.node.scale=Vector3.ONE*q.scale;p.material:SetShaderParameter('uOpacity',Variant(q.opacity)) end
end
function M:Light(index,q) local l=self.lights[index];if q.p then l.node.position=Coord.Vec(table.unpack(q.p)) end;l.brightness=q.intensity or 0 end
function M:Clock(clock) for _,m in ipairs(self.materials) do m:SetShaderParameter('uClock',Variant(clock)) end end
function M:Explode(pos,size,big) self.rules:Explode(pos,size,big) end
function M:Update(dt,camera,player)
    if camera then local right,up=camera.worldRotation*Vector3.RIGHT,camera.worldRotation*Vector3.UP
        for _,m in ipairs(self.materials) do m:SetShaderParameter('uRight',Variant(right));m:SetShaderParameter('uUp',Variant(up)) end
    end
    self.rules:Update(dt)
    -- Source compiles transparent representatives during the initial drop.
    if self.warmT>0 then self.warmT=self.warmT-dt
        for _,kind in ipairs({'fire','core','smoke'}) do local p=self.pools[kind][1]
            if not self.rules[kind][1].on then p.node.enabled=self.warmT>0;p.node.position=Coord.Vec(table.unpack(player or {0,0,0}));p.model.instanceCustomData=Vector4(self.rules.clock,1,1,1);p.model.instanceColor=Color(0,0,0,0) end
        end
    end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.root:Dispose();for _,m in ipairs(self.materials) do m:Dispose() end
    if self.model then self.model:Dispose();self.model=nil end
    if self.rules then self.rules.sink=nil end
    self.materials={};self.pools={};self.rings={};self.lights={}
end
return M

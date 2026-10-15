local M={};M.__index=M
function M.New(scene,layout)
    local self=setmetatable({scene=scene,time=0,glows={}},M)
    self.deck=require('scene.EnginePitDeck').Get(scene,layout)
    self.deck.dust=require('render.EnginePitDust').New(scene,self.deck)
    scene:SetVar('VoxColorGrade',Variant('crater'))
    for _,group in ipairs(scene:GetComponents('StaticModelGroup',true)) do
        if group.numInstanceNodes==0 then for _,node in ipairs(group.node:GetChildren()) do if node.name=='Instance' then group:AddInstanceNode(node) end end end
        group.drawDistance=group.castShadows and 240 or 120
    end
    local sun=scene:GetChild('CraterSun',true):GetComponent('Light');sun.node.direction=Vector3(-.5209,-.5009,.6912)
    sun.shadowCascade=CascadeParameters(15,40,75,0,.8);sun.shadowBias=BiasParameters(.0004,.06)
    self.sky=scene:GetChild('CraterSky'):GetComponent('Skybox');self.skyMaterial=self.sky.material:Clone();self.sky.material=self.skyMaterial
    local mats=require('core.ResourceData').Read('EnginePit/Materials.json')
    for i,d in ipairs(mats) do if d.kind=='glow' then
        local mat=cache:GetResource('Material','EnginePit/material-'..i..'.xml'):Clone()
        for _,model in ipairs(scene:GetComponents('StaticModel',true)) do if model.material and model.material.name=='EnginePit/material-'..i..'.xml' then model.material=mat end end
        self.glows[#self.glows+1]={material=mat,color=d.color,fire=d.name=='喷口余火',seed=i*.71}
    end end
    local engine=layout.enginePit.ceilings[1];local a=14*math.pi/180
    local function At(u,v) return -64+u*math.cos(a)-v*math.sin(a),106-u*math.sin(a)-v*math.cos(a) end
    local nx,nz=At(106,0);local tx,tz=At(-74,8)
    self.effects=require('render.CraterEffects').New(scene,layout,{noShields=true,noLamps=true,ground='EnginePit/texture-0.bin',groundHalf=500,area=300,limit=320,
        origins={{nx,engine.center[2]+12,nz,1.4,6,.85},{tx,engine.center[2]+30,tz,.6,4,.6}},allowed=function(x,z) return x*x+z*z<320*320 end})
    return self
end
function M:Update(dt,camera)
    self.time=self.time+dt;self.sky.material:SetShaderParameter('uTime',Variant(self.time))
    for _,g in ipairs(self.glows) do
        local t,s=self.time,g.seed;local k=g.fire and (.7+.2*math.sin(t*7.3+s)+.12*math.sin(t*17.1+s*3)) or (math.sin(t*23+s)*math.sin(t*7.7)>.85 and .35 or 1)
        local c=g.color;g.material:SetShaderParameter('tint',Variant(Vector4(c[1]*k*(g.fire and .3 or 1),c[2]*k*(g.fire and .15 or 1),c[3]*k*(g.fire and .09 or 1),1)))
    end
    self.effects:Update(dt,self.time,camera)
    self.deck:Update(dt);self.deck.dust:Update(dt,self.time,camera)
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.effects then self.effects:Dispose();self.effects=nil end
    for _,g in ipairs(self.glows) do g.material:Dispose() end
    if self.skyMaterial then self.skyMaterial:Dispose();self.skyMaterial=nil end
    self.glows={};self.sky=nil;self.scene=nil;self.deck=nil
end
function M.Release() cache:ReleaseAllResources(false) end
return M

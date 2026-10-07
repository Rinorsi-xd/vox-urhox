-- Behavior for assets/Scenes/Crater.xml: no second scene or procedural rebuild.
local Coord=require 'core.Coord'
local M={};M.__index=M
local spin={genRing=.45,genHalo=-.3,anchorRing=.7,radar=.5,holo=.6,pointRing=.12,dropRing=-.25}
function M.New(scene,layout)
    scene:SetVar('VoxColorGrade',Variant('crater'))
    local self=setmetatable({scene=scene,dynamics={},glows={},time=0},M)
    local materials=require('core.ResourceData').Read('Crater/Materials.json')
    for _,d in ipairs(require('core.ResourceData').Read('Crater/Dynamics.json')) do
        local n=scene:GetNode(d.id);assert(n,'Missing authored dynamic node '..d.name)
        local p=n.position;local seed=(math.abs(math.sin(-p.x*12.9898+p.z*78.233))*43758.5453)%1
        self.dynamics[#self.dynamics+1]={node=n,kind=d.kind,home=p,rotation=n.rotation,scale=n.scale,seed=seed,dir=(string.byte(d.name,-1)%2==1) and 1 or -1}
    end
    for _,group in ipairs(scene:GetComponents('StaticModelGroup',true)) do
        if group.numInstanceNodes==0 then
            for _,n in ipairs(group.node:GetChildren()) do if n.name=='Instance' then group:AddInstanceNode(n) end end
        end
        group.drawDistance=group.castShadows and 220 or 150
    end
    local flicker={['喷口余火']='fire',['反应堆光']='breath',['空投灯_红']='blink',['点位全息']='holo',['舰灯_橙弱']='buzz'}
    for i,d in ipairs(materials) do if flicker[d.name] then
        local mat=assert(cache:GetResource('Material','Crater/material-'..i..'.xml')):Clone()
        for _,model in ipairs(scene:GetComponents('StaticModel',true)) do
            if model.material and model.material.name=='Crater/material-'..i..'.xml' then model.material=mat end
        end
        local c=d.color;local fire=flicker[d.name]=='fire'
        self.glows[#self.glows+1]={material=mat,kind=flicker[d.name],color={c[1]*(fire and .3 or 1),c[2]*(fire and .15 or 1),c[3]*(fire and .09 or 1)},seed=i*.71}
    end end
    local sun=scene:GetChild('CraterSun',true):GetComponent('Light');sun.node.direction=Vector3(-.5209,-.5009,.6912)
    sun.shadowCascade=CascadeParameters(15,40,75,0,.8);sun.shadowBias=BiasParameters(.0004,.06)
    local zone=scene:GetComponent('Zone',true);zone.envTextureDiffIntensity=.75;zone.envTextureSpecIntensity=.75
    zone.ssaoIntensity=0;zone.heightFogEnable=false
    self.sky=scene:GetChild('CraterSky');self.skyMaterial=self.sky:GetComponent('Skybox').material:Clone();self.sky:GetComponent('Skybox').material=self.skyMaterial
    -- Current shipping Runtime predates SkyLightCapture. Bake the same source
    -- sky formula into HDR once and use its supported asynchronous SH/IBL path.
    zone.sourceTexture=assert(cache:GetResource('Texture2D','Crater/Sky.hdr'));zone.ambientIntensity=.75
    self.effects=require('render.CraterEffects').New(scene,layout or require('drive.CraterLayout').Read())
    print('[Crater] Bound source map, '..#self.dynamics..' moving parts')
    return self
end
function M:Update(dt,camera)
    self.time=self.time+dt;local t=self.time
    -- Native Skybox already follows the camera; translating its node again
    -- displaces the unit cube and can leave only the Zone clear color visible.
    self.skyMaterial:SetShaderParameter('uTime',Variant(t))
    for _,d in ipairs(self.dynamics) do
        local n,k,s=d.node,d.kind,d.seed
        if spin[k] then n.rotation=Quaternion(-(t*spin[k]*(k=='genRing' and d.dir*(.7+s*.6) or 1)+s*6.28)*180/math.pi,Vector3.UP)
        elseif k=='genCore' then n.position=d.home+Vector3(0,math.sin(t*1.3)*.25,0)
        elseif k=='searchlight' then n.rotation=Quaternion(-math.sin(t*.35+s*6)*.8*180/math.pi,Vector3.UP)
        elseif k=='beacon' then n:SetScale(.85+.25*math.max(0,math.sin(t*3.1+s*6.28)))
        elseif k=='flag' then n.rotation=Quaternion(math.sin(t*2.9+s)*.05*180/math.pi,Vector3.RIGHT)*Quaternion(-math.sin(t*1.7+s*6)*.12*180/math.pi,Vector3.UP) end
    end
    for _,g in ipairs(self.glows) do
        local s=g.seed;local k=g.kind=='fire' and (.7+.2*math.sin(t*7.3+s)+.12*math.sin(t*17.1+s*3)) or g.kind=='breath' and (.8+.2*math.sin(t*1.6+s)) or g.kind=='blink' and (math.sin(t*3.2+s)>.2 and 1 or .25) or g.kind=='holo' and (.85+.15*math.sin(t*4+s)*math.sin(t*11)) or (math.sin(t*23+s)*math.sin(t*7.7)>.85 and .35 or 1)
        g.material:SetShaderParameter('tint',Variant(Vector4(g.color[1]*k,g.color[2]*k,g.color[3]*k,1)))
    end
    self.effects:Update(dt,t,camera)
end
function M:Dispose() if self.effects then self.effects:Dispose() end;self.dynamics={};self.glows={} end
function M.Release() cache:ReleaseAllResources(false) end
return M

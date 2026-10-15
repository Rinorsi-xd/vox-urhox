-- Meaningful regression assertions against the real main.lua scene and animation state.
local firstArm = 0
local firstCrane = 0
---@type Vector3
local firstDrone = Vector3.ZERO
V.atFrame(60, function()
    local ctx=VOX_HANGAR
    V.assert(ctx~=nil,"main exposes the actual hangar")
    if not ctx then return end
    V.assert(ctx.app.loader.state=="ready","authored scene load committed successfully")
    V.assert(ctx.scene:GetChild("Car")~=nil,"live blueprint vehicle belongs to loaded scene")
    local h=ctx.garage
    local bp=ctx.blueprint
    local Config=require "Config"
    local Defs=require "parts.Defs"
    local diagnostics={}
    for i,tier in ipairs(Config.TIERS) do
        local d=bp:Diagnose(tier)
        diagnostics[i]={list=d.list,stats=d.stats,conn={coreId=d.conn.coreId,floatingCount=d.conn.floatingCount}}
    end
    local file=assert(io.open('tools/migration/native-panels.json','w'))
    file:write(cjson.encode({name=bp.name,parts=bp:List(),tiers=Config.TIERS,diagnostics=diagnostics,defs=Defs.LIST}))
    file:close()
    V.assert(#h.arms==4,"four articulated arms")
    V.assert(#h.drones==2,"two patrol drones")
    V.assert(#h.niches==6,"six original display parts")
    V.assert(#h.holos==2,"both hologram panels")
    V.assert(h.root:GetChild("DynamicSpace")~=nil,"dynamic exterior sky")
    V.assert(h.root:GetChild("EnergyDoor")~=nil,"energy door")
    V.assert(h.envTex~=nil,"current hangar HDR environment")
    V.assert(h.reflTex~=nil,"planar reflection target")
    local lights=ctx.scene:GetComponents('Light',true)
    V.assert(#lights==5,"only original spotlight and four area lights")
    local shadows=0
    for _,light in ipairs(lights) do
        V.assert(light.lightType~=LIGHT_DIRECTIONAL,"no invented preset directional light")
        if light.castShadows then shadows=shadows+1 end
    end
    V.assert(shadows==1,"source spotlight is the only shadow caster")
    local Mat=require 'scene.HangarMaterials'
    local animated={}
    for _,material in ipairs(h.animatedMaterials) do animated[material]=true end
    V.assert(#h.animatedMaterials<#h.materials/2,'static hall materials excluded from per-frame uniform writes')
    local staticValue=h:Material('BuildDeck'):GetShaderParameter('hangar_time'):GetFloat()
    Mat.Update(h.animatedMaterials,17)
    for _,material in ipairs(h.animatedMaterials) do
        V.assert(math.abs(material:GetShaderParameter('hangar_time'):GetFloat()-17)<.0001,'animated material receives shared frame time: '..material.name)
    end
    V.assert(h:Material('BuildDeck'):GetShaderParameter('hangar_time'):GetFloat()==staticValue,'static deck retains authored time')
    V.assert(animated[h:Material('Holo_stats')] and animated[h:Material('HangarDust')] and animated[h:Material('DynamicSpace')],'screens, GPU dust and exterior keep time updates')
    Mat.Update(h.animatedMaterials,3)
    V.assert(h:Material('Holo_stats'):GetShaderParameter('hangar_time'):GetFloat()==3,'debug time rewind still updates animation')
    print('[HangarMaterials] total='..#h.materials..' animated='..#h.animatedMaterials)
    firstArm=h.arms[1].upper.rotation:PitchAngle()
    firstCrane=h.bridge.position.z
    firstDrone=h.drones[1].node.position
    V.assert(math.abs(h.grid-.3)<.02 and math.abs(h.frame-.8)<.02,"original homepage grid and independent frame")
    local lo=h.padMat:GetShaderParameter('uEnvMin'):GetVector2()
    local hi=h.padMat:GetShaderParameter('uEnvMax'):GetVector2()
    local bounds=Config.TierBounds()
    V.assert(lo.x==(bounds.minX-.5)*Config.CELL and hi.y==(bounds.maxZ+.5)*Config.CELL,"frozen shared build envelope reaches deck shader")
    h:SetGrid(true)
    h:UpdateGrid(.05)
    V.assert(not h.boundary.enabled and h.grid>.3,"source grid fades toward editing before boundary appears")
    h:UpdateGrid(.1)
    V.assert(h.boundary.enabled and h.guides.enabled,"construction boundary and height guides after source fade")
    V.assert(math.abs(h.guideMat:GetShaderParameter('uOpacity'):GetFloat()-.16*h.grid)<.0001,"guide opacity tracks original grid fade")
    h:SetTier(5)
end)
-- Spread the microbenchmark across frames; keep the normal 500 ms spike gate.
local measurement={iterations=2000,legacyMs={},optimizedMs={}}
for round=1,5 do
    V.atFrame(65+round*10,function()
        local h=VOX_HANGAR.garage
        local Mat=require 'scene.HangarMaterials'
        measurement.materials=#h.materials;measurement.animated=#h.animatedMaterials
        local function measure(legacy)
            collectgarbage('collect')
            local started=os.clock()
            for step=1,measurement.iterations do
                local frameTime=step/60
                if legacy then
                    for _,material in ipairs(h.materials) do Mat.Set(material,'hangar_time',frameTime) end
                else Mat.Update(h.animatedMaterials,frameTime) end
            end
            return (os.clock()-started)*1000
        end
        if round%2==1 then
            measurement.legacyMs[round]=measure(true);measurement.optimizedMs[round]=measure(false)
        else
            measurement.optimizedMs[round]=measure(false);measurement.legacyMs[round]=measure(true)
        end
        Mat.Update(h.animatedMaterials,h.time)
        if round==5 then
            local perfFile=assert(io.open('docs/migration/evidence/hangar-material-update.json','w'))
            perfFile:write(cjson.encode(measurement));perfFile:close()
        end
    end)
end
V.atFrame(150,function()
    local h=VOX_HANGAR.garage
    V.assert(math.abs(h.arms[1].upper.rotation:PitchAngle()-firstArm)>0.1,"arm animation changes")
    V.assert(math.abs(h.bridge.position.z-firstCrane)>0.001,"crane travels")
    V.assert((h.drones[1].node.position-firstDrone):Length()>0.1,"drone patrol moves")
    V.assert(h.reflCam.farClip==320,"reflection reaches the exterior")
    h:SetTier(3);h:SetGrid(false)
    h:UpdateGrid(1)
    V.assert(math.abs(h.grid-.3)<.0001 and math.abs(h.frame-.8)<.0001 and not h.boundary.enabled,"home restores independent grid and frame after edit")
end)

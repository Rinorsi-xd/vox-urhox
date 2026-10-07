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
    firstArm=h.arms[1].upper.rotation:PitchAngle()
    firstCrane=h.bridge.position.z
    firstDrone=h.drones[1].node.position
    h:SetGrid(true)
    V.assert(h.boundary.enabled and h.guides.enabled,"construction boundary and height guides")
    h:SetTier(5)
end)
V.atFrame(150,function()
    local h=VOX_HANGAR.garage
    V.assert(math.abs(h.arms[1].upper.rotation:PitchAngle()-firstArm)>0.1,"arm animation changes")
    V.assert(math.abs(h.bridge.position.z-firstCrane)>0.001,"crane travels")
    V.assert((h.drones[1].node.position-firstDrone):Length()>0.1,"drone patrol moves")
    V.assert(h.reflCam.farClip==320,"reflection reaches the exterior")
    h:SetTier(3);h:SetGrid(false)
end)

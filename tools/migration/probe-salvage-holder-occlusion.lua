-- QA-only, appended to the existing frozen-package probe. ScrollLock is unused
-- when drive-sections profiling is disabled by the boundary runner contract.
local holderOriginalUpdate=HandleUpdate
function HandleUpdate(et,ed)
    holderOriginalUpdate(et,ed)
    if not input:GetKeyPress(KEY_SCROLLLOCK) then return end
    local app=VOX_HANGAR and VOX_HANGAR.app or VOX_TRIAL and VOX_TRIAL.app or lastObservedApp
    local session=app and app.trial
    local cine=session and session.salvage and session.salvage.cine
    assert(cine and not cine.playing,'Holder QA requires completed natural drop')
    local holder=cine.view.nodes.holder
    holder:SetEnabledRecursive(not holder.enabled)
    local camera=session.camera:GetNode();local p=camera.worldPosition
    local ground=cache:GetExistingResource('Texture2D','Salvage/GroundBaked.png')
    print('VOX_QA_HOLDER_OCCLUSION '..cjson.encode({frame=frames,clock=Time:GetSystemTime(),visible=holder.enabled,
        camera={p.x,p.y,p.z},near=session.camera:GetCamera().nearClip,runTime=session.salvage.rules.time,
        ground=ground and {width=ground.width,height=ground.height,bytes=ground.memoryUse} or false,
        purpose='temporary holder visibility negative control; not production or performance evidence'}))
end

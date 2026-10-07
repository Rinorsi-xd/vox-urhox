-- Authored lighting stays in XML. Only runtime render targets are allocated here.
local M={}
local Quality=require "render.Quality"
function M.Bind(h)
    local zone=assert(h.scene:GetComponent("Zone",true),"Missing hangar Zone")
    h.envTex=zone.sourceTexture
    h:BuildReflection()
    h.reflCam.farClip=320
    h.padMat:SetShaderParameter("refl_strength",Variant(0.28))
end
function M.Update(h,camNode,cam,t)
    h:ResizeReflection(cam)
    if h.time>=(h.nextReflection or 0) then
        h.reflNode:SetWorldTransform(camNode.worldPosition,camNode.worldRotation)
        h.reflCam.fov=cam.fov;h.reflCam.nearClip=cam.nearClip;h.reflCam.farClip=cam.farClip
        h.reflCam.aspectRatio=h.reflAspect
        -- Keep the projection paired with the captured frame at limited refresh rates.
        h.padMat:SetShaderParameter('refl_matrix',Variant(h.reflCam:GetProjection()*h.reflCam:GetView()))
        h.padMat:SetShaderParameter('refl_flip_y',Variant(graphics.apiName:find('OpenGL') and 1.0 or 0.0))
        h.reflTex.renderSurface:QueueUpdate()
        h.reflFilter:Queue()
        h.nextReflection=h.time+1/Quality.current.reflectionHz
    end
end
return M

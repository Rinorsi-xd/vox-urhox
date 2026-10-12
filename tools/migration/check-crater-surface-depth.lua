-- Production scene A/B: same camera, geometry, lighting and frozen animation.
-- Only restore the retired searchlight housing slope offset between captures.
local views={
    {name='fort',eye={70,28,-200},at={0,8,-272},lens=26},
    {name='ship',eye={-150,45,-190},at={0,0,0},lens=24},
    {name='interior',eye={100,-5,-20},at={-40,-2,10},lens=20},
    {name='deck',eye={105,45,-75},at={-85,40,0},lens=22},
    {name='gate',eye={45,4,-125},at={45,0,-30},lens=26},
}
local solids={}
local configured=false
local function Bias(legacy)
    for _,entry in ipairs(solids) do
        entry.material:SetDepthBias(BiasParameters(entry.bias.constantBias,legacy and -1 or 0))
    end
end
local function Shot(name)
    local image=Image:new()
    V.assert(graphics:TakeScreenShot(image),'capture '..name)
    V.assert(image:SavePNG('docs/migration/evidence/crater-depth-'..name..'.png'),'save '..name)
    image:Dispose()
end
local function Pose(view)
    local p=assert(CRATER_PREVIEW)
    if not configured then
        p.environment.time=10;p.environment:Update(0,p.camera.node)
        p.environment.Update=function() end
        V.assert(p.settings.post.fixedResolution,'validation uses a fixed render resolution')
        for _,model in ipairs(p.scene:GetComponents('StaticModel',true)) do
            local mat=model.material
            if mat then
                local bias=mat.depthBias
                if mat.name=='Crater/material-34.xml' then
                    V.assert(bias.slopeScaledBias==0,'rotating searchlight housing uses no slope bias')
                    solids[#solids+1]={material=mat,bias=bias}
                end
            end
        end
        local glow=cache:GetResource('Material','Crater/material-30.xml')
        V.assert(glow.depthBias.slopeScaledBias==-2,'surface fix preserves glow strip offset')
        local hull=cache:GetResource('Material','Crater/material-36.xml')
        V.assert(hull.depthBias.slopeScaledBias==-1,'static hull and terrain seam bias is preserved')
        V.assert(#solids==1,'only the authored searchlight housing is affected')
        configured=true
    end
    p.camera.node.position=Vector3(-view.eye[1],view.eye[2],view.eye[3])
    p.camera.node:LookAt(Vector3(-view.at[1],view.at[2],view.at[3]))
    p.camera.fov=2*math.atan(18/view.lens/(graphics:GetWidth()/graphics:GetHeight()))*180/math.pi
    Bias(true)
end
for i,view in ipairs(views) do
    local frame=120+(i-1)*30
    V.atFrame(frame,function() Pose(view) end)
    V.atFrame(frame+10,function() Shot(view.name..'-before');Bias(false) end)
    V.atFrame(frame+20,function() Shot(view.name..'-after') end)
end
V.atFrame(270,function() V.assert(configured,'all source cameras reviewed');V.finish() end)

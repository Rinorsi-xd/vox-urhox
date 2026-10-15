local ready,p
local function Shot(name)
    local im=Image:new();V.assert(graphics:TakeScreenShot(im),'capture source sun view '..name)
    V.assert(im:SavePNG('docs/migration/evidence/crater-native-map-sun-'..name..'.png'),'save source sun view '..name);im:Dispose()
end
for frame=1,350 do V.atFrame(frame,function()
    if not ready and CRATER_PREVIEW then
        p=CRATER_PREVIEW;ready=frame
        p.camera.node.position=Vector3(-70,5,140)
        p.camera.node:LookAt(p.camera.node.position+Vector3(.52,.5,-.69).normalized*1500)
        p.camera.fov=2*math.atan(18/20/(graphics:GetWidth()/graphics:GetHeight()))*180/math.pi
        local update=p.environment.Update
        p.environment.Update=function(self,dt,node) self.time=10;update(self,0,node) end
    end
    if ready and frame==ready+25 then
        local post=p.settings.post;local mat=post.graph.materials[post.indices.clamp]
        V.assert(mat:GetShaderParameter('shaft_on'):GetFloat()>.99,'sun-facing camera enables shafts')
        local uv=mat:GetShaderParameter('shaft_sun'):GetVector2()
        V.assert(math.abs(uv.x-.5)<.001 and math.abs(uv.y-.5)<.001,'mirrored source sun projects to image center')
        Shot('on');p.settings.PostUpdate=function() end
        post.graph:Parameter(post.indices.clamp,'shaft_on',0)
    end
    if ready and frame==ready+35 then
        Shot('off')
        local post=p.settings.post
        p.camera.node:LookAt(p.camera.node.position-Vector3(.52,.5,-.69).normalized*1500);post:PostUpdate()
        V.assert(post.graph.materials[post.indices.clamp]:GetShaderParameter('shaft_on'):GetFloat()==0,'facing away disables shaft samples')
        p.camera.node:LookAt(p.camera.node.position+Vector3(.52,.5,-.69).normalized*1500)
        post.data.quality='low';post:PostUpdate()
        V.assert(post.graph.materials[post.indices.clamp]:GetShaderParameter('shaft_on'):GetFloat()==0,'source low quality disables shafts')
        post.data.quality='high';V.finish()
    end
end) end

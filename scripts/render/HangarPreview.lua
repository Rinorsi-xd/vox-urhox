-- One on-demand authored-scene capture for all home/library owners. No gameplay
-- input, second application or persistent preview world. Source camera/crop:
-- shared/build/editor.js::_thumbnail + three/src/render/pipeline.js::capture.
local Cache=require 'storage.PreviewCache'
local Config=require 'Config'
local M={};M.__index=M
function M.New(app)
    return setmetatable({app=app,loader=require('app.SceneLoader').New(function(scene) scene:SetVar('VoxPreview',Variant(true)) end),queue={},frame=0,
        captures=0,cacheHits=0,cancelled=0,sceneLoads=0,idle=0},M)
end
function M:Request(data,done)
    local request={data=data,ref=data.preview,done=done}
    self.queue[#self.queue+1]=request;return request
end
function M:Cancel(request)
    if not request or request.finished or request.cancelled then return end
    request.cancelled=true;request.done=nil;request.data=nil;self.cancelled=self.cancelled+1
    if self.job and self.job.request==request then self:ReleaseJob() end
end
function M:ReleaseJob()
    local job=self.job;if not job then return end
    if job.texture then require('render.RenderTargetLifetime').Retire(job.texture) end
    if job.view then job.view:Dispose() end
    self.job=nil;self.bp=nil
end
function M:ReleaseScene()
    self:ReleaseJob();self.loader:Cancel()
    if self.hangar then self.hangar:Dispose();self.hangar=nil end
    if self.scene then self.scene:Dispose();self.scene=nil end
    self.camera=nil;self.cameraNode=nil
end
function M:Complete(request,image,message)
    request.finished=true;local done=request.done;request.done=nil;request.data=nil
    if done and not request.cancelled then done(image,message) elseif image then image:Dispose() end
end
function M:LoadScene()
    self.sceneLoads=self.sceneLoads+1
    self.loader:Load('Scenes/OrbitalHangar.xml',function(scene)
        self.scene=scene
        -- Authored hall geometry is sufficient for a saved thumbnail. Binding
        -- the live hall also creates reflection/filter scenes and NanoVG panel
        -- render targets; tearing those nested captures down can stall the GPU.
        self.cameraNode=scene:CreateChild('SavedVehicleCamera')
        self.camera=self.cameraNode:CreateComponent('Camera')
        self.camera.nearClip=.05;self.camera.farClip=320;self.camera.autoAspectRatio=false
    end,function(message)
        -- SceneLoader owns disposal of a failed candidate.
        self.scene=nil
        if self.hangar then self.hangar:Dispose();self.hangar=nil end
        self.camera=nil;self.cameraNode=nil
        for _,r in ipairs(self.queue) do if not r.cancelled then self:Complete(r,nil,message) end end
        self.queue={}
    end)
end
function M:Start(request)
    local data=request.data;local context=request.ref and request.ref.context or {}
    if type(context)~='table' then context={} end
    local aspect=tonumber(context.aspect) or 16/9
    aspect=math.max(.5,math.min(4,aspect))
    local width=math.ceil(math.max(320,200*aspect)*1.35)
    local height=math.ceil(width/aspect)
    local bp=require('construction.Blueprint').New():Load(data)
    local view=require('render.VehicleView').New(self.scene,'SavedVehicle')
    self.job={request=request,view=view,frame=self.frame}
    view:Rebuild(bp)
    local stats=bp:Stats();local b=stats.bb;local cell=Config.CELL
    local floor=stats.count>0 and b.minY*cell or 0
    view.root.position=Vector3(0,-floor,0)
    local center=stats.count>0 and Vector3(-(b.minX+b.maxX)*cell/2,((b.minY+b.maxY)/2+.5)*cell-floor,(b.minZ+b.maxZ)*cell/2) or Vector3(0,1,0)
    local dims=stats.dims
    local radius=stats.count>0 and math.sqrt(dims.L^2+dims.W^2+dims.H^2)*cell/2 or 2
    self.cameraNode.position=center+Vector3(-.72,.42,.95):Normalized()*(radius*1.75+1.2)
    self.cameraNode:LookAt(center);self.camera.fov=48;self.camera.aspectRatio=width/height
    self.bp=bp;self.tier=math.max(1,math.min(5,tonumber(context.tier) or 3));self.slot=request.ref and request.ref.slot
    local settings=context.graphics
    if not require('render.GraphicsSettings').Valid(settings) then settings=self.app.graphicsSettings.data end
    require('render.GraphicsSettings').Apply({app={ownsScene=true},data=settings},self.scene)
    local texture=Texture2D:new();texture:SetNumLevels(1)
    self.job.texture=texture
    assert(texture:SetSize(width,height,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Cannot allocate saved preview')
    local viewport=Viewport:new(self.scene,self.camera)
    viewport:SetRenderPath(renderer:GetDefaultRenderPath():Clone())
    local surface=texture:GetRenderSurface();surface:SetViewport(0,viewport);surface:SetUpdateMode(SURFACE_MANUALUPDATE)
    self.job.viewport=viewport;self.job.width=width;self.job.height=height
    self.captures=self.captures+1
end
function M:Readback()
    local job=self.job;local request=job.request
    local image=assert(job.texture:GetImage(),'Saved preview readback unavailable')
    -- Canvas drawImage centers a cover fit scaled by 1.35, then shifts up 6%.
    local x=math.floor((job.width-320)/2+.5);local y=math.floor((job.height-200)/2+12+.5)
    local crop=image:GetSubimage(IntRect(x,y,x+320,y+200));image:Dispose()
    assert(crop,'Saved preview crop unavailable')
    if request.ref then Cache.Save(request.ref,crop) end
    self:ReleaseJob();self:Complete(request,crop)
end
function M:Update(dt)
    self.frame=self.frame+1;self.loader:Update(dt)
    if self.job then
        local job=self.job
        if job.request.ref and not Cache.Current(job.request.ref) then
            self:ReleaseJob();self:Complete(job.request,nil,'存档版本已更新');return
        end
        if self.frame-job.frame>=5 then
            local ok,err=pcall(self.Readback,self)
            if not ok then self:ReleaseJob();self:Complete(job.request,nil,tostring(err)) end
        else
            job.texture:GetRenderSurface():QueueUpdate()
        end
        return
    end
    while self.queue[1] and self.queue[1].cancelled do table.remove(self.queue,1) end
    local request=self.queue[1]
    if not request then
        self.idle=self.idle+dt
        if self.idle>=.25 and (self.scene or self.loader.state=='loading') then self:ReleaseScene() end
        return
    end
    self.idle=0
    if request.ref and not Cache.Current(request.ref) then
        table.remove(self.queue,1);self:Complete(request,nil,'存档版本已更新');return
    end
    local image
    if not request.cacheChecked then image=Cache.Load(request.ref);request.cacheChecked=true end
    if image then
        table.remove(self.queue,1);self.cacheHits=self.cacheHits+1;self:Complete(request,image);return
    end
    if not self.scene then if self.loader.state~='loading' then self:LoadScene() end;return end
    table.remove(self.queue,1)
    local ok,err=pcall(self.Start,self,request)
    if not ok then self:ReleaseJob();self:Complete(request,nil,tostring(err)) end
end
function M:Dispose()
    if self.job then self:Cancel(self.job.request) end
    for _,r in ipairs(self.queue) do self:Cancel(r) end
    self.queue={};self:ReleaseScene()
end
return M

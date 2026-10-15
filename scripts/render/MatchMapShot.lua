-- One capture of the existing scene. No copied world, live camera or per-frame RT.
local M={};M.__index=M
local active
local subscribed=false
local fogValues={depthFogEnable=false,heightFogEnable=false,volumetricFogEnabled=false,depthFogDensity=0,heightFogDensity=0,depthFogStart=10000,depthFogEnd=20000,fogStart=10000,fogEnd=20000,fogDensity=0,heightFog=false}
local function Restore(self)
    for _,item in ipairs(self.fog or {}) do for key in pairs(fogValues)do item.zone[key]=item.values[key] end end
    for _,item in ipairs(self.distances or {})do item.drawable.drawDistance=item.distance end
    self.fog=nil;self.distances=nil
end
local function Subscribe()
    if subscribed then return end;subscribed=true
    SubscribeToEvent('BeginViewUpdate',function(_,e)
        local self=active
        if not self or self.disposed or e:GetPtr('Camera')~=self.camera or e:GetPtr('Texture')~=self.texture then return end
        self.fog={}
        self.distances={}
        for _,result in ipairs(self.scene:GetComponent('Octree'):GetAllDrawables(DRAWABLE_GEOMETRY,0xffffffff))do
            local drawable=result.drawable
            if drawable.drawDistance>0 then
                self.distances[#self.distances+1]={drawable=drawable,distance=drawable.drawDistance};drawable.drawDistance=0
            end
        end
        local zones=self.scene:GetComponents('Zone',true);zones[#zones+1]=renderer.defaultZone
        for _,zone in ipairs(zones) do
            local item={zone=zone,values={}}
            for key in pairs(fogValues)do item.values[key]=zone[key] end
            for key,value in pairs(fogValues)do zone[key]=value end
            self.fog[#self.fog+1]=item
        end
    end)
    SubscribeToEvent('EndViewRender',function(_,e)
        local self=active
        if not self or e:GetPtr('Camera')~=self.camera or e:GetPtr('Texture')~=self.texture then return end
        Restore(self);self.views=(self.views or 0)+1
        self.captured=self.views>=5;self.captureFrame=GetTime().frameNumber
    end)
end
function M.Initialize()
    Subscribe()
end
function M.Shutdown()
    if active then active:Dispose() end
    if subscribed then
        UnsubscribeFromEvent('BeginViewUpdate');UnsubscribeFromEvent('EndViewRender')
        subscribed=false
    end
end
local function Baked(scene,map)
    if not map or map.scene~='Scenes/Crater.xml' then return false end
    return true
end
function M:LoadBaked()
    local meta=require('core.ResourceData').Read('Crater/Minimap.json')
    assert(meta.version==1 and meta.revision=='crater-static-v1' and meta.scene=='Scenes/Crater.xml'
        and meta.size==1024 and meta.half==320 and meta.image=='Crater/Minimap.bin','Stale minimap contract')
    for path,expected in pairs(meta.runtimeChecks)do
        local file=assert(cache:GetFile(path),'Missing minimap input '..path)
        local matches=file.size==expected.bytes and file:GetChecksum()==expected.checksum
        file:Dispose();assert(matches,'Stale minimap input '..path)
    end
    local image=assert(cache:GetResource('Image',meta.image,false),'Missing baked minimap pixels')
    assert(not image.compressed and image.width==1024 and image.height==1024,'Invalid baked minimap pixels')
    local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetSRGB(false)
    if not texture:SetData(image)then texture:Dispose();error('Cannot upload baked minimap')end
    texture:SetFilterMode(FILTER_BILINEAR)
    self.result=texture;self.ready=true;self.captured=true;self.progress=1;self.baked=true;self.scene=nil
end
function M.New(scene,map)
    assert(not active,'Minimap capture already active')
    local self=setmetatable({scene=scene,half=320,size=1024},M)
    if Baked(scene,map) then
        self.bakePending=true;self.bakeStarted=Time:GetSystemTime()
        cache:DownloadResources({'Crater/Minimap.json','Crater/Minimap.bin'},function(ok,failed)
            if self.disposed or not self.bakePending then return end
            self.bakeDownloaded=ok and (not failed or failed==0)
            self.bakeFinished=true
        end)
    else self:Capture() end
    return self
end
function M:Capture()
    local scene=self.scene
    active=self;M.Initialize()
    local ok,err=pcall(function()
        self.node=scene:CreateChild('MatchMapShotCamera')
        self.node.position=Vector3(0,1200,0);self.node.rotation=Quaternion(90,Vector3.RIGHT)
        self.camera=self.node:CreateComponent('Camera');self.camera.orthographic=true;self.camera.orthoSize=640
        self.camera.autoAspectRatio=false;self.camera.aspectRatio=1;self.camera.nearClip=1;self.camera.farClip=3000
        self.texture=Texture2D:new();self.texture:SetNumLevels(1)
        assert(self.texture:SetSize(1024,1024,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Cannot allocate map capture')
        local viewport=Viewport:new(scene,self.camera);viewport:SetRenderPath(renderer:GetDefaultRenderPath():Clone())
        self.viewport=viewport
        local surface=self.texture:GetRenderSurface();surface:SetViewport(0,viewport);surface.updateMode=SURFACE_MANUALUPDATE;surface:QueueUpdate()
    end)
    if not ok then self:Dispose();error(err) end
end
local function Shift(color)
    local mask=color:ToUInt()
    for i=0,24,8 do if ((mask>>i)&255)==255 then return i end end
    error('Unknown packed Color format')
end
local function Byte(value)
    local low=math.floor(value);local fraction=value-low
    return math.max(0,math.min(255,fraction>.5 and low+1 or fraction<.5 and low or low%2==0 and low or low+1))
end
function M.Tone(r,g,b,lo,hi)
    local lum=((.3*r+.59*g+.11*b)/255)^(1/2.2)
    local l=math.max(0,math.min(1,(lum-lo)/math.max(.05,hi-lo)))
    return Byte(30+104*l),Byte(40+112*l),Byte(54+120*l)
end
function M:Process()
    local image=self.image;local size=self.size;local total=size*size
    local rs,gs,bs,as=Shift(Color(1,0,0,0)),Shift(Color(0,1,0,0)),Shift(Color(0,0,1,0)),Shift(Color(0,0,0,1))
    local histogram={}
    local function Read(x,y)
        local value=image:GetPixelInt(x,y)
        return (value>>rs)&255,(value>>gs)&255,(value>>bs)&255
    end
    for i=0,total-1 do
        local r,g,b=Read(i%size,math.floor(i/size));local weight=30*r+59*g+11*b
        histogram[weight]=(histogram[weight] or 0)+1
        if i%1024==1023 then self.progress=(i+1)/total*.5;coroutine.yield() end
    end
    local count=0;local lo,hi
    for i=0,25500 do
        count=count+(histogram[i] or 0)
        if not lo and count>math.floor(total*.03) then lo=(i/25500)^(1/2.2) end
        if count>math.floor(total*.98) then hi=(i/25500)^(1/2.2);break end
    end
    hi=hi~=0 and hi or 1
    for i=0,total-1 do
        local x,y=i%size,math.floor(i/size);local r,g,b=Read(x,y)
        local tr,tg,tb=M.Tone(r,g,b,lo,hi)
        image:SetPixelInt(x,y,(tr<<rs)|(tg<<gs)|(tb<<bs)|(255<<as))
        if i%1024==1023 then self.progress=.5+(i+1)/total*.5;coroutine.yield() end
    end
    local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetSRGB(false)
    assert(texture:SetData(image),'Cannot upload minimap base');texture:SetFilterMode(FILTER_BILINEAR)
    self.result=texture;image:Dispose();self.image=nil;self.ready=true
end
function M:Update()
    if self.disposed or self.ready then return end
    if self.bakePending then
        if not self.bakeFinished and Time:GetSystemTime()-self.bakeStarted<10000 then return end
        self.bakePending=false
        if self.bakeDownloaded then
            local ok,message=pcall(self.LoadBaked,self)
            if ok then return end
            print('[MatchMapShot] Baked base unavailable: '..tostring(message))
        end
        self:Capture()
    end
    if not self.captured then self.texture:GetRenderSurface():QueueUpdate();return end
    if GetTime().frameNumber<(self.captureFrame or 0)+3 then return end
    if not self.worker then
        self.image=assert(self.texture:GetImage(),'Minimap readback unavailable')
        self.texture:GetRenderSurface():SetNumViewports(0);self.viewport=nil
        require('render.RenderTargetLifetime').Retire(self.texture);self.texture=nil
        self.node:Dispose();self.node=nil;self.camera=nil;self.scene=nil
        if active==self then active=nil end
        self.worker=coroutine.create(function()self:Process()end)
    end
    local deadline=Time:GetSystemTime()+4
    repeat
        local ok,err=coroutine.resume(self.worker)
        if not ok then self:Dispose();error(err) end
    until coroutine.status(self.worker)=='dead' or Time:GetSystemTime()>=deadline
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    Restore(self);if active==self then active=nil end
    if self.texture then self.texture:GetRenderSurface():SetNumViewports(0);require('render.RenderTargetLifetime').Retire(self.texture)end
    if self.node then self.node:Dispose()end
    if self.image then self.image:Dispose()end
    -- The receiving minimap owns the processed texture after Take().
    if self.result then self.result:Dispose()end
    self.texture=nil;self.node=nil;self.image=nil;self.result=nil;self.worker=nil;self.viewport=nil;self.scene=nil
end
function M:Take()
    if not self.ready then return end
    local texture=self.result;self.result=nil
    return texture,self.half
end
return M

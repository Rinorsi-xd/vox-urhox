-- Retained GPU portrait; only the visible speaker queues its two small targets.
local RenderTargetLifetime=require("render.RenderTargetLifetime")

local Layout=require 'ui.CommsPortraitLayout'
---@class CommsPortrait
---@field who string
---@field width integer
---@field height integer
local M={};M.__index=M
local vertices={{-1,-1,0,1},{-1,1,0,0},{1,1,1,0},{-1,-1,0,1},{1,1,1,0},{1,-1,1,1}}
function M.Path(who,face)
    face=face:gsub('^'..who..'_','')
    return (who=='nono' and 'Intro/Images/' or 'UI/Faces/')..who..'_'..face..'.png'
end
function M.New(who)
    local self=setmetatable({who=who,scenes={},textures={},materials={},images={},faces={},glitch=0,nextGlitch=3,lastTime=0},M)
    self.width=who=='huhu' and 156 or 330;self.height=who=='huhu' and 195 or 410
    local xml=XMLFile:new();assert(xml:FromString('<renderpath><command type="clear" color="0 0 0 0" depth="1"/><command type="scenepass" pass="base" vertexlights="false"/><command type="scenepass" pass="alpha" vertexlights="false"/></renderpath>'))
    local path=renderer:GetDefaultRenderPath():Clone();assert(path:Load(xml));xml:Dispose()
    for i=1,2 do
        local scene=Scene();scene:CreateComponent('Octree');self.scenes[i]=scene
        local camera=scene:CreateChild('PortraitCamera'):CreateComponent('Camera');camera.node.position=Vector3(0,0,-2)
        camera.orthographic=true;camera.orthoSize=2;camera.autoAspectRatio=false;camera.aspectRatio=1
        local geometry=scene:CreateChild('PortraitQuad'):CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
        for _,v in ipairs(vertices) do geometry:DefineVertex(Vector3(v[1],v[2],0));geometry:DefineNormal(Vector3(0,0,-1));geometry:DefineTexCoord(Vector2(v[3],v[4])) end
        geometry:Commit();local material=Material:new();assert(material:SetSurfaceShader('Shaders/BLGL/UI/CommsPortrait.shader'));geometry:SetMaterial(material);self.materials[i]=material
        material:SetShaderParameter('canvas_size',Variant(Vector2(self.width,self.height)))
        material:SetShaderParameter('opaque_rgb',Variant(i==2 and 1.0 or 0.0))
        if who=='huhu' then material:SetShaderParameter('holo_tint',Variant(Vector3(1,.28,.24)));material:SetShaderParameter('mouth_rect',Variant(Vector4(.455,.365,.572,.436))) end
        local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetSRGB(false)
        local dpr=math.min(2,graphics:GetDPR());assert(texture:SetSize(math.ceil(self.width*dpr),math.ceil(self.height*dpr),Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET))
        texture:SetFilterMode(FILTER_BILINEAR);texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
        self.textures[i]=texture
        local viewport=Viewport:new(scene,camera);viewport:SetRenderPath(path)
        local surface=texture:GetRenderSurface();surface:SetViewport(0,viewport);surface.updateMode=SURFACE_MANUALUPDATE
    end
    return self
end
function M:Texture(face)
    if self.faces[face] then return self.faces[face] end
    local path=M.Path(self.who,face)
    if not cache:Exists(path) then return nil end
    local texture=cache:GetResource('Texture2D',path)
    if texture then self.faces[face]=texture end;return texture
end
function M:ResetPresentation()
    self.width=self.who=='huhu' and 156 or 330;self.height=self.who=='huhu' and 195 or 410
    self.glitch=0;self.nextGlitch=3;self.lastTime=0;self.face=nil;self.ready=false;self.requested=false
    for _,material in ipairs(self.materials) do material:SetShaderParameter('canvas_size',Variant(Vector2(self.width,self.height))) end
end
function M:Prepare(time,face,talking)
    face=(face or 'talk'):gsub('^'..self.who..'_','')
    if talking and (self.who=='nono' or face=='smug') then face='talk' end
    local texture=self:Texture(face);if not texture then return false end
    local closed=self:Texture(self.who=='huhu' and 'smug' or 'smile') or texture
    local dt=math.max(0,math.min(.1,time-self.lastTime));self.lastTime=time
    if self.face and self.face~=face then self.glitch=math.max(self.glitch,.7) end;self.face=face
    if time>self.nextGlitch then self.glitch=math.max(self.glitch,.45);self.nextGlitch=time+4.5 end
    self.glitch=self.glitch*math.exp(-dt*10)
    local sx,sy,ox,oy=Layout.Fit(self.width,self.height,texture.width,texture.height)
    for i,material in ipairs(self.materials) do
        material:SetSurfaceTexture('face_map',texture);material:SetSurfaceTexture('mouth_map',closed)
        material:SetShaderParameter('image_scale',Variant(Vector2(sx,sy)));material:SetShaderParameter('image_offset',Variant(Vector2(ox,oy)))
        material:SetShaderParameter('clock',Variant(time));material:SetShaderParameter('glitch',Variant(self.glitch))
        material:SetShaderParameter('mouth_on',Variant(face=='talk' and talking and math.floor(time/.09)%2==0 and 1.0 or 0.0))
    end
    self.ready=true;self.requested=true;return true
end
function M:Queue()
    if not self.requested then return end
    self.requested=false
    for _,texture in ipairs(self.textures) do texture:GetRenderSurface():QueueUpdate() end
end
function M:Draw(vg,r)
    if not self.ready then return end
    local handles=self.images[vg]
    if not handles then handles={nvgCreateVideo(vg,self.textures[1]),nvgCreateVideo(vg,self.textures[2])};self.images[vg]=handles end
    nvgSave(vg)
    nvgBeginPath(vg);nvgRect(vg,r.x,r.y,r.w,r.h)
    nvgFillPaint(vg,nvgImagePatternTinted(vg,r.x,r.y,r.w,r.h,0,handles[1],nvgRGBA(0,0,0,255)));nvgFill(vg)
    nvgGlobalCompositeBlendFuncSeparate(vg,NVG_ONE,NVG_ONE,NVG_ZERO,NVG_ONE)
    nvgFillPaint(vg,nvgImagePattern(vg,r.x,r.y,r.w,r.h,0,handles[2],1));nvgFill(vg);nvgRestore(vg)
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    for vg,handles in pairs(self.images) do for _,image in ipairs(handles) do nvgDeleteVideo(vg,image) end end;self.images={}
    for _,texture in ipairs(self.textures) do texture:GetRenderSurface():SetNumViewports(0) end
    for _,scene in ipairs(self.scenes) do scene:Dispose() end
    for _,material in ipairs(self.materials) do material:Dispose() end
    for _,texture in ipairs(self.textures) do RenderTargetLifetime.Retire(texture) end
    self.textures={};self.scenes={};self.materials={};self.faces={}
end
return M

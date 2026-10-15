-- Three explicit HDR mip equivalents, used by the source deck's LOD 1.52..2.52.
-- Owned by the hangar reflection; three small GPU draws per reflection refresh.
local M={};M.__index=M
function M.New(source)
    local self=setmetatable({scene=Scene(),textures={},materials={}},M)
    local ok,err=pcall(function() self:Init(source) end)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:Init(source)
    self.scene:CreateComponent('Octree')
    local xml=XMLFile:new()
    assert(xml:FromString('<renderpath><command type="clear" color="0 0 0 1" depth="1" stencil="0"/><command type="scenepass" pass="base" vertexlights="false"/></renderpath>'))
    local path=renderer:GetDefaultRenderPath():Clone();assert(path:Load(xml));xml:Dispose()
    local vertices={{-1,-1,0,1},{-1,1,0,0},{1,1,1,0},{-1,-1,0,1},{1,1,1,0},{1,-1,1,1}}
    local width,height=source.width,source.height
    for level=1,3 do
        width=math.max(1,math.floor(width/2));height=math.max(1,math.floor(height/2))
        local cam=self.scene:CreateChild('FilterCamera'..level):CreateComponent('Camera')
        cam.node.position=Vector3(0,0,-2);cam.orthographic=true;cam.orthoSize=2;cam.autoAspectRatio=false;cam.aspectRatio=1;cam.viewMask=1<<level
        local geometry=self.scene:CreateChild('FilterQuad'..level):CreateComponent('CustomGeometry')
        geometry.viewMask=1<<level;geometry:BeginGeometry(0,TRIANGLE_LIST)
        for _,v in ipairs(vertices) do
            geometry:DefineVertex(Vector3(v[1],v[2],0));geometry:DefineNormal(Vector3(0,0,-1));geometry:DefineTexCoord(Vector2(v[3],v[4]))
        end
        geometry:Commit()
        local material=Material:new();self.materials[level]=material
        assert(material:SetSurfaceShader('Shaders/BLGL/Hangar/ReflectionDownsample.shader'))
        material:SetShaderParameter('box_width',Variant(2^level))
        assert(material:SetSurfaceTexture('source_map',source));geometry:SetMaterial(material)
        local texture=Texture2D:new();self.textures[level]=texture;texture:SetNumLevels(1)
        assert(texture:SetSize(width,height,Graphics:GetRGBAFloat16Format(),TEXTURE_RENDERTARGET))
        texture.filterMode=FILTER_BILINEAR;texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
        local viewport=Viewport:new(self.scene,cam)
        viewport:SetRenderPath(path)
        texture.renderSurface:SetViewport(0,viewport);texture.renderSurface.updateMode=SURFACE_MANUALUPDATE
    end
end
function M:Queue()
    -- Independent levels all read the same source capture.
    for _,texture in ipairs(self.textures) do texture.renderSurface:QueueUpdate() end
end
function M:Bind(material)
    for level,texture in ipairs(self.textures) do material:SetSurfaceTexture('refl_mip'..level,texture) end
end
function M:Dispose()
    if self.scene then self.scene:Dispose();self.scene=nil end
    for _,material in ipairs(self.materials) do material:Dispose() end;self.materials={}
    for _,texture in ipairs(self.textures) do require('render.RenderTargetLifetime').Retire(texture) end;self.textures={}
end
return M

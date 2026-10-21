-- GPU-side orientation map for render targets. Devices and runtime versions
-- disagree on which way up render targets are shown through NanoVG or sampled
-- in shaders, and WebGPU has no synchronous readback, so nothing here reads
-- pixels on the CPU and nothing assumes a platform's direction.
-- This 8x8 NanoVG canvas paints a NanoVG reference on the left (red over blue)
-- and a source's displayed left corners on the right, exactly as the UI draws
-- them. Consumer shaders (Orientation.shaderinc) sample it next frame: matching
-- columns mean the source is shown upright; a blue left column means NanoVG
-- targets sample upside down. A camera-rendered sentinel (red top half) answers
-- whether camera targets sample reversed, and is the source when no live marker
-- source is on screen. Missing or unpainted inputs always mean "do not flip".
local M={}
M.SHADER_DIR='Shaders/Orientation/'
local SIZE=8
local HALF=SIZE/2
local IDLE=1 -- stop repainting this long after the last source was used
local SENTINEL=8
---@class OrientationSource
---@field ready boolean|nil
---@field disposed boolean|nil
---@field DrawCorner fun(self:any,vg:NVGContextWrapper,x:number,y:number,size:number,bottom:boolean)
---@class OrientationSentinel : OrientationSource
---@field texture Texture2D
---@field scene Scene
---@field material Material
---@field readyFrame integer
---@field handle integer|nil
---@class OrientationMapState
---@field vg NVGContextWrapper
---@field texture Texture2D
---@field node Node
---@field receiver LuaScriptObject
---@field source OrientationSource|nil
---@field sentinel OrientationSentinel|nil
---@field lastUse number
---@field painted integer
---@type OrientationMapState|nil
local state=nil
---@type Texture2D|nil
local fallback=nil
local function Now() return Time:GetSystemTime()/1000 end
local function Frame() return time.frameNumber end
function M.Render()
    local s=state;if not s then return end
    local sentinel=s.sentinel
    if sentinel and sentinel==s.source then sentinel.ready=Frame()>=sentinel.readyFrame end
    local source=s.source
    if not source or source.disposed or not source.ready then return end
    if Now()-s.lastUse>IDLE then return end
    local vg=s.vg
    nvgBeginFrame(vg,SIZE,SIZE,1)
    nvgSave(vg);nvgGlobalCompositeOperation(vg,NVG_COPY)
    nvgBeginPath(vg);nvgRect(vg,0,0,SIZE,SIZE);nvgFillColor(vg,nvgRGBA(0,0,0,0));nvgFill(vg)
    nvgRestore(vg)
    -- Whichever row the shader samples, left and right agree only when upright.
    -- Samples sit at block centres, clear of anti-aliasing fringes.
    nvgBeginPath(vg);nvgRect(vg,0,0,HALF,HALF);nvgFillColor(vg,nvgRGBA(255,0,0,255));nvgFill(vg)
    nvgBeginPath(vg);nvgRect(vg,0,HALF,HALF,HALF);nvgFillColor(vg,nvgRGBA(0,0,255,255));nvgFill(vg)
    source:DrawCorner(vg,HALF,0,HALF,false)
    source:DrawCorner(vg,HALF,HALF,HALF,true)
    nvgEndFrame(vg)
    s.painted=Frame()
end
local function Ensure()
    if state then return state end
    local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetSRGB(false)
    assert(texture:SetSize(SIZE,SIZE,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Orientation canvas allocation failed')
    texture:SetFilterMode(FILTER_NEAREST)
    texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
    local vg=assert(nvgCreate(1),'Orientation context unavailable');nvgSetRenderTarget(vg,texture)
    local node=Node()
    local receiver=assert(node:CreateScriptObject('LuaScriptObject'),'Orientation map requires a native ScriptObject')
    state={vg=vg,texture=texture,node=node,receiver=receiver,lastUse=0,painted=-1}
    receiver:SubscribeToEvent(vg,'NanoVGRender',function()
        local ok,message=pcall(M.Render)
        if not ok then print('[OrientationMap] render error '..tostring(message)) end
    end)
    -- apiName is logged for diagnosis only; never branch on it.
    print('[OrientationMap] orientation map ready api='..tostring(graphics.apiName))
    return state
end
-- Same quad, camera and render path as a marker-carrying content target, markers only.
-- Keep these in sync with the project's content quads (v=0 on the top vertex).
local vertices={{-1,-1,0,1},{-1,1,0,0},{1,1,1,0},{-1,-1,0,1},{1,1,1,0},{1,-1,1,1}}
local function NewSentinel()
    local scene=Scene();scene:CreateComponent('Octree')
    local sentinel={scene=scene,ready=false,readyFrame=0} --[[@as OrientationSentinel]]
    local ok,err=pcall(function()
        local camera=scene:CreateChild('SentinelCamera'):CreateComponent('Camera');camera.node.position=Vector3(0,0,-2)
        camera.orthographic=true;camera.orthoSize=2;camera.autoAspectRatio=false;camera.aspectRatio=1
        local geometry=scene:CreateChild('SentinelQuad'):CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
        for _,v in ipairs(vertices) do geometry:DefineVertex(Vector3(v[1],v[2],0));geometry:DefineNormal(Vector3(0,0,-1));geometry:DefineTexCoord(Vector2(v[3],v[4])) end
        geometry:Commit()
        local material=Material:new();sentinel.material=material
        assert(material:SetSurfaceShader(M.SHADER_DIR..'OrientSentinel.shader'),'Cannot load orientation sentinel shader');geometry:SetMaterial(material)
        local xml=XMLFile:new();assert(xml:FromString('<renderpath><command type="clear" color="0 0 0 0" depth="1"/><command type="scenepass" pass="base" vertexlights="false"/><command type="scenepass" pass="alpha" vertexlights="false"/></renderpath>'))
        local path=renderer:GetDefaultRenderPath():Clone();assert(path:Load(xml));xml:Dispose()
        local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetSRGB(false);sentinel.texture=texture
        assert(texture:SetSize(SENTINEL,SENTINEL,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Orientation sentinel allocation failed')
        texture:SetFilterMode(FILTER_NEAREST);texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
        local viewport=Viewport:new(scene,camera);viewport:SetRenderPath(path)
        local surface=texture:GetRenderSurface();surface:SetViewport(0,viewport);surface.updateMode=SURFACE_MANUALUPDATE
    end)
    if not ok then scene:Dispose();if sentinel.material then sentinel.material:Dispose() end;error(err) end
    --- Paint the displayed top (or bottom) half of the target as a size x size square.
    function sentinel:DrawCorner(vg,x,y,size,bottom)
        self.handle=self.handle or nvgCreateVideo(vg,self.texture)
        nvgBeginPath(vg);nvgRect(vg,x,y,size,size)
        nvgFillPaint(vg,nvgImagePattern(vg,x,bottom and y-size or y,size,size*2,0,self.handle,1));nvgFill(vg)
    end
    return sentinel
end
--- The shared orientation map, or nil when it cannot be created (consumers then draw unflipped).
---@return Texture2D|nil
function M.Texture()
    local ok,s=pcall(Ensure)
    if not ok then print('[OrientationMap] unavailable '..tostring(s));return nil end
    return s.texture
end
--- Mark the live marker source currently on screen; its corners feed the map.
--- Call every frame the source is visible (path A).
---@param source OrientationSource
function M.Use(source)
    local s=state;if not s then return end
    s.source=source;s.lastUse=Now()
end
--- Keep the map fresh without a live source on screen. Returns the sentinel target
--- (bind it as orient_sentinel), or nil when the map or sentinel is unavailable.
---@return Texture2D|nil
function M.Request()
    if not M.Texture() then return nil end
    local s=assert(state)
    if not s.sentinel then
        local ok,sentinel=pcall(NewSentinel)
        if not ok then print('[OrientationMap] sentinel unavailable '..tostring(sentinel));return nil end
        s.sentinel=sentinel
    end
    local sentinel=assert(s.sentinel)
    -- Re-render the 8x8 target on every request; it is ready once a full frame has drawn it.
    sentinel.texture:GetRenderSurface():QueueUpdate()
    if sentinel.readyFrame==0 then sentinel.readyFrame=Frame()+2 end
    s.source=sentinel;s.lastUse=Now()
    return sentinel.texture
end
--- True once the map has been repainted after the given frame.
---@param frame integer
---@return boolean
function M.PaintedAfter(frame)
    return state~=nil and state.painted>frame
end
--- 1x1 transparent texture; bound wherever an input is missing so shaders never flip.
---@return Texture2D
function M.Fallback()
    if fallback then return fallback end
    local image=Image:new();image:SetSize(1,1,4);image:SetPixel(0,0,Color(0,0,0,0))
    local texture=Texture2D:new();texture:SetNumLevels(1);assert(texture:SetData(image),'Orientation fallback texture failed');image:Dispose()
    fallback=texture;return texture
end
--- Bind the map (and optionally the sentinel) to a material that includes
--- Orientation.shaderinc. Returns true when every requested input is real.
--- Consumers without a live marker source must keep calling M.Request() until
--- M.PaintedAfter(startFrame) (see M.Settle).
---@param material Material
---@param needSentinel boolean|nil
---@return boolean
function M.Bind(material,needSentinel)
    local map=M.Texture()
    local sentinel=(map and needSentinel) and M.Request() or nil
    material:SetSurfaceTexture('orient_map',map or M.Fallback())
    material:SetSurfaceTexture('orient_sentinel',sentinel or M.Fallback())
    material:SetShaderParameter('orient_enabled',Variant(map and 1.0 or 0.0))
    return map~=nil and (sentinel~=nil or not needSentinel)
end
--- Per-frame helper for consumers without a live source: keeps requesting the
--- sentinel until the map is painted after startFrame. Returns true while waiting.
---@param startFrame integer
---@param timeout integer|nil frames before giving up (map stays unpainted -> no flip)
---@return boolean
function M.Settle(startFrame,timeout)
    if M.PaintedAfter(startFrame) then return false end
    if Frame()-startFrame>(timeout or 60) then return false end
    M.Request();return true
end
return M

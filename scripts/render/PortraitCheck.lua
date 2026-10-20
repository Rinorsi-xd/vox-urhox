-- GPU-side orientation map for render targets shown through NanoVG. Devices
-- disagree on which way up these targets are shown (desktop and phone WebGPU,
-- two WebGL phones...), and WebGPU has no synchronous readback, so nothing here
-- reads pixels on the CPU.
-- Each source writes raw corner markers into its own target (red top-left, blue
-- bottom-left). This 8x8 NanoVG canvas paints a NanoVG reference on the left and
-- the source's displayed left corners on the right, exactly as the UI draws
-- them. CommsPortrait.shader and OrientedCopy.shader sample one row of it next
-- frame: matching colours mean the target is shown upright, otherwise they flip.
-- Sources: the comms portrait on screen, or a tiny sentinel target when only
-- scene snapshots need the answer (render.OrientedCopy).
local M={}
local SIZE=8
local HALF=SIZE/2
local IDLE=1 -- stop repainting this long after the last source was used
local SENTINEL=8
---@class PortraitCheckSource
---@field ready boolean|nil
---@field disposed boolean|nil
---@field DrawCorner fun(self:any,vg:NVGContextWrapper,x:number,y:number,size:number,bottom:boolean)
---@class PortraitCheckSentinel : PortraitCheckSource
---@field texture Texture2D
---@field scene Scene
---@field material Material
---@field readyFrame integer
---@field handle integer|nil
---@class PortraitCheckState
---@field vg NVGContextWrapper
---@field texture Texture2D
---@field node Node
---@field receiver LuaScriptObject
---@field source PortraitCheckSource|nil
---@field sentinel PortraitCheckSentinel|nil
---@field lastUse number
---@field painted integer
---@type PortraitCheckState|nil
local state=nil
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
    assert(texture:SetSize(SIZE,SIZE,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Portrait orientation canvas allocation failed')
    texture:SetFilterMode(FILTER_NEAREST)
    texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
    local vg=assert(nvgCreate(1),'Portrait orientation context unavailable');nvgSetRenderTarget(vg,texture)
    local node=Node()
    local receiver=assert(node:CreateScriptObject('LuaScriptObject'),'Portrait orientation requires a native ScriptObject')
    state={vg=vg,texture=texture,node=node,receiver=receiver,lastUse=0,painted=-1}
    receiver:SubscribeToEvent(vg,'NanoVGRender',function()
        local ok,message=pcall(M.Render)
        if not ok then print('[PortraitCheck] render error '..tostring(message)) end
    end)
    print('[PortraitCheck] orientation map ready api='..tostring(graphics.apiName))
    return state
end
-- Same quad, camera and render path as a CommsPortrait target, markers only.
local vertices={{-1,-1,0,1},{-1,1,0,0},{1,1,1,0},{-1,-1,0,1},{1,1,1,0},{1,-1,1,1}}
local function NewSentinel()
    local scene=Scene();scene:CreateComponent('Octree')
    local sentinel={scene=scene,ready=false,readyFrame=0} --[[@as PortraitCheckSentinel]]
    local ok,err=pcall(function()
        local camera=scene:CreateChild('SentinelCamera'):CreateComponent('Camera');camera.node.position=Vector3(0,0,-2)
        camera.orthographic=true;camera.orthoSize=2;camera.autoAspectRatio=false;camera.aspectRatio=1
        local geometry=scene:CreateChild('SentinelQuad'):CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
        for _,v in ipairs(vertices) do geometry:DefineVertex(Vector3(v[1],v[2],0));geometry:DefineNormal(Vector3(0,0,-1));geometry:DefineTexCoord(Vector2(v[3],v[4])) end
        geometry:Commit()
        local material=Material:new();sentinel.material=material
        assert(material:SetSurfaceShader('Shaders/BLGL/UI/OrientSentinel.shader'),'Cannot load orientation sentinel shader');geometry:SetMaterial(material)
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
    if not ok then print('[PortraitCheck] unavailable '..tostring(s));return nil end
    return s.texture
end
--- Mark the portrait (or other marker source) currently on screen; its corners feed the map.
---@param portrait PortraitCheckSource
function M.Use(portrait)
    local s=state;if not s then return end
    s.source=portrait;s.lastUse=Now()
end
--- Keep the map fresh without a portrait on screen. Returns the sentinel target
--- (for OrientedCopy.shader), or nil when the map or sentinel is unavailable.
---@return Texture2D|nil
function M.Request()
    if not M.Texture() then return nil end
    local s=assert(state)
    if not s.sentinel then
        local ok,sentinel=pcall(NewSentinel)
        if not ok then print('[PortraitCheck] sentinel unavailable '..tostring(sentinel));return nil end
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
return M

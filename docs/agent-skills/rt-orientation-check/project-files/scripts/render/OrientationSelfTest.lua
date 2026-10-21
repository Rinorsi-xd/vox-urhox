-- 一屏方向自检：每次新增 RT 显示路径、每次 runtime 升级后，在所有目标平台跑一次。
-- 合格标准：所有 FIXED 格都是「红上蓝下、绿点在左上」。RAW 格展示本设备当前的怪癖，仅供记录。
--   第 1 行  B  相机 RT 被 shader 采样                    RAW | FIXED（哨兵 sampled）
--   第 2 行  C  NanoVG RT 被 shader 采样                  RAW | FIXED（方向图左列 nvgSampled）
--   第 3 行  D  相机 RT 快照 → OrientedCopy → NanoVG     RAW | FIXED（sampled XOR shown）
--   第 4 行  A  相机 RT → 内容 shader 按 shown 翻 → NanoVG RAW | FIXED（内容 shader 内翻）
-- 用法：require('render.OrientationSelfTest').Start()；结束调用 .Stop()。会接管 viewport 0。
local OrientationMap=require 'render.OrientationMap'
local OrientedCopy=require 'render.OrientedCopy'
local M={}
local SRC=128
local TILE=2.0
local COLUMNS={-1.5,1.5}
local ROWS={4.4,1.5,-1.5,-4.4}
local vertices={{-1,-1,0,1},{-1,1,0,0},{1,1,1,0},{-1,-1,0,1},{1,1,1,0},{1,-1,1,1}}
---@class OrientationSelfTestState
---@field scene Scene
---@field camera Camera
---@field source Scene
---@field camTexture Texture2D
---@field nvgTexture Texture2D
---@field srcVg NVGContextWrapper
---@field vg NVGContextWrapper
---@field materials Material[]
---@field copy OrientedCopy|nil
---@field copied Texture2D|nil
---@field frames integer
---@field images table<string,integer>
---@field node Node
---@field receiver LuaScriptObject
---@field previous Viewport|nil
---@field aRaw Texture2D
---@field aFixed Texture2D
---@field aScenes Scene[]
---@type OrientationSelfTestState|nil
local state=nil
local function Quad(scene,name,x,y,size,material)
    local geometry=scene:CreateChild(name):CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
    for _,v in ipairs(vertices) do geometry:DefineVertex(Vector3(x+v[1]*size/2,y+v[2]*size/2,0));geometry:DefineNormal(Vector3(0,0,-1));geometry:DefineTexCoord(Vector2(v[3],v[4])) end
    geometry:Commit();geometry:SetMaterial(material)
end
local function Target()
    local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetSRGB(false)
    assert(texture:SetSize(SRC,SRC,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Self-test target allocation failed')
    texture:SetFilterMode(FILTER_NEAREST);texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
    return texture
end
-- Camera-rendered source: OrientPattern on the same v=0-top quad as the sentinel.
local function NewSourceScene(texture)
    local scene=Scene();scene:CreateComponent('Octree')
    local camera=scene:CreateChild('SourceCamera'):CreateComponent('Camera');camera.node.position=Vector3(0,0,-2)
    camera.orthographic=true;camera.orthoSize=2;camera.autoAspectRatio=false;camera.aspectRatio=1
    local material=Material:new();assert(material:SetSurfaceShader(OrientationMap.SHADER_DIR..'OrientPattern.shader'),'Cannot load OrientPattern.shader')
    Quad(scene,'SourceQuad',0,0,2,material)
    local surface=texture:GetRenderSurface();surface:SetViewport(0,Viewport:new(scene,camera));surface.updateMode=SURFACE_UPDATEALWAYS
    return scene
end
-- NanoVG-rendered source: the same pattern painted by NanoVG.
local function PaintPattern(vg)
    nvgBeginFrame(vg,SRC,SRC,1)
    nvgBeginPath(vg);nvgRect(vg,0,0,SRC,SRC/2);nvgFillColor(vg,nvgRGBA(255,0,0,255));nvgFill(vg)
    nvgBeginPath(vg);nvgRect(vg,0,SRC/2,SRC,SRC/2);nvgFillColor(vg,nvgRGBA(0,0,255,255));nvgFill(vg)
    nvgBeginPath(vg);nvgRect(vg,0,0,SRC/4,SRC/4);nvgFillColor(vg,nvgRGBA(0,255,0,255));nvgFill(vg)
    nvgEndFrame(vg)
end
-- Path A: a content shader renders into a camera RT (flip chosen inside the
-- shader), and the RT is then shown through nvgCreateVideo like real content.
local function NewContentTarget(texture,view,mode)
    local scene=Scene();scene:CreateComponent('Octree')
    local camera=scene:CreateChild('ContentCamera'):CreateComponent('Camera');camera.node.position=Vector3(0,0,-2)
    camera.orthographic=true;camera.orthoSize=2;camera.autoAspectRatio=false;camera.aspectRatio=1
    local material=Material:new();assert(material:SetSurfaceShader(OrientationMap.SHADER_DIR..'OrientView.shader'),'Cannot load OrientView.shader')
    assert(material:SetSurfaceTexture('view_map',view))
    material:SetShaderParameter('mode',Variant(mode+0.0))
    OrientationMap.Bind(material,false)
    Quad(scene,'ContentQuad',0,0,2,material)
    local surface=texture:GetRenderSurface();surface:SetViewport(0,Viewport:new(scene,camera));surface.updateMode=SURFACE_UPDATEALWAYS
    return scene,material
end
local function View(s,name,x,y,texture,mode)
    local material=Material:new();assert(material:SetSurfaceShader(OrientationMap.SHADER_DIR..'OrientView.shader'),'Cannot load OrientView.shader')
    assert(material:SetSurfaceTexture('view_map',texture))
    material:SetShaderParameter('mode',Variant(mode+0.0))
    local real=OrientationMap.Bind(material,mode==1)
    print(string.format('[OrientationSelfTest] %s mode=%d inputs=%s',name,mode,tostring(real)))
    s.materials[#s.materials+1]=material
    Quad(s.scene,name,x,y,TILE,material)
end
local function Layout(s)
    local w,h=graphics:GetWidth(),graphics:GetHeight()
    local aspect=w/math.max(1,h)
    local ortho=math.max(10,6.6/aspect)
    s.camera.orthoSize=ortho
    local dpr=graphics:GetDPR();local lw,lh=w/dpr,h/dpr
    local k=lh/ortho -- logical px per world unit
    return lw,lh,dpr,k
end
local function Tile(vg,image,cx,cy,size)
    if not image or image==0 then return end
    nvgBeginPath(vg);nvgRect(vg,cx-size/2,cy-size/2,size,size)
    nvgFillPaint(vg,nvgImagePattern(vg,cx-size/2,cy-size/2,size,size,0,image,1));nvgFill(vg)
end
local function Label(vg,text,x,y,size)
    nvgFontFace(vg,'orient-sans');nvgFontSize(vg,size);nvgTextAlign(vg,NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    nvgFillColor(vg,nvgRGBA(255,255,255,235));nvgText(vg,x,y,text)
end
local function Overlay()
    local s=state;if not s then return end
    local vg=s.vg
    local lw,lh,dpr,k=Layout(s)
    nvgBeginFrame(vg,lw,lh,dpr)
    local function X(wx) return lw/2+wx*k end
    local function Y(wy) return lh/2-wy*k end
    local size=TILE*k
    s.images.raw=s.images.raw or nvgCreateVideo(vg,s.camTexture)
    if s.copied and not s.images.fixed then s.images.fixed=nvgCreateVideo(vg,s.copied) end
    s.images.aRaw=s.images.aRaw or nvgCreateVideo(vg,s.aRaw)
    s.images.aFixed=s.images.aFixed or nvgCreateVideo(vg,s.aFixed)
    Tile(vg,s.images.raw,X(COLUMNS[1]),Y(ROWS[3]),size)
    Tile(vg,s.images.fixed,X(COLUMNS[2]),Y(ROWS[3]),size)
    Tile(vg,s.images.aRaw,X(COLUMNS[1]),Y(ROWS[4]),size)
    Tile(vg,s.images.aFixed,X(COLUMNS[2]),Y(ROWS[4]),size)
    local font=math.max(11,size*.09)
    local names={'B 相机RT→shader采样','C NanoVG RT→shader采样','D 相机RT快照→OrientedCopy→NanoVG','A 相机RT→内容shader按shown翻→NanoVG'}
    for i,row in ipairs(ROWS) do
        Label(vg,names[i]..'  RAW',X(COLUMNS[1]),Y(row)+size/2+font,font)
        Label(vg,names[i]..'  FIXED',X(COLUMNS[2]),Y(row)+size/2+font,font)
    end
    if not s.copied then Label(vg,'等待方向图…',X(COLUMNS[2]),Y(ROWS[3]),font) end
    Label(vg,'合格：所有 FIXED 格「红上蓝下、绿点左上」  api='..tostring(graphics.apiName),lw/2,font*1.4,font*1.1)
    nvgEndFrame(vg)
end
local function Update()
    local s=state;if not s then return end
    s.frames=s.frames+1
    -- The test is live: keep the map painted every frame.
    OrientationMap.Request()
    if s.frames==3 then s.copy=OrientedCopy.New(s.camTexture) end
    if s.copy then
        local shown=s.copy:Step()
        if shown then
            s.copied=shown;s.copy=nil
            print('[OrientationSelfTest] copy ready '..(shown==s.camTexture and '(fallback: unflipped source)' or '(oriented)'))
        end
    end
end
function M.Start()
    if state then return end
    local scene=Scene();scene:CreateComponent('Octree')
    local camera=scene:CreateChild('Camera'):CreateComponent('Camera');camera.node.position=Vector3(0,0,-10)
    camera.orthographic=true
    local s={scene=scene,camera=camera,materials={},frames=0,images={}} --[[@as OrientationSelfTestState]]
    state=s
    s.camTexture=Target();s.source=NewSourceScene(s.camTexture)
    s.nvgTexture=Target()
    s.srcVg=assert(nvgCreate(1),'Self-test NanoVG source unavailable');nvgSetRenderTarget(s.srcVg,s.nvgTexture)
    -- Own receiver so Stop() never unsubscribes the host's handlers.
    s.node=Node();s.receiver=assert(s.node:CreateScriptObject('LuaScriptObject'),'Self-test requires a native ScriptObject')
    s.receiver:SubscribeToEvent(s.srcVg,'NanoVGRender',function() PaintPattern(s.srcVg) end)
    View(s,'B-raw',COLUMNS[1],ROWS[1],s.camTexture,0)
    View(s,'B-fixed',COLUMNS[2],ROWS[1],s.camTexture,1)
    View(s,'C-raw',COLUMNS[1],ROWS[2],s.nvgTexture,0)
    View(s,'C-fixed',COLUMNS[2],ROWS[2],s.nvgTexture,2)
    s.aRaw=Target();s.aFixed=Target();s.aScenes={}
    local aRawScene,aRawMaterial=NewContentTarget(s.aRaw,s.camTexture,0)
    local aFixedScene,aFixedMaterial=NewContentTarget(s.aFixed,s.camTexture,3)
    s.aScenes[1]=aRawScene;s.aScenes[2]=aFixedScene
    s.materials[#s.materials+1]=aRawMaterial;s.materials[#s.materials+1]=aFixedMaterial
    s.previous=renderer:GetViewport(0);renderer:SetViewport(0,Viewport:new(scene,camera))
    s.vg=assert(nvgCreate(1),'Self-test overlay unavailable')
    assert(nvgCreateFont(s.vg,'orient-sans','Fonts/MiSans-Regular.ttf')>=0,'Self-test font unavailable')
    s.receiver:SubscribeToEvent(s.vg,'NanoVGRender',Overlay)
    s.receiver:SubscribeToEvent('Update',Update)
    print('[OrientationSelfTest] started api='..tostring(graphics.apiName))
end
function M.Stop()
    local s=state;if not s then return end;state=nil
    s.receiver:UnsubscribeFromEvent('Update')
    s.receiver:UnsubscribeFromEvent(s.vg,'NanoVGRender');s.receiver:UnsubscribeFromEvent(s.srcVg,'NanoVGRender')
    for _,image in pairs(s.images) do if image~=0 then nvgDeleteVideo(s.vg,image) end end
    nvgDelete(s.vg);nvgDelete(s.srcVg)
    if s.copy then s.copy:Dispose() end
    if s.copied and s.copied~=s.camTexture then OrientedCopy.Retire(s.copied) end
    if s.previous then renderer:SetViewport(0,s.previous) end
    -- Materials and geometry reference the targets; release them first.
    s.node:Dispose();s.scene:Dispose();s.source:Dispose()
    for _,aScene in ipairs(s.aScenes) do aScene:Dispose() end
    for _,material in ipairs(s.materials) do material:Dispose() end
    OrientedCopy.Retire(s.camTexture);OrientedCopy.Retire(s.nvgTexture)
    OrientedCopy.Retire(s.aRaw);OrientedCopy.Retire(s.aFixed)
end
return M

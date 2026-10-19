-- 在设备上测量通讯头像的显示方向。独立 NanoVG 通道位于主 UI、
-- 加载页及虚拟控件之上；读屏失败时延迟重试，不再永久放弃。
local CommsPortrait=require 'ui.CommsPortrait'
local UI=require 'urhox-libs/UI'
local M={}
local SIZE=24
local RENDER_ORDER=1000000 -- 主 UI 为 999990，虚拟控件为 999999。
local REQUIRED_FRAMES=3
-- 四象限依次为左上红、右上绿、左下蓝、右下白。
---@type number[][]
local QUADRANTS={{1,0,0},{0,1,0},{0,0,1},{1,1,1}}
---@class PortraitOrientationState
---@field phase string
---@field attempts integer
---@field frames integer
---@field delay number
---@field drawn boolean
---@field scale number
---@field width integer
---@field height integer
---@field renderError string|nil
---@field vg NVGContextWrapper|nil
---@field receiver LuaScriptObject|nil
---@field portrait CommsPortrait|nil
---@field texture Texture2D|nil
---@field node Node|nil
---@field rect table
---@field reference table
local state={phase='idle',attempts=0,frames=0,delay=0,drawn=false,scale=1,width=0,height=0,
    rect={x=0,y=0,w=SIZE,h=SIZE},reference={x=SIZE+2,y=0,w=SIZE,h=SIZE}}
local function SourceTexture()
    local n=16;local image=Image:new();assert(image:SetSize(n,n,4))
    local color=Color()
    for y=0,n-1 do for x=0,n-1 do
        local index=(y<n/2 and 0 or 2)+(x<n/2 and 1 or 2)
        local q=assert(QUADRANTS[index])
        color.r,color.g,color.b,color.a=q[1],q[2],q[3],1;image:SetPixel(x,y,color)
    end end
    local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetSRGB(false)
    texture:SetFilterMode(FILTER_NEAREST);assert(texture:SetData(image));image:Dispose()
    return texture
end
local function Classify(c)
    local hi=math.max(c.r,c.g,c.b);if hi<.2 then return nil end
    local lo=math.min(c.r,c.g,c.b)
    if lo>hi*.6 then return 4 end
    if c.r==hi and c.g<hi*.6 and c.b<hi*.6 then return 1 end
    if c.g==hi and c.r<hi*.6 and c.b<hi*.6 then return 2 end
    if c.b==hi and c.r<hi*.6 and c.g<hi*.6 then return 3 end
    return nil
end
local function ReleaseProbe()
    -- 先删除图片句柄，再删除它们所属的 NanoVG context。
    if state.portrait then state.portrait:Dispose();state.portrait=nil end
    if state.texture then state.texture:Dispose();state.texture=nil end
end
local function Dispose()
    if state.receiver then state.receiver:UnsubscribeFromAllEvents();state.receiver=nil end
    ReleaseProbe()
    if state.vg then nvgDelete(state.vg);state.vg=nil end
    if state.node then state.node:Dispose();state.node=nil end
    state.drawn=false;state.renderError=nil
end
local function Finish(phase,fx,fy)
    if fx then CommsPortrait.flipX,CommsPortrait.flipY=fx,fy end
    print(('[PortraitOrientation] %s api=%s flipX=%d flipY=%d attempts=%d'):format(phase,tostring(graphics.apiName),CommsPortrait.flipX,CommsPortrait.flipY,state.attempts))
    state.phase=phase;Dispose()
end
local function Retry(reason)
    state.attempts=state.attempts+1
    -- 失败不再永久退出；退避期间隐藏色块，也不读屏或更新渲染目标。
    state.delay=math.min(8,2^math.min(state.attempts-1,3))
    state.phase='retry';state.frames=0;state.drawn=false;state.renderError=nil
    print(('[PortraitOrientation] retry reason=%s api=%s attempt=%d delay=%.1fs'):format(reason,tostring(graphics.apiName),state.attempts,state.delay))
end
local function Measure(image,r)
    local w,h=image:GetWidth(),image:GetHeight()
    if w~=state.width or h~=state.height then return nil end
    local seen={}
    for i,p in ipairs({{.25,.25},{.75,.25},{.25,.75},{.75,.75}}) do
        local x=math.floor((r.x+r.w*p[1])*state.scale);local y=math.floor((r.y+r.h*p[2])*state.scale)
        if x<0 or y<0 or x>=w or y>=h then return nil end
        seen[i]=Classify(image:GetPixel(x,y));if not seen[i] then return nil end
    end
    return seen
end
local function Decide(seen)
    local key=table.concat(seen,'')
    local flips={['1234']={1,1},['2143']={-1,1},['3412']={1,-1},['4321']={-1,-1}}
    return flips[key],key
end
function M.Render()
    local vg,portrait=state.vg,state.portrait
    if state.phase~='wait' or not vg or not portrait or not portrait.ready or state.renderError then return end
    local w,h=graphics:GetWidth(),graphics:GetHeight();local scale=UI.GetScale()
    if w<=0 or h<=0 or scale<=0 then return end
    if w~=state.width or h~=state.height or scale~=state.scale then state.frames=0 end
    -- 模式 B：与 UI.Render 使用相同的逻辑像素及 DPR。
    -- 采样使用本次绘制的比例，避免读屏时 UI 缩放已发生变化。
    state.width,state.height,state.scale=w,h,scale
    local fx,fy=CommsPortrait.flipX,CommsPortrait.flipY
    CommsPortrait.flipX,CommsPortrait.flipY=1,1
    local ok,message=pcall(function()
        nvgBeginFrame(vg,w/scale,h/scale,scale)
        portrait:Draw(vg,state.rect)
        local r=state.reference;local hw,hh=r.w/2,r.h/2
        for i,q in ipairs(QUADRANTS) do
            nvgBeginPath(vg);nvgRect(vg,r.x+((i-1)%2)*hw,r.y+(i>2 and hh or 0),hw,hh)
            nvgFillColor(vg,nvgRGBA(q[1]*255,q[2]*255,q[3]*255,255));nvgFill(vg)
        end
        nvgEndFrame(vg)
    end)
    CommsPortrait.flipX,CommsPortrait.flipY=fx,fy
    if not ok then
        nvgCancelFrame(vg);state.renderError=tostring(message);return
    end
    state.drawn=true
end
local function Readback()
    local image=Image:new()
    local ok,seen,reference=pcall(function()
        if not graphics:TakeScreenShot(image) then return nil,nil end
        return Measure(image,state.rect),Measure(image,state.reference)
    end)
    image:Dispose()
    if not ok then return nil,nil,'readback-error '..tostring(seen) end
    return seen,reference
end
local function Prepare()
    if not state.vg then state.vg=assert(nvgCreate(1),'Orientation probe context unavailable') end
    local vg=assert(state.vg);local receiver=assert(state.receiver)
    -- 初始化中途失败后，重试也必须重新设置层级与订阅。
    nvgSetRenderOrder(vg,RENDER_ORDER)
    receiver:SubscribeToEvent(vg,'NanoVGRender',function() M.Render() end)
    if not state.texture then state.texture=SourceTexture() end
    if not state.portrait then
        local portrait=CommsPortrait.New('nono',SIZE,SIZE);state.portrait=portrait
        for _,material in ipairs(portrait.materials) do
            material:SetShaderParameter('holo_tint',Variant(Vector3(0,0,0)))
            material:SetShaderParameter('probe',Variant(1.0))
        end
    end
    local texture=assert(state.texture);local portrait=assert(state.portrait)
    assert(portrait:PrepareTextures(0,'probe',false,texture,texture),'Orientation probe texture unavailable')
    portrait:Queue();state.frames=0;state.drawn=false;state.phase='wait'
end
local function Step()
    if state.phase=='retry' then return end
    if state.renderError then
        local message=state.renderError;ReleaseProbe();Retry('render-error '..message);return
    end
    if state.phase=='draw' then Prepare();return end
    local portrait=state.portrait
    if state.phase~='wait' or not portrait then return end
    -- 仅经过 EndFrame 不能证明探针实际画出过。
    if not state.drawn then state.frames=0;return end
    state.drawn=false;state.frames=state.frames+1
    if state.frames<REQUIRED_FRAMES then portrait.requested=true;portrait:Queue();return end
    local seen,reference,message=Readback()
    if message then Retry(message);return end
    local flip,key,base,baseKey=nil,nil,nil,nil
    if seen then flip,key=Decide(seen) end
    if reference then base,baseKey=Decide(reference) end
    if flip and base then
        Finish('measured '..key..' ref '..baseKey,flip[1]*base[1],flip[2]*base[2]);return
    end
    Retry('inconclusive '..tostring(key)..' ref '..tostring(baseKey))
end
--- 保留成功校准结果；失败时持续重试，直到 Stop()。
function M.Start()
    if state.node or state.phase:match('^measured') then return end
    state.phase='draw';state.attempts=0;state.frames=0;state.drawn=false;state.delay=0
    local ok,err=pcall(function()
        state.node=Node()
        local receiver=assert(state.node:CreateScriptObject('LuaScriptObject'),'Orientation probe requires a native ScriptObject')
        state.receiver=receiver
        receiver:SubscribeToEvent('Update',function(_,_,eventData)
            if state.phase~='retry' then return end
            state.delay=math.max(0,state.delay-eventData:GetFloat('TimeStep'))
            if state.delay==0 then state.phase='draw' end
        end)
        receiver:SubscribeToEvent('EndFrame',function()
            local stepped,message=pcall(Step)
            if not stepped then ReleaseProbe();Retry('error '..tostring(message)) end
        end)
        print(('[PortraitOrientation] started api=%s order=%d'):format(tostring(graphics.apiName),RENDER_ORDER))
    end)
    if not ok then print('[PortraitOrientation] start failed '..tostring(err));Finish('error') end
end
function M.Stop() if state.node then Finish('stopped') end end
function M.Phase() return state.phase end
return M

-- 在设备上测量通讯头像的显示方向。独立 NanoVG 通道位于主 UI、
-- 加载页及虚拟控件之上；成功即收起，不支持读屏时跳过，暂时失败只有限重试。
local CommsPortrait=require 'ui.CommsPortrait'
local TextureFlip=require 'render.TextureFlip'
local ReadbackSupport=require 'render.Readback'
local OrientationScan=require 'render.OrientationScan'
local UI=require 'urhox-libs/UI'
local M={}
-- 探针块足够大，才能在不知道屏幕坐标映射的前提下靠全屏扫描找到它。
local SIZE=64
local RENDER_ORDER=1000000 -- 主 UI 为 999990，虚拟控件为 999999。
local REQUIRED_FRAMES=3
local MAX_ATTEMPTS=5
local MEASURE_TIMEOUT=30
-- 显式 Start({diagnostics=true}) 时保留结果面板，方便真机截图取证。
-- 正常启动只短暂绘制测量色块，不显示调试面板。
local PANEL_FONT='Fonts/VoxIndustrial-Bold.otf'
local PANEL_HOLD=45
-- 诊断面板的显示上限；测量超时另由 MEASURE_TIMEOUT 限制。
local PANEL_DEADLINE=120
-- 参照块（纯 NanoVG 绘制，一定正确）：左上红、右上绿、左下蓝、右下白。
---@type number[][]
local REFERENCE_QUADRANTS={{1,0,0},{0,1,0},{0,0,1},{1,1,1}}
-- 立绘探针走真实 RT 管线，用一组游戏 UI 里罕见的颜色，便于和参照块区分。
-- 左上品红、右上黄、左下青、右下紫。
---@type number[][]
local PROBE_QUADRANTS={{1,0,1},{1,1,0},{0,1,1},{.6,0,1}}
local QUADRANTS=REFERENCE_QUADRANTS
---@class PortraitProbeDiag
---@field shot boolean|nil
---@field shotw integer|nil
---@field shoth integer|nil
---@field shotError string|nil
---@field probeColors number[][]|nil
---@field referenceColors number[][]|nil
---@field rtsize integer[]|nil
---@field result string|nil
---@field scan table|nil
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
---@field scenePortrait CommsPortrait|nil
---@field texture Texture2D|nil
---@field node Node|nil
---@field rect table
---@field reference table
---@field diag PortraitProbeDiag
---@field panel boolean
---@field panelUntil number|nil
---@field panelDeadline number|nil
---@field panelVg NVGContextWrapper|nil
---@field diagnostics boolean
---@field elapsed number
---@field candidate number[]|nil
---@field confirmations integer
local state={phase='idle',attempts=0,frames=0,delay=0,drawn=false,scale=1,width=0,height=0,
    rect={x=4,y=4,w=SIZE,h=SIZE},reference={x=SIZE+8,y=4,w=SIZE,h=SIZE},
    diag={},panel=false,diagnostics=false,elapsed=0,confirmations=0}
local function IsTerminal()
    return state.phase:match('^measured')~=nil or state.phase=='unsupported' or state.phase=='failed'
end
local function Now() return Time:GetSystemTime()/1000 end
local function PanelVisible()
    if not state.panel then return false end
    -- 从第一次真正能显示开始计时，避开加载阶段把窗口耗光。
    if not state.panelDeadline then state.panelDeadline=Now()+PANEL_DEADLINE end
    local limit=math.min(state.panelUntil or math.huge,state.panelDeadline or math.huge)
    if Now()>=limit then state.panel=false;state.panelUntil=nil;return false end
    return true
end
local function SourceTexture()
    local n=16;local image=Image:new();assert(image:SetSize(n,n,4))
    local color=Color()
    for y=0,n-1 do for x=0,n-1 do
        local index=(y<n/2 and 0 or 2)+(x<n/2 and 1 or 2)
        local q=assert(PROBE_QUADRANTS[index])
        color.r,color.g,color.b,color.a=q[1],q[2],q[3],1;image:SetPixel(x,y,color)
    end end
    local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetSRGB(false)
    texture:SetFilterMode(FILTER_NEAREST);assert(texture:SetData(image));image:Dispose()
    return texture
end
local function ReleaseProbe()
    -- 先删除图片句柄，再删除它们所属的 NanoVG context。
    if state.scenePortrait then state.scenePortrait:Dispose();state.scenePortrait=nil end
    if state.portrait then state.portrait:Dispose();state.portrait=nil end
    if state.texture then state.texture:Dispose();state.texture=nil end
end
local function Dispose()
    if state.receiver then state.receiver:UnsubscribeFromAllEvents();state.receiver=nil end
    ReleaseProbe()
    if state.vg then nvgDelete(state.vg);state.vg=nil end
    if state.node then state.node:Dispose();state.node=nil end
    state.drawn=false;state.renderError=nil;state.panel=false;state.panelVg=nil
end
-- 诊断面板：期望顺序与截图上实读到的颜色并排画出来，差异一眼可见。
local function Swatch(vg,x,y,s,p)
    if p then nvgFillColor(vg,nvgRGBA(p[1]*255,p[2]*255,p[3]*255,255))
    else nvgFillColor(vg,nvgRGBA(70,78,86,255)) end
    nvgBeginPath(vg);nvgRect(vg,x,y,s,s);nvgFill(vg)
    nvgStrokeColor(vg,nvgRGBA(0,0,0,190));nvgStrokeWidth(vg,1);nvgStroke(vg)
end
local function DrawPanel(vg)
    if state.panelVg~=vg then state.panelVg=vg;nvgCreateFont(vg,'probe',PANEL_FONT) end
    local d=state.diag
    local pad,line=6,12
    local top=SIZE+8 -- 探针色块占 0..SIZE，面板从它下方开始，两者都要可读
    local logicalW=state.width/math.max(state.scale,.001)
    local w=math.min(logicalW-pad*2,420)
    local h=pad*2+line*8
    nvgSave(vg)
    nvgBeginPath(vg);nvgRoundedRect(vg,pad,top,w,h,5);nvgFillColor(vg,nvgRGBA(0,0,0,196));nvgFill(vg)
    nvgFontFace(vg,'probe');nvgFontSize(vg,9.5);nvgTextAlign(vg,NVG_ALIGN_LEFT|NVG_ALIGN_TOP)
    local head=nvgRGBA(110,214,255,255);local body=nvgRGBA(214,228,238,255);local dim=nvgRGBA(140,158,172,255)
    local x,y=pad+7,top+5
    nvgFillColor(vg,head)
    nvgText(vg,x,y,('PORTRAIT PROBE  api=%s  phase=%s'):format(tostring(graphics.apiName),state.phase));y=y+line
    nvgFillColor(vg,body)
    nvgText(vg,x,y,('dpr=%.2f screen=%dx%d ui=%.3f rt=%dx%d'):format(graphics:GetDPR(),state.width,state.height,
        state.scale,d.rtsize and d.rtsize[1] or 0,d.rtsize and d.rtsize[2] or 0));y=y+line
    local shot=d.shot and ('shot=OK %dx%d'):format(d.shotw or 0,d.shoth or 0) or ('shot=FAIL %s'):format(d.shotError or '')
    nvgText(vg,x,y,('%s  frames=%d attempts=%d'):format(shot,state.frames,state.attempts));y=y+line
    local function Row(label,pts)
        nvgFillColor(vg,dim);nvgText(vg,x,y,label)
        for i=1,4 do Swatch(vg,x+58+(i-1)*16,y-1,13,pts and pts[i]) end
        y=y+line
    end
    Row('want',QUADRANTS)
    Row('probe',d.probeColors)
    Row('ref',d.referenceColors)
    local scan=d.scan
    local refOrder=scan and scan.refOrder and table.concat(scan.refOrder) or 'nil'
    local probeOrder=scan and scan.probeOrder and table.concat(scan.probeOrder) or 'nil'
    nvgFillColor(vg,body)
    nvgText(vg,x,y,('scan ref %d/%s   probe %d/%s'):format(
        scan and scan.refCount or 0,refOrder,scan and scan.probeCount or 0,probeOrder));y=y+line
    nvgFillColor(vg,d.result and head or dim)
    nvgText(vg,x,y,d.result or 'measuring...')
    nvgRestore(vg)
end
local function Finish(phase,fx,fy,scene,hold)
    if fx then CommsPortrait.flipX,CommsPortrait.flipY=fx,fy end
    if scene then TextureFlip.scene={x=scene[1],y=scene[2],source=scene[3]} end
    local s=TextureFlip.scene
    print(('[PortraitOrientation] %s api=%s %s flipX=%d flipY=%d sceneX=%d sceneY=%d scene=%s attempts=%d'):format(phase,tostring(graphics.apiName),
        ('shot=%s %dx%d'):format(state.diag.shot and 'ok' or 'fail',state.diag.shotw or 0,state.diag.shoth or 0),
        CommsPortrait.flipX,CommsPortrait.flipY,s.x,s.y,s.source,state.attempts))
    state.phase=phase
    if hold and state.diagnostics then
        state.diag.result=('RESULT flipX=%+d flipY=%+d sceneX=%+d sceneY=%+d'):format(
            CommsPortrait.flipX,CommsPortrait.flipY,s.x,s.y)
        state.panel=true;state.panelUntil=Now()+PANEL_HOLD
    else
        state.panel=false;state.panelUntil=nil;Dispose()
    end
end
local function Retry(reason)
    state.attempts=state.attempts+1
    if state.attempts>=MAX_ATTEMPTS then
        print('[PortraitOrientation] giving up: '..reason)
        Finish('failed');return
    end
    -- 退避期间隐藏色块，也不读屏或更新渲染目标。
    state.delay=math.min(8,2^math.min(state.attempts-1,3))
    state.phase='retry';state.frames=0;state.drawn=false;state.renderError=nil
    state.candidate=nil;state.confirmations=0
    state.diag.result=('retry %d: %s'):format(state.attempts,reason)
    -- 测量期间不画诊断色样，避免色样自身污染全屏扫描。
    print(('[PortraitOrientation] retry reason=%s shot=%s %dx%d screen=%dx%d api=%s attempt=%d delay=%.1fs'):format(
        reason,state.diag.shot and 'ok' or 'fail',state.diag.shotw or 0,state.diag.shoth or 0,
        state.width,state.height,tostring(graphics.apiName),state.attempts,state.delay))
end
-- 采样点原始颜色：即使判定改走全屏扫描，这四项仍能直接看出坐标偏了多少。
---@param r table
---@return number[][]
local function SamplePoints(image,r)
    local w,h=image:GetWidth(),image:GetHeight()
    local out={}
    for i,p in ipairs({{.25,.25},{.75,.25},{.25,.75},{.75,.75}}) do
        local x=math.floor((r.x+r.w*p[1])*state.scale);local y=math.floor((r.y+r.h*p[2])*state.scale)
        if x>=0 and y>=0 and x<w and y<h then
            local c=image:GetPixel(x,y);out[i]={c.r,c.g,c.b}
        end
    end
    return out
end
local function CanDrawProbe()
    return (state.phase=='wait' or state.phase=='verify')
        and state.portrait and state.portrait.ready and not state.renderError
end
function M.Render()
    local vg=state.vg
    if not vg then return end
    local w,h=graphics:GetWidth(),graphics:GetHeight();local scale=UI.GetScale()
    if w<=0 or h<=0 or scale<=0 then return end
    if w~=state.width or h~=state.height or scale~=state.scale then state.frames=0 end
    -- 沿用主 UI 的设计空间缩放；UI.GetScale() 不等同于系统 DPR。
    -- 采样使用本次绘制的比例，避免读屏时 UI 缩放已发生变化。
    state.width,state.height,state.scale=w,h,scale
    local drawProbe=CanDrawProbe()
    local drawPanel=PanelVisible()
    if not drawProbe and not drawPanel then return end
    local ok,message=pcall(function()
        nvgBeginFrame(vg,w/scale,h/scale,scale)
        if drawProbe then
            -- 绘制失败必须交给外层记录，不能把失败帧计入读屏等待。
            local drawn,drawError=pcall(function()
                local portrait=assert(state.portrait)
                -- Opaque backing isolates marker components from same-coloured scene/UI pixels.
                nvgBeginPath(vg);nvgRect(vg,0,0,SIZE*2+12,SIZE+8)
                nvgFillColor(vg,nvgRGBA(0,0,0,255));nvgFill(vg)
                portrait:Draw(vg,state.rect,state.candidate or {1,1})
                -- 参照块必须自己画，不能跟探针共用颜色，否则全屏扫描会把两组质心混在一起。
                local r=state.reference;local hw,hh=r.w/2,r.h/2
                for i,q in ipairs(QUADRANTS) do
                    nvgBeginPath(vg);nvgRect(vg,r.x+((i-1)%2)*hw,r.y+(i>2 and hh or 0),hw,hh)
                    nvgFillColor(vg,nvgRGBA(q[1]*255,q[2]*255,q[3]*255,255));nvgFill(vg)
                end
            end)
            if not drawn then error(drawError) end
        end
        if drawPanel then pcall(DrawPanel,vg) end
        nvgEndFrame(vg)
    end)
    if not ok then
        nvgCancelFrame(vg);state.renderError=tostring(message);return
    end
    if drawProbe then state.drawn=true end
end
local function Readback()
    local image=Image:new()
    local d=state.diag
    local ok,message,scan=pcall(function()
        local took=graphics:TakeScreenShot(image)
        d.shot=took and true or false
        d.shotw,d.shoth=image:GetWidth(),image:GetHeight()
        if not took then return 'screenshot-failed' end
        d.probeColors=SamplePoints(image,state.rect)
        d.referenceColors=SamplePoints(image,state.reference)
        return nil,OrientationScan.Scan(image)
    end)
    image:Dispose()
    if not ok then d.shotError=tostring(message);return 'readback-error '..tostring(message),nil end
    if message then return message,nil end
    d.scan=scan
    return nil,scan
end
local function Prepare()
    if not state.vg then state.vg=assert(nvgCreate(1),'Orientation probe context unavailable') end
    local vg=assert(state.vg);local receiver=assert(state.receiver)
    -- 初始化中途失败后，重试也必须重新设置层级与订阅。
    nvgSetRenderOrder(vg,RENDER_ORDER)
    receiver:SubscribeToEvent(vg,'NanoVGRender',function() M.Render() end)
    if not state.texture then state.texture=SourceTexture() end
    if not state.portrait then
        local portrait=CommsPortrait.New('nono',SIZE,SIZE);portrait.probe=true;state.portrait=portrait
        for _,material in ipairs(portrait.materials) do
            material:SetShaderParameter('holo_tint',Variant(Vector3(0,0,0)))
            material:SetShaderParameter('probe',Variant(1.0))
            material:SetShaderParameter('marker_size',Variant(Vector2(0,0)))
            material:SetShaderParameter('orient_enabled',Variant(0.0))
        end
    end
    local texture=assert(state.texture);local portrait=assert(state.portrait)
    assert(portrait:PrepareTextures(0,'probe',false,texture,texture),'Orientation probe texture unavailable')
    local rt=portrait.textures[1]
    if rt then state.diag.rtsize={rt:GetWidth(),rt:GetHeight()} end
    -- 场景快照通道与立绘共用探针颜色，全屏扫描下会互相污染，这里不再建第二套。
    -- TextureFlip.scene 直接沿用立绘判定结果。
    portrait:Queue()
    state.frames=0;state.drawn=false;state.phase='wait'
end
local function Step()
    -- 显式诊断时只保留结果面板供截图，色块在测完时立即停止绘制。
    if state.phase:match('^measured')~=nil then
        if not state.node then return end
        if not PanelVisible() then Dispose() end
        return
    end
    if state.phase=='retry' then return end
    if state.renderError then
        local message=state.renderError;ReleaseProbe();Retry('render-error '..message);return
    end
    if state.phase=='draw' then Prepare();return end
    local portrait=state.portrait
    if (state.phase~='wait' and state.phase~='verify') or not portrait then return end
    -- 仅经过 EndFrame 不能证明探针实际画出过。
    if not state.drawn then state.frames=0;return end
    state.drawn=false;state.frames=state.frames+1
    if state.frames<REQUIRED_FRAMES then
        portrait.requested=true;portrait:Queue()
        return
    end
    local message,scan=Readback()
    if message then Retry(message);return end
    local flip,key,base,baseKey=OrientationScan.Resolve(scan)
    if flip and base then
        local fx,fy=flip[1]*base[1],flip[2]*base[2]
        if state.phase=='wait' then
            state.candidate={fx,fy};state.confirmations=0;state.phase='verify'
            print(('[PortraitOrientation] candidate flipX=%d flipY=%d raw=%s ref=%s; verifying'):format(fx,fy,key,baseKey))
        elseif fx~=1 or fy~=1 then
            Retry(('verification-failed probe=%s ref=%s'):format(key,baseKey));return
        else
            state.confirmations=state.confirmations+1
            if state.confirmations>=2 then
                local candidate=assert(state.candidate)
                -- Retain the existing scene fallback, labelled as inferred rather than independently measured.
                local sceneFlip={candidate[1],candidate[2],'portrait-inferred'}
                Finish('measured verified '..key..' ref '..baseKey,candidate[1],candidate[2],sceneFlip,true);return
            end
        end
        -- Give the corrected draw its own completed frames before reading again.
        state.frames=0;state.drawn=false;portrait.requested=true;portrait:Queue();return
    end
    local refOrder=scan and scan.refOrder and table.concat(scan.refOrder) or 'nil'
    local probeOrder=scan and scan.probeOrder and table.concat(scan.probeOrder) or 'nil'
    Retry(('inconclusive probe=%s ref=%s scanRef=%d/%s scanProbe=%d/%s'):format(
        tostring(key),tostring(baseKey),scan and scan.refCount or 0,refOrder,
        scan and scan.probeCount or 0,probeOrder))
end
--- 保留本次运行的校准结果；仅显式诊断时保留结果面板。
---@param options table|nil
function M.Start(options)
    if state.node or IsTerminal() then return end
    state.phase='draw';state.attempts=0;state.frames=0;state.drawn=false;state.delay=0;state.diag={}
    state.diagnostics=options~=nil and options.diagnostics==true
    state.elapsed=0;state.candidate=nil;state.confirmations=0;state.panel=false;state.panelUntil=nil;state.panelDeadline=nil
    -- 已知 WebGPU 运行时同步截图失败。保留当前方向，不能冒充实测成功。
    if not ReadbackSupport.Sync() then Finish('unsupported');return end
    local ok,err=pcall(function()
        state.node=Node()
        local receiver=assert(state.node:CreateScriptObject('LuaScriptObject'),'Orientation probe requires a native ScriptObject')
        state.receiver=receiver
        receiver:SubscribeToEvent('Update',function(_,_,eventData)
            if IsTerminal() then return end
            local dt=eventData:GetFloat('TimeStep')
            state.elapsed=state.elapsed+dt
            if state.elapsed>=MEASURE_TIMEOUT then Finish('failed');return end
            if state.phase~='retry' then return end
            state.delay=math.max(0,state.delay-dt)
            if state.delay==0 then state.phase='draw' end
        end)
        receiver:SubscribeToEvent('EndFrame',function()
            local stepped,message=pcall(Step)
            if not stepped then ReleaseProbe();Retry('error '..tostring(message)) end
        end)
        print(('[PortraitOrientation] v2 started api=%s order=%d'):format(tostring(graphics.apiName),RENDER_ORDER))
    end)
    if not ok then print('[PortraitOrientation] start failed '..tostring(err));Finish('failed') end
end
function M.Stop()
    if not state.node then return end
    if IsTerminal() then Dispose() else Finish('stopped') end
end
function M.Phase() return state.phase end
return M

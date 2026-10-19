-- Measures how CommsPortrait render targets reach the screen on this device.
-- Some phone runtimes present them mirrored although the editor preview does
-- not. A tiny probe portrait is drawn with the real pipeline (portrait shader ->
-- render target -> nvgCreateVideo -> UI NanoVG) from a quadrant-coloured source;
-- the presented backbuffer is read back and CommsPortrait.flipX/flipY corrected.
local CommsPortrait=require 'ui.CommsPortrait'
local UI=require 'urhox-libs/UI'
local M={}
local SIZE=24 -- probe portrait size, UI base pixels
local MAX_ATTEMPTS=3
-- Source quadrants: top-left red, top-right green, bottom-left blue, bottom-right white.
---@type number[][]
local QUADRANTS={{1,0,0},{0,1,0},{0,0,1},{1,1,1}}
---@class PortraitOrientationState
---@field phase string
---@field attempts integer
---@field frames integer
---@field portrait CommsPortrait|nil
---@field texture Texture2D|nil
---@field node Node|nil
---@field rect table|nil
---@field reference table|nil
local state={phase='idle',attempts=0,frames=0}
local function SourceTexture()
    local n=16;local image=Image:new();assert(image:SetSize(n,n,4))
    local color=Color()
    for y=0,n-1 do for x=0,n-1 do
        local index=(y<n/2 and 0 or 2)+(x<n/2 and 1 or 2)
        local q=QUADRANTS[index]
        color.r,color.g,color.b,color.a=q[1],q[2],q[3],1;image:SetPixel(x,y,color)
    end end
    local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetSRGB(false)
    texture:SetFilterMode(FILTER_NEAREST);assert(texture:SetData(image));image:Dispose()
    return texture
end
-- Classify a presented pixel by its dominant channel; nil when inconclusive.
local function Classify(c)
    local hi=math.max(c.r,c.g,c.b);if hi<.2 then return nil end
    local lo=math.min(c.r,c.g,c.b)
    if lo>hi*.6 then return 4 end
    if c.r==hi and c.g<hi*.6 and c.b<hi*.6 then return 1 end
    if c.g==hi and c.r<hi*.6 and c.b<hi*.6 then return 2 end
    if c.b==hi and c.r<hi*.6 and c.g<hi*.6 then return 3 end
    return nil
end
local function Dispose()
    if state.portrait then state.portrait:Dispose();state.portrait=nil end
    if state.texture then state.texture:Dispose();state.texture=nil end
    if state.node then state.node:Dispose();state.node=nil end
    UI.UnregisterGlobalComponent('vox-portrait-orientation')
end
local function Finish(phase,fx,fy)
    if fx then CommsPortrait.flipX,CommsPortrait.flipY=fx,fy end
    print(('[PortraitOrientation] %s api=%s flipX=%d flipY=%d attempts=%d'):format(phase,tostring(graphics.apiName),CommsPortrait.flipX,CommsPortrait.flipY,state.attempts))
    state.phase=phase;Dispose()
end
-- Sample the four quadrant centres of the drawn rect; returns the observed layout.
local function Measure(image,r)
    local scale=UI.GetScale()
    local w,h=image:GetWidth(),image:GetHeight()
    local seen={}
    for i,p in ipairs({{.25,.25},{.75,.25},{.25,.75},{.75,.75}}) do
        local x=math.floor((r.x+r.w*p[1])*scale);local y=math.floor((r.y+r.h*p[2])*scale)
        if x<0 or y<0 or x>=w or y>=h then return nil end
        seen[i]=Classify(image:GetPixel(x,y));if not seen[i] then return nil end
    end
    return seen
end
local function Decide(seen)
    -- Identity {1,2,3,4}; X mirror {2,1,4,3}; Y mirror {3,4,1,2}; both {4,3,2,1}.
    local key=table.concat(seen,'')
    local flips={['1234']={1,1},['2143']={-1,1},['3412']={1,-1},['4321']={-1,-1}}
    return flips[key],key
end
function M.Render(_,vg)
    if state.phase~='draw' and state.phase~='wait' then return end
    local portrait=state.portrait;if not portrait then return end
    -- Draw unflipped so the measurement sees the raw device orientation.
    local fx,fy=CommsPortrait.flipX,CommsPortrait.flipY;CommsPortrait.flipX,CommsPortrait.flipY=1,1
    nvgSave(vg);nvgResetTransform(vg);nvgResetScissor(vg)
    portrait:Draw(vg,state.rect)
    -- Plain NanoVG reference with the same layout calibrates the readback itself.
    local r=state.reference;local hw,hh=r.w/2,r.h/2
    for i,q in ipairs(QUADRANTS) do
        nvgBeginPath(vg);nvgRect(vg,r.x+((i-1)%2)*hw,r.y+(i>2 and hh or 0),hw,hh)
        nvgFillColor(vg,nvgRGBA(q[1]*255,q[2]*255,q[3]*255,255));nvgFill(vg)
    end
    nvgRestore(vg)
    CommsPortrait.flipX,CommsPortrait.flipY=fx,fy
end
local function Readback()
    local image=Image:new()
    if not graphics:TakeScreenShot(image) then image:Dispose();return nil end
    local seen,reference=Measure(image,state.rect),Measure(image,state.reference);image:Dispose()
    return seen,reference
end
local function Step()
    local portrait=state.portrait;if not portrait then return end
    if state.phase=='draw' then
        portrait:PrepareTextures(0,'probe',false,state.texture,state.texture)
        portrait:Queue();state.frames=0;state.phase='wait';return
    end
    if state.phase~='wait' then return end
    state.frames=state.frames+1
    if state.frames<3 then portrait.requested=true;portrait:Queue();return end
    local ok,seen,reference=pcall(Readback)
    if not ok then Finish('readback-error');return end
    local flip,key,base,baseKey=nil,nil,nil,nil
    if seen then flip,key=Decide(seen) end
    if reference then base,baseKey=Decide(reference) end
    -- Mirrors are self-inverse and commute: portrait relative to reference.
    if flip and base then Finish('measured '..key..' ref '..baseKey,flip[1]*base[1],flip[2]*base[2]);return end
    state.attempts=state.attempts+1
    if state.attempts>=MAX_ATTEMPTS then Finish('inconclusive '..tostring(key)..' ref '..tostring(baseKey));return end
    state.phase='draw'
end
--- Start once per session. Safe to call repeatedly; later calls are ignored.
function M.Start()
    if state.phase~='idle' then return end
    local ok,err=pcall(function()
        state.texture=SourceTexture()
        state.portrait=CommsPortrait.New('nono',SIZE,SIZE)
        -- Two small squares in the top-left corner for a few boot frames.
        state.rect={x=0,y=0,w=SIZE,h=SIZE};state.reference={x=SIZE+2,y=0,w=SIZE,h=SIZE}
        for _,material in ipairs(state.portrait.materials) do
            -- Disable the hologram tint/glitch/edge fade so the colours read back clean.
            material:SetShaderParameter('holo_tint',Variant(Vector3(0,0,0)))
            material:SetShaderParameter('probe',Variant(1.0))
        end
        state.node=Node()
        local receiver=assert(state.node:CreateScriptObject('LuaScriptObject'),'Orientation probe requires a native ScriptObject')
        receiver:SubscribeToEvent('EndFrame',function() local stepped,message=pcall(Step);if not stepped then print('[PortraitOrientation] '..tostring(message));Finish('error') end end)
        UI.RegisterGlobalComponent('vox-portrait-orientation',M)
        state.phase='draw'
    end)
    if not ok then print('[PortraitOrientation] start failed '..tostring(err));Finish('error') end
end
function M.Stop() if state.phase=='draw' or state.phase=='wait' then Finish('stopped') end end
function M.Phase() return state.phase end
return M

-- Original UI cues; input never downloads or decodes a sound.
local UI=require 'urhox-libs/UI'
local Levels=require 'audio.AudioLevels'
local Data=require('core.ResourceData').Read('UI/Sounds.json')
local M={}
local current=nil ---@type table|nil
local function Now() return Time:GetSystemTime()/1000 end
local function ButtonAt(widget,x,y)
    while widget do
        if widget.UiSoundButtonAt and widget:UiSoundButtonAt(x,y) then return true end
        -- Widget:new wraps instances in property routing; _super is inherited.
        local class=widget
        while class do
            if class==UI.Button or class._className and class._className==UI.Button._className then return not widget.props.disabled end
            class=class._super
        end
        widget=widget.parent
    end
    return false
end
function M.Dependencies()
    local paths={};for _,cue in pairs(Data.cues) do paths[#paths+1]=cue.path end;table.sort(paths);return paths
end
function M.Start()
    M.Dispose()
    local s={scene=Scene(),sounds={},voices={},last={},counts={},order=0,focused=true,requests=0,errors={},preparation={},next=1,decoding={},decodeCursor=1}
    current=s;s.root=s.scene:CreateChild('UiSound');s.gate=require('app.ResourceGate').New()
    for i=1,10 do
        local source=s.root:CreateComponent('SoundSource');source:SetSoundType('VoxUI')
        s.voices[i]={source=source,order=0}
    end
    for id,cue in pairs(Data.cues) do
        local sound=cache:GetExistingResource('Sound',cue.path)
        if sound then s.sounds[id]=sound else s.preparation[#s.preparation+1]=id end
    end
    table.sort(s.preparation)
    s.gate:Start(M.Dependencies(),function(ok,message)
        if current~=s then return end
        s.downloadReady=ok==true;s.downloadError=not ok and tostring(message) or nil
    end)
    s.listener=UI.Input.On('PointerDown',function(event)
        if not event:IsPrimaryAction() then return end
        local scale=UI.GetScale();local x,y=event.x/scale,event.y/scale
        if ButtonAt(UI.FindWidgetAt(x,y),x,y) then M.Play('press') end
    end)
    return s
end
function M.Play(id)
    local s=current;local cue=Data.cues[id]
    if not s or not cue or not input.focus or input.minimized or Levels.Get('sfx')<=0 then return false end
    local sound=s.sounds[id];if not sound then return false end
    local now=Now();if now-(s.last[id] or -math.huge)<cue.gap then return false end
    local free,oldest,same,oldestSame=nil,1,0,nil
    for i,voice in ipairs(s.voices) do
        if not voice.source.playing and not free then free=i end
        if voice.order<s.voices[oldest].order then oldest=i end
        if voice.source.playing and voice.id==id then
            same=same+1
            if not oldestSame or voice.order<s.voices[oldestSame].order then oldestSame=i end
        end
    end
    local voice=s.voices[same>=3 and oldestSame or free or oldest]
    voice.source:StopImmediate();s.order=s.order+1;voice.order=s.order;voice.id=id;s.last[id]=now
    Levels.Play(voice.source,sound,0,cue.gain*.65,0,'sfx','ui')
    s.counts[id]=(s.counts[id] or 0)+1;return true
end
function M.Update()
    local s=current;if not s then return end
    if s.downloadError then
        s.errors[#s.errors+1]=s.downloadError;print('[UiSound] '..s.downloadError);s.downloadError=nil
    end
    -- Never enter the cache from a native download-completion callback.
    local id=s.downloadReady and s.preparation[s.next]
    if id then
        s.next=s.next+1;local path=Data.cues[id].path
        local sound=cache:GetExistingResource('Sound',path)
        if sound then s.sounds[id]=sound
        else
            s.requests=s.requests+1
            if not cache:BackgroundLoadResource('Sound',path,true) then s.errors[#s.errors+1]='Background load rejected: '..path end
            s.decoding[#s.decoding+1]=id
        end
    end
    local queue=s.decoding
    for _=1,math.min(4,#queue) do
        if #queue==0 then break end
        local index=s.decodeCursor;local pending=queue[index]
        local sound=cache:GetExistingResource('Sound',Data.cues[pending].path)
        if sound then s.sounds[pending]=sound;queue[index]=queue[#queue];table.remove(queue)
        else s.decodeCursor=index+1 end
        if s.decodeCursor>#queue then s.decodeCursor=1 end
    end
    local focused=input.focus and not input.minimized
    if not focused and s.focused then for _,voice in ipairs(s.voices) do voice.source:StopImmediate() end end
    s.focused=focused
end
function M.Snapshot()
    local s=current;if not s then return {active=false} end
    local ready=0;for _ in pairs(s.sounds) do ready=ready+1 end
    return {active=true,ready=ready,counts=s.counts,voices=#s.voices,state=s.gate.state,requests=s.requests,errors=s.errors}
end
function M.Dispose()
    local s=current;if not s then return end;current=nil
    UI.Input.Off('PointerDown',s.listener);s.gate:Cancel()
    for _,voice in ipairs(s.voices) do voice.source:StopImmediate() end
    s.scene:Dispose();s.sounds={};s.voices={};s.preparation={};s.decoding={}
end
return M

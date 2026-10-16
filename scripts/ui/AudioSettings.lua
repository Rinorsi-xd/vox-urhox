-- Frozen shared/audio/gameMusic.js settings; controls share the source .gfx CSS.
local UI=require 'urhox-libs/UI'
local Host=require 'ui.DialogHost'
local Button=require 'ui.SourceButton'
local Controls=require 'ui.SourceGraphicsControls'
local Levels=require 'audio.AudioLevels'
local M={}
local function Metrics()
    local w,h=graphics:GetWidth(),graphics:GetHeight()
    local compact=require('controls.TouchMode').Enabled() and math.min(w,h)/math.max(1,graphics:GetDPR())<=600
    local refH=compact and 600 or 1080
    return math.min(w/(refH*16/9),h/refH)/UI.GetScale(),compact
end
local Heading=UI.Panel:Extend('VoxAudioHeading')
function Heading:Render(vg)
    require('ui.SourceDraw').Begin(vg);local r=self:GetAbsoluteLayout()
    local k=self.props.sourceScale
    nvgSave(vg);nvgScale(vg,k,k)
    require('ui.SourceModal').DrawHeading(vg,r.x/k,r.y/k,r.w/k,'声音与音乐','立即生效，自动保存',self.props.compact)
    nvgRestore(vg)
end
function M.Open(owner,options)
    options=options or {}
    if owner.Pause then owner:Pause() end
    local player=owner.app.music
    local k,compact=Metrics()
    local modal=Host.Open(owner,'声音与音乐',nil,{width=780*k,fullScroll=true,sourceScale=k})
    modal.sourceScale=k;modal.compact=compact;modal.sourceAudioSettings=true
    modal.controls={};modal.rows={}
    local _,h=UI.GetViewportSize()
    local natural=(compact and 376.25 or 424.25)*k
    local scroll=UI.ScrollView{width='100%',height=math.min(natural,h*.86),sourceNaturalHeight=natural,flexShrink=0}
    scroll:AddChild(Heading{width='100%',height=(compact and 66 or 94)*k,sourceScale=k,compact=compact,flexShrink=0})
    local body=UI.Panel{width='100%',paddingHorizontal=(compact and 18 or 28)*k,paddingBottom=(compact and 16 or 24)*k,flexShrink=0}
    local rows=UI.Panel{width='100%',gap=2*k,flexShrink=0};body:AddChild(rows)
    local function Row(label,height,valueText)
        local row=Controls.Row{width='100%',height=(height-(compact and 4 or 0))*k,sourceScale=k,flexShrink=0,label=label,valueText=valueText}
        rows:AddChild(row);modal.rows[#modal.rows+1]=row;return row
    end
    local enabled=Controls.Checkbox{position='absolute',left=(compact and 122 or 158)*k,right=(compact and 86 or 98)*k,top=(compact and 9 or 11)*k,height=22*k,sourceScale=k,
        label='开启场景音乐',checked=player.enabled,onClick=function(self)
            player:SetEnabled(not player.enabled);self.props.checked=player.enabled
        end}
    Row('背景音乐',45):AddChild(enabled);modal.controls.musicEnabled=enabled
    local function Report(ok,err)
        if not ok and owner.app.toasts then owner.app.toasts:Push('声音设置保存失败：'..tostring(err),'bad') end
    end
    for _,spec in ipairs({{'sfx','音效音量'},{'music','音乐音量'},{'voice','语音音量'}}) do
        local key=spec[1]
        local row=Row(spec[2],47,function() return math.floor(Levels.Get(key)*100+.5)..'%' end)
        local slider=Controls.Slider{position='absolute',left=(compact and 124 or 160)*k,right=(compact and 84 or 96)*k,top=(compact and 13 or 15)*k,height=16*k,sourceScale=k,
            min=0,max=100,step=1,thumbSize=16*k,value=math.floor(Levels.Get(key)*100+.5),focusable=true,
            onChange=function(_,value)
                if key=='music' then player:SetVolume(value/100) else Report(Levels.Set(key,value/100)) end
            end}
        row:AddChild(slider);modal.controls[key]=slider
    end
    local hint=require('ui.SourceHint'){text='',width='100%',height=29.25*k,marginTop=12.5*k,marginBottom=12.5*k,sourceScale=k,flexShrink=0}
    body:AddChild(hint);modal.status=hint
    local buttonHeight=(compact and 44 or 40)*k
    modal.actions={pause=Button{text='暂停音乐',sourceKind='dialog',width=116*k,height=buttonHeight,sourceScale=k,
        onClick=function() player:SetPaused(not player.userPaused) end},
        next=Button{text='下一首',sourceKind='dialog',width=97.5*k,height=buttonHeight,sourceScale=k,onClick=function() player:Next() end},
        done=Button{text=options.onDone and '返回设置' or '完成',sourceKind='primary',width=(options.onDone and 116 or 79)*k,height=buttonHeight,sourceScale=k,onClick=function() if options.onDone then options.onDone() else Host.Close(owner) end end}}
    body:AddChild(UI.Panel{width='100%',flexDirection='row',justifyContent='flex-end',height=buttonHeight,marginTop=20*k,gap=8*k,flexShrink=0,
        children={modal.actions.pause,modal.actions.next,modal.actions.done}})
    scroll:AddChild(body);modal:AddContent(scroll);modal.scroll=scroll
    local function Refresh()
        if owner.dialog~=modal then return end
        local currentScale,currentCompact=Metrics()
        if math.abs(currentScale-k)>.00001 or currentCompact~=compact then M.Open(owner,options);return end
        local track=player:Track()
        local status=(not player.enabled or player.volume==0) and '音乐已关闭'
            or player.userPaused and '音乐已暂停' or track and '正在播放：'..track.title or '准备播放'
        hint:SetText(status)
        modal.actions.pause.props.text=player.userPaused and '继续音乐' or '暂停音乐'
        modal.actions.next:SetDisabled(not player.enabled or player.volume==0 or player.userPaused)
        enabled.props.checked=player.enabled
        for _,key in ipairs({'sfx','music','voice'}) do
            local slider=modal.controls[key]
            if not slider.state.dragging then slider.props.value=math.floor(Levels.Get(key)*100+.5) end
        end
    end
    owner.dialogTick=Refresh;Refresh();return modal
end
function M.Attach(session,root,top)
    return require('ui.GameSettings').Attach(session,root,top)
end
return M

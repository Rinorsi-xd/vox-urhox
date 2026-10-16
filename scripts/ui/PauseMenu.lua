local Button=require 'ui.SourceButton'
local Host=require 'ui.DialogHost'
local UI=require 'urhox-libs/UI'
local M={}
local Heading=UI.Panel:Extend('VoxPauseHeading')
function Heading:Render(vg)
    require('ui.SourceDraw').Begin(vg);local r=self:GetAbsoluteLayout();local k=self.props.sourceScale
    nvgSave(vg);nvgScale(vg,k,k)
    require('ui.SourceModal').DrawHeading(vg,r.x/k,r.y/k,r.w/k,'暂停',nil,self.props.compact)
    nvgRestore(vg)
end
function M.Open(owner,options)
    options=options or {}
    local build=owner.editor~=nil
    local inGame=options.inGame==true
    local touch=require('controls.TouchMode').Enabled()
    local w,h=graphics:GetWidth(),graphics:GetHeight()
    local compact=touch and math.min(w,h)/math.max(1,graphics:GetDPR())<=600
    local refH=compact and 600 or 1080
    local k=math.min(w/(refH*16/9),h/refH)/UI.GetScale()
    local modal=Host.Open(owner,'暂停',nil,{width=480*k,fullScroll=true,heightRatio=.9,sourceScale=k});local buttons={}
    local _,vh=UI.GetViewportSize()
    local scroll=UI.ScrollView{width='100%',height=vh*.9,flexShrink=0}
    scroll:AddChild(Heading{width='100%',height=(compact and 66 or 94)*k,sourceScale=k,compact=compact,flexShrink=0})
    local body=UI.Panel{width='100%',paddingHorizontal=(compact and 18 or 28)*k,paddingBottom=(compact and 16 or 24)*k,gap=6*k,flexShrink=0}
    scroll:AddChild(body);modal:AddContent(scroll);modal.scroll=scroll
    local function Add(id,label,icon,subtitle,action,disabled)
        local b=Button{text=label,icon=icon,subtitle=subtitle,sourceKind='pause',sourceScale=k,onClick=action,width='100%',height=66*k,flexShrink=0,disabled=disabled};body:AddChild(b);buttons[id]=b
    end
    Add('resume','继续','play',inGame and '回到'..(owner.map and owner.map.name or '对局') or '回到'..(build and '编辑' or owner.app.lobby=='salvage' and '打捞行动' or '机库'),function()
        Host.Close(owner);if inGame and owner.Resume then owner:Resume() end
    end)
    if inGame then
        Add('return','返回车库','hangar','结束当前驾驶并返回',function()
            Host.Close(owner)
            if owner.battle then require('combat.MatchActions').ConfirmLeave(owner.battle) else owner.wantsReturn=true end
        end)
    end
    if build then
        Add('save','保存','save',touch and '存进车位' or '存进车位（Ctrl+S）',function() owner:SaveSlot() end)
        Add('home','回机库','hangar','有车位的车自动保存',function() Host.Close(owner);owner.app:ExitBuild() end)
    end
    if not touch then Add('help','操作说明','help','建造、视角、试车的全部按键（H）',function() require('ui.GarageDialogs').Help(owner) end) end
    if owner.app.tutorial and not inGame then Add('tutorial','新手引导','play','让诺诺从头再带一遍',function()
        Host.Close(owner);local app=owner.app
        if app.build then app:ExitBuild() end
        local home=require('ui.GarageHud').GetState();if home then home.SetTab('hangar') end
        app.tutorial:Start()
    end) end
    Add('modeIntro','模式介绍','play','下一局重新播放对战开场的地图和规则介绍',function()
        local ok,err=require('combat.Matchmaker').ResetIntro(owner.app.store)
        Host.Close(owner)
        Host.Notify(owner,ok and '下一局对战会重新播放完整的模式介绍' or '模式介绍设置保存失败：'..tostring(err),ok and 'ok' or 'bad')
    end)
    local childOptions=options.unified and {onDone=function() require('ui.GameSettings').Open(owner) end} or nil
    Add('graphics','画面设置','gear','画质、泛光、曝光、环境光遮蔽',function() require('ui.GraphicsPanel').Open(owner,childOptions) end)
    Add('audio','声音与音乐','sliders','音乐、音效音量与场景曲目',function() require('ui.AudioSettings').Open(owner,childOptions) end)
    if touch then Add('touch','触屏操作','sliders','灵敏度、按钮大小、瞄准辅助、建造方式',function() require('ui.TouchSettings').Open(owner,childOptions) end)
    else Add('keys','键位设置','sliders','开发中',function() end,true) end
    local count=0;for _ in pairs(buttons) do count=count+1 end
    local natural=((compact and 82 or 118)+count*66+math.max(0,count-1)*6)*k
    scroll.props.sourceNaturalHeight=natural;scroll:SetHeight(math.min(natural,vh*.9))
    modal.actions=buttons;modal.sourceScale=k;modal.compact=compact;modal.unifiedSettings=options.unified==true
    if options.unified then owner.dialogTick=function()
        if owner.dialog==modal and (w~=graphics:GetWidth() or h~=graphics:GetHeight()) then M.Open(owner,options) end
    end end
    return modal
end
return M

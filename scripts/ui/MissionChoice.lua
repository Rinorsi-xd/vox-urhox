-- storyHud.css choice strips, rendered in the existing UI-owned VG frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Motion=require 'ui.SourceButtonMotion'
local Panel=UI.Panel:Extend('VoxMissionChoice')
local Button=require('ui.ActionButton'):Extend('VoxMissionChoiceOption')
local M={}
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local color={70,200,255,255}
    D.Path(vg,{r.x,r.y,r.x+r.w,r.y,r.x+r.w-14,r.y+r.h,r.x,r.y+r.h})
    if self.picked then nvgFillColor(vg,D.Color(color));nvgFill(vg)
    else
        local hover=self.hoverTween and self.hoverTween.value or 0
        D.Gradient(vg,r.x,r.y,r.w,r.h,{10+60*hover,30+170*hover,44+211*hover,235-179*hover},{10+60*hover,20+180*hover,30+225*hover,204-148*hover},true)
    end
    nvgStrokeColor(vg,D.Color({70,200,255,77}));nvgStrokeWidth(vg,1);nvgStroke(vg)
    D.Rect(vg,r.x,r.y,2,r.h,color);D.Rect(vg,r.x+8,r.y+9,24,22,{70,200,255,51})
    nvgBeginPath(vg);nvgRect(vg,r.x+8.5,r.y+9.5,23,21);nvgStrokeColor(vg,D.Color({70,200,255,153}));nvgStroke(vg)
    D.Text(vg,tostring(self.props.index),r.x+20,r.y+11,13,color,'vox-display',NVG_ALIGN_CENTER)
    local size=math.min(17,17*(r.w-64)/math.max(1,D.Width(vg,self.props.text,17,'vox-display',1)))
    D.Text(vg,self.props.text,r.x+42,r.y+(r.h-size)/2,size,self.picked and {4,18,31,255} or {244,245,247,255},'vox-display',nil,1)
end
function Panel:Render(vg)
    if not self.choice then return end
    D.Begin(vg);local r=self:GetAbsoluteLayout();local width=300
    for _,option in ipairs(self.choice.options) do width=math.max(width,D.Width(vg,option.label,17,'vox-display',1)+64) end
    local prompt=self.choice.prompt or '';local pw=D.Width(vg,prompt,15,'vox-body',.6)+27
    self.naturalWidth=math.max(width,prompt~='' and pw or 0)
    if prompt=='' then return end
    pw=math.min(r.w,pw);nvgBeginPath(vg);nvgRect(vg,r.x,r.y,pw,28)
    D.Gradient(vg,r.x,r.y,pw,28,{4,18,31,224},{4,18,31,140},true)
    D.Rect(vg,r.x,r.y,3,28,{70,200,255,255})
    D.Text(vg,prompt,r.x+13,r.y+5,15,{255,255,255,255},'vox-body',nil,.6,false,18,{{y=1,blur=3,color={0,0,0,255}}})
end
function M.Attach(session,root)
    local panel=Panel{position='absolute',width=480,height=184,pointerEvents='box-none',visible=false};root:AddChild(panel)
    local buttons={}
    for i=1,3 do local index=i
        local button=Button{index=i,text='',position='absolute',top=46+(i-1)*46,width='100%',height=40,
            onClick=function()
                if session.story.rules.choice~=panel.choice then return end
                if session.story.rules:Choose(index) then session.story:Events();if not session.touch then session:Resume() end end
            end}
        panel:AddChild(button);buttons[i]=button
    end
    return function()
        local state=session.story.choiceView:State();panel:SetVisible(state~=nil and state.visible);if not state or not state.visible then return end
        local choice=state.choice
        panel.choice=choice;local w,h=UI.GetViewportSize();local touch=session.touch
        local width=math.max(1,math.min(panel.naturalWidth or 480,w-(touch and 280 or 206)))
        local offset=choice.prompt and choice.prompt~='' and 36 or 0;local height=offset+#choice.options*46-6
        panel:SetStyle{left=touch and w-width-20 or 186,top=touch and h*.37 or h-284-height,width=width,height=height,
            opacity=state.alpha,translateX=state.x,pointerEvents=state.on and 'box-none' or 'none'}
        for i,button in ipairs(buttons) do local item=choice.options[i];button:SetVisible(item~=nil);if item then
            button:SetText(item.label);button.picked=state.picked==i
            button.hoverTween=button.hoverTween or {value=0,start=0,target=0,elapsed=0,duration=0}
            local now=Time:GetSystemTime();local elapsed=button.hoverAt and math.max(0,now-button.hoverAt)/1000 or 0;button.hoverAt=now
            Motion.Step(button.hoverTween,button.state.hovered and 1 or 0,.15,elapsed,'ease')
            button:SetStyle{top=offset+(i-1)*46,translateX=4*button.hoverTween.value}
        end end
    end
end
return M

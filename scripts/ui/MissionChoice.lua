-- storyHud.css choice strips, rendered in the existing UI-owned VG frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Paragraph=require 'ui.SourceParagraph'
local Panel=UI.Panel:Extend('VoxMissionChoice')
local Button=UI.Button:Extend('VoxMissionChoiceOption')
local M={}
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local color={70,200,255,255}
    D.Path(vg,{r.x,r.y,r.x+r.w,r.y,r.x+r.w-14,r.y+r.h,r.x,r.y+r.h})
    nvgFillColor(vg,D.Color(self.state.hovered and {15,65,83,245} or {10,25,38,235}));nvgFill(vg)
    D.Rect(vg,r.x,r.y,2,r.h,color);D.Rect(vg,r.x+8,r.y+9,24,22,{70,200,255,55})
    D.Text(vg,tostring(self.props.index),r.x+20,r.y+11,13,color,'vox-story',NVG_ALIGN_CENTER)
    local size=math.min(17,17*(r.w-54)/math.max(1,D.Width(vg,self.props.text,17,'vox-story')))
    D.Text(vg,self.props.text,r.x+42,r.y+(r.h-size)/2,size,{244,245,247,255},'vox-story')
end
function Panel:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();D.Rect(vg,r.x,r.y,r.w,40,{4,18,31,230})
    D.Rect(vg,r.x,r.y,3,40,{70,200,255,255});self.prompt:Draw(vg,self.choice.prompt or '',r.x+12,r.y+7,r.w-24,{255,255,255,255})
end
function M.Attach(session,root)
    local panel=Panel{position='absolute',width=480,height=184,pointerEvents='box-none',visible=false};panel.prompt=Paragraph.New(15,20);root:AddChild(panel)
    local buttons={}
    for i=1,3 do local index=i
        local button=Button{index=i,text='',position='absolute',top=46+(i-1)*46,width='100%',height=40,
            onClick=function() session.story.rules:Choose(index);session.story:Events();if not session.touch then session:Resume() end end}
        panel:AddChild(button);buttons[i]=button
    end
    return function()
        local choice=session.story.rules.choice;panel:SetVisible(choice~=nil);if not choice then return end
        panel.choice=choice;local w,h=UI.GetViewportSize();local touch=session.touch
        local width=math.min(480,w-(touch and 280 or 206));panel:SetStyle{left=touch and w-width-20 or 186,top=touch and h*.37 or h-460,width=width}
        for i,button in ipairs(buttons) do local item=choice.options[i];button:SetVisible(item~=nil);if item then button:SetText(item.label) end end
    end
end
return M

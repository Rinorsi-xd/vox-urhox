local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Key=require('ui.BuildButton').Key
local Defs=require 'parts.Defs'
local Badge=require 'ui.BuildModeBadge'
local Overlay=Panel:Extend('VoxBuildOverlay')
local arms={{-1,-13,2,8},{-1,5,2,8},{-13,-1,8,2},{5,-1,8,2}}
local function Fade(vg,x,y,w,h,a,b,horizontal)
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h);D.Gradient(vg,x,y,w,h,a,b,horizontal)
end
local function Mouse(vg,x,y,part)
    nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,.8,.8)
    nvgBeginPath(vg);nvgRoundedRect(vg,1,1,18,26,9);nvgFillColor(vg,nvgRGBA(0,0,0,89));nvgFill(vg);nvgStrokeWidth(vg,1.2);nvgStrokeColor(vg,nvgRGBA(255,255,255,128));nvgStroke(vg)
    nvgBeginPath(vg);nvgMoveTo(vg,10,1.6);nvgLineTo(vg,10,12);nvgLineTo(vg,1.6,12);nvgBezierTo(vg,1.6,5.5,5.5,1.6,10,1.6);nvgClosePath(vg);nvgFillColor(vg,D.Color(part=='L' and D.orange or {255,255,255,26}));nvgFill(vg)
    nvgBeginPath(vg);nvgMoveTo(vg,10,1.6);nvgLineTo(vg,10,12);nvgLineTo(vg,18.4,12);nvgBezierTo(vg,18.4,5.5,14.5,1.6,10,1.6);nvgClosePath(vg);nvgFillColor(vg,D.Color(part=='R' and D.orange or {255,255,255,26}));nvgFill(vg)
    nvgBeginPath(vg);nvgRoundedRect(vg,8.2,4.5,3.6,6,1.8);nvgFillColor(vg,D.Color((part=='W' or part=='M') and D.orange or {255,255,255,26}));nvgFill(vg);nvgRestore(vg)
end
function Overlay:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local w,h=r.w,r.h;local s=self.session;local e=s.editor
    if self.props.shade then
        Fade(vg,0,0,260,h,{9,10,12,209},{9,10,12,128},true);Fade(vg,260,0,200,h,{9,10,12,128},{9,10,12,0},true)
        Fade(vg,w-280,0,280,h,{9,10,12,0},{9,10,12,179},true);Fade(vg,0,0,w,120,{9,10,12,199},{9,10,12,0})
        Fade(vg,0,h-210,w,210,{9,10,12,0},{9,10,12,224});return
    end
    if s.inventoryPanel then return end
    if not s.buildCamera.touch then
    local hints={};local function Hint(text,key,mouse,extra,bold) hints[#hints+1]={text=text,key=key,mouse=mouse,extra=extra,bold=bold} end
    local rot=tostring(((e.pasting and e.pasteSpin or e.spin)%4)*90)..'°'
    if e.pasting then Hint('放下粘贴',nil,'L');Hint('旋转 '..rot,'R');Hint('取消','Esc')
    elseif e.tool=='stretch' then
        local phase=e.stretch and e.stretch.phase
        Hint(phase=='rect' and '定长宽' or phase=='height' and '放下' or phase=='selection' and '确认选区拉伸' or '定起点',nil,'L',nil,true)
        if phase=='height' or phase=='selection' then Hint('微调层数',nil,'W') end
        Hint(phase=='height' and '回去改长宽' or '取消',nil,'R');Hint('退出拉伸','J / Esc')
    elseif s.selecting then Hint('选择',nil,'L',nil,true);Hint('全选','Ctrl+A');Hint('清空 / 退出','Esc')
    elseif e.tool=='erase' then Hint('删除零件',nil,'L',nil,true);Hint('删除零件',nil,'R');Hint('退出删除','X / Esc')
    elseif e.tool=='paint' then
        Hint(e.paintChannel=='accent' and '涂装饰色' or '涂主色',nil,'L',nil,true);Hint('换颜色',nil,'W');Hint('主色 / 装饰色','Tab');Hint('吸色','C');Hint('回去放零件','1–0')
    else
        Hint('放置',nil,'L',nil,true);Hint('删除',nil,'R');Hint('换零件',nil,'W');Hint('旋转 '..rot,'R')
        if Defs.PARTS[e.type].shape then Hint('翻转安装面','Alt+R');Hint('换材质','G') end
        Hint('拾取零件和颜色',nil,'M');Hint('换颜色','Alt','W');Hint('零件库','B')
    end
    local fly=s.buildCamera
    if fly.mode=='fp' then Hint('平移','WASD');Hint('上升','空格');Hint('下降','Shift');Hint('快飞','Z');Hint('飞行速度 '..s.flyStep..' 档','- / =');Hint('回到车旁','L')
    else Hint('拖动转视角',nil,'R');Hint('缩放','Shift','W') end
    local selected=#e:Selected();if selected>0 then Hint('移动所选 '..selected..' 个','方向键') end;Hint('全部操作','H')
    local cy=76
    for _,item in ipairs(hints) do
        local tw=D.Width(vg,item.text,item.bold and 15 or 12.5,item.bold and nil or 'vox-body')
        local kw=item.key and D.Width(vg,item.key,12)+8 or 0;local mw=item.mouse and 16 or 0
        local width=36+tw+kw+mw+(kw>0 and 7 or 0)+(mw>0 and 7 or 0);local x=w-20-width;local height=item.mouse and 30 or 26
        Fade(vg,x,cy,width,height,{9,10,12,0},{9,10,12,209},true);local tx=x+34
        if item.key then Key(vg,item.key,tx,cy+(height-17)/2,12);tx=tx+kw+7 end
        if item.mouse then Mouse(vg,tx,cy+4,item.mouse);tx=tx+23 end
        D.Text(vg,item.text,tx,cy+(height-(item.bold and 18 or 16))/2,item.bold and 15 or 12.5,item.bold and e.tool=='erase' and {255,59,48,255} or {201,206,214,255},item.bold and nil or 'vox-body');cy=cy+height+2
    end
    end
    local fly=s.buildCamera
    if fly.mode=='fp' and not s.dialog and not s.hud.colorOpen then
        -- H5 keeps its crosshair in CSS pixels, outside the reference-scaled UI.
        local unit=graphics:GetDPR()/require('urhox-libs/UI').GetScale()
        local x,y=w/2,h/2;local mode=Badge.Mode(s)
        nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,unit,unit)
        D.Rect(vg,-2,-14,4,10,{0,0,0,153});D.Rect(vg,-14,-2,10,4,{0,0,0,153})
        for _,q in ipairs(arms) do D.Rect(vg,q[1],q[2],q[3],q[4],D.white) end
        local size=mode=='paint' and 10 or (mode=='erase' or mode=='select') and 6 or 4
        local edge=mode=='paint' and 2 or size==6 and 1 or 0
        if edge>0 then D.Rect(vg,-size/2-edge,-size/2-edge,size+edge*2,size+edge*2,{0,0,0,mode=='paint' and 166 or 179}) end
        local badge=s.hud.modeBadge
        D.Rect(vg,-size/2,-size/2,size,size,badge.renderMode==mode and badge.color or Badge.Color(s));nvgRestore(vg)
        if not fly.captured and not fly.touch then
            local text='点击画面开始建造';local width=D.Width(vg,text,17)+40;D.Rect(vg,(w-width)/2,h*.58,width,42,{14,15,18,235});D.Rect(vg,(w-width)/2,h*.58,3,42,D.orange);D.Text(vg,text,w/2,h*.58+10,17,nil,nil,NVG_ALIGN_CENTER)
        end
    end
end
return Overlay

local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Key=require('ui.BuildButton').Key
local Defs=require 'parts.Defs'
local Overlay=Panel:Extend('VoxBuildOverlay')
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
    if s.buildCamera.touch then
        local action=e.tool=='erase' and '点按车辆删除零件' or e.tool=='paint' and '点按车辆涂装' or '点按安装位置放置零件'
        for i,text in ipairs({action,'拖动画面旋转视角','下方按钮旋转、翻转与缩放','点按零件库更换部件'}) do
            D.Text(vg,text,w-20,78+(i-1)*28,15,D.white,nil,NVG_ALIGN_RIGHT)
        end
        return
    end
    local hints={};local function Hint(text,key,mouse,extra,bold) hints[#hints+1]={text=text,key=key,mouse=mouse,extra=extra,bold=bold} end
    local rot=tostring(((e.pasting and e.pasteSpin or e.spin)%4)*90)..'°'
    if e.pasting then Hint('放下粘贴',nil,'L');Hint('旋转 '..rot,'R');Hint('取消','Esc')
    elseif e.tool=='erase' then Hint('删除零件',nil,'L',nil,true);Hint('删除零件',nil,'R');Hint('多选','Shift','L');Hint('删除所选','Del');Hint('退出删除','X')
    elseif e.tool=='paint' then
        Hint(e.paintChannel=='accent' and '涂装饰色' or '涂装外壳',nil,'L',nil,true);Hint('外壳 / 饰色',nil,'W');Hint('吸取颜色','C');Hint('复制零件及配色',nil,'M');Hint('切回放置','1–0');Hint('退出涂装','P')
    else
        Hint('放置',nil,'L',nil,true);Hint('删除',nil,'R');Hint('换零件',nil,'W');Hint('旋转 '..rot,'R')
        if Defs.PARTS[e.type].shape then Hint('翻转安装面','Alt+R');Hint('换材质','G') end
        Hint('拾取',nil,'M');Hint('零件库','B')
    end
    local fly=s.buildCamera
    if fly.mode=='fp' then Hint('平移','WASD');Hint('上升','空格');Hint('下降','Shift/Q');Hint('快飞','Z')
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
    if fly.mode=='fp' and not s.dialog and not s.hud.colorOpen then
        local x,y=w/2,h/2;for _,q in ipairs({{-1,-13,2,8},{-1,5,2,8},{-13,-1,8,2},{5,-1,8,2}}) do D.Rect(vg,x+q[1],y+q[2],q[3],q[4],D.white) end;D.Rect(vg,x-2,y-2,4,4,D.orange)
        if not fly.captured then
            local text='点击画面开始建造 · Tab 返回环绕视角';local width=D.Width(vg,text,17)+40;D.Rect(vg,(w-width)/2,h*.58,width,42,{14,15,18,235});D.Rect(vg,(w-width)/2,h*.58,3,42,D.orange);D.Text(vg,text,w/2,h*.58+10,17,nil,nil,NVG_ALIGN_CENTER)
        end
    end
end
return Overlay

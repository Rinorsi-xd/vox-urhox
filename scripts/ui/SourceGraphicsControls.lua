-- H5 .gfx-row metrics and Chromium range styling, drawn in the UI-owned NVG frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local M={}
M.Row=UI.Panel:Extend('VoxGraphicsRow')
function M.Row:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props
    D.Rect(vg,r.x,r.y+r.h-1,r.w,1,{255,255,255,15})
    D.Text(vg,p.label,r.x+2,r.y+(r.h-1-22)/2,18)
    if p.valueText then D.Text(vg,p.valueText(),r.x+r.w-2,r.y+(r.h-1-24)/2,20,D.orange,nil,NVG_ALIGN_RIGHT) end
end
M.Slider=UI.Slider:Extend('VoxGraphicsSlider')
function M.Slider:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props
    local fraction=(p.value-p.min)/(p.max-p.min);local tx=r.x+8+fraction*(r.w-16);local cy=r.y+r.h/2
    nvgSave(vg);if p.disabled then nvgGlobalAlpha(vg,.45) end
    nvgBeginPath(vg);nvgRoundedRect(vg,r.x+1,cy-3.5,r.w-2,7,3.5)
    nvgFillColor(vg,nvgRGBA(59,59,59,255));nvgFill(vg)
    nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(133,133,133,255));nvgStroke(vg)
    nvgBeginPath(vg);nvgRoundedRect(vg,r.x+1,cy-3.5,math.max(0,tx-r.x-1),7,3.5)
    nvgFillColor(vg,D.Color(D.orange));nvgFill(vg)
    nvgBeginPath(vg);nvgCircle(vg,tx,cy,7.5);nvgFillColor(vg,D.Color(D.orange));nvgFill(vg)
    nvgRestore(vg)
end
function M.Slider:OnPointerDown(event)
    if not self.props.disabled and event:IsPrimaryAction() then UI.SetFocus(self) end
    return UI.Slider.OnPointerDown(self,event)
end
function M.Slider:OnKeyDown(key)
    if UI.GetFocus()~=self or self.props.disabled then return end
    local p=self.props;local value=p.value
    if key==KEY_LEFT or key==KEY_DOWN then value=value-p.step
    elseif key==KEY_RIGHT or key==KEY_UP then value=value+p.step
    elseif key==KEY_HOME then value=p.min elseif key==KEY_END then value=p.max else return end
    self:SetValue(value);return true
end
function M.Slider:OnPointerCancel(event)
    self:SetState({dragging=false})
    return UI.Slider.OnPointerCancel(self,event)
end
M.Checkbox=UI.Button:Extend('VoxGraphicsCheckbox')
function M.Checkbox:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local y=r.y+(r.h-18)/2
    nvgSave(vg);if self.props.disabled then nvgGlobalAlpha(vg,.45) end
    nvgBeginPath(vg);nvgRoundedRect(vg,r.x,y,18,18,2)
    nvgFillColor(vg,D.Color(self.props.checked and D.orange or {59,59,59,255}));nvgFill(vg)
    if self.props.checked then
        nvgBeginPath(vg);nvgMoveTo(vg,r.x+4,y+9);nvgLineTo(vg,r.x+8,y+13);nvgLineTo(vg,r.x+14,y+5)
        nvgStrokeWidth(vg,2.5);nvgStrokeColor(vg,nvgRGBA(59,59,59,255));nvgStroke(vg)
    end
    nvgRestore(vg)
    D.Text(vg,'让方块缝隙和接触处更有体积感',r.x+28,r.y+(r.h-22)/2,18,D.muted)
end
return M

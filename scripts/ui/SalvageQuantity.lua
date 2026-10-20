-- Frozen salvageHub._bindStepper; updates in place so held pointers retain ownership.
local UI=require 'urhox-libs/UI'
local Base=require 'urhox-libs/UI/Widgets/TextField'
local Button=require 'ui.SalvageButton'
local D=require 'ui.SourceDraw'
local Field=Base:Extend('VoxSalvageQuantity')
local Step=Button:Extend('VoxSalvageQuantityStep')
local Row=UI.Panel:Extend('VoxSalvageQuantityRow')
local M={}
-- Shared across module reloads; the last live row restores the engine handler.
local wheelBinding=rawget(UI,'voxSalvageQuantityWheel') or {rows={}}
rawset(UI,'voxSalvageQuantityWheel',wheelBinding)
local function PointerHit()
    local mouse=input.mousePosition;local scale=UI.GetScale()
    return UI.FindWidgetAt(mouse.x/scale,mouse.y/scale)
end
local function QuantityField(widget)
    return widget and widget.quantityRow and wheelBinding.rows[widget.quantityRow] and widget==widget.quantityRow.field
end
local function BindWheel(row)
    wheelBinding.rows[row]=true
    if wheelBinding.previous then return end
    wheelBinding.previous=UI.HandleWheel
    wheelBinding.handler=function(dx,dy)
        -- The host routes wheel to cached hover before refreshing pointer position.
        if QuantityField(PointerHit()) or QuantityField(UI.GetHoveredWidget()) then
            local mouse=input.mousePosition;UI.HandleMouseMove(mouse.x,mouse.y)
        end
        return wheelBinding.previous(dx,dy)
    end
    UI.HandleWheel=wheelBinding.handler
end
local function UnbindWheel(row)
    wheelBinding.rows[row]=nil
    if not next(wheelBinding.rows) and UI.HandleWheel==wheelBinding.handler then
        UI.HandleWheel=wheelBinding.previous;wheelBinding.previous=nil;wheelBinding.handler=nil
    end
end
local function Now() return Time:GetSystemTime() end
local function Prefix(s,n) local b=utf8.offset(s,n+1);return b and s:sub(1,b-1) or s end
function Field:Render(vg)
    D.Begin(vg);self.vg=vg;local r=self:GetAbsoluteLayout();local text=self:GetValue();local st=self.state
    D.Rect(vg,r.x,r.y,r.w,r.h,{0,0,0,89})
    if st.focused then
        D.Rect(vg,r.x,r.y,r.w,2,D.orange);D.Rect(vg,r.x,r.y+r.h-2,r.w,2,D.orange)
        D.Rect(vg,r.x,r.y,2,r.h,D.orange);D.Rect(vg,r.x+r.w-2,r.y,2,r.h,D.orange)
    end
    local x=r.x+(r.w-D.Width(vg,text,28,'vox-tabular'))/2;self.textX=x
    nvgSave(vg);nvgIntersectScissor(vg,r.x+4,r.y,r.w-8,r.h)
    local a,b=self:GetSelectionRange()
    if a then local left=D.Width(vg,Prefix(text,a),28,'vox-tabular');D.Rect(vg,x+left,r.y+9,D.Width(vg,Prefix(text,b),28,'vox-tabular')-left,r.h-18,{75,112,150,180}) end
    D.Text(vg,text,x,r.y+(r.h-28*1.2)/2,28,D.white,'vox-tabular')
    if st.focused and st.cursorBlink then D.Rect(vg,x+D.Width(vg,Prefix(text,st.cursorPos),28,'vox-tabular'),r.y+10,1,r.h-20,D.orange) end
    nvgRestore(vg)
end
function Field:GetCursorPosFromX(x)
    if not self.vg then return 0 end
    local text=self:GetValue();local target=x-(self.textX or self:GetAbsoluteLayout().x);local last=0
    for n=1,utf8.len(text) do local width=D.Width(self.vg,Prefix(text,n),28,'vox-tabular');if target<(last+width)/2 then return n-1 end;last=width end
    return utf8.len(text)
end
function Field:OnBlur()
    Base.OnBlur(self)
    local number=tonumber(self:GetValue():match('^[ \t\r\n]*([+-]?%d+)')) or 1
    self.quantityRow:SetQuantity(number==0 and 1 or number)
end
function Field:OnKeyDown(key)
    if key==KEY_RETURN or key==KEY_KP_ENTER then
        self.quantityRow.owner.salvage.quantityEnterGuard=true;UI.ClearFocus();return true
    end
    Base.OnKeyDown(self,key);return true
end
function Field:OnWheel(_,dy)
    if self.quantityRow.disposed or PointerHit()~=self or dy==0 then return true end
    self.quantityRow:SetQuantity(self.quantityRow.owner.salvage.qty+(dy>0 and 1 or -1));return true
end
function Step:OnPointerDown(event)
    if self.quantityRow.disposed then return end
    Button.OnPointerDown(self,event)
    if not event or not event:IsPrimaryAction() or self.props.disabled then return end
    local row=self.quantityRow;row.hold={pointerId=event.pointerId,direction=self.direction,nextAt=Now()+400,ticks=0}
    row:SetQuantity(row.owner.salvage.qty+self.direction)
end
function Step:OnPointerUp(event)
    if self.quantityRow.disposed then return end
    if event and event:IsPrimaryAction() then self.quantityRow:Stop(event.pointerId) end
    return Button.OnPointerUp(self,event)
end
function Step:OnPointerCancel(event)
    if self.quantityRow.disposed then return end
    self.quantityRow:Stop(event and event.pointerId);return Button.OnPointerCancel(self,event)
end
function Step:OnClick(event)
    if event or self.props.disabled or self.quantityRow.disposed then return end
    self.quantityRow:SetQuantity(self.quantityRow.owner.salvage.qty+self.direction)
end
function Row:SetQuantity(value)
    if self.disposed then return end
    local max=self.maximum();local qty=math.max(1,math.min(max,value));self.owner.salvage.qty=qty
    self.field:SetValue(string.format('%.0f',qty));self.field:SetState({cursorPos=#self.field:GetValue()})
    if qty~=value then self.shakeAt=Now() end
    if self.changed then self.changed(qty) end
end
function Row:Stop(pointerId)
    if self.hold and (pointerId==nil or self.hold.pointerId==pointerId) then self.hold=nil end
end
function Row:Update()
    if self.disposed then return end
    if self.shakeAt then
        local age=Now()-self.shakeAt
        if age>=160 then self.shakeAt=nil;self:SetStyle({translateX=0})
        else self:SetStyle({translateX=age<80 and -4+age/10 or 4-(age-80)/20}) end
    end
    if not input.focus or input.minimized or self.owner.dialog then self:Stop();return end
    local hold=self.hold
    if hold and Now()>=hold.nextAt then
        hold.ticks=hold.ticks+1;hold.nextAt=Now()+70
        self:SetQuantity(self.owner.salvage.qty+hold.direction*(hold.ticks>12 and 5 or 1))
    end
end
function Row:Destroy()
    self:Stop()
    if UI.GetFocus()==self.field then UI.ClearFocus() end
    self.disposed=true;self.changed=nil
    UnbindWheel(self)
    return UI.Panel.Destroy(self)
end
function M.Create(owner,max,x,y,width,changed)
    local row=Row{position='absolute',left=x,top=y,width=width,height=52,flexDirection='row',gap=4}
    row.owner=owner;row.maximum=max;row.changed=changed
    local function Stepper(text,direction)
        local b=owner.Track(Step{text=text,kind='quantity',width=52,height=52,flexShrink=0})
        b.quantityRow=row;b.direction=direction;return b
    end
    row:AddChild(Stepper('-',-1))
    local field=Field{value=tostring(owner.salvage.qty),width=width-188,height=52,flexShrink=0}
    field.quantityRow=row;row.field=field;row:AddChild(field)
    row:AddChild(Stepper('+',1))
    row:AddChild(owner.Track(Button{text='最大',kind='quantity',width=72,height=52,onClick=function() row:SetQuantity(math.max(1,max())) end}))
    BindWheel(row)
    return row
end
return M

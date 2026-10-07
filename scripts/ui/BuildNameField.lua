local Base=require 'urhox-libs/UI/Widgets/TextField'
local D=require 'ui.SourceDraw'
local Field=Base:Extend('VoxBuildNameField')
local function Prefix(s,n) local b=utf8.offset(s,n+1);return b and s:sub(1,b-1) or s end
function Field:Render(vg)
    D.Begin(vg);self.vg=vg;local r=self:GetAbsoluteLayout();local text=self:GetValue();local st=self.state;local size=self.props.sourceFontSize or 34;local top=r.y+(44-size)/2-4
    nvgSave(vg);nvgIntersectScissor(vg,r.x+6,r.y,r.w-12,r.h)
    local cursor=D.Width(vg,Prefix(text,st.cursorPos),size,nil,.5)
    self.scrollX_=st.focused and math.max(0,cursor-r.w+20) or 0
    local x=r.x+6-self.scrollX_;local a,b=self:GetSelectionRange()
    if a then local left=D.Width(vg,Prefix(text,a),size,nil,.5);D.Rect(vg,x+left,top+1,D.Width(vg,Prefix(text,b),size,nil,.5)-left,size+4,{75,112,150,180}) end
    D.Text(vg,text,x,top,size,nil,nil,nil,.5)
    if st.focused and st.cursorBlink then D.Rect(vg,x+cursor,top+2,1,size+2,D.white) end
    nvgRestore(vg)
    if st.focused or st.hovered then D.Rect(vg,r.x,r.y+r.h-2,r.w,2,st.focused and D.orange or {255,255,255,64}) end
end
function Field:GetCursorPosFromX(x)
    if not self.vg then return 0 end
    local size=self.props.sourceFontSize or 34
    local target=x-self:GetAbsoluteLayout().x-6+(self.scrollX_ or 0);local text=self:GetValue();local last=0
    for n=1,utf8.len(text) do local width=D.Width(self.vg,Prefix(text,n),size,nil,.5);if target<(last+width)/2 then return n-1 end;last=width end
    return utf8.len(text)
end
return Field

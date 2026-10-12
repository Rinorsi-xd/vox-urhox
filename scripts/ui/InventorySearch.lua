local Base=require 'urhox-libs/UI/Widgets/TextField'
local D=require 'ui.SourceDraw'
local Field=Base:Extend('VoxInventorySearch')
local function Prefix(s,n) local b=utf8.offset(s,n+1);return b and s:sub(1,b-1) or s end
function Field:Render(vg)
    D.Begin(vg);self.vg=vg;local r=self:GetAbsoluteLayout();local text=self:GetValue();local st=self.state
    local solid=self.props.solid;local inset=solid and 42 or 40;local size=self.props.sourceSize or (solid and 16 or 15)
    if solid then
        D.Rect(vg,r.x,r.y,r.w,r.h,{0,0,0,89})
        if st.focused then D.Path(vg,{r.x+1,r.y+1,r.x+r.w-1,r.y+1,r.x+r.w-1,r.y+r.h-1,r.x+1,r.y+r.h-1});nvgStrokeColor(vg,D.Color(D.orange));nvgStrokeWidth(vg,2);nvgStroke(vg) end
    else D.Rect(vg,r.x,r.y+r.h-1,r.w,st.focused and 3 or 1,st.focused and D.orange or {86,114,142,255}) end
    D.Icon(vg,'search',r.x+(solid and 12 or 10),r.y+(r.h-20)/2,20,st.focused and D.orange or D.muted)
    nvgSave(vg);nvgIntersectScissor(vg,r.x+inset,r.y,r.w-inset-4,r.h)
    local cursor=D.Width(vg,Prefix(text,st.cursorPos),size,'vox-body')
    self.scrollX_=st.focused and math.max(0,cursor-r.w+inset+16) or 0
    local x=r.x+inset-self.scrollX_;local a,b=self:GetSelectionRange()
    if a then local left=D.Width(vg,Prefix(text,a),size,'vox-body');D.Rect(vg,x+left,r.y+9,D.Width(vg,Prefix(text,b),size,'vox-body')-left,24,{75,112,150,180}) end
    D.Text(vg,text=='' and (self.props.placeholder or '搜索零件：名称或说明') or text,x,r.y+(r.h-size*1.2)/2,size,text=='' and D.dim or D.white,'vox-body')
    if st.focused and st.cursorBlink then D.Rect(vg,x+cursor,r.y+10,1,22,D.white) end;nvgRestore(vg)
end
function Field:GetCursorPosFromX(x)
    if not self.vg then return 0 end
    local target=x-self:GetAbsoluteLayout().x-(self.props.solid and 42 or 40)+(self.scrollX_ or 0);local text=self:GetValue();local last=0
    for n=1,utf8.len(text) do local width=D.Width(self.vg,Prefix(text,n),self.props.sourceSize or (self.props.solid and 16 or 15),'vox-body');if target<(last+width)/2 then return n-1 end;last=width end
    return utf8.len(text)
end
return Field

local Base=require 'urhox-libs/UI/Widgets/TextField'
local D=require 'ui.SourceDraw'
local Field=Base:Extend('VoxInventorySearch')
local function Prefix(s,n) local b=utf8.offset(s,n+1);return b and s:sub(1,b-1) or s end
function Field:Render(vg)
    D.Begin(vg);self.vg=vg;local r=self:GetAbsoluteLayout();local text=self:GetValue();local st=self.state
    D.Icon(vg,'search',r.x+4,r.y+10,20,st.focused and D.white or D.muted)
    D.Rect(vg,r.x,r.y+r.h-2,r.w,2,st.focused and D.orange or {255,255,255,46})
    nvgSave(vg);nvgIntersectScissor(vg,r.x+32,r.y,r.w-36,r.h)
    local cursor=D.Width(vg,Prefix(text,st.cursorPos),15,'vox-body')
    self.scrollX_=st.focused and math.max(0,cursor-r.w+48) or 0
    local x=r.x+32-self.scrollX_;local a,b=self:GetSelectionRange()
    if a then local left=D.Width(vg,Prefix(text,a),15,'vox-body');D.Rect(vg,x+left,r.y+9,D.Width(vg,Prefix(text,b),15,'vox-body')-left,24,{75,112,150,180}) end
    D.Text(vg,text=='' and '搜索零件：名称或说明' or text,x,r.y+11,15,text=='' and D.dim or D.white,'vox-body')
    if st.focused and st.cursorBlink then D.Rect(vg,x+cursor,r.y+10,1,22,D.white) end;nvgRestore(vg)
end
function Field:GetCursorPosFromX(x)
    if not self.vg then return 0 end
    local target=x-self:GetAbsoluteLayout().x-32+(self.scrollX_ or 0);local text=self:GetValue();local last=0
    for n=1,utf8.len(text) do local width=D.Width(self.vg,Prefix(text,n),15,'vox-body');if target<(last+width)/2 then return n-1 end;last=width end
    return utf8.len(text)
end
return Field

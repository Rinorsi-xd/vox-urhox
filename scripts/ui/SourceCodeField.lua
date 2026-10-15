-- Blueprint textarea: native text editing/clipboard, wrapped NanoVG rendering.
-- Cache line breaks on text/width changes, and draw only the visible rows.
local Base=require 'urhox-libs/UI/Widgets/TextField'
local D=require 'ui.SourceDraw'
local Field=Base:Extend('VoxSourceCodeField')
local LINE=18
function Field:SetValue(value)
    Base.SetValue(self,value)
    local length=utf8.len(value) or 0
    self.state.cursorPos=math.min(self.state.cursorPos,length)
    if self.state.selectionStart then self.state.selectionStart=math.min(self.state.selectionStart,length) end
    if self.state.selectionEnd then self.state.selectionEnd=math.min(self.state.selectionEnd,length) end
    return self
end
function Field:RefreshMeasure()
    if self.vg then self:Measure(self.vg,self:GetAbsoluteLayout().w-24) end
end
function Field:Measure(vg,width)
    local text=self.props.value or ''
    if self.cachedText==text and self.cachedWidth==width then return end
    local rows={};local count,start,byteStart,advance=0,0,1,0;local widths={}
    for offset,code in utf8.codes(text) do
        local character=utf8.char(code)
        local cw=widths[code]
        if not cw then cw=D.Width(vg,character,12,'vox-code');widths[code]=cw end
        if code==10 then
            rows[#rows+1]={text=text:sub(byteStart,offset-1),start=start,finish=count}
            start=count+1;byteStart=offset+1;advance=0
        else
            if advance+cw>width and count>start then
                rows[#rows+1]={text=text:sub(byteStart,offset-1),start=start,finish=count}
                start=count;byteStart=offset;advance=0
            end
            advance=advance+cw
        end
        count=count+1
    end
    rows[#rows+1]={text=text:sub(byteStart),start=start,finish=count}
    self.lines=rows;self.length=count;self.cachedText=text;self.cachedWidth=width
    self.metricsBuilds=(self.metricsBuilds or 0)+1
end
function Field:RowAt(position)
    local rows=self.lines or {{text='',start=0,finish=0}};local lo,hi=1,#rows
    while lo<hi do local mid=math.floor((lo+hi+1)/2);if rows[mid].start<=position then lo=mid else hi=mid-1 end end
    return lo,rows[lo]
end
local function Prefix(text,characters)
    if characters<=0 then return '' end
    local ending=utf8.offset(text,characters+1)
    return ending and text:sub(1,ending-1) or text
end
function Field:Render(vg)
    D.Begin(vg);self.vg=vg;local r=self:GetAbsoluteLayout();local st=self.state
    self:Measure(vg,r.w-24)
    D.Rect(vg,r.x,r.y,r.w,r.h,{0,0,0,89})
    nvgBeginPath(vg);nvgRect(vg,r.x+.5,r.y+.5,r.w-1,r.h-1);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,D.Color(st.focused and D.orange or {255,255,255,20}));nvgStroke(vg)
    local visible=math.max(1,math.floor((r.h-24)/LINE));local rowIndex,row=self:RowAt(st.cursorPos)
    local top=self.topRow or 1
    if self.lastCursor~=st.cursorPos then top=math.min(top,rowIndex);if rowIndex>=top+visible then top=rowIndex-visible+1 end;self.lastCursor=st.cursorPos end
    top=math.max(1,math.min(top,math.max(1,#self.lines-visible+1)));self.topRow=top
    nvgSave(vg);nvgIntersectScissor(vg,r.x+12,r.y+12,r.w-24,r.h-24)
    local a,b=self:GetSelectionRange();self.visibleRows=0
    for i=top,math.min(#self.lines,top+visible) do
        local item=self.lines[i];local y=r.y+12+(i-top)*LINE
        if a and b>item.start and a<=item.finish then
            local x1=D.Width(vg,Prefix(item.text,math.max(0,a-item.start)),12,'vox-code')
            local x2=D.Width(vg,Prefix(item.text,math.min(item.finish,b)-item.start),12,'vox-code')
            D.Rect(vg,r.x+12+x1,y,math.max(2,x2-x1),LINE,{75,112,150,180})
        end
        D.Text(vg,item.text,r.x+12,y,12,D.white,'vox-code');self.visibleRows=self.visibleRows+1
    end
    if self.length==0 then D.Text(vg,self.props.placeholder or 'FKZC1:...',r.x+12,r.y+12,12,D.dim,'vox-code') end
    if st.focused and st.cursorBlink and rowIndex>=top and rowIndex<top+visible then
        local cx=D.Width(vg,Prefix(row.text,st.cursorPos-row.start),12,'vox-code')
        D.Rect(vg,r.x+12+cx,r.y+12+(rowIndex-top)*LINE,1,LINE,D.white)
    end
    nvgRestore(vg)
end
function Field:GetCursorPosFromX(x)
    self:RefreshMeasure()
    if not self.lines or not self.vg then return 0 end
    local r=self:GetAbsoluteLayout();local index=math.max(1,math.min(#self.lines,(self.topRow or 1)+math.floor(((self.pointerY or r.y+12)-r.y-12)/LINE)))
    local row=self.lines[index];local target=x-r.x-12;local count,advance=0,0
    for _,code in utf8.codes(row.text) do local width=D.Width(self.vg,utf8.char(code),12,'vox-code');if target<advance+width/2 then break end;advance=advance+width;count=count+1 end
    return row.start+count
end
function Field:OnPointerDown(e) self.pointerY=e.y;return Base.OnPointerDown(self,e) end
function Field:OnPointerMove(e) self.pointerY=e.y;return Base.OnPointerMove(self,e) end
function Field:OnClick(e) self.pointerY=e.y;return Base.OnClick(self,e) end
function Field:OnPanMove(e) self.pointerY=e.y;return Base.OnPanMove(self,e) end
function Field:OnDoubleTap(e) self.pointerY=e.y;return Base.OnDoubleTap(self,e) end
function Field:OnWheel(_,dy)
    self.topRow=math.max(1,(self.topRow or 1)-(dy or 0)*3);return true
end
function Field:OnTextInput(text) if not self.props.readOnly then return Base.OnTextInput(self,text) end end
function Field:DoCut() if not self.props.readOnly then return Base.DoCut(self) end end
function Field:OnKeyDown(key)
    if not self.state.focused or self.props.disabled then return end
    self:RefreshMeasure()
    if self.props.readOnly and (key==KEY_BACKSPACE or key==KEY_DELETE or key==KEY_RETURN or key==KEY_KP_ENTER) then return end
    if key==KEY_RETURN or key==KEY_KP_ENTER then return self:OnTextInput('\n') end
    if self.lines and (key==KEY_UP or key==KEY_DOWN or key==KEY_HOME or key==KEY_END or key==KEY_LEFT or key==KEY_RIGHT) then
        local i,row=self:RowAt(self.state.cursorPos);local target=self.state.cursorPos
        local ctrl=input:GetQualifierDown(QUAL_CTRL);local shift=input:GetQualifierDown(QUAL_SHIFT)
        if key==KEY_HOME then target=ctrl and 0 or row.start elseif key==KEY_END then target=ctrl and self.length or row.finish
        elseif key==KEY_LEFT or key==KEY_RIGHT then
            local a,b=self:GetSelectionRange()
            if a and not shift then target=key==KEY_LEFT and a or b
            else target=math.max(0,math.min(self.length,target+(key==KEY_LEFT and -1 or 1))) end
        else local nextRow=self.lines[math.max(1,math.min(#self.lines,i+(key==KEY_UP and -1 or 1)))];target=math.min(nextRow.finish,nextRow.start+target-row.start) end
        if shift then self.state.selectionStart=self.state.selectionStart or self.state.cursorPos;self.state.selectionEnd=target else self:ClearSelection() end
        self:SetState({cursorPos=target,cursorBlink=true});self.blinkTimer_=0;return
    end
    return Base.OnKeyDown(self,key)
end
return Field

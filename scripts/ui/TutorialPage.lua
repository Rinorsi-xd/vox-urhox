-- Source tutorial.css and NonoComms composition in the UI-owned VG frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local F=require 'ui.MissionFrame'
local Paragraph=require 'ui.SourceParagraph'
local Paint=require 'ui.WorkshopPaint'
local Page=UI.Widget:Extend('VoxTutorialPage')
local M={}
local cyan={70,200,255,255};local ink={4,18,31,255};local white={244,245,247,255}
local function Inside(r,x,y) return r and x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end
function M.New(owner)
    local page=Page{pointerEvents='auto',focusable=false};page.owner=owner;page.pointers={};page.buttons={}
    page.paragraph=Paragraph.New(19,30.4);page.hint=Paragraph.New(14,22)
    UI.RegisterGlobalComponent('vox-tutorial',page);return page
end
function Page:GetAbsoluteLayout() local w,h=UI.GetViewportSize();return {x=0,y=0,w=w,h=h} end
function Page:GetAbsoluteLayoutForHitTest() return self:GetAbsoluteLayout() end
function Page:HitTest(x,y) return self.owner.visible and Inside(self.cardRect,x,y) end
function Page:OnPointerDown(e) self.pointers[e.pointerId]=e.pointerType;return true end
function Page:OnPointerUp(e) self.pointers[e.pointerId]=nil;return true end
function Page:OnPointerCancel(e) self.pointers[e.pointerId]=nil;return true end
function Page:OnClick(e)
    for _,b in ipairs(self.buttons) do if Inside(b,e.x,e.y) then
        if b.id=='next' then self.owner:Advance()
        elseif b.id=='skip' then self.owner:Skip()
        else self.owner:Choose(b.id) end
        return true
    end end
    return true
end
function Page:CancelInput()
    for id,kind in pairs(self.pointers) do UI.CancelPointer(id,kind) end
    self.pointers={}
end
function Page:Close() self:CancelInput();UI.UnregisterGlobalComponent('vox-tutorial') end
function Page:Update(dt) self.owner:Update(dt) end
function Page:Target()
    local a=self.owner.app;local h=require('ui.GarageHud').GetState();local b=a.build
    local id=self.owner.rules:StepSpec().id;local widgets={}
    if h then
        if id=='car' then widgets={h.info}
        elseif id=='bays' then widgets={h.bayScroll}
        elseif id=='choose' then widgets={h.buttons.edit,h.buttons.battle}
        elseif id=='edit' then widgets={h.buttons.edit}
        elseif id=='battle' then widgets={h.buttons.battle}
        elseif id=='story' or id=='go' or id=='leave' then
            local text=({story='剧情模式',go='开始任务',leave='选择模式'})[id]
            local function Find(w)
                if w:IsVisible() and w.props.text==text then widgets[#widgets+1]=w end
                for _,child in ipairs(w.children or {}) do if child:IsVisible() then Find(child) end end
            end
            Find(h.root)
        end
    end
    if b then
        if id=='bag' or id=='place' then widgets={b.hud.hotbar.root}
        elseif id=='pick' then widgets={b.inventoryPanel and b.inventoryPanel.body}
        elseif id=='save' then widgets={b.hud.buttons.save}
        elseif id=='back' then widgets={b.hud.buttons.home} end
    end
    local union=false
    for _,widget in ipairs(widgets) do if widget and widget:IsVisible() then
        local r=widget:GetAbsoluteLayoutForHitTest()
        if r.w>2 and r.h>2 then
            if not union then union={x=r.x,y=r.y,w=r.w,h=r.h}
            else local x,y=math.min(union.x,r.x),math.min(union.y,r.y)
                union={x=x,y=y,w=math.max(union.x+union.w,r.x+r.w)-x,h=math.max(union.y+union.h,r.y+r.h)-y} end
        end
    end end
    return union
end
local function Button(vg,id,text,x,y,w,ready,buttons,k)
    local color=id=='skip' and {255,255,255,18} or ready and cyan or {70,200,255,41}
    D.Path(vg,{x,y,x+w,y,x+w-(id=='skip' and 0 or 10),y+34*k,x,y+34*k})
    nvgFillColor(vg,D.Color(color));nvgFill(vg)
    D.Text(vg,text,x+w/2,y+7*k,15*k,ready and ink or id=='skip' and {170,182,192,255} or white,'vox-story',NVG_ALIGN_CENTER)
    buttons[#buttons+1]={id=id,text=text,x=x,y=y,w=w,h=34*k}
end
function Page:Render(vg)
    local t=self.owner;if not t.visible then return end
    D.Begin(vg);local w,h=UI.GetViewportSize();local s=t.rules:StepSpec()
    local touch=require('controls.TouchMode').Enabled();local k=touch and math.max(.65,math.min(1,h/760)) or math.min(1,w/740)
    local cw=660*k;local hint=s.hint and s.hint:gsub('<[^>]+>','') or ''
    local line=s.lines[t.line];self.paragraph.size=19*k;self.paragraph.lineHeight=30.4*k
    local commHeight=math.max(180*k,self.paragraph:Measure(vg,line[2],cw-206*k,white).height+92*k)
    if touch then
        hint=({bag='长按快捷栏打开零件库',pick='点选零件，选好后点「关闭」',place='滑动画面转向，选底部「放置」后点车身装一块；选「删除」拆除',save='点上方「保存」，把战车存进车位'})[s.id] or hint
    end
    self.hint.size=14*k;self.hint.lineHeight=22*k
    local hintHeight=hint~='' and self.hint:Measure(vg,hint,cw-190*k).height+14*k or 0
    local ch=commHeight+hintHeight+86*k+(s.choice and 40*k or 0)
    local r=self:Target();self.targetRect=r
    local x,y=(w-cw)/2,h*.62-ch/2
    if r then
        local pad=10;local l,top=math.max(0,r.x-pad),math.max(0,r.y-pad)
        local rw,rh=math.min(w,r.x+r.w+pad)-l,math.min(h,r.y+r.h+pad)-top
        D.Rect(vg,0,0,w,top,{2,7,12,158});D.Rect(vg,0,top,l,rh,{2,7,12,158})
        D.Rect(vg,l+rw,top,w-l-rw,rh,{2,7,12,158});D.Rect(vg,0,top+rh,w,h-top-rh,{2,7,12,158})
        local color=t.rules.doneAt and D.green or cyan
        nvgBeginPath(vg);nvgRect(vg,l,top,rw,rh);nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,1.5);nvgStroke(vg)
        local pulse=4*(.5-.5*math.cos(t.rules.elapsed*math.pi*2/1.6));local bracket=18
        for _,p in ipairs({{l-9-pulse,top-9-pulse,1,1},{l+rw+9+pulse,top-9-pulse,-1,1},{l-9-pulse,top+rh+9+pulse,1,-1},{l+rw+9+pulse,top+rh+9+pulse,-1,-1}}) do
            D.Line(vg,p[1],p[2],p[1]+p[3]*bracket,p[2],color,3);D.Line(vg,p[1],p[2],p[1],p[2]+p[4]*bracket,color,3)
        end
        local tagY=top<60 and top+rh+14 or top-38
        D.Rect(vg,l,tagY,30,24,{4,14,24,217});D.Text(vg,string.format('%02d',t.rules.index),l+15,tagY+2,18,cyan,'vox-story',NVG_ALIGN_CENTER)
        D.Text(vg,'//  +  '..s.title,l+40,tagY+2,19,white,'vox-story')
        local cy=math.max(20,math.min(h-ch-20,top+rh/2-ch/2))
        if l+rw+30+cw<w then x=l+rw+30;y=cy
        elseif l-30-cw>0 then x=l-30-cw;y=cy
        else x=math.max(20,math.min(w-cw-20,l+rw/2-cw/2));y=top-ch-30>20 and top-ch-30 or math.min(h-ch-20,top+rh+30) end
    else D.Rect(vg,0,0,w,h,{2,7,12,115}) end
    if s.card=='corner' then x=w-cw-24;y=h-ch-24 end
    x=math.max(12,math.min(w-cw-12,x));y=math.max(12,math.min(h-ch-12,y))
    self.cardRect={x=x,y=y,w=cw,h=ch};self.buttons={}
    local count=utf8.len(line[2]);local n=math.min(count,math.floor(count*t.lineAge/math.max(.001,t.typing or count*.032)));local offset=utf8.offset(line[2],n+1)
    local text=offset and line[2]:sub(1,offset-1) or line[2]
    local face=line[3] or 'nono_talk'
    F.Draw(vg,x,y,150*k,commHeight,12,cyan);nvgSave(vg);nvgScissor(vg,x,y,150*k,commHeight)
    Paint.Image(vg,'UI/Faces/'..face..'.png',{x=x-70*k,y=y-2*k,w=330*k,h=410*k},1,0,nil,nil,0)
    for yy=3,commHeight/k,3 do D.Rect(vg,x,y+yy*k,150*k,k,{70,200,255,18}) end;nvgRestore(vg)
    local cx=x+166*k;F.Draw(vg,cx,y,cw-166*k,commHeight,12,cyan)
    D.Text(vg,'INCOMING · 诺诺',cx+20*k,y+16*k,16*k,cyan,'vox-story')
    D.Text(vg,'战术领航员',cx+20*k,y+42*k,12*k,D.muted,'vox-body')
    self.paragraph.size=19*k;self.paragraph.lineHeight=30.4*k
    self.paragraph:Draw(vg,text,cx+20*k,y+64*k,cw-206*k,white)
    D.Text(vg,'CH-07 · 64 KBPS · ENC',cx+20*k,y+commHeight-20*k,10*k,D.muted,'vox-story')
    local by=y+commHeight+12*k
    if hint~='' then
        D.Rect(vg,cx,by,cw-166*k,hintHeight,{6,14,22,184});D.Rect(vg,cx,by,2*k,hintHeight,cyan)
        self.hint:Draw(vg,hint,cx+12*k,by+7*k,cw-190*k,{223,234,242,255});by=by+hintHeight+12*k
    end
    D.Text(vg,string.format('%02d / %02d · %s',t.rules.index,#t.rules.flow,s.title),cx,by+8*k,13*k,{159,179,194,255},'vox-story')
    by=by+30*k
    if s.choice then
        by=by+36*k
        Button(vg,'build','先学改车',cx,by,136*k,true,self.buttons,k)
        Button(vg,'drive','先上前线',cx+144*k,by,136*k,true,self.buttons,k)
    end
    local skip=t.skipConfirm and t.skipConfirm>0 and '确定跳过？再点一次' or '跳过引导'
    local sw=(t.skipConfirm and t.skipConfirm>0 and 190 or 110)*k
    if s.next=='button' then
        Button(vg,'next',touch and '下一步' or '下一步 Space',x+cw-134*k,by,134*k,n==count and t.line==#s.lines,self.buttons,k)
        Button(vg,'skip',skip,x+cw-144*k-sw,by,sw,false,self.buttons,k)
    else Button(vg,'skip',skip,x+cw-sw,by,sw,false,self.buttons,k) end
end
return M

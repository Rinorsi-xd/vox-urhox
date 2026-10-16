-- Source tutorial.css and NonoComms composition in the UI-owned VG frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Comms=require 'ui.CommsCard'
local Paragraph=require 'ui.SourceParagraph'
local Page=UI.Widget:Extend('VoxTutorialPage')
local M={}
local cyan={70,200,255,255};local ink={4,18,31,255};local white={244,245,247,255}
local function Inside(r,x,y) return r and x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end
function M.New(owner)
    local page=Page{pointerEvents='auto',focusable=false};page.owner=owner;page.pointers={};page.buttons={}
    page.hint=Paragraph.New(14,'normal');page.hint.font='vox-title'
    UI.RegisterGlobalComponent('vox-tutorial',page);return page
end
function Page:GetAbsoluteLayout() local w,h=UI.GetViewportSize();return {x=0,y=0,w=w,h=h} end
function Page:GetAbsoluteLayoutForHitTest() return self:GetAbsoluteLayout() end
function Page:HitTest(x,y) return self.owner.visible and Inside(self.cardRect,x,y) end
function Page:UiSoundButtonAt(x,y)
    if not self.owner.visible then return false end
    for _,button in ipairs(self.buttons) do if Inside(button,x,y) then return true end end
    return false
end
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
        local hud=b.hud;local touch=hud.touchControls
        local function Add(widget) if widget then widgets[#widgets+1]=widget end end
        if id=='bag' or id=='place' then
            Add(hud.hotbar.root)
            if touch then
                if id=='bag' then Add(touch.buttons['me-bag'])
                else for _,slot in ipairs(touch.slots) do Add(slot) end end
            end
        elseif id=='pick' then Add(b.inventoryPanel and b.inventoryPanel.body)
        elseif id=='save' then Add(hud.buttons.save);if touch then Add(touch.buttons['me-save']) end
        elseif id=='back' then Add(hud.buttons.home);if touch then Add(touch.buttons['me-back']) end end
    end
    local function Visible(widget)
        while widget do if not widget:IsVisible() then return false end;widget=widget.parent end
        return true
    end
    local union=false
    for _,widget in ipairs(widgets) do if widget and Visible(widget) then
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
    D.Text(vg,text,x+w/2,y+7*k,15*k,ready and ink or id=='skip' and {170,182,192,255} or white,'vox-legacy-display',NVG_ALIGN_CENTER,2*k)
    buttons[#buttons+1]={id=id,text=text,x=x,y=y,w=w,h=34*k}
end
function Page:Render(vg)
    local t=self.owner;if not t.visible then return end
    D.Begin(vg);local w,h=UI.GetViewportSize();local s=t.rules:StepSpec()
    local touch=require('controls.TouchMode').Enabled();local k=touch and math.max(.65,math.min(1,h/760)) or math.min(1,w/740)
    local cw=660*k;local hint=(t:Hint() or ''):gsub('<[^>]+>','')
    local lines=t:Lines();local line=lines[t.line]
    local card=t.voice and t.voice.card or {who=line[1],text=line[2],face=line[3],age=t.lineAge or 0,typing=t.typing or utf8.len(line[2])*.032}
    local commHeight=Comms.Height(vg,card,660,180)*k
    self.hint.size=14*k;self.hint.lineHeight='normal'
    local hintHeight=hint~='' and self.hint:Measure(vg,hint,cw-190*k).height+14*k or 0
    local number=string.format('%02d',t.rules.index)
    local step=string.format(' / %02d · %s',#t.rules.flow,s.title)
    local numberWidth=D.Width(vg,number,18*k,'vox-legacy-display',k)
    local infoWidth=numberWidth+D.Width(vg,step,13*k,'vox-legacy-display',k)+10*k
    local waitWidth=s.next~='button' and 13*k+D.Width(vg,'等你操作',12*k,'vox-title')+10*k or 0
    local skip=t.skipConfirm and t.skipConfirm>0 and '确定跳过？再点一次' or '跳过引导'
    local sw=D.Width(vg,skip,15*k,'vox-legacy-display',2*k)+28*k
    -- Reserve the confirmation label before the first click so it cannot cover
    -- a route choice or move onto a different row during the second click.
    local reserveSkip=D.Width(vg,'确定跳过？再点一次',15*k,'vox-legacy-display',2*k)+28*k
    local controlWidth=cw-166*k
    local row=0;local used=infoWidth+waitWidth;local choiceRow=0;local choiceX=used
    local pw=D.Width(vg,'先学改车',15*k,'vox-legacy-display',2*k)+36*k
    if s.choice then
        local picksWidth=pw*2+8*k
        if used+picksWidth>controlWidth then row=row+1;used=0;choiceRow=row;choiceX=0 end
        used=used+picksWidth+10*k
    end
    local nextWidth=s.next=='button' and 134*k or 0
    local actionWidth=reserveSkip+(nextWidth>0 and nextWidth+10*k or 0)
    if used+actionWidth>controlWidth then row=row+1 end
    local actionRow=row
    local ch=commHeight+(hint~='' and hintHeight+10*k or 0)+46*k+row*44*k
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
    -- The battle HUD's bottom offset does not belong to this tutorial stack.
    local commY=y
    self.cardRect={x=x,y=commY,w=cw,h=ch};self.buttons={}
    local count=utf8.len(line[2]);local n=utf8.len(Comms.Typed(card))
    Comms.Draw(vg,card,x,commY,660,commHeight/k,k,t.voice and t.voice.time or t.lineAge,180)
    local cx=x+166*k
    local by=y+commHeight+10*k
    if hint~='' then
        D.Rect(vg,cx,by,cw-166*k,hintHeight,{6,14,22,184});D.Rect(vg,cx,by,2*k,hintHeight,cyan)
        self.hint:Draw(vg,hint,cx+12*k,by+7*k,cw-190*k,{223,234,242,255});by=by+hintHeight+2*k
    end
    by=by+2*k
    D.Text(vg,number,cx,by+6*k,18*k,cyan,'vox-legacy-display',nil,k)
    D.Text(vg,step,cx+numberWidth,by+8*k,13*k,{159,179,194,255},'vox-legacy-display',nil,k)
    local afterStep=cx+infoWidth
    if s.next~='button' then
        D.Rect(vg,afterStep,by+14*k,7*k,7*k,{255,176,46,255})
        D.Text(vg,'等你操作',afterStep+13*k,by+10*k,12*k,{255,207,106,255},'vox-title')
    end
    if s.choice then
        local px=cx+choiceX;local py=by+choiceRow*44*k
        Button(vg,'build','先学改车',px,py,pw,true,self.buttons,k)
        Button(vg,'drive','先上前线',px+pw+8*k,py,pw,true,self.buttons,k)
    end
    local actionY=by+actionRow*44*k
    if s.next=='button' then
        Button(vg,'next',touch and '下一步' or '下一步 Space',x+cw-134*k,actionY,134*k,n==count and t.line==#lines,self.buttons,k)
        Button(vg,'skip',skip,x+cw-144*k-sw,actionY,sw,false,self.buttons,k)
    else Button(vg,'skip',skip,x+cw-sw,actionY,sw,false,self.buttons,k) end
end
return M

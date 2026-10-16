-- Final October 14 new-ui-drive.css readouts. World-space reticle stays outside
-- this scaled surface, while details, summary and entry use the H5 UI viewport.
local Wheel=require("controls.Wheel")
local SourceButtonMotion=require("ui.SourceButtonMotion")

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Rich=require 'ui.SourceRichText'
local Readout=require 'ui.DriveReadout'
local Panel=UI.Panel:Extend('VoxDriveReadouts')
local M={}
local body={222,235,248,255};local muted={168,186,208,255};local heading={166,212,241,255}
local summaryShadows={{x=0,y=1,blur=2,color={7,17,30,255}},{x=0,y=0,blur=8,color={7,17,30,204}}}
local entryShadows={{x=0,y=2,blur=8,color={7,17,30,255}}}
local keyTokens={{'W'},{'S'},' 油门 · ',{'A'},{'D'},' 转向 · ',{'Q/E'},' 横移 · ',{'空格/Shift'},' 升降（松开定高） · ',{'X'},
    ' 关闭推进定高 · 悬浮调离地高度；节足空格跳跃、空中按住接推进；轮式车空格手刹 · 鼠标 瞄准 · 左键 开火 · 右键 开镜（点一下切换） · ',{'1-6'},' 换武器 · ',
    {'R'},' 翻正 · ',{'C'},' 镜头跟车 · '}
local function In(r,x,y) return r and x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end
local function Paragraph(vg,text,width,size,lineHeight,color)
    return Rich.Layout(vg,{{{text=text,font='vox-body',size=size,color=color or body}}},width,lineHeight)
end
local function ShadowParagraph(vg,layout,x,y)
    for _,line in ipairs(layout.lines) do
        local lx=x+(layout.width-line.width)/2
        for _,run in ipairs(line.runs) do D.Text(vg,run.text,lx+run.x,y+line.y+line.baseline,run.size,run.color,run.font,nil,run.spacing,true,nil,summaryShadows) end
    end
end
function M.Viewport(w,h,cw,ch,touch)
    local ref=touch and 600 or 1080;local scale=math.min(cw/(ref*16/9),ch/ref)*(touch and .85 or 1)
    local k=w/cw*scale
    return {w=w/k,h=h/k,k=k,compact=ch/scale<=600,touch=touch}
end
function M.New(session,root,details)
    local self=Panel{position='absolute',width='100%',height='100%',pointerEvents='auto'}
    self.session=session;self.details=details;self.scroll=0;self.entryTime=0;self.entryPending=not session.story
    self.layouts={};root:AddChild(self);return self
end
function Panel:Toggle() self.session.details=not self.session.details end
function Panel:HitTest(x,y)
    if not self:IsVisible() then return false end
    local k=self.geometry and self.geometry.k or 1
    return In(self.toggleRect,x/k,y/k) or self.session.details and In(self.expandedRect,x/k,y/k)
end
function Panel:OnPointerDown(e)
    local k=self.geometry and self.geometry.k or 1
    if In(self.toggleRect,e.x/k,e.y/k) then self.togglePointer=e.pointerId;return true end
    if self.session.details and In(self.expandedRect,e.x/k,e.y/k) then self.dragY=e.y/k;self.dragPointer=e.pointerId;return true end
    return false
end
function Panel:OnPointerMove(e)
    if self.dragY and self.dragPointer==e.pointerId then local y=e.y/(self.geometry and self.geometry.k or 1);self:ScrollDetails(self.dragY-y);self.dragY=y;return true end
end
function Panel:OnPointerUp(e)
    if self.togglePointer and self.togglePointer==e.pointerId then
        local k=self.geometry and self.geometry.k or 1
        if In(self.toggleRect,e.x/k,e.y/k) then self:Toggle() end
    end
    if self.togglePointer==e.pointerId then self.togglePointer=nil end
    if self.dragPointer==e.pointerId then self.dragY=nil;self.dragPointer=nil end
    return true
end
function Panel:OnPointerCancel(e)
    if not e or self.togglePointer==e.pointerId then self.togglePointer=nil end
    if not e or self.dragPointer==e.pointerId then self.dragY=nil;self.dragPointer=nil end
end
function Panel:ScrollDetails(delta)
    if not self.session.details then return false end
    self.scroll=math.max(0,math.min(self.maxScroll or 0,self.scroll+delta));return true
end
function Panel:OnWheel(_,dy)
    -- PC consumes the same wheel once in TrialSession, also while unlocked.
    if not self.session.touch then return false end
    return self:ScrollDetails(Wheel.Pixels(dy))
end
function Panel:Tick(dt,covered)
    if self.session.story then self.entryPending=false;self.entryTime=0;return end
    if covered then return end
    if self.entryPending then self.entryPending=false;self.entryTime=3.6 else self.entryTime=math.max(0,self.entryTime-dt) end
end
function Panel:Refresh()
    local s=self.session;self.speed=Readout.Speed(s.vehicle);self.motion=Readout.Motion(s.vehicle)
    self.alert,self.state=Readout.Summary(s.vehicle.telemetry)
end
function Panel:LayoutText(vg,key,text,width,size,lineHeight,color)
    local cache=self.layouts[key]
    if not cache or cache.text~=text or cache.width~=width then
        cache={text=text,width=width,layout=Paragraph(vg,text,width,size,lineHeight,color)};self.layouts[key]=cache
    end
    return cache.layout
end
function Panel:Keys(vg,width)
    local s=self.session;local tag=(s.battle and 'battle' or s.endless and 'endless' or 'trial')..':'..tostring(#(s.vehicle.spec.rotors or {})>0)
    if self.keysLayout and self.keysWidth==width and self.keysTag==tag then return self.keysLayout end
    local tokens={};for _,t in ipairs(keyTokens) do tokens[#tokens+1]=t end
    if not s.battle and not s.endless then tokens[#tokens+1]={'N'};tokens[#tokens+1]=' 传送 · ' end
    tokens[#tokens+1]={'I'};tokens[#tokens+1]=' 详细数据'
    if not s.battle and not s.endless then tokens[#tokens+1]=' · ';tokens[#tokens+1]={'Backspace'};tokens[#tokens+1]=' 全部复原' end
    if #(s.vehicle.spec.rotors or {})>0 then tokens[#tokens+1]=' · ';tokens[#tokens+1]={'F'};tokens[#tokens+1]=' 转轴步进 90°' end
    if s.endless then for _,t in ipairs({' · ',{'G'},' 波间改装 · ',{'Enter'},' 下一波 · ',{'V'},' 维修补给'}) do tokens[#tokens+1]=t end end
    if s.battle then tokens[#tokens+1]=' · ';tokens[#tokens+1]={'Tab'};tokens[#tokens+1]=' 计分板' end
    local items={};local x,y=0,0;local lh=22.8
    local function Add(text,key)
        local w=D.Width(vg,text,12,'vox-body',key and .5 or 0)+(key and 14 or 0)
        if x>0 and x+w>width then x=0;y=y+lh end
        items[#items+1]={text=text,key=key,x=x,y=y,w=w};x=x+w
    end
    for _,token in ipairs(tokens) do
        if type(token)=='table' then Add(token[1],true)
        else
            local word='';local function Flush() if word~='' then Add(word);word='' end end
            for _,cp in utf8.codes(token) do
                if cp>255 then Flush();Add(utf8.char(cp)) elseif cp==32 then Flush();Add(' ') else word=word..utf8.char(cp) end
            end;Flush()
        end
    end
    self.keysLayout={items=items,height=y+lh};self.keysWidth=width;self.keysTag=tag;return self.keysLayout
end
local function Key(vg,text,x,y,w,shadows)
    D.Rect(vg,x+1,y+1,w-2,19,{0,0,0,89});nvgBeginPath(vg);nvgRoundedRect(vg,x+1.5,y+1.5,w-3,18,2)
    nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(83,123,156,100));nvgStroke(vg)
    D.Text(vg,text,x+w/2,y+2,12,D.white,'vox-body',NVG_ALIGN_CENTER,.5,false,17,shadows)
end
function Panel:Expanded(vg,x,y,w,viewH,g)
    local px,py,gap=g.compact and 14 or 20,g.compact and 10 or 16,g.compact and 16 or 24
    local column=(w-2*px-gap)/2;local info=self:LayoutText(vg,'info',self.motion or '',column,12,19.2,D.muted)
    local m=self.session.vehicle.spec.motion
    local base=string.format('地面 %.0f km/h%s · 负载率 %s · 质量 %.0f kg',m.topSpeed*3.6,#self.session.vehicle.spec.thrusters>0 and string.format(' · 推进参考 %.0f km/h',(m.thrusterSpeed or 0)*3.6) or '',m.L<math.huge and string.format('%.2f',m.L) or '—',m.mass)
    local baseLayout=self:LayoutText(vg,'base',base,column,12,19.2,D.muted)
    local leftH=18.6+8+baseLayout.height+(self.motion~='' and info.height or 0)
    local rightH=self.details:ContentHeight();local rowH=math.max(leftH,rightH)
    local keys=self:Keys(vg,w-2*px);local keyY=py+rowH+(g.compact and 8 or 12)
    local contentH=keyY+22.8+4+keys.height+py;local h=math.min(viewH,contentH)
    self.maxScroll=math.max(0,contentH-h);self.scroll=math.min(self.scroll,self.maxScroll)
    self.expandedRect={x=x,y=y-h,w=w,h=h};local top=y-h
    D.Rect(vg,x,top,w,h,{10,23,39,235});nvgSave(vg);nvgIntersectScissor(vg,x,top,w,h);local cy=top+py-self.scroll
    D.Text(vg,'车辆状态',x+px,cy,12,heading,'vox-body',nil,0,false,15)
    -- Production mechReticle hides the legacy speed/bar children in this grid.
    Rich.Draw(vg,baseLayout,x+px,cy+26.6);if self.motion~='' then Rich.Draw(vg,info,x+px,cy+26.6+baseLayout.height) end
    self.details:DrawContent(vg,x+px+column+gap,cy,column)
    local ky=top+keyY-self.scroll;D.Text(vg,'操作说明',x+px,ky,12,heading,'vox-body',nil,0,false,22.8)
    for _,item in ipairs(keys.items) do
        if item.key then Key(vg,item.text,x+px+item.x,ky+26.8+item.y,item.w)
        else D.Text(vg,item.text,x+px+item.x,ky+26.8+item.y,12,muted,'vox-body',nil,0,false,22.8) end
    end
    nvgRestore(vg);return h
end
function Panel:Render(vg)
    D.Begin(vg);local uiw,uih=UI.GetViewportSize();local dpr=math.max(1,graphics:GetDPR())
    local g=M.Viewport(uiw,uih,graphics:GetWidth()/dpr,graphics:GetHeight()/dpr,self.session.touch);self.geometry=g
    nvgSave(vg);nvgScale(vg,g.k,g.k)
    local w=math.min(g.compact and 680 or 740,g.w-(g.compact and 48 or 40));local x=(g.w-w)/2
    local size=g.compact and 12 or 13;local paddingY=g.compact and 2 or 6;local summaryGap=g.compact and 2 or 6
    local statusH=0;local layouts={}
    for i,text in ipairs({self.alert or '',self.state or ''}) do if text~='' then
        local l=self:LayoutText(vg,'status'..i,text,w-32,size,size*1.55,i==1 and {255,210,140,255} or body)
        layouts[#layouts+1]=l;statusH=statusH+(#layouts>1 and 2 or 0)+l.height
    end end
    local toggleText=self.session.details and '收起详情 · 滚轮翻阅' or '驾驶详情'
    local toggleW=14+D.Width(vg,'I',12,'vox-body',.5)+D.Width(vg,' '..toggleText,12,'vox-body')+16
    local chips={{key='WASD',text=' 驾驶'}}
    if #self.session.weapons.groups>0 then chips[#chips+1]={text='左键 开火 · 右键 开镜'} end
    if #self.session.weapons.groups>1 then chips[#chips+1]={key='1–6',text=' 换武器'} end
    if self.session.endless then chips[#chips+1]={key='V',text=' 维修'} end
    if self.session.battle then chips[#chips+1]={key='R',text=' 翻正'};chips[#chips+1]={key='Tab',text=' 计分板'} end
    local rows={{width=0,items={}}};local row=rows[1]
    for _,chip in ipairs(chips) do
        chip.keyW=chip.key and D.Width(vg,chip.key,12,'vox-body',.5)+14 or 0;chip.w=chip.keyW+D.Width(vg,chip.text,12,'vox-body')
        if row.width>0 and row.width+18+chip.w>w-32 then row={width=0,items={}};rows[#rows+1]=row end
        chip.x=row.width+(#row.items>0 and 18 or 0);row.width=chip.x+chip.w;row.items[#row.items+1]=chip
    end
    if row.width+18+toggleW>w-32 then row={width=0,items={}};rows[#rows+1]=row end
    local toggleX=row.width+(#row.items>0 and 18 or 0);row.width=toggleX+toggleW
    local controlH=30;local shortcutsH=self.session.touch and 0 or #rows*controlH+(#rows-1)*4
    local summaryH=paddingY*2+statusH+(statusH>0 and summaryGap or 0)+shortcutsH
    local bottom=g.h-(g.compact and 6 or 16);local top=bottom-summaryH
    if self.session.details then self:Expanded(vg,x,top-(g.compact and 4 or 10),w,math.min(g.h*.48,g.compact and g.h*.48 or 440),g) else self.expandedRect=nil end
    local cy=top+paddingY
    for _,l in ipairs(layouts) do ShadowParagraph(vg,l,x+(w-l.width)/2,cy);cy=cy+l.height+2 end
    if statusH>0 then cy=top+paddingY+statusH+summaryGap end
    local clock=self.session.hud and self.session.hud.vitals.clock or 0
    local fade=not self.session.details and 1-SourceButtonMotion.Ease(math.min(1,math.max(0,(clock-10)/.8)),'ease') or 1
    nvgSave(vg);nvgGlobalAlpha(vg,fade)
    self.toggleRect=nil
    for i,r in ipairs(self.session.touch and {} or rows) do
        local rx=x+(w-r.width)/2;local ry=cy+(i-1)*(controlH+4)
        for _,chip in ipairs(r.items) do
            if chip.key then Key(vg,chip.key,rx+chip.x,ry+(controlH-21)/2,chip.keyW,summaryShadows) end
            D.Text(vg,chip.text,rx+chip.x+chip.keyW,ry+(controlH-18.6)/2,12,{190,208,227,255},'vox-body',nil,0,false,18.6,summaryShadows)
        end
        if i==#rows then
            local tx=rx+toggleX;self.toggleRect={x=tx,y=ry,w=toggleW,h=controlH}
            D.Rect(vg,tx,ry,toggleW,controlH,{57,84,121,168});local kw=D.Width(vg,'I',12,'vox-body',.5)+14
            Key(vg,'I',tx+8,ry+(controlH-21)/2,kw);D.Text(vg,' '..toggleText,tx+8+kw,ry+(controlH-15)/2,12,{225,240,252,255},'vox-body',nil,0,false,15)
        end
    end
    nvgRestore(vg)
    if self.entryTime>0 then
        local elapsed=3.6-self.entryTime;local ease=SourceButtonMotion.Ease
        local alpha=elapsed<3.6*.14 and ease(elapsed/(3.6*.14),'ease') or elapsed>3.6*.68 and 1-ease((elapsed-3.6*.68)/(3.6*.32),'ease') or 1
        nvgSave(vg);nvgGlobalAlpha(vg,math.max(0,alpha));local ey=g.compact and 58 or self.session.battle and math.max(172,g.h*.19) or 82
        D.Text(vg,self.session.map.name or '试车场',g.w/2,ey,g.compact and 22 or 30,D.white,'vox-title',NVG_ALIGN_CENTER,3,false,nil,entryShadows)
        D.Text(vg,self.session.name,g.w/2,ey+(g.compact and 31 or 40),14,{190,208,227,255},'vox-body',NVG_ALIGN_CENTER,0,false,nil,entryShadows);nvgRestore(vg)
    end
    nvgRestore(vg)
end
return M

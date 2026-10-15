local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Images=require 'urhox-libs/UI/Core/ImageCache'
local Comms=require 'ui.CommsCard'
local Resource=require('core.ResourceData').Read('Story/Boss/Epilogue.json')
local Radio=require 'audio.StoryRadio'
local Typography=require 'ui.IntroTypography'
local Page=UI.Widget:Extend('VoxStoryEpilogue')
local M={};M.__index=M
local function Text(vg,text,x,y,size,color,font,align,spacing) D.Text(vg,text,x,y,size,color,font or 'vox-display',align,spacing or 0) end
local function Poly(p,w,h,expand)
    local points={};local vertices=p.polyPoints or {{0,0},{100,0},{100,100},{0,100}}
    for _,v in ipairs(vertices) do points[#points+1]=v[1]*w/100+(v[1]/100-.5)*expand*2;points[#points+1]=v[2]*h/100+(v[2]/100-.5)*expand*2 end;return points
end
local function Contain(vg,path,r,points)
    local image=Images.Get(path);if not image or image<=0 then return end
    local iw,ih=Images.GetSize(path);if iw<=0 or ih<=0 then return end
    local k=math.min(r.w/iw,r.h/ih);local x,y=r.x+(r.w-iw*k)/2,r.y+r.h-ih*k
    nvgSave(vg);nvgIntersectScissor(vg,x,y,iw*k,ih*k);D.Path(vg,points);nvgFillPaint(vg,nvgImagePattern(vg,x,y,iw*k,ih*k,0,image,1));nvgFill(vg);nvgRestore(vg)
end
function Page:GetAbsoluteLayout() local w,h=UI.GetViewportSize();return {x=0,y=0,w=w,h=h} end
function Page:OnPointerDown() self.owner:Advance();return true end
function Page:OnPointerUp() return true end
function Page:HitTest() return self.owner.active end
function Page:Render(vg)
    Typography.Begin(vg);local o=self.owner;local r=o.rules;local box=self:GetAbsoluteLayout();local w,h=box.w,box.h
    local screenAlpha=r.current.kind=='finish' and math.max(0,1-r.age/.8) or math.min(1,r.time/.8)
    nvgSave(vg);nvgGlobalAlpha(vg,screenAlpha);D.Rect(vg,0,0,w,h,{7,8,11,255})
    self.dots=self.dots or nvgCreateImage(vg,'UI/Comms/dots.png',NVG_IMAGE_REPEATX|NVG_IMAGE_REPEATY)
    nvgBeginPath(vg);nvgRect(vg,0,0,w,h);nvgFillPaint(vg,nvgImagePatternTinted(vg,0,0,7,7,0,self.dots,nvgRGBA(255,255,255,9)));nvgFill(vg)
    if r.current.kind=='place' or r.current.kind=='placeOut' then Text(vg,Resource.data.place,w/2,h*.4,15,{143,184,216,math.floor(255*(r.current.kind=='place' and math.min(1,r.age) or math.max(0,1-r.age/.7)))},'vox-display',NVG_ALIGN_CENTER,10) end
    local fade=r.current.kind=='pageOut' and math.max(0,1-r.age/.45) or (r.current.kind=='stamp' or r.current.kind=='finish') and 0 or 1
    nvgSave(vg);nvgGlobalAlpha(vg,fade)
    for _,entry in ipairs(o.panels) do
        local p=entry.panel;local age=r.time-entry.at;local q=p.rect;local x,y,pw,ph=q[1]*w/100,q[2]*h/100,q[3]*w/100,q[4]*h/100
        local enter=math.min(1,age/.32);local eased=1-(1-enter)^3;local from=p.fromParts or {0,-40,'vh'}
        x=x+(1-eased)*from[1]*(from[3]=='vw' and w or h)/100;y=y+(1-eased)*from[2]*(from[3]=='vw' and w or h)/100
        nvgSave(vg);nvgTranslate(vg,x,y);nvgRotate(vg,(-4*(1-eased))*math.pi/180);nvgGlobalAlpha(vg,screenAlpha*fade*enter)
        local clip=Poly(p,pw,ph,0)
        for _,frame in ipairs({{h*.008,1.5*h/100,{0,0,0,184}},{h*.008,0,{11,11,13,255}},{h*.005,0,{255,255,255,255}}}) do nvgSave(vg);nvgTranslate(vg,frame[2],frame[2]);D.Path(vg,Poly(p,pw,ph,frame[1]));nvgFillColor(vg,D.Color(frame[3]));nvgFill(vg);nvgRestore(vg) end
        local path=nil
        for _,key in ipairs(p.shot or {}) do if o.shots[key] then path=o.shots[key];break end end
        path=path or Resource.images[p.bg or 'ep_photo_bg'].path
        local zoom=1+math.min(1,age/14)*.12;if p.kb=='out' then zoom=1.12-math.min(1,age/14)*.12 end
        if type(path)=='string' then Paint.Image(vg,path,{x=0,y=0,w=pw,h=ph},zoom,.5,clip)
        else
            self.captures=self.captures or {};self.captures[vg]=self.captures[vg] or {};local handles=self.captures[vg]
            handles[path]=handles[path] or nvgCreateVideo(vg,path);local iw,ih=path.width,path.height;local k=math.max(pw/iw,ph/ih)*zoom
            D.Path(vg,clip);nvgFillPaint(vg,nvgImagePattern(vg,(pw-iw*k)/2,(ph-ih*k)/2,iw*k,ih*k,0,handles[path],1));nvgFill(vg)
        end
        if p.chr then local c=p.chr;local portrait=Resource.images[c.src=='chairman' and 'chairman_cut' or c.src].path;nvgSave(vg);nvgIntersectScissor(vg,0,0,pw,ph)
            if c.zoom then local handle=Images.Get(portrait);local iw,ih=Images.GetSize(portrait);if handle and iw>0 then local cw=c.zoom[3]*pw/100;local ch=cw*ih/iw;D.Path(vg,clip);nvgFillPaint(vg,nvgImagePattern(vg,c.zoom[1]*pw/100,c.zoom[2]*ph/100,cw,ch,0,handle,1));nvgFill(vg) end
            else Contain(vg,portrait,{x=c.left*pw/100,y=c.top*ph/100+(1-math.min(1,age/1.6))*ph*.02,w=c.width*pw/100,h=(100-c.top-c.bottom)*ph/100},clip) end;nvgRestore(vg)
        end
        if p.shot then for yy=0,ph,4 do D.Line(vg,0,yy,pw,yy,{0,0,0,46},2) end;Text(vg,'● REC',pw*.96,ph*.05,h*.018,{255,74,74,age%1>.5 and 64 or 255},'vox-display',NVG_ALIGN_RIGHT,2) end
        if p.deal then nvgSave(vg);nvgTranslate(vg,pw*.09,ph*.08);nvgRotate(vg,-2.5*math.pi/180);local cw,ch=pw*.82,ph*.84;D.Rect(vg,0,0,cw,ch,{244,239,228,255})
            local tx,ty=cw*.085,ch*.06;Text(vg,'雇佣合同',tx,ty,h*.03,{26,26,26,255},'vox-title',nil,h*.0036);Text(vg,'星际前途有限公司 · 人事部 · 机修师',tx,ty+h*.045,h*.014,{26,26,26,140},'vox-title')
            for i,text in ipairs({'甲方：星际前途有限公司','乙方：机修师（代号见档案）','合同期限：试用三个月 → 长期','备注：行踪每日上报董事长办公室。'}) do Text(vg,text,tx,ty+h*.075+(i-1)*h*.045,h*.02,{26,26,26,255},'vox-title') end
            if age>=1.6 then nvgSave(vg);nvgTranslate(vg,cw*.62,ch*.52);nvgRotate(vg,-12*math.pi/180);nvgBeginPath(vg);nvgRect(vg,0,0,cw*.32,h*.06);nvgStrokeWidth(vg,h*.0045);nvgStrokeColor(vg,nvgRGBA(196,22,28,230));nvgStroke(vg);Text(vg,'董事长批准',cw*.16,h*.006,h*.026,{196,22,28,230},'vox-title',NVG_ALIGN_CENTER);nvgRestore(vg) end;nvgRestore(vg)
        end
        if p.label then local size=h*.024;local tw=D.Width(vg,p.label,size,Typography.face);local lx=p.labelRight and pw*(1-p.labelRight/100)-tw-h*.04 or pw*.05;local ly=ph*.05
            D.Rect(vg,lx,ly,tw+h*.04,size*1.5,p.labelCls=='dark' and {17,17,17,255} or {255,255,255,255});Text(vg,p.label,lx+h*.02,ly+size*.15,size,p.labelCls=='dark' and {255,255,255,255} or {17,17,17,255},Typography.face)
        end
        local sfxDelay=p.deal and 1.65 or .16
        if p.sfx and age>sfxDelay then local fx=p.sfxParts or {right=12,bottom=10};local text=p.sfx[1];nvgSave(vg);nvgTranslate(vg,pw*(1-fx.right/100),ph*(1-fx.bottom/100));nvgRotate(vg,(p.sfx[4] or -6)*math.pi/180);local scale=1+1.4*(1-math.min(1,(age-sfxDelay)/.22))^3;nvgScale(vg,scale,scale)
            Text(vg,text,4,4,h*.09,{11,11,13,255},Typography.face,NVG_ALIGN_RIGHT);Text(vg,text,0,0,h*.09,p.sfx[2]=='red' and {255,59,48,255} or {255,211,106,255},Typography.face,NVG_ALIGN_RIGHT);nvgRestore(vg)
        end;nvgRestore(vg)
    end;nvgRestore(vg)
    if r.current.kind=='stamp' then local k=math.min(1,r.age/.25);nvgSave(vg);nvgTranslate(vg,w/2,h*.44);nvgRotate(vg,-9*math.pi/180);local scale=1+1.4*(1-k)^3;nvgScale(vg,scale,scale)
        local width=D.Width(vg,'已驳回',64,'vox-title',10)+72;D.Rect(vg,-width/2,-42,width,136,{5,5,6,191});nvgBeginPath(vg);nvgRect(vg,-width/2,-42,width,136);nvgStrokeWidth(vg,5);nvgStrokeColor(vg,nvgRGBA(208,40,46,242));nvgStroke(vg)
        Text(vg,'带薪年假申请单',0,-22,18,{233,228,218,179},'vox-display',NVG_ALIGN_CENTER,3);Text(vg,'已驳回',0,6,64,{208,40,46,242},'vox-title',NVG_ALIGN_CENTER,10);nvgRestore(vg)
    end
    local card=o.voice.card;if card then if card.who=='boss' then card.portraitPath=Resource.images.chairman_cut.path end;local width=646;local scale=math.min(1,(w-40)/width);local height=Comms.Height(vg,card,width);Comms.Draw(vg,card,20,h-24-height*scale,width,height,scale,o.voice.time) end
    Text(vg,'Enter 下一句    Esc 跳过',w-28,22,13,{138,133,128,255},'vox-display',NVG_ALIGN_RIGHT,3);nvgRestore(vg)
end
function M.Dependencies() local out=Radio.Dependencies();for _,path in ipairs(Typography.Dependencies()) do out[#out+1]=path end;out[#out+1]='Story/Boss/Epilogue.json';for _,image in pairs(Resource.images) do out[#out+1]=image.path end;return out end
function M.Attach(scene,root,onDone,shots)
    local self=setmetatable({active=true,panels={},shots=shots or {},onDone=onDone,dealCues={}},M);self.rules=require('story.EpilogueRules').New(Resource.data);self.voice=require('audio.StoryComms').New(scene,{voices={}},true);self.radio=Radio.New()
    self.page=Page{position='absolute',width='100%',height='100%',pointerEvents='auto',focusable=false,zIndex=10000};self.page.owner=self;root:AddChild(self.page);return self
end
function M:Advance() if self.rules.current.kind=='say' then self.voice:SkipLine() else self.rules:Next() end end
function M:Key(key) if key==KEY_ESCAPE then self.rules:Finish();self.voice:Hide();return true elseif key==KEY_RETURN or key==KEY_SPACE then self:Advance();return true end;return false end
function M:Update(dt,focus)
    if not self.active then return end;self.radio:Update(dt,focus);self.voice:Update(dt,focus~=false)
    -- Source keeps the final card visible but advances after its authored end.
    local card=self.voice.card;local lineRunning=#self.voice.queue>0 or card and card.age<=card.length
    self.rules:Step(dt,lineRunning)
    for i=#self.dealCues,1,-1 do if self.rules.time>=self.dealCues[i] then self.radio:Play('install');table.remove(self.dealCues,i) end end
    for _,e in ipairs(self.rules:Drain()) do if e.kind=='panel' then if e.page then self.panels={} end;self.panels[#self.panels+1]={panel=e.panel,at=self.rules.time};self.radio:Play('pickup');if e.panel.deal then self.dealCues[#self.dealCues+1]=self.rules.time+1.6 end
        elseif e.kind=='say' then self.voice:Say({e.line},true)
        elseif e.kind=='stamp' then self.radio:Play('done')
        elseif e.kind=='pageOut' or e.kind=='finish' then self.voice:Hide()
        elseif e.kind=='done' then self:Dispose();if self.onDone then self.onDone() end end
    end
end
function M:Dispose()
    if not self.active then return end;self.active=false;self.voice:Dispose();self.radio:Dispose();self.dealCues={}
    if self.page.parent then self.page.parent:RemoveChild(self.page) end;self.page:Destroy();self.panels={}
    for vg,handles in pairs(self.page.captures or {}) do for _,handle in pairs(handles) do nvgDeleteVideo(vg,handle) end end
    self.page.captures={};self.shots={}
    if self.page.dots then nvgDeleteImage(Images.GetContext(),self.page.dots);self.page.dots=nil end
    for _,image in pairs(Resource.images) do Images.Release(image.path) end
end
return M

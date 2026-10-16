-- Frozen storyPage.js/story.css composition, rendered over the real 3D holo.
local ResourceData=require("core.ResourceData")
local StoryHolo=require("render.StoryHolo")
local StoryPageVoice=require("audio.StoryPageVoice")
local ResourceGate=require("app.ResourceGate")
local AudioLevels=require("audio.AudioLevels")
local TouchMode=require("controls.TouchMode")

local UI=require 'urhox-libs/UI'
local Draw=require 'ui.SourceDraw'
local D=setmetatable({}, {__index=Draw})
function D.Text(vg,text,x,y,size,color,font,align,spacing,baseline,lineHeight,shadows)
    return Draw.Text(vg,text,x,y,size,color,font or 'vox-legacy-display',align,spacing,baseline,lineHeight,shadows)
end
function D.Width(vg,text,size,font,spacing) return Draw.Width(vg,text,size,font or 'vox-legacy-display',spacing) end
local F=require 'ui.StoryFrame'
local Paragraph=require 'ui.SourceParagraph'
local Data=require('core.ResourceData').Read('UI/Outgame.json')
local Page=UI.Panel:Extend('VoxStoryPage')
local Brief=UI.Panel:Extend('VoxStoryBrief')
local Button=require('ui.ActionButton'):Extend('VoxStoryButton')
local Comms=UI.Panel:Extend('VoxStoryComms')
local Labels=UI.Panel:Extend('VoxStoryLabels')
local Layout=require 'ui.StoryPageLayout'
local M={}
local ice={214,240,255,255};local cy={110,214,255,255};local muted={214,240,255,158};local dim={214,240,255,92};local red={255,77,66,255}
-- Layout can re-show the mounted page before the next tab rebuild replaces it.
local function PageActive(page)
    return page.owner.storyPage==page and page.owner.storyHolo~=nil
end
local function Diamond(vg,x,y,size,color,fill)
    D.Path(vg,{x,y-size,x+size,y,x,y+size,x-size,y})
    if fill then nvgFillColor(vg,D.Color(color));nvgFill(vg) else nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,1.5);nvgStroke(vg) end
end
local function Flow(s,vg)
    local brief=s.storyBrief;local l=Data.levels[s.storyLevel]
    local rec=s.storyProgress[l.id]
    local height=s.storyPageHeight or s.height
    if brief.flow and brief.flowLevel==l and brief.flowRecord==rec and brief.flowHeight==height and brief.flowContext==vg then return brief.flow end
    brief.flow=Layout.Measure(vg,l,rec,444,height-300,brief.story,brief.goals,brief.enemy,
        function(e) return math.max(D.Width(vg,e[1],15,nil,1),D.Width(vg,e[2],12,'vox-body'))+23 end)
    brief.flowLevel=l;brief.flowRecord=rec;brief.flowHeight=height;brief.flowContext=vg;return brief.flow
end
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local x,y,w,h=r.x,r.y,r.w,r.h
    if p.storyKind=='level' then
        local l=Data.levels[p.index];local cx=x+64
        D.Path(vg,{cx,y,x+w,y,x+w,y+h-14,x+w-14,y+h,cx,y+h})
        D.Gradient(vg,cx,y,w-64,h,p.selected and {110,214,255,77} or {3,10,18,179},{3,10,18,82},true)
        Diamond(vg,x+32,y+h/2,p.selected and 38 or 32,p.selected and {216,244,255,255} or {214,240,255,115},p.selected)
        if not p.selected then Diamond(vg,x+32,y+h/2,31,{3,10,18,255},true) end
        D.Text(vg,l.no,x+32,y+h/2-12,20,p.selected and {3,20,31,255} or ice,nil,NVG_ALIGN_CENTER)
        D.Text(vg,l.name,cx+22,y+16,30,{238,248,255,255},nil,nil,2)
        D.Text(vg,l.type..' · '..l.typeEn,cx+22,y+60,13,muted,nil,nil,2)
        D.Icon(vg,l.icon,x+w-42,y+h/2-11,22,p.selected and ice or dim)
        local rec=self.owner.storyProgress[l.id]
        if rec then Diamond(vg,x+w-69,y+h/2,15,{174,234,255,255},true);D.Text(vg,rec.grade,x+w-69,y+h/2-11,18,{3,20,31,255},nil,NVG_ALIGN_CENTER) end
        if p.selected then F.Draw(vg,cx,y,w-64,h,'lv') end
    elseif p.storyKind=='back' then
        D.Path(vg,{x,y,x+w,y,x+w,y+h-10,x+w-10,y+h,x,y+h})
        D.Gradient(vg,x,y,w,h,{110,214,255,26},{3,10,18,128},true)
        F.Draw(vg,x,y,w,h,'btn');D.Icon(vg,'back',x+16,y+16,22,ice)
        D.Text(vg,'返回',x+64,y+5,12,muted,'vox-body',nil,1);D.Text(vg,'选择模式',x+64,y+27,19,ice,nil,nil,1)
    elseif p.storyKind=='voice' then
        D.Panel(vg,x,y,w,h,6,cy,cy);D.Icon(vg,'play',x+8,y+4,12,{3,20,31,255})
        D.Text(vg,'播放语音',x+26,y+3,11,{3,20,31,255},'vox-body')
    else
        local l=Data.levels[self.owner.storyLevel];local ready=l.ready
        y=176+Flow(self.owner,vg).go
        if math.abs(self.props.top-y)>.01 then self:SetStyle({top=y}) end
        D.Path(vg,{x,y,x+w-16,y,x+w,y+16,x+w,y+h,x+16,y+h,x,y+h-16})
        D.Gradient(vg,x,y,w,h,ready and {142,224,255,255} or {19,34,46,255},ready and {214,244,255,255} or {19,34,46,255},true)
        if ready then
            nvgSave(vg);nvgIntersectScissor(vg,x,y,w,h)
            local sheen=x+w*(1-((self.owner.storyTime or 0)%3.2)/3.2)*3-w
            D.Path(vg,{sheen,y,sheen+w*.7,y,sheen+w*.7,y+h,sheen,y+h})
            D.Gradient(vg,sheen,y,w*.7,h,{240,251,255,0},{240,251,255,185},true);nvgRestore(vg)
        end
        D.Text(vg,ready and '开始任务' or '制作中',x+30,y+9.5,32,ready and {3,20,31,255} or {109,135,153,255},nil,nil,8)
        D.Text(vg,'第 '..l.no..' 关 · '..(ready and l.name or '即将开放'),x+30,y+48,13,ready and {3,20,31,158} or {86,112,127,255},'vox-body')
        D.Rect(vg,x+w-68,y+26,40,22,{3,20,31,31});D.Text(vg,'Enter',x+w-48,y+29,13,{3,20,31,255},nil,NVG_ALIGN_CENTER)
    end
end
function Brief:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local l=Data.levels[self.owner.storyLevel]
    F.Fill(vg,r.x,r.y,r.w,r.h,24);F.Draw(vg,r.x,r.y,r.w,r.h,'terminal','MSN·'..l.no)
    local x,y,w=r.x+34,r.y+30,r.w-68;local flow=Flow(self.owner,vg)
    D.Icon(vg,l.icon,x,y+1,18,cy)
    D.Text(vg,'任务 '..l.no..' · '..l.type,x+26,y,15,cy,nil,nil,2)
    local tx=x+26+D.Width(vg,'任务 '..l.no..' · '..l.type,15,nil,2)+8
    D.Text(vg,l.typeEn,tx,y+3,11,dim,'vox-tabular',nil,3.3)
    D.Text(vg,l.name,x,y+26,56,nil,nil,nil,4);D.Text(vg,l.en,x,y+86,13,muted,'vox-tabular',nil,5.85)
    D.Line(vg,x,r.y+143,x+w,r.y+143,{214,240,255,70})
    self.story:Draw(vg,l.story,x,r.y+flow.story,w,{220,235,245,255})
    local function Heading(title,en,yy)
        D.Rect(vg,x,yy+7,6,6,cy);D.Text(vg,title,x+16,yy,17,nil,nil,nil,3)
        D.Text(vg,en,x+16+D.Width(vg,title,17,nil,3)+10,yy+6,10,dim,'vox-tabular',nil,4)
    end
    Heading('任务目标','OBJECTIVES',r.y+flow.objectives)
    for i,text in ipairs(l.goals) do
        local yy=r.y+flow.goals[i];Diamond(vg,x+5,yy+11,6.36,cy);self.goals:Draw(vg,text,x+19,yy,w-19,{220,235,245,255})
    end
    Heading('敌情','HOSTILES',r.y+flow.hostiles)
    for i,e in ipairs(l.enemies) do
        local box=flow.enemies[i];local ex,yy,ew=x+box.x,r.y+box.y,box.w
        D.Rect(vg,ex,yy,ew,49,{255,77,66,20});D.Rect(vg,ex,yy,2,49,red)
        D.Text(vg,e[1],ex+11,yy+7,15,{255,213,215,255},nil,nil,1);D.Text(vg,e[2],ex+11,yy+27,12,muted,'vox-body')
    end
    local yy=r.y+flow.intercept
    local quote='「'..l.huhu..'」';local qh=flow.interceptHeight
    D.Rect(vg,x,yy,w,qh,{255,77,66,15});D.Line(vg,x,yy,x+w,yy,{255,77,66,61})
    local voice=self.owner.storyVoice;local talking=voice and voice.card and voice.card.intercept
    if talking then D.Rect(vg,x,yy,w,qh,{255,77,66,20}) end
    D.Rect(vg,x+14,yy+15,6,6,red);D.Text(vg,'拦截到的通讯 · 狐狐海盗团',x+28,yy+10,11,red,'vox-body',nil,2)
    self.enemy:Draw(vg,quote,x+14,yy+30,w-28,{255,227,228,255});yy=r.y+flow.factsTop
    for _,fact in ipairs(flow.facts) do
        D.Line(vg,x,yy,x+w,yy,{214,240,255,31})
        D.Text(vg,fact[1],x,yy+8,14,muted,'vox-body');D.Text(vg,fact[2],x+w,yy+7,17,ice,nil,NVG_ALIGN_RIGHT)
        yy=yy+34
    end
end
function Comms:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local l=Data.levels[self.owner.storyLevel]
    local x,y=r.x,r.y;local voice=self.owner.storyVoice;local card=voice and voice.card
    F.Fill(vg,x,y,136,136,13,true,225)
    if self.owner.storyFacesReady then self:RenderBackgroundImage(vg,'Story/Page/Faces/'..l.nono[1]..'.png',{x=x,y=y,w=136,h=136},'cover',nil) end
    for yy=0,136,3 do D.Rect(vg,x,y+yy,136,1,{110,214,255,51}) end
    F.Draw(vg,x,y,136,136,'face')
    local cx=x+156;F.Fill(vg,cx,y,724,136,15);F.Draw(vg,cx,y,724,136,'dialog')
    self.paragraph:Draw(vg,voice and voice:Text() or l.nono[2],cx+30,y+30,664,{242,250,255,255})
    D.Rect(vg,cx+44,y-12,376,24,{3,10,18,230});D.Rect(vg,cx+56,y-3,7,7,cy)
    D.Text(vg,'INCOMING · 诺诺',cx+73,y-6,12,ice,'vox-tabular')
    D.Text(vg,'战术领航员',cx+208,y-6,12,muted,'vox-body')
    for i=0,5 do
        local phase=({0,-.12,-.3,-.05,-.22,-.4})[i+1]
        local wave=card and card.talking and (.6+.4*math.sin(((self.owner.storyTime or 0)+phase)*math.pi/.5)) or .18
        D.Rect(vg,cx+294+i*5,y+6-12*wave,3,12*wave,cy)
    end
end
local callouts={
    {position={0,1.116,0},code='CV-07 · ARGUS',name='坠毁运输舰',info='舰体 280 m · 机库大厅能把车开进去',note='公司资产 · 残值评估中'},
    {position={0,.468,-2.5},code='OUTPOST · 07-S',name='我方要塞',info='星际前途前哨站 · 有顶机库 · 出生点',note='你的工位'},
    {position={0,.468,2.5},code='HOSTILE · 07-N',name='敌方要塞',info='狐狐海盗团据点 · 护盾覆盖',note='不建议上门推销',enemy=true},
}
function Labels:Render(vg)
    D.Begin(vg);local s=self.owner;local holo=s.storyHolo;if not holo or not holo.ready then return end
    local r=self:GetAbsoluteLayout();local w,h=r.w,r.h
    local layout=Data.levels[s.storyLevel].holo
    local marks=ResourceData.Read('Story/Manifest.json').levels[s.storyLevel].marks
    for _,mark in ipairs(marks) do
        local x,y=holo:Project(mark.position,w,h);local enemy=mark.kind=='enemy' or mark.kind=='boss'
        D.Text(vg,mark.label,r.x+x,r.y+y-40,15,enemy and {255,198,201,255} or ice,nil,NVG_ALIGN_CENTER)
        local kind=({start='起点',goal='目标',base='我方',enemy='敌方',boss='首领'})[mark.kind]
        D.Text(vg,kind,r.x+x,r.y+y-19,10,enemy and red or cy,'vox-tabular',NVG_ALIGN_CENTER)
    end
    local centerX=holo.camera:WorldToScreenPoint(holo.focus).x*w
    local placed={};local lo,hi,top,bottom=420,w-600,150,h-260
    for _,c in ipairs(callouts) do
        local mx,my=holo:Project(c.position,w,h)
        if mx>lo-40 and mx<hi+40 then
            local cw=math.max(D.Width(vg,c.info,13,'vox-body'),D.Width(vg,c.name,22))+24;local ch=88
            local choices={};local side=mx<centerX and -1 or 1
            for _,pick in ipairs({{side,false},{-side,false},{side,true},{-side,true}}) do
                local sd,dn=pick[1],pick[2];local ex,ey=mx+sd*44,my+(dn and 44 or -44)
                local left=sd>0 and ex+8 or ex-8-cw;local yy=dn and ey+4 or ey-ch-4
                choices[#choices+1]={side=sd,ex=ex,ey=ey,x=left,y=yy}
            end
            local chosen=choices[1]
            for _,q in ipairs(choices) do
                local fits=q.x>lo and q.x+cw<hi and q.y>top and q.y+ch<bottom
                for _,p in ipairs(placed) do if not (q.x>p.x+p.w or q.x+cw<p.x or q.y>p.y+p.h or q.y+ch<p.y) then fits=false end end
                if fits then chosen=q;break end
            end
            local q=chosen;placed[#placed+1]={x=q.x-8,y=q.y-8,w=cw+16,h=ch+16}
            local color=c.enemy and {255,140,130,191} or {214,240,255,191}
            D.Line(vg,mx,my,q.ex,q.ey,color,1.25);D.Line(vg,q.ex,q.ey,q.ex+q.side*(cw+16),q.ey,color,1.25)
            nvgBeginPath(vg);nvgCircle(vg,mx,my,3);nvgFillColor(vg,D.Color(color));nvgFill(vg)
            local x,y=q.x,q.y;D.Rect(vg,x,y,cw,ch,{3,10,18,220});D.Rect(vg,q.side>0 and x or x+cw-2,y,2,ch,c.enemy and red or cy)
            local tx=q.side>0 and x+12 or x+cw-12;local align=q.side>0 and NVG_ALIGN_LEFT or NVG_ALIGN_RIGHT
            D.Text(vg,c.code,tx,y+7,11,c.enemy and red or cy,'vox-tabular',align)
            D.Text(vg,c.name,tx,y+24,22,c.enemy and {255,214,211,255} or ice,nil,align)
            D.Text(vg,c.info,tx,y+51,13,muted,'vox-body',align);D.Text(vg,c.note,tx,y+70,11,dim,'vox-body',align)
        end
    end
end
function Page:Render(vg)
    if not PageActive(self) then return end
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y=r.x,r.y
    -- GarageLayout sizes the outer page to the viewport; drawing uses its scaled design space.
    local w,h=self.storyLogicalWidth,self.storyLogicalHeight
    if not self.owner.storyHolo.ready then D.Rect(vg,x,y,w,h,{3,8,14,255}) end
    local t=self.owner.storyTime or 0
    D.Rect(vg,x+240,y+30,8,8,{110,214,255,t%1.6<.8 and 255 or 51})
    D.Text(vg,'剧情模式 · STORY',x+257,y+28,13,ice,'vox-tabular',nil,3.9)
    D.Text(vg,'第一章 · '..Data.chapter.name,x+240,y+49,52,nil,nil,nil,3)
    D.Text(vg,Data.chapter.en..' · '..Data.chapter.sub,x+240,y+107,14,muted,nil,nil,3)
    D.Line(vg,x+240,y+135,x+700,y+135,{214,240,255,100})
    for xx=0,450,14 do D.Line(vg,x+240+xx,y+137,x+240+xx,y+142,{214,240,255,60}) end
    D.Text(vg,'章节进度',x+w-180,y+28,13,muted,'vox-body');D.Text(vg,'PROGRESS',x+w-108,y+31,10,dim,'vox-tabular')
    local completed=0;for _,level in ipairs(Data.levels) do if self.owner.storyProgress[level.id] then completed=completed+1 end end
    D.Text(vg,tostring(completed),x+w-112,y+53,34);D.Text(vg,'/ '..#Data.levels,x+w-79,y+67,20,dim)
    for i,level in ipairs(Data.levels) do D.Rect(vg,x+w-56-i*33,y+94,28,5,self.owner.storyProgress[level.id] and cy or {214,240,255,31}) end
    D.Text(vg,'任务航线',x+56,y+200,20,nil,nil,nil,4);D.Text(vg,'MISSION ROUTE',x+148,y+211,11,dim,'vox-tabular',nil,4.4)
    for yy=270,704,11 do D.Rect(vg,x+87,y+yy,1,6,{214,240,255,102}) end
    D.Text(vg,'关卡全部开放，可以任意顺序挑战',x+142,y+762,13,dim,'vox-body')
    local hx=x+64
    for _,hint in ipairs({{'↑↓','选择关卡'},{'Enter','开始任务'},{'Esc','返回'}}) do
        local kw=math.max(22,D.Width(vg,hint[1],13)+12)
        D.Rect(vg,hx,y+h-52,kw,22,{3,10,18,153});D.Text(vg,hint[1],hx+kw/2,y+h-48,13,ice,nil,NVG_ALIGN_CENTER)
        D.Text(vg,hint[2],hx+kw+6,y+h-51,15,muted,'vox-body');hx=hx+kw+6+D.Width(vg,hint[2],15,'vox-body')+24
    end
    D.Text(vg,'HOLO-TABLE · 07 · CRASH CRATER',x+w-36,y+h-35,11,dim,'vox-tabular',NVG_ALIGN_RIGHT)
    for _,p in ipairs({{x+w*.009,y+h*.014,1,1},{x+w*.991,y+h*.014,-1,1},{x+w*.009,y+h*.986,1,-1},{x+w*.991,y+h*.986,-1,-1}}) do
        D.Line(vg,p[1],p[2],p[1]+p[3]*38.88,p[2],dim);D.Line(vg,p[1],p[2],p[1],p[2]+p[4]*38.88,dim)
    end
end
function Page:CustomRenderChildren(vg,renderFn)
    if PageActive(self) then UI.Panel.CustomRenderChildren(self,vg,renderFn) end
end
function M.Leave(s)
    -- Tab input can retire the scene after this frame's page rebuild.
    if s.storyPage then s.storyPage:SetVisible(false);s.storyPage=nil end
    if s.storyHolo then s.storyHolo:Dispose();s.storyHolo=nil end
    if s.storyVoice then s.storyVoice:Dispose();s.storyVoice=nil end
    if s.storyFaceGate then s.storyFaceGate:Cancel();s.storyFaceGate=nil end
    s.storyFacesReady=false
    s.storyVoiceLevel=nil;s.storyTime=nil;s.storyBrief=nil
end
function M.Start(s)
    local l=Data.levels[s.storyLevel]
    if l.ready then s.app:EnterTrial('story'..s.storyLevel)
    else s.app.toasts:Push('第 '..l.no..' 关「'..l.name..'」的玩法还在迁移中','warn') end
end
function M.Update(s,dt)
    s.storyTime=(s.storyTime or 0)+dt;F.SetTime(s.storyTime)
    if s.storyHolo then s.storyHolo:Update(dt) end
    if s.storyVoice then s.storyVoice:Update(dt,input.focus and not input.minimized) end
end
function M.Key(s)
    local n=#Data.levels;local nextIndex=s.storyLevel
    if input:GetKeyPress(KEY_ESCAPE) then s.SetTab('battle');return
    elseif input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then nextIndex=(nextIndex-2)%n+1
    elseif input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_S) then nextIndex=nextIndex%n+1
    elseif input:GetKeyPress(KEY_RETURN) then M.Start(s) end
    for i,key in ipairs({KEY_1,KEY_2,KEY_3,KEY_4,KEY_5}) do if input:GetKeyPress(key) then nextIndex=i end end
    if nextIndex~=s.storyLevel then s.storyLevel=nextIndex;s.revision=-1 end
end
function M.Create(s)
    s.storyProgress=s.app.store:Read('story-progress',function(data) return type(data)=='table' end) or {}
    s.storyLevel=s.storyLevel or 1;s.storyHolo=s.storyHolo or StoryHolo.New(s.app)
    s.storyVoice=s.storyVoice or StoryPageVoice.New()
    if not s.storyFaceGate then
        local gate=ResourceGate.New();s.storyFaceGate=gate
        local faces={};for _,l in ipairs(Data.levels) do faces[#faces+1]='Story/Page/Faces/'..l.nono[1]..'.png' end
        gate:Start(faces,function(ok) if s.storyFaceGate==gate then s.storyFacesReady=ok end end)
    end
    if s.storyVoiceLevel~=s.storyLevel then
        local voiced=s.app.storyPageVoiced or s.app.store:Read('vox.story.voiced',function(value) return value==true end)
        local auto=not voiced and not AudioLevels.Speaking()
        if auto then s.app.storyPageVoiced=true;s.app.store:Write('vox.story.voiced',true,function(value) return value==true end) end
        s.storyVoice:Select(s.storyLevel,Data.levels[s.storyLevel].nono[2],auto);s.storyVoiceLevel=s.storyLevel
    end
    if s.storyHolo.level~=s.storyLevel then s.storyHolo:Select(s.storyLevel) end
    local compact=TouchMode.Enabled()
    local pageScale=compact and 1080*.58/600 or 1
    local w,h=s.width/pageScale,s.height/pageScale;s.storyPageHeight=h
    local page=Page{position='absolute',width=w,height=h,scale=pageScale,transformOrigin='top-left',pointerEvents='box-none'};page.owner=s
    page.storyLogicalWidth=w;page.storyLogicalHeight=h
    local drag=UI.Panel{position='absolute',width=w,height=h,pointerEvents='auto'};local last={}
    drag.OnPointerDown=function(self,e) if not PageActive(page) then return false end;last[e.pointerId]={x=e.x,y=e.y};return true end
    drag.OnPointerMove=function(self,e)
        if not PageActive(page) then return end
        local p=last[e.pointerId];if p then s.storyHolo:Drag((e.x-p.x)/pageScale,(e.y-p.y)/pageScale,h);p.x=e.x;p.y=e.y end
    end
    drag.OnPointerUp=function(self,e) last[e.pointerId]=nil end;drag.OnPointerCancel=drag.OnPointerUp
    drag.OnWheel=function(self,dx,dy) if PageActive(page) then s.storyHolo:Zoom(-dy*40) end end
    local tap={time=-1000,x=0,y=0}
    drag.OnClick=function(self,e)
        if not PageActive(page) then return end
        local now=e.timestamp
        if now-tap.time<350 and math.abs(e.x-tap.x)+math.abs(e.y-tap.y)<12 then s.storyHolo:Reset();tap.time=-1000
        else tap.time=now;tap.x=e.x;tap.y=e.y end
    end
    page:AddChild(drag)
    local labels=Labels{position='absolute',width=w,height=h,pointerEvents='none'};labels.owner=s;page:AddChild(labels)
    local function Add(text,kind,x,y,bw,bh,fn,extra)
        local p={text=text,storyKind=kind,position='absolute',left=x,top=y,width=bw,height=bh,onClick=fn}
        for k,v in pairs(extra or {}) do p[k]=v end
        local button=s.Track(Button(p));button.owner=s;page:AddChild(button);return button
    end
    Add('选择模式','back',56,28,151,54,function() s.SetTab('battle') end)
    for i,l in ipairs(Data.levels) do
        Add(l.no..'  '..l.name,'level',56+(s.storyLevel==i and 10 or 0),241+(i-1)*102,340,92,function() s.storyLevel=i;s.revision=-1 end,{index=i,selected=s.storyLevel==i})
    end
    local brief=Brief{position='absolute',left=w-576,top=176,width=512,height=h-300,pointerEvents='none'}
    brief.owner=s;brief.story=Paragraph.New(16,27.1875);brief.goals=Paragraph.New(15,21.75);brief.enemy=Paragraph.New(16,24);s.storyBrief=brief;page:AddChild(brief)
    Add('开始任务','go',w-542,h-224,444,74,function() M.Start(s) end)
    local comm=Comms{position='absolute',left=64,top=h-218,width=880,height=136,pointerEvents='none'}
    comm.owner=s;comm.paragraph=Paragraph.New(20,32);comm.paragraph.spacing=.4;page:AddChild(comm)
    Add('播放语音','voice',546,h-224,84,20,function() s.storyVoice:Play(s.storyLevel,Data.levels[s.storyLevel].nono[2]) end)
    s.storyPage=page
    return page
end
return M

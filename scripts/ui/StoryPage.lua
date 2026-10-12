-- Frozen storyPage.js/story.css composition, rendered over the real 3D holo.
local UI=require 'urhox-libs/UI'
local Draw=require 'ui.SourceDraw'
local D=setmetatable({}, {__index=Draw})
function D.Text(vg,text,x,y,size,color,font,align,spacing,baseline)
    return Draw.Text(vg,text,x,y,size,color,font or 'vox-story',align,spacing,baseline)
end
function D.Width(vg,text,size,font,spacing) return Draw.Width(vg,text,size,font or 'vox-story',spacing) end
local F=require 'ui.StoryFrame'
local Paragraph=require 'ui.SourceParagraph'
local Data=require('core.ResourceData').Read('UI/Outgame.json')
local Page=UI.Panel:Extend('VoxStoryPage')
local Brief=UI.Panel:Extend('VoxStoryBrief')
local Button=UI.Button:Extend('VoxStoryButton')
local Comms=UI.Panel:Extend('VoxStoryComms')
local Labels=UI.Panel:Extend('VoxStoryLabels')
local M={}
local ice={214,240,255,255};local cy={110,214,255,255};local muted={214,240,255,158};local dim={214,240,255,92};local red={255,77,66,255}
local function Diamond(vg,x,y,size,color,fill)
    D.Path(vg,{x,y-size,x+size,y,x,y+size,x-size,y})
    if fill then nvgFillColor(vg,D.Color(color));nvgFill(vg) else nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,1.5);nvgStroke(vg) end
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
        D.Text(vg,l.name,cx+22,y+19,30,ice)
        D.Text(vg,l.type..' · '..l.typeEn,cx+22,y+59,13,muted)
        D.Icon(vg,l.icon,x+w-42,y+h/2-11,22,p.selected and ice or dim)
        if p.selected then F.Draw(vg,cx,y,w-64,h,'lv') end
    elseif p.storyKind=='back' then
        D.Path(vg,{x,y,x+w,y,x+w,y+h-10,x+w-10,y+h,x,y+h})
        D.Gradient(vg,x,y,w,h,{110,214,255,26},{3,10,18,128},true)
        F.Draw(vg,x,y,w,h,'btn');D.Icon(vg,'back',x+16,y+16,22,ice)
        D.Text(vg,'返回',x+62,y+5,12,muted,'vox-body');D.Text(vg,'选择模式',x+62,y+27,19,ice)
    elseif p.storyKind=='voice' then
        D.Panel(vg,x,y,w,h,6,cy,cy);D.Icon(vg,'play',x+8,y+4,12,{3,20,31,255})
        D.Text(vg,'播放语音',x+26,y+3,11,{3,20,31,255},'vox-body')
    else
        local l=Data.levels[self.owner.storyLevel];local ready=l.ready
        D.Path(vg,{x,y,x+w-16,y,x+w,y+16,x+w,y+h,x+16,y+h,x,y+h-16})
        D.Gradient(vg,x,y,w,h,ready and {142,224,255,255} or {19,34,46,255},ready and {214,244,255,255} or {19,34,46,255},true)
        D.Text(vg,ready and '开始任务' or '制作中',x+30,y+12,32,ready and {3,20,31,255} or {109,135,153,255})
        D.Text(vg,'第 '..l.no..' 关 · '..(ready and l.name or '即将开放'),x+30,y+48,13,ready and {3,20,31,158} or {86,112,127,255},'vox-body')
        D.Rect(vg,x+w-68,y+26,40,22,{3,20,31,31});D.Text(vg,'Enter',x+w-48,y+29,13,{3,20,31,255},nil,NVG_ALIGN_CENTER)
    end
end
function Brief:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local l=Data.levels[self.owner.storyLevel]
    F.Fill(vg,r.x,r.y,r.w,r.h,24);F.Draw(vg,r.x,r.y,r.w,r.h,'terminal','MSN·'..l.no)
    local x,y,w=r.x+34,r.y+30,r.w-68
    D.Icon(vg,l.icon,x,y+1,18,cy)
    D.Text(vg,'任务 '..l.no..' · '..l.type,x+26,y,15,cy)
    local tx=x+26+D.Width(vg,'任务 '..l.no..' · '..l.type,15)+8
    D.Text(vg,l.typeEn,tx,y+3,11,dim,'vox-tabular')
    D.Text(vg,l.name,x,y+23,56);D.Text(vg,l.en,x,y+88,13,muted,'vox-tabular')
    D.Line(vg,x,y+112,x+w,y+112,{214,240,255,70})
    local yy=y+128
    yy=yy+self.story:Draw(vg,l.story,x,yy,w,{220,235,245,255}).height+16
    local function Heading(title,en)
        D.Rect(vg,x,yy+7,6,6,cy);D.Text(vg,title,x+16,yy,17)
        D.Text(vg,en,x+16+D.Width(vg,title,17)+10,yy+6,10,dim,'vox-tabular');yy=yy+28
    end
    Heading('任务目标','OBJECTIVES')
    for _,text in ipairs(l.goals) do
        Diamond(vg,x+5,yy+11,5,cy);yy=yy+self.goals:Draw(vg,text,x+19,yy,w-19,{220,235,245,255}).height+7
    end
    yy=yy+7;Heading('敌情','HOSTILES')
    local ex,eh=x,0
    for _,e in ipairs(l.enemies) do
        local ew=math.max(D.Width(vg,e[1],15),D.Width(vg,e[2],12,'vox-body'))+24
        if ex+ew>x+w then ex=x;yy=yy+eh+6;eh=0 end
        D.Rect(vg,ex,yy,ew,49,{255,77,66,20});D.Rect(vg,ex,yy,2,49,red)
        D.Text(vg,e[1],ex+11,yy+7,15,{255,213,215,255});D.Text(vg,e[2],ex+11,yy+28,12,muted,'vox-body')
        ex=ex+ew+6;eh=49
    end
    yy=yy+eh+16
    local quote='「'..l.huhu..'」';local qh=36+self.enemy:Measure(vg,quote,w-28).height+10
    D.Rect(vg,x,yy,w,qh,{255,77,66,15});D.Line(vg,x,yy,x+w,yy,{255,77,66,61})
    D.Rect(vg,x+14,yy+15,6,6,red);D.Text(vg,'拦截到的通讯 · 狐狐海盗团',x+28,yy+10,11,red,'vox-body')
    self.enemy:Draw(vg,quote,x+14,yy+32,w-28,{255,227,228,255});yy=yy+qh+14
    for _,fact in ipairs({{'地点',Data.chapter.name},{'预计时长',l.minutes..' 分钟'},{'出战战车','任意'}}) do
        D.Line(vg,x,yy,x+w,yy,{214,240,255,31})
        D.Text(vg,fact[1],x,yy+8,14,muted,'vox-body');D.Text(vg,fact[2],x+w,yy+7,17,ice,nil,NVG_ALIGN_RIGHT)
        yy=yy+34
    end
end
function Comms:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local l=Data.levels[self.owner.storyLevel]
    local x,y=r.x,r.y
    F.Fill(vg,x,y,136,136,13,true,225)
    self:RenderBackgroundImage(vg,'UI/Faces/'..l.nono[1]..'.png',{x=x,y=y,w=136,h=136},'cover',nil)
    for yy=0,136,3 do D.Rect(vg,x,y+yy,136,1,{110,214,255,51}) end
    F.Draw(vg,x,y,136,136,'face')
    local cx=x+156;F.Fill(vg,cx,y,724,136,15);F.Draw(vg,cx,y,724,136,'dialog')
    self.paragraph:Draw(vg,l.nono[2],cx+30,y+30,664,{242,250,255,255})
    D.Rect(vg,cx+44,y-12,376,24,{3,10,18,230});D.Rect(vg,cx+56,y-3,7,7,cy)
    D.Text(vg,'INCOMING · 诺诺',cx+73,y-6,12,ice,'vox-tabular')
    D.Text(vg,'战术领航员',cx+208,y-6,12,muted,'vox-body')
    for i=0,5 do D.Rect(vg,cx+294+i*5,y+1-i%3*3,3,4+i%3*3,cy) end
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
    local marks=require('core.ResourceData').Read('Story/Manifest.json').levels[s.storyLevel].marks
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
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y,w,h=r.x,r.y,r.w,r.h
    if not self.owner.storyHolo.ready then D.Rect(vg,x,y,w,h,{3,8,14,255}) end
    D.Text(vg,'剧情模式 · STORY',x+240,y+28,13,ice,'vox-tabular')
    D.Text(vg,'第一章 · '..Data.chapter.name,x+240,y+49,52)
    D.Text(vg,Data.chapter.en..' · '..Data.chapter.sub,x+240,y+113,14,muted)
    D.Line(vg,x+240,y+135,x+700,y+135,{214,240,255,100})
    for xx=0,450,14 do D.Line(vg,x+240+xx,y+137,x+240+xx,y+142,{214,240,255,60}) end
    D.Text(vg,'章节进度',x+w-180,y+28,13,muted,'vox-body');D.Text(vg,'PROGRESS',x+w-108,y+31,10,dim,'vox-tabular')
    D.Text(vg,'0',x+w-112,y+53,34);D.Text(vg,'/ '..#Data.levels,x+w-79,y+67,20,dim)
    for i=1,#Data.levels do D.Rect(vg,x+w-56-i*33,y+94,28,5,{214,240,255,31}) end
    D.Text(vg,'任务航线',x+56,y+200,20);D.Text(vg,'MISSION ROUTE',x+150,y+211,11,dim,'vox-tabular')
    for yy=270,704,11 do D.Rect(vg,x+87,y+yy,1,6,{214,240,255,102}) end
    D.Text(vg,'关卡全部开放，可以任意顺序挑战',x+142,y+762,13,dim,'vox-body')
    D.Text(vg,'HOLO-TABLE · 07 · CRASH CRATER',x+w-36,y+h-35,11,dim,'vox-tabular',NVG_ALIGN_RIGHT)
    for _,p in ipairs({{x+w*.009,y+h*.014,1,1},{x+w*.991,y+h*.014,-1,1},{x+w*.009,y+h*.986,1,-1},{x+w*.991,y+h*.986,-1,-1}}) do
        D.Line(vg,p[1],p[2],p[1]+p[3]*38.88,p[2],dim);D.Line(vg,p[1],p[2],p[1],p[2]+p[4]*38.88,dim)
    end
end
function M.Leave(s) if s.storyHolo then s.storyHolo:Dispose();s.storyHolo=nil end end
function M.Start(s)
    local l=Data.levels[s.storyLevel]
    s.app.toasts:Push(l.ready and '剧情战斗尚未迁移' or '第 '..l.no..' 关「'..l.name..'」的玩法还在制作中','warn')
end
function M.Update(s,dt)
    if s.storyHolo then s.storyHolo:Update(dt) end
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
    s.storyLevel=s.storyLevel or 1;s.storyHolo=s.storyHolo or require('render.StoryHolo').New(s.app)
    if s.storyHolo.level~=s.storyLevel then s.storyHolo:Select(s.storyLevel) end
    local w,h=s.width,s.height;local page=Page{position='absolute',width=w,height=h,pointerEvents='box-none'};page.owner=s
    local drag=UI.Panel{position='absolute',width=w,height=h,pointerEvents='auto'};local last={}
    drag.OnPointerDown=function(self,e) last[e.pointerId]={x=e.x,y=e.y};return true end
    drag.OnPointerMove=function(self,e)
        local p=last[e.pointerId];if p then s.storyHolo:Drag(e.x-p.x,e.y-p.y,h);p.x=e.x;p.y=e.y end
    end
    drag.OnPointerUp=function(self,e) last[e.pointerId]=nil end;drag.OnPointerCancel=drag.OnPointerUp
    drag.OnWheel=function(self,dx,dy) s.storyHolo:Zoom(-dy*40) end
    local tap={time=-1000,x=0,y=0}
    drag.OnClick=function(self,e)
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
        Add(l.no..'  '..l.name,'level',56+(s.storyLevel==i and 10 or 0),242+(i-1)*102,340,92,function() s.storyLevel=i;s.revision=-1 end,{index=i,selected=s.storyLevel==i})
    end
    local brief=Brief{position='absolute',left=w-576,top=176,width=512,height=h-300,pointerEvents='none'}
    brief.owner=s;brief.story=Paragraph.New(16,27.2);brief.goals=Paragraph.New(15,21.75);brief.enemy=Paragraph.New(16,24);page:AddChild(brief)
    Add('开始任务','go',w-542,h-210,444,74,function() M.Start(s) end)
    local comm=Comms{position='absolute',left=64,top=h-218,width=880,height=136,pointerEvents='none'}
    comm.owner=s;comm.paragraph=Paragraph.New(20,32);page:AddChild(comm)
    Add('播放语音','voice',546,h-224,84,20,function() if s.storyVoice then s.storyVoice:Play(s.storyLevel) else s.app.toasts:Push('语音资源尚未迁移','warn') end end)
    return page
end
return M

-- storyHud.css composition, original copy and portraits, UI-owned VG frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local F=require 'ui.MissionFrame'
local Paragraph=require 'ui.SourceParagraph'
local Paint=require 'ui.WorkshopPaint'
local Panel=UI.Panel:Extend('VoxMissionHud')
local M={}
local cyan={70,200,255,255};local orange={255,106,19,255};local white={244,245,247,255};local muted={154,163,173,255}
local function Text(vg,text,x,y,size,color,align) D.Text(vg,text,x,y,size,color or white,'vox-story',align) end
local function Tag(vg,no,title,x,y,w)
    D.Rect(vg,x,y,34,28,{3,10,18,230});D.Line(vg,x,y,x+34,y,cyan);D.Line(vg,x,y+28,x+34,y+28,cyan)
    Text(vg,no,x+17,y+2,21,cyan,NVG_ALIGN_CENTER);Text(vg,'//  +',x+44,y+6,16,cyan);Text(vg,title,x+98,y+1,23)
end
local function Frame(vg,x,y,w,h)
    F.Draw(vg,x,y,w,h,12,cyan)
end
local function Typed(card)
    local count=utf8.len(card.text) or 0;local want=math.floor(count*math.min(1,card.age/math.max(.001,card.typing)))
    local offset=utf8.offset(card.text,want+1);return offset and card.text:sub(1,offset-1) or card.text
end
function Panel:Marker(vg,target,label,color,w,h)
    local session=self.session;local p=require('core.Coord').Vec(target[1],target[2]+9,target[3]);local camera=session.camera:GetCamera()
    local uv=camera:WorldToScreenPoint(p);local x,y=uv.x*w,uv.y*h
    if camera.node:WorldToLocal(p).z<0 then x=w-x;y=h-y end
    local margin=70;local off=x<margin or x>w-margin or y<margin or y>h-margin
    if off then local dx,dy=x-w/2,y-h/2;local k=math.min((w/2-margin)/math.max(.00001,math.abs(dx)),(h/2-margin)/math.max(.00001,math.abs(dy)))
        x=w/2+dx*k;y=h/2+dy*k;local angle=math.atan(dy,dx)
        D.Path(vg,{x+math.cos(angle)*18,y+math.sin(angle)*18,x+math.cos(angle+2.5)*10,y+math.sin(angle+2.5)*10,x+math.cos(angle-2.5)*10,y+math.sin(angle-2.5)*10});nvgFillColor(vg,D.Color(color));nvgFill(vg)
    end
    D.Path(vg,{x,y-12,x+12,y,x,y+12,x-12,y});nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,2);nvgStroke(vg)
    Text(vg,label,x,y+20,17,color,NVG_ALIGN_CENTER)
    local pos=session.story.player:Position();Text(vg,string.format('%.0f m',math.sqrt((pos[1]-target[1])^2+(pos[3]-target[3])^2)),x,y+44,15,white,NVG_ALIGN_CENTER)
end
function Panel:Render(vg)
    D.Begin(vg);local s=self.session;local mission=s.story;local r=mission.rules;local box=self:GetAbsoluteLayout();local w,h=box.w,box.h
    local scale=s.touch and .65 or 1;nvgSave(vg);nvgTranslate(vg,box.x,box.y);nvgScale(vg,scale,scale);w=w/scale;h=h/scale
    local step=r:StepSpec()
    if step then
        local top=s.touch and 92 or 62
        Tag(vg,mission.level.no,mission.level.name,20,top,430);Text(vg,string.format('%02d / %02d',r.index,#mission.level.steps),430,top+10,14,muted,NVG_ALIGN_RIGHT)
        Frame(vg,20,top+44,430,170);Text(vg,r.phase=='fight' and step.fightTitle or step.title,56,top+66,23)
        self.hint:Draw(vg,step.hint or '',56,top+101,368,muted)
        for i,row in ipairs({{'情报','INTEL',r.stats.intel,3,cyan},{'采集器','COLLECTOR',r.stats.collectors,3,orange}}) do local y=top+128+(i-1)*36
            D.Rect(vg,38,y,394,32,{0,0,0,90});Text(vg,'> '..row[1],46,y+3,13,row[5]);Text(vg,row[2],112,y+6,10,muted)
            for n=1,row[4] do D.Rect(vg,300+(n-1)*22,y+12,18,8,n<=row[3] and row[5] or {255,255,255,25}) end
            Text(vg,row[3]..'/'..row[4],420,y+5,15,white,NVG_ALIGN_RIGHT)
        end
        local target=r:Target();if r.phase=='fight' then for i=2,#mission.entries do target=mission.entries[i].unit:Position();break end end
        if target and mission.player.alive then self:Marker(vg,target,r.phase=='fight' and '海盗' or step.kind=='install' and '采集器' or step.kind=='pickup' and '情报' or step.id=='home' and '要塞' or '目标',r.phase=='fight' and {255,59,70,255} or cyan,w,h) end
    end
    local card=mission.voice.card
    if card then
        local x,y=20,s.touch and 332 or h-260;local enemy=card.who=='huhu';local color=enemy and {255,59,70,255} or cyan
        Frame(vg,x,y,150,196);nvgSave(vg);nvgScissor(vg,x,y,150,196)
        if enemy then Paint.Image(vg,'UI/Faces/'..card.face..'.png',{x=x-3,y=y-16,w=156,h=195},1,0,nil,nil,0)
        else Paint.Image(vg,'UI/Faces/'..card.face..'.png',{x=x-70,y=y-2,w=330,h=410},1,0,nil,nil,0) end
        nvgRestore(vg);for yy=3,195,3 do D.Rect(vg,x,y+yy,150,1,{color[1],color[2],color[3],18}) end
        local cx=x+166;Frame(vg,cx,y,480,196);Text(vg,enemy and 'INTERCEPT · 狐狐' or 'INCOMING · 诺诺',cx+20,y+16,16,color)
        Text(vg,enemy and '狐狐海盗团团长' or '战术领航员',cx+20,y+43,12,muted)
        self.comms:Draw(vg,Typed(card),cx+20,y+65,440,white);Text(vg,enemy and 'UNKNOWN · 12 KBPS · NOISE' or 'CH-07 · 64 KBPS · ENC',cx+20,y+177,10,muted)
    end
    local intel=mission.intelCard
    if intel and r.time<intel.untilAt then
        local x=s.touch and w/2-210 or w-444
        local y=s.touch and (w/h<1.5 and h-260 or 20) or h*.27
        Tag(vg,tostring(r.stats.intel),'情报获取',x,y,420);Frame(vg,x,y+44,420,170)
        Text(vg,intel.item.name,x+20,y+62,24);Text(vg,'来源 · '..intel.item.sub,x+20,y+100,13,cyan)
        self.intel:Draw(vg,intel.item.text,x+20,y+128,380,white)
    end
    if r.inside and step and step.kind=='install' then local x,y=w/2,h*.63
        nvgBeginPath(vg);nvgCircle(vg,x,y+42,34);nvgStrokeColor(vg,nvgRGBA(255,255,255,38));nvgStrokeWidth(vg,5);nvgStroke(vg)
        nvgBeginPath(vg);nvgArc(vg,x,y+42,34,-math.pi/2,-math.pi/2+math.pi*2*math.min(1,r.install/2.4),NVG_CW);nvgStrokeColor(vg,D.Color(orange));nvgStroke(vg)
        Text(vg,s.touch and '安装' or 'G',x,y+27,20,white,NVG_ALIGN_CENTER)
        Text(vg,r.blocked and '先停稳' or '按住安装采集器',x,y+90,20,white,NVG_ALIGN_CENTER)
    end
    if r.begun and r.time<4.2 or r.completeAt and not r.finished then
        Text(vg,'剧情模式 · 任务 '..mission.level.no,w/2,h*.12,18,cyan,NVG_ALIGN_CENTER)
        Text(vg,r.completeAt and '任务完成' or mission.level.name,w/2,h*.12+30,64,white,NVG_ALIGN_CENTER)
        Text(vg,mission.level.en..' · CV-07 ARGUS',w/2,h*.12+110,16,muted,NVG_ALIGN_CENTER)
    end
    if not mission.player.alive then
        Text(vg,'信号丢失 · SIGNAL LOST',w/2,h*.34,18,{255,59,70,255},NVG_ALIGN_CENTER)
        Text(vg,'战车损毁',w/2,h*.34+36,54,white,NVG_ALIGN_CENTER);Text(vg,string.format('%.1f 秒后从检查点重新空投',r.respawnLeft or 3),w/2,h*.34+108,20,muted,NVG_ALIGN_CENTER)
    end
    nvgRestore(vg)
end
function M.Attach(session,root)
    local layer=Panel{position='absolute',width='100%',height='100%',pointerEvents='none'};layer.session=session
    layer.hint=Paragraph.New(13,19);layer.comms=Paragraph.New(19,30.4);layer.intel=Paragraph.New(15,24);root:AddChild(layer)
    local state=require('ui.MissionResult').Attach(session,root);state.layer=layer;return state
end
return M

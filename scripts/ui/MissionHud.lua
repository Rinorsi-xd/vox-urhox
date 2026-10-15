-- storyHud.css composition, original copy and portraits, UI-owned VG frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local F=require 'ui.MissionFrame'
local Paragraph=require 'ui.SourceParagraph'
local Comms=require 'ui.CommsCard'
local Markers=require 'story.MarkerRules'
local Panel=UI.Panel:Extend('VoxMissionHud')
local M={}
local cyan={70,200,255,255};local orange={255,106,19,255};local white={244,245,247,255};local muted={154,163,173,255}
local function Text(vg,text,x,y,size,color,align) D.Text(vg,text,x,y,size,color or white,'vox-display',align) end
local function Tag(vg,no,title,x,y,w)
    D.Rect(vg,x,y,34,28,{3,10,18,230});D.Line(vg,x,y,x+34,y,cyan);D.Line(vg,x,y+28,x+34,y+28,cyan)
    Text(vg,no,x+17,y+2,21,cyan,NVG_ALIGN_CENTER);Text(vg,'//  +',x+44,y+6,16,cyan);Text(vg,title,x+98,y+1,23)
end
local function Frame(vg,x,y,w,h)
    F.Draw(vg,x,y,w,h,12,cyan)
end
function Panel:Project(target,lift,w,h)
    local p=require('core.Coord').Vec(target[1],target[2]+lift,target[3]);local camera=self.session.camera:GetCamera()
    local uv=camera:WorldToScreenPoint(p);local depth=camera.node:WorldToLocal(p).z
    return Markers.Project(uv.x*2-1,1-uv.y*2,depth<0 or depth>camera.farClip,w,h)
end
local function Diamond(vg,x,y,size,color,inner)
    nvgSave(vg);nvgTranslate(vg,x,y);nvgRotate(vg,math.pi/4)
    nvgBeginPath(vg);nvgRect(vg,-size/2,-size/2,size,size);nvgFillColor(vg,nvgRGBA(0,0,0,64));nvgFill(vg)
    for _,line in ipairs({{8,22},{5,45},{2,255}}) do
        nvgStrokeWidth(vg,line[1]);nvgStrokeColor(vg,nvgRGBA(color[1],color[2],color[3],line[2]*(color[4] or 255)/255));nvgStroke(vg)
    end
    if inner then D.Rect(vg,-size/2+7,-size/2+7,size-14,size-14,color) end
    nvgRestore(vg)
end
function Panel:Markers(vg,w,h)
    local mission=self.session.story;local state=Markers.Select(mission);if not state then return end
    for i=2,#mission.entries do local u=mission.entries[i].unit;if u.alive and u~=state.excluded then
        local p=self:Project(u:Position(),3,w,h);Diamond(vg,p.x,p.y,12,{255,59,70,p.off and 153 or 255},false)
    end end
    local p=self:Project(state.target,state.lift,w,h);if state.close then if not p.off then return end;p.y=math.max(p.y,120) end
    local x,y=p.x,p.y;local color=state.kind=='enemy' and {255,59,70,255} or state.kind=='install' and orange or cyan
    Diamond(vg,x,y,state.kind=='enemy' and 18 or 22,color,true)
    if p.off then
        nvgSave(vg);nvgTranslate(vg,x,y);nvgRotate(vg,p.angle)
        D.Path(vg,{15,-7,27,0,15,7});nvgFillColor(vg,D.Color(color));nvgFill(vg);nvgRestore(vg)
    else Text(vg,state.label,x,y-40,14,white,NVG_ALIGN_CENTER) end
    local pos=mission.player:Position();local distance=math.sqrt((pos[1]-state.target[1])^2+(pos[3]-state.target[3])^2)
    Text(vg,distance<1000 and (math.floor(distance+.5)..' m') or string.format('%.1f km',distance/1000),x,y+18,13,white,NVG_ALIGN_CENTER)
end
function Panel:Render(vg)
    D.Begin(vg);local s=self.session;local mission=s.story;local r=mission.rules;local box=self:GetAbsoluteLayout();local w,h=box.w,box.h
    local scale=s.touch and .65 or 1;nvgSave(vg);nvgTranslate(vg,box.x,box.y);nvgScale(vg,scale,scale);w=w/scale;h=h/scale
    local step=r:StepSpec();local cinematic=mission.boss and mission.boss.cinematic
    if step and not cinematic then
        local top=s.touch and 92 or 62
        Tag(vg,mission.level.no,mission.level.name,20,top,430);Text(vg,string.format('%02d / %02d',r.index,#mission.level.steps),430,top+10,14,muted,NVG_ALIGN_RIGHT)
        Frame(vg,20,top+44,430,170);Text(vg,r.retitle or (r.phase=='fight' and step.fightTitle or step.title),56,top+66,23)
        self.hint:Draw(vg,step.hint or '',56,top+101,368,muted)
        local rows=mission.convoy and {{'运输车','CARGO HP',mission.convoy.hp,1,orange,true},{'检查点','CHECKPOINT',r.stats.checkpoints,3,cyan}} or
            {{'情报','INTEL',r.stats.intel,3,cyan},{'采集器','COLLECTOR',r.stats.collectors,3,orange}}
        if mission.level.id=='s3' then
            local hold=r.hold;local left=math.max(0,hold and hold.left or 120)
            rows={{'坚守','HOLD',hold and 1-left/120 or 0,1,cyan,true,string.format('%d:%02d',math.floor(left/60),math.floor(left%60))},
                {'护盾能量','SHIELD',hold and hold.energy or 1,1,orange,true}}
        end
        if mission.level.id=='s4' then rows={{'采集器','RECLAIMED',r.stats.sites or 0,3,cyan},{'涂鸦清理','GRAFFITI',r.stats.graffiti or 0,3,orange}} end
        if mission.level.id=='s5' then rows={} end
        for i,row in ipairs(rows) do local y=top+128+(i-1)*36
            D.Rect(vg,38,y,394,32,{0,0,0,90});Text(vg,'> '..row[1],46,y+3,13,row[5]);Text(vg,row[2],112,y+6,10,muted)
            if row[6] then
                D.Rect(vg,244,y+12,112,8,{255,255,255,25});D.Rect(vg,244,y+12,112*math.max(0,row[3]),8,row[5])
            else for n=1,row[4] do D.Rect(vg,300+(n-1)*22,y+12,18,8,n<=row[3] and row[5] or {255,255,255,25}) end end
            Text(vg,row[7] or (row[6] and string.format('%d%%',math.floor(math.max(0,row[3])*100+.5)) or row[3]..'/'..row[4]),420,y+5,15,white,NVG_ALIGN_RIGHT)
        end
        if mission.player.alive then self:Markers(vg,w,h) end
    end
    if step and step.kind=='hold' and r.hold then
        local left=math.max(0,r.hold.left)
        Text(vg,string.format('%d:%02d',math.floor(left/60),math.floor(left%60)),w/2,50,42,left<20 and {255,59,70,255} or white,NVG_ALIGN_CENTER)
    end
    local card=mission.voice.card
    if card then
        local height=Comms.Height(vg,card,646)
        Comms.Draw(vg,card,20,h-(cinematic and h*.09+14 or 64)-height,646,height,1,mission.voice.time)
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
    if r.inside and step and step.kind=='capture' then local x,y=w/2,h*.63;local scrub=r.cap.phase=='scrub'
        D.Rect(vg,x-150,y,300,8,{255,255,255,38});D.Rect(vg,x-150,y,300*math.min(1,r.progress),8,r.blocked and {255,59,70,255} or cyan)
        Text(vg,scrub and (s.touch and '按住清理涂鸦' or '按住 G 擦掉涂鸦') or r.blocked and '圈里还有海盗' or '正在夺回采集器…',x,y+18,20,white,NVG_ALIGN_CENTER)
        Text(vg,scrub and '「狐狐到此一游」——清理费从工资里扣' or r.blocked and '先清掉圈附近的 '..r.cap.contested..' 辆' or '待在圈里别出去',x,y+48,15,muted,NVG_ALIGN_CENTER)
    end
    if not mission.player.alive then
        Text(vg,'信号丢失 · SIGNAL LOST',w/2,h*.34,18,{255,59,70,255},NVG_ALIGN_CENTER)
        Text(vg,'战车损毁',w/2,h*.34+36,54,white,NVG_ALIGN_CENTER);Text(vg,string.format('%.1f 秒后从检查点重新空投',r.respawnLeft or 3),w/2,h*.34+108,20,muted,NVG_ALIGN_CENTER)
    end
    require('ui.MissionBanner').Draw(vg,mission.banner,r.time,mission.level.no,w,h)
    nvgRestore(vg)
end
function M.Attach(session,root)
    local layer=Panel{position='absolute',width='100%',height='100%',pointerEvents='none'};layer.session=session
    layer.hint=Paragraph.New(13,19);layer.intel=Paragraph.New(15,24);root:AddChild(layer)
    local state=require('ui.MissionResult').Attach(session,root);state.layer=layer
    local update=state.Update;local choice=require('ui.MissionChoice').Attach(session,root)
    state.Update=function(dt) update(dt);choice() end;return state
end
return M

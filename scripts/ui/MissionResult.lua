-- Frozen storyHud.js result composition and storyHud.css dimensions.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Paragraph=require 'ui.SourceParagraph'
local Panel=UI.Panel:Extend('VoxMissionResult')
local Button=UI.Button:Extend('VoxMissionResultButton')
local M={}
local cyan={70,200,255,255};local orange={255,106,19,255};local white={244,245,247,255};local muted={154,163,173,255}
local function Text(vg,text,x,y,size,color,align) D.Text(vg,text,x,y,size,color or white,'vox-display',align) end
local function Layout(self)
    local r=self:GetAbsoluteLayout();local scale=math.min(1,(r.w-40)/728,(r.h-36)/660)
    return r,scale,r.x+(r.w-728*scale)/2,r.y+(r.h-640*scale)/2
end
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local scale=self.props.resultScale or 1
    nvgSave(vg);nvgTranslate(vg,r.x,r.y);nvgScale(vg,scale,scale)
    local w,h=r.w/scale,r.h/scale;local back=self.props.back;local hover=self.state.hovered
    D.Path(vg,{0,0,w,0,w-(back and 18 or 0),h,0,h})
    nvgFillColor(vg,D.Color(back and (hover and {255,140,69,255} or orange) or {255,255,255,hover and 38 or 20}));nvgFill(vg)
    local color=back and {26,13,5,255} or white;local key=back and 'Enter' or 'R'
    local total=D.Width(vg,self.props.text,22,'vox-display')+12+(back and 52 or 24)
    Text(vg,self.props.text,(w-total)/2,17,22,color)
    local kx=(w-total)/2+total-(back and 52 or 24)
    D.Rect(vg,kx,19,back and 52 or 24,22,back and {0,0,0,51} or {0,0,0,128})
    Text(vg,key,kx+(back and 26 or 12),22,13,color,NVG_ALIGN_CENTER);nvgRestore(vg)
end
function Panel:Render(vg)
    D.Begin(vg);local box,scale,x,y=Layout(self);D.Rect(vg,box.x,box.y,box.w,box.h,{4,5,7,218})
    local mission=self.session.story;local r=mission.rules
    local progress=math.min(1,self.age/.5);local rise=(1-progress)^3*24
    nvgSave(vg);nvgTranslate(vg,x,y+rise);nvgScale(vg,scale,scale);nvgGlobalAlpha(vg,math.min(1,self.age/.4))
    require('ui.MissionFrame').Draw(vg,0,0,728,640,18,cyan)
    Text(vg,'MISSION '..mission.level.no..' · '..mission.level.name,34,30,15,cyan)
    Text(vg,'任务完成',34,54,76);Text(vg,'MISSION COMPLETE',34,137,13,muted)
    D.Path(vg,{652,30,694,72,652,114,610,72});nvgFillColor(vg,D.Color(orange));nvgFill(vg)
    Text(vg,r.grade,652,42,50,{18,10,5,255},NVG_ALIGN_CENTER);Text(vg,mission.newBest and '新纪录' or '评价',652,123,12,muted,NVG_ALIGN_CENTER)
    D.Rect(vg,34,174,34,28,{3,10,18,230});Text(vg,'01',51,176,21,cyan,NVG_ALIGN_CENTER)
    Text(vg,'//  +',78,178,16,cyan);Text(vg,'任务数据',132,174,23);Text(vg,'DEBRIEF',242,184,11,muted)
    local rows={{'用时','TIME',string.format('%d:%02d',math.floor(r.time/60),math.floor(r.time%60))},
        {'情报','INTEL',r.stats.intel..' / 3'},{'采集器','COLLECTOR',r.stats.collectors..' / 3'},
        {'击退海盗','WRECKED',r.stats.kills},{'战车损毁','LOSSES',r.stats.deaths..' 次'}}
    if mission.level.resultPolicy=='truck' then
        rows[2]={'运输车耐久','CARGO HP',string.format('%d%%',math.floor((r.stats.truckHp or 0)*100+.5))}
        rows[3]={'检查点','CHECKPOINT',(r.stats.checkpoints or 0)..' / 3'}
    end
    if mission.level.resultPolicy=='shield' then
        rows[2]={'护盾剩余','SHIELD',string.format('%d%%',math.floor(math.max(0,r.stats.shield or 0)*100+.5))}
        rows[3]={'击退海盗','WRECKED',r.stats.kills};rows[4]={'重来次数','RETRIES',r.stats.fails}
    end
    if mission.level.resultPolicy=='sites' then
        rows[2]={'夺回采集器','RECLAIMED',(r.stats.sites or 0)..' / 3'}
        rows[3]={'你的留言','TAG',({'机修师到此一游','狐狐是笨蛋','（没写，很专业）'})[(r.flags.tag or 2)+1]}
    end
    for i,row in ipairs(rows) do local yy=216+(i-1)*38
        D.Rect(vg,34,yy,660,32,{0,0,0,90});Text(vg,'>',42,yy+4,16,cyan)
        Text(vg,row[1],62,yy+4,15,muted);Text(vg,row[2],160,yy+9,10,muted)
        Text(vg,tostring(row[3]),678,yy+3,18,white,NVG_ALIGN_RIGHT)
    end
    D.Rect(vg,34,418,660,94,{70,200,255,15});D.Rect(vg,34,418,3,94,cyan)
    nvgSave(vg);nvgScissor(vg,44,430,58,58)
    Paint.Image(vg,'UI/Faces/'..(r.grade=='B' and 'nono_deadpan' or 'nono_smile')..'.png',{x=18,y=418,w=126,h=156},1,0,nil,nil,0);nvgRestore(vg)
    Text(vg,'诺诺',116,428,15,cyan);Text(vg,'NONO',166,433,10,muted)
    self.quote:Draw(vg,'「'..mission:Quote()..'」',116,451,560,{214,221,227,255})
    D.Rect(vg,34,590,660,30,{0,0,0,90});D.Line(vg,34,590,694,590,cyan);D.Line(vg,34,620,694,620,cyan)
    Text(vg,'+  //:  剧情模式  |',46,596,14,cyan);Text(vg,mission.level.en,244,596,15)
    D.Rect(vg,660,594,30,22,cyan);Text(vg,mission.level.no,675,596,16,{6,18,27,255},NVG_ALIGN_CENTER)
    nvgRestore(vg)
end
function M.Attach(session,root)
    local panel=Panel{position='absolute',width='100%',height='100%',visible=false,pointerEvents='auto'}
    panel.session=session;panel.age=0;panel.quote=Paragraph.New(15,24)
    local buttons={}
    for i,item in ipairs({{'再来一次',true},{'返回剧情页',false}}) do local again=item[2]
        local button=Button{text=item[1],back=not again,position='absolute',onClick=function() session.app.restartStory=again;session.wantsReturn=true end}
        button.props.onClick=function() session.app.restartStory=again and session.map.id or false;session.wantsReturn=true end
        panel:AddChild(button);buttons[i]=button
    end
    root:AddChild(panel)
    return {result=panel,Update=function(dt)
        local finished=session.story.rules.finished;panel:SetVisible(finished)
        if not finished then return end;panel.age=panel.age+(dt or 0)
        local box,scale,x,y=Layout(panel)
        if panel.layoutWidth~=box.w or panel.layoutHeight~=box.h then
            panel.layoutWidth=box.w;panel.layoutHeight=box.h
            for i,button in ipairs(buttons) do button.props.resultScale=scale;button:SetStyle{left=x-box.x+(i==1 and 34 or 319)*scale,top=y-box.y+526*scale,width=(i==1 and 275 or 375)*scale,height=60*scale} end
        end
    end}
end
return M

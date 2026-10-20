-- Frozen MatchHud._teams/result and the final production CSS cascade.
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Motion=require 'combat.MvpMotion'
local Ease=require('ui.SourceButtonMotion').Ease
local Typography=require 'ui.SourceTextLayout'
local M={}
local blue={46,168,255,255};local red={255,74,61,255};local gold={255,211,106,255}
local damageColor={255,255,255,192}
local roles={assault='突击',heavy='重装',sniper='狙击',hover='悬浮快攻'}
local labels={'等级','击毁','助攻','被毁','伤害','得分'}
local widths={70,80,80,80,120,110}
local compactWidths={48,54,54,54,90,78}
local columnWidths={40,46,46,46,72,62} -- 两队并排时每列更窄，16:9 的手机也放得下
local function Measure(text,size,font,spacing)
    local layout=Typography.Get(tostring(text),font or 'vox-title')
    return layout and Typography.Width(layout,size,spacing) or utf8.len(tostring(text))*(size+(spacing or 0))
end
local function Subtitle(cfg) return cfg.en..' · '..cfg.size..'V'..cfg.size..' · 坠舰陨坑 · AI 对战（离线）' end
local function State(b)
    return b.mode=='elimination' and ('第 '..b.rules.round..' 回合'..(b.rules.sudden and ' · 决胜时刻' or ''))
        or b.mode=='escort' and (b.rules.half==1 and '上半场' or '下半场') or b.rules.overtime and '加时' or '进行中'
end
local function Scores(b)
    local suffix=b.mode=='conquest' and '%' or b.mode=='escort' and '米' or ''
    return math.floor(b.rules.score.blue)..suffix,math.floor(b.rules.score.red)..suffix
end
local function Lines(text,width)
    local result={};local line='';local token=''
    local function Push(word)
        if line~='' and Measure(line..word,12,'vox-title',5)>width then result[#result+1]=line:gsub('[ \t\r\n]+$','');line='' end
        line=line..word
    end
    for _,cp in utf8.codes(text) do
        local char=utf8.char(cp)
        if cp<128 and char:match('[%w%%]') then token=token..char
        else
            if token~='' then Push(token);token='' end
            if line~='' or char~=' ' then Push(char) end
        end
    end
    if token~='' then Push(token) end
    if line~='' then result[#result+1]=line:gsub('[ \t\r\n]+$','') end
    return result
end
local function RewardWidth(result)
    return Measure('段位分',16,'vox-title',1)+Measure((result.delta>=0 and '+' or '')..result.delta,22,'vox-title',1)+8
        +Measure('（'..result.profile.rating..'） · 经验',16,'vox-title',1)+Measure('+'..result.xp,22,'vox-title',1)+8
        +Measure(' · 等级 '..result.profile.level,16,'vox-title',1)
end
-- These are source CSS pixels, independent of the general HUD's design scale.
-- columns=true：两队左右并排（手机结算用，表格高度减半，配合整体缩放一屏放下、按钮常驻可见）
function M.Layout(w,h,b,cfg,compact,columns)
    local over=b.rules.state=='over';local bw=math.min(1440,w*.94)
    local small=compact==true;local p=small and 16 or 34
    local row=small and 48 or 62;local av=small and 44 or 62;local tracks=columns and columnWidths or small and compactWidths or widths
    local fixed=av;for _,width in ipairs(tracks) do fixed=fixed+width end
    local rw=math.max(bw-2*p,fixed+(small and 120 or 0))
    local teamHeight=(small and 20 or 34)+2*(37+31+cfg.size*(row+5))+16
    if columns then rw=math.max((bw-3*p)/2,fixed+60);teamHeight=(small and 20 or 34)+(37+31+cfg.size*(row+5))+16 end
    local a,c=Scores(b);local time=math.max(0,math.ceil(b.rules:TimeLeft()))
    local timeText=string.format('%d:%02d',math.floor(time/60),time%60)
    local timeWidth=math.max(Measure(State(b),14,'vox-title',3),Measure(timeText,28,'vox-display'))
    local scoreWidth=over and Measure(a..':'..c,40,'vox-display',2)
        or Measure(a,44,'vox-display')+Measure(c,44,'vox-display')+Measure(':',22,'vox-display')+28
    local caption=Subtitle(cfg);local mdWidth=math.min(Measure(caption,12,'vox-title',5),math.max(160,bw-68-44-scoreWidth-timeWidth))
    local lines=Lines(caption,mdWidth)
    local header=over and (small and 85 or 133.796875) or 79+15*#lines
    local footer=over and (small and 69 or 87) or 0
    local buttonH=small and 44 or 50;local buttonBack=small and 106 or 134;local buttonRetry=small and 128 or 156
    local footerPad=small and 18 or 36;local gap=small and 12 or 18
    local buttonY=header+teamHeight+(small and 13 or 19)
    local backX=bw-footerPad-buttonBack-gap-buttonRetry;local retryX=bw-footerPad-buttonRetry
    if over and small then
        local items={{kind='gain',width=RewardWidth(b.result),height=27},{kind='space',width=0,height=0},
            {kind='back',width=buttonBack,height=44},{kind='retry',width=buttonRetry,height=44}}
        if b.mvp then table.insert(items,2,{kind='mvp',width=Measure('★ 本局 MVP：'..b.mvp.unit.name,15,'vox-title',2),height=18}) end
        local rows={{items={},width=0,height=0}};local inner=bw-footerPad*2
        for _,item in ipairs(items) do
            local r=rows[#rows];local needed=item.width+(#r.items>0 and gap or 0)
            if #r.items>0 and r.width+needed>inner then r={items={},width=0,height=0};rows[#rows+1]=r;needed=item.width end
            r.items[#r.items+1]=item;r.width=r.width+needed;r.height=math.max(r.height,item.height)
        end
        local y=header+teamHeight+13
        for _,r in ipairs(rows) do
            local x=footerPad;local free=math.max(0,inner-r.width)
            for _,item in ipairs(r.items) do
                if item.kind=='back' then backX=x;buttonY=y+(r.height-44)/2
                elseif item.kind=='retry' then retryX=x end
                item.x=x;item.y=y+(r.height-item.height)/2
                x=x+item.width+(item.kind=='space' and free or 0)+gap
            end
            y=y+r.height+gap
        end
        footer=y-(header+teamHeight)-gap+12
        -- The source footer may wrap independently from the team table.
        local layoutItems={};for _,r in ipairs(rows) do for _,item in ipairs(r.items) do layoutItems[item.kind]=item end end
        local bh=header+teamHeight+footer+31
        return {w=bw,h=bh,viewH=math.min(bh,h*.94),contentW=math.max(bw,(columns and 2*rw+p or rw)+2*p),header=header,teamHeight=teamHeight,
            compact=true,columns=columns==true,padding=p,row=row,avatar=av,tracks=tracks,rowWidth=rw,nameWidth=rw-fixed,caption=lines,time=timeText,timeWidth=timeWidth,scoreWidth=scoreWidth,
            backX=backX,retryX=retryX,buttonY=layoutItems.back.y,retryY=layoutItems.retry.y,buttonBack=buttonBack,buttonRetry=buttonRetry,buttonH=buttonH,footer=footer,footerItems=layoutItems}
    end
    local bh=header+teamHeight+footer+(over and 31 or 0)
    return {w=bw,h=bh,viewH=math.min(bh,h*(small and .94 or .92)),contentW=math.max(bw,rw+2*p),header=header,teamHeight=teamHeight,
        compact=small,padding=p,row=row,avatar=av,tracks=tracks,rowWidth=rw,nameWidth=rw-fixed,caption=lines,time=timeText,timeWidth=timeWidth,scoreWidth=scoreWidth,
        backX=backX,retryX=retryX,buttonY=buttonY,retryY=buttonY,buttonBack=buttonBack,buttonRetry=buttonRetry,buttonH=buttonH,footer=footer}
end
function M.Update(layer,b,visible,dt)
    local identity=visible and (b.rules.state=='over' and b.result or b.rules) or false
    if layer.boardIdentity~=identity then layer.boardIdentity=identity;layer.boardAge=0 end
    layer.boardAge=math.min(.2,(layer.boardAge or 0)+math.max(0,dt or 0))
    layer.boardAlpha=visible and Ease(layer.boardAge/.2,'css-ease-out') or 0
end
local function Reward(vg,result,x,y)
    local runs={{'段位分',16,'vox-title',false},
        {(result.delta>=0 and '+' or '')..result.delta,22,'vox-title',true},
        {'（'..result.profile.rating..'） · 经验',16,'vox-title',false},
        {'+'..result.xp,22,'vox-title',true},
        {' · 等级 '..result.profile.level,16,'vox-title',false}}
    for _,run in ipairs(runs) do
        if run[4] then x=x+4 end
        D.Text(vg,run[1],x,y,run[2],run[4] and D.white or {255,255,255,176},run[3],nil,1,true)
        x=x+D.Advance(vg,run[1],run[2],run[3],1)+(run[4] and 4 or 0)
    end
    return x
end
local function Rows(layer,b)
    local key=tostring(b.rules)..':'..tostring(b.result)..':'..math.floor(b.clock*10)
    if layer.boardKey==key then return layer.boardRows end
    local teams={blue={},red={}}
    for i,e in ipairs(b.entries) do teams[e.unit.team][#teams[e.unit.team]+1]={entry=e,index=i,score=Motion.Score(b.stats[e.unit])} end
    for _,list in pairs(teams) do table.sort(list,function(a,c) return a.score==c.score and a.index<c.index or a.score>c.score end) end
    layer.boardKey=key;layer.boardRows=teams;return teams
end
local function Fit(vg,text,size,width,font)
    text=tostring(text);if D.Width(vg,text,size,font)<=width then return text end
    local chars={};for _,cp in utf8.codes(text) do chars[#chars+1]=utf8.char(cp) end
    repeat table.remove(chars) until #chars==0 or D.Width(vg,table.concat(chars)..'...',size,font)<=width
    return table.concat(chars)..'...'
end
function M.Background(vg,x,y,w,h,alpha)
    nvgSave(vg);nvgGlobalAlpha(vg,alpha or 1)
    Paint.Glow(vg,x,y+4,w,h,12,{8,15,28},85/255)
    D.Path(vg,{x,y,x+w-26,y,x+w,y+26,x+w,y+h,x+26,y+h,x,y+h-26})
    nvgFillColor(vg,nvgRGBA(16,34,56,245));nvgFill(vg);nvgRestore(vg)
end
function M.Draw(vg,layer,b,w,h,k,cfg,layout)
    if b.rules.state=='over' and not b.result then layer.resultRect=nil;return end
    local over=b.rules.state=='over';local teams=Rows(layer,b)
    local embedded=layout~=nil;local m=layout or M.Layout(w,h,b,cfg,w>h and h<=600)
    local header,teamHeight,bh,bw=m.header,m.teamHeight,m.h,m.w
    local bx,by=embedded and 0 or (w-bw)/2,embedded and 0 or (h-m.viewH)/2+m.viewH*.02*(1-(layer.boardAlpha or 1))
    nvgSave(vg);nvgGlobalAlpha(vg,layer.boardAlpha or 1)
    if not embedded then M.Background(vg,bx,by,bw,m.viewH,layer.boardAlpha or 1) end
    D.Path(vg,{bx,by,bx+bw-26,by,bx+bw,by+26,bx+bw,by+header,bx,by+header})
    nvgFillColor(vg,nvgRGBA(27,53,78,255));nvgFill(vg)
    D.Rect(vg,bx,by+header-1,bw,1,{255,255,255,20})
    local winner=b.rules.winner;local title=over and (winner=='blue' and '胜利' or winner=='red' and '失败' or '平局') or cfg.name
    local resultPad=m.compact and 18 or 36;local titleSize=m.compact and 52 or 92
    local titleLine=over and math.floor(titleSize*.9*64)/64 or 34
    local resultBottom=by+header-1-(m.compact and 18 or 20)
    D.Text(vg,title,bx+(over and resultPad or 34),over and resultBottom-titleLine or by+22,over and titleSize or 34,over and (winner=='red' and red or winner=='blue' and blue or D.white) or D.white,'vox-title',nil,over and 10 or 4,false,titleLine,
        over and winner and {{blur=40,color=winner=='red' and {255,74,61,102} or {46,168,255,102}}} or nil)
    if not over then
        for i,line in ipairs(m.caption) do D.Text(vg,line,bx+34,by+62+(i-1)*15,12,{255,106,19,255},'vox-title',nil,5) end
        local state=State(b)
        local right=bx+bw-34
        layer.boardTimeWidth=m.timeWidth
        local timeY=by+22+(header-39-52)/2
        D.Text(vg,state,right,timeY,14,{255,255,255,160},'vox-title',NVG_ALIGN_RIGHT,3)
        local left=math.max(0,math.ceil(b.rules:TimeLeft()))
        D.Text(vg,string.format('%d:%02d',math.floor(left/60),left%60),right,timeY+18,28,D.white,'vox-display',NVG_ALIGN_RIGHT)
    end
    local sc=b.rules.score;local suffix=b.mode=='conquest' and '%' or b.mode=='escort' and '米' or ''
    local text=math.floor(sc.blue)..suffix;local other=math.floor(sc.red)..suffix
    if over then
        local tx=bx+resultPad+D.Width(vg,title,titleSize,'vox-title',10)+(m.compact and 16 or 28)
        D.Text(vg,text..':'..other,tx,resultBottom-48,40,D.white,'vox-display',nil,2,false,48)
    else
        local tx=bx+bw-56-layer.boardTimeWidth-m.scoreWidth;local scoreY=by+22+(header-39-44)/2
        D.Text(vg,text,tx,scoreY,44,blue,'vox-display')
        tx=tx+D.Width(vg,text,44,'vox-display')+14;D.Text(vg,':',tx,scoreY+6,22,{255,255,255,96},'vox-display')
        tx=tx+D.Width(vg,':',22,'vox-display')+14;D.Text(vg,other,tx,scoreY,44,red,'vox-display')
    end
    if over then for i,event in ipairs(b.rules.history or {}) do
        local x=bx+bw-36-(#b.rules.history-i+1)*40;local y=by+header-30
        D.Path(vg,{x+5,y,x+39,y,x+34,y+10,x,y+10});nvgFillColor(vg,D.Color(event.winner=='blue' and blue or event.winner=='red' and red or {255,255,255,32}));nvgFill(vg)
    end end
    local x,y=bx+m.padding,by+header+(m.compact and 10 or 12);local rw=m.rowWidth;local nameWidth=m.nameWidth
    local centers={};local nextX=x+m.avatar+nameWidth
    for i,width in ipairs(m.tracks) do centers[i]=nextX+width/2;nextX=nextX+width end
    local top=y
    for index,team in ipairs({'blue','red'}) do
        if m.columns and index==2 then
            x=bx+m.padding*2+rw;y=top;nextX=x+m.avatar+nameWidth
            for i,width in ipairs(m.tracks) do centers[i]=nextX+width/2;nextX=nextX+width end
        end
        local list=teams[team];local alive,damage=0,0
        for _,row in ipairs(list) do local e=row.entry;alive=alive+(e.unit.alive and 1 or 0);damage=damage+b.stats[e.unit].damage end
        local name=team=='blue' and '蓝队 · 我方' or '红队 · 敌方';D.Text(vg,name,x,y,24,team=='blue' and blue or red,'vox-title',nil,5)
        D.Text(vg,alive..' / '..#list..' 存活 · 总伤害 '..D.Number(damage),x+D.Width(vg,name,24,'vox-title',5)+14,y+12,12,{255,255,255,112},'vox-title',nil,3)
        y=y+37;D.Text(vg,'机修师',x+m.avatar+16,y+5.5,12,{255,255,255,112},'vox-title',nil,3)
        for i,label in ipairs(labels) do D.Text(vg,label,centers[i],y+5.5,12,{255,255,255,112},'vox-title',NVG_ALIGN_CENTER,3) end;y=y+31
        for _,row in ipairs(list) do local e=row.entry;local u=e.unit;local st=b.stats[u];local me=u==b.player;local isMvp=over and b.mvp==e
            if me then D.Path(vg,{x,y,x+rw,y,x+rw,y+m.row,x,y+m.row});D.Gradient(vg,x,y,rw,m.row,{122,216,255,64},{122,216,255,16},true)
            else D.Rect(vg,x,y,rw,m.row,{28,53,75,255}) end
            D.Rect(vg,x,y,4,m.row,me and D.orange or team=='blue' and blue or red)
            nvgSave(vg);nvgGlobalAlpha(vg,u.alive and 1 or .4);Paint.Image(vg,'UI/Avatars/'..e.member.avatar..'.jpg',{x=x,y=y,w=m.avatar,h=m.row},1,.5);nvgRestore(vg)
            local nameSize=m.compact and 16 or 21;local display=Fit(vg,u.name,nameSize,nameWidth-16-(isMvp and 60 or 0),'vox-title')
            nvgSave(vg);nvgGlobalAlpha(vg,u.alive and 1 or .5);D.Text(vg,display,x+m.avatar+16,y+(m.compact and 4.5 or 5.5),nameSize,D.white,'vox-title');nvgRestore(vg)
            if isMvp then local mx=x+m.avatar+24+D.Width(vg,display,nameSize,'vox-title');D.Rect(vg,mx,y+10,43,17,gold);D.Text(vg,'MVP',mx+6,y+11,11,{26,18,6,255},'vox-title',nil,2) end
            D.Text(vg,(me and '你' or roles[e.member.role] or '')..' · 段位 '..e.member.rating,x+m.avatar+16,y+(m.compact and 30.5 or 40.5),m.compact and 10 or 12,{255,255,255,128},'vox-title',nil,m.compact and 0 or 2)
            local values={e.member.level,st.kills,st.assists or 0,st.deaths,D.Number(st.damage),math.floor(row.score+.5)}
            for i,value in ipairs(values) do local size=i==1 and 18 or i==5 and 19 or m.compact and 17 or 22
                D.Text(vg,value,centers[i],y+(m.row-size*1.2)/2,size,i==6 and gold or i==1 and {255,255,255,176} or i==5 and damageColor or D.white,'vox-display',NVG_ALIGN_CENTER)
            end;y=y+m.row+5
        end;y=y+16
    end
    if over then
        local fy=by+header+teamHeight;D.Rect(vg,bx,fy,bw,1,{255,255,255,20})
        local gain=m.footerItems and m.footerItems.gain
        local gainEnd=Reward(vg,b.result,bx+(gain and gain.x or 36),gain and by+gain.y+22 or fy+52)
        if b.mvp then local item=m.footerItems and m.footerItems.mvp
            D.Text(vg,item and '★ 本局 MVP：'..b.mvp.unit.name or Fit(vg,'★ 本局 MVP：'..b.mvp.unit.name,15,math.max(0,bx+bw-344-gainEnd-18),'vox-title'),bx+(item and item.x or gainEnd-bx+18),item and by+item.y or fy+34.5,15,gold,'vox-title',nil,2)
        end
        D.Text(vg,'本局为 AI 对战（离线），对手和队友均为电脑控制',bx+36,fy+m.footer,12,{255,255,255,85},'vox-title',nil,2)
        layer.resultRect={x=bx*k,y=by*k,w=bw*k,h=bh*k,scale=k,buttonY=(by+m.buttonY)*k}
    else layer.resultRect=nil end
    nvgRestore(vg)
end
return M

-- Frozen home.js battle pane: full canvas with its original card and action bands.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Card=require 'ui.ModeCard'
local Action=require 'ui.ModeAction'
local Paragraph=require 'ui.SourceParagraph'
local Data=require('core.ResourceData').Read('UI/Outgame.json')
local Config=require 'Config'
local Page=UI.Panel:Extend('VoxModePage')
local M={}
local sublines={elimination='三局两胜 · 不复活',conquest='先到 100% · 8 秒复活',escort='一攻一守 · 上下半场换边',test='练习 · 不计战绩',crater='练习 · 没有敌人'}
local solo={
    {id='story',name='剧情模式',en='STORY',sub='坠舰陨坑 · 狐狐海盗团来袭',art='crater',icon='flag'},
    {id='test',name='试车场',en='PROVING GROUND',sub='加速道 · 坡道 · 靶场',icon='flag'},
    {id='crater',name='自由探索',en='FREE ROAM',sub='坠舰陨坑 · N 键传送',icon='target'},
}
local function Fade(vg,x,y,w,h,a,b,horizontal)
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h);D.Gradient(vg,x,y,w,h,a,b,horizontal)
end
function Page:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local w,h=r.w,r.h
    local x,y=r.x,r.y;local s=self.owner;local p=Data.modes[s.modeChoice]
    local test=s.modeChoice=='test';local dark={11,12,15,255};local transparent={11,12,15,0}
    D.Rect(vg,x,y,w,h,{10,20,34,255})
    require('ui.WorkshopPaint').Image(vg,'UI/Modes/Filtered/'..(test and 'test' or 'crater')..'-map.jpg',{x=x+w*.4,y=y,w=w*.6,h=h},1,.5)
    Fade(vg,x+w*.4,y,w*.084,h,dark,{11,12,15,235},true)
    Fade(vg,x+w*.484,y,w*.168,h,{11,12,15,235},{11,12,15,89},true)
    Fade(vg,x+w*.652,y,w*.12,h,{11,12,15,89},transparent,true)
    Fade(vg,x+w*.4,y,w*.6,h*.3,{11,12,15,140},transparent)
    Fade(vg,x+w*.4,y+h*.55,w*.6,h*.45,transparent,{11,12,15,235})
    Fade(vg,x+w*.76,y,w*.24,h,transparent,{11,12,15,191},true)
    D.Rect(vg,x,y,w*.425,h,dark);Fade(vg,x+w*.425,y,w*.075,h,dark,transparent,true)
    local tx=x+w-522
    D.Rect(vg,tx,y+96,120,19,D.orange);D.Text(vg,'MAP · 地图',tx+9,y+100,12,D.ink,nil,nil,4,false,12)
    D.Text(vg,test and '试车场' or '坠舰陨坑',tx,y+125,84,nil,nil,nil,4,false,79.8)
    D.Text(vg,test and 'PROVING GROUND' or 'CRASH CRATER',tx,y+210.8,16,{255,255,255,140},nil,nil,10)
    D.Text(vg,test and '100 米加速道 · 坡道 · 靶场 · 三辆能逐块打坏的靶车' or '第 7 边境星区 · 600 × 600 米 · 坠毁战舰 CV-07 ARGUS',tx,y+239.8,13,D.muted,'vox-body')
    D.Rect(vg,tx,y+281.8,470,1,{255,255,255,36})
    local name=p and p.name or test and '试车场' or '自由探索'
    D.Text(vg,name,tx,y+298.8,30,nil,nil,nil,2)
    local tag=p and (p.en..' · '..p.size..'V'..p.size..' · '..sublines[p.id]) or sublines[s.modeChoice]
    D.Text(vg,tag,tx+D.Width(vg,name,30,nil,2)+14,y+314.8,13,{230,243,255,255},nil,nil,2)
    local rules=p and p.rules or test and {'自由驾驶，熟悉操控和武器','靶车会逐块被打坏，看看你的火力','可以选任意档位'}
        or {'开着自己的车在地图里随便转（没有敌人）','N 键传送到各个区域，Backspace 回出生点','熟悉路线、找狙击位和掩体'}
    local yy=y+352.8
    for i,text in ipairs(rules) do
        D.Path(vg,{tx+4.8,yy,tx+24,yy,tx+19.2,yy+24,tx,yy+24});nvgFillColor(vg,D.Color(D.orange));nvgFill(vg)
        D.Text(vg,i,tx+12,yy+3,15,D.ink,nil,NVG_ALIGN_CENTER)
        yy=yy+self.paragraph:Draw(vg,text,tx+36,yy,434,{223,226,230,255}).height+14
    end
    if test then D.Text(vg,'出战档位',tx,yy+14,13,D.muted,'vox-body') end
    if not test and h>=800 then require('ui.TacticalMap').Draw(vg,x+w-262,y+h-360,210,s.modeChoice) end
    Fade(vg,x,y,w,60,{8,9,12,235},{8,9,12,184})
    D.Rect(vg,x,y+59,w,1,{255,255,255,20})
end
function M.Start(s)
    if Data.modes[s.modeChoice] then s.app:EnterBattle(s.modeChoice);return end
    s.app:EnterTrial(s.modeChoice=='test' and 'trial' or 'crater')
end
function M.Create(s)
    s.modeChoice=s.modeChoice or 'elimination'
    local w,h=s.width,s.height
    local page=Page{position='absolute',width=w,height=h,pointerEvents='box-none'};page.owner=s
    page.paragraph=Paragraph.New(15,21.75)
    local leftWidth=w*.5;local gridWidth=leftWidth-44;local soloHeight=h*.17
    local modesHeight=math.max(160,h-280-soloHeight);local soloY=201+modesHeight+53
    local left=UI.Panel{width=leftWidth,height=math.max(h,201+modesHeight+53+soloHeight+26),flexShrink=0,pointerEvents='box-none'}
    function left:Render(vg)
        D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y=r.x,r.y
        D.Text(vg,'选择模式',x+44,y+86,58,nil,nil,nil,2,false,58);D.Text(vg,'SELECT MODE',x+300,y+120,16,D.orange,nil,nil,8)
        for _,g in ipairs({{164,'匹配对战','MATCHMAKING','AI 对战 · 离线'},{soloY-37,'单人','SOLO','剧情 · 练习'}}) do
            D.Text(vg,g[2],x+44,y+g[1],20,nil,nil,nil,4);D.Text(vg,g[3],x+44+(g[2]=='单人' and 60 or 108),y+g[1]+7,12,{127,154,180,255},nil,nil,5)
            D.Text(vg,g[4],x+leftWidth-14,y+g[1]+9,11,D.muted,'vox-body',NVG_ALIGN_RIGHT)
        end
    end
    local function Choose(id)
        s.modeChoice=id;s.app.selectedMap=id=='test' and 'trial' or 'crater';s.revision=-1
    end
    local icons={'target','tower','car'}
    for i,id in ipairs({'elimination','conquest','escort'}) do
        local p=Data.modes[id];local item={id=id,name=p.name,en=p.en,size=p.size,icon=icons[i],no='0'..i,
            sub=sublines[id]..' · 约 '..p.minutes..' 分钟',focus=i==1 and .4 or .45,bias=i==1 and .7 or .62}
        local card=s.Track(Card{text=p.name,position='absolute',left=44+(i-1)*(gridWidth+14)/3,top=201,width=(gridWidth-28)/3,height=modesHeight,onClick=function() Choose(id) end})
        card.item=item;card.owner=s;left:AddChild(card)
    end
    local unit=(gridWidth-28)/3.25;local sx=44
    for i,p in ipairs(solo) do
        local width=unit*(i==1 and 1.25 or 1)
        local card=s.Track(Card{text=p.name,position='absolute',left=sx,top=soloY,width=width,height=soloHeight,onClick=function() if p.id=='story' then s.SetTab('story') else Choose(p.id) end end})
        card.item=p;card.owner=s;card.wide=true;left:AddChild(card);sx=sx+width+14
    end
    page:AddChild(UI.ScrollView{position='absolute',width=leftWidth,height=h,scrollY=true,scrollX=false,bounces=false,showScrollbar=false,children={left}})
    local selected=Data.modes[s.modeChoice]
    local name=selected and '开始匹配' or s.modeChoice=='test' and '开始试车' or '进入地图'
    local subtitle=selected and (selected.size..'V'..selected.size..' · 预计等待 0:'..string.format('%02d',8+selected.size*2)) or '单人 · 不计战绩'
    local valid=true
    for _,issue in ipairs(s.app.blueprint:Diagnose(Config.TIERS[s.app.tier]).list) do if issue.level~='warn' then valid=false end end
    local car=s.Track(Action{text=s.app.blueprint.name,sourceKind='loadout',tier=s.app.tier,valid=valid,
        position='absolute',left=w-783.53,top=h-122,width=365.53,height=88,onClick=function() s.SetTab('hangar') end})
    page:AddChild(car)
    page:AddChild(s.Track(Action{text=name,subtitle=subtitle,position='absolute',left=w-432,top=h-122,width=380,height=88,onClick=function() M.Start(s) end}))
    if s.modeChoice=='test' then
        for i=1,5 do
            page:AddChild(s.Track(require('ui.SourceButton'){text='T'..i,sourceKind='flat',selected=s.app.tier==i,position='absolute',
                left=w-436+(i-1)*67,top=500,width=60,height=32,onClick=function() s.app.tier=i;s.app.hangar:SetTier(i);s.revision=-1 end}))
        end
    end
    return page
end
return M

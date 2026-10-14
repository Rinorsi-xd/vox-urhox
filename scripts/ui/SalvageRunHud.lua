-- Frozen srh CSS/CSS2 composition, rendered within the UI-owned NVG frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Loot=require 'salvage.Loot'
local Data=require('core.ResourceData').Read('UI/Outgame.json')
local Theme=require 'ui.VoxTheme'
local Paint=require 'ui.WorkshopPaint'
local Host=require 'ui.DialogHost'
local Panel=UI.Panel:Extend('VoxSalvageRunHud')
local M={}
local white={242,239,232,255};local muted={201,193,178,255};local gold={240,162,28,255};local cyan={62,230,255,255}
local function Text(vg,t,x,y,size,c,align) D.Text(vg,tostring(t),x,y,size,c or white,'vox-story',align) end
local function Fmt(seconds) local s=math.max(0,math.ceil(seconds));return string.format('%02d:%02d',math.floor(s/60),s%60) end
local function Color(item)
    local hex=Data.rarity[item.rarity+1].color
    return {tonumber(hex:sub(2,3),16),tonumber(hex:sub(4,5),16),tonumber(hex:sub(6,7),16),255}
end
local function Frame(vg,x,y,w,h,color)
    D.Panel(vg,x,y,w,h,12,{14,19,25,230},{11,15,20,242});D.Rect(vg,x,y,w-12,2,color or gold)
end
local function Icon(vg,it,x,y,size,c)
    if it.part then Paint.Image(vg,Theme.Thumbnail(it.part),{x=x,y=y,w=size,h=size},1,0,nil,nil,0)
    else D.Icon(vg,it.icon,x+3,y+3,size-6,c) end
end
function Panel:Render(vg)
    D.Begin(vg);local box=self:GetAbsoluteLayout();local run=self.session.salvage;local r=run.rules
    if r.finished then return end
    local opacity=1-run.cine.hud.value;if opacity<=.001 then return end
    local scale=self.session.touch and .65 or math.min(1,box.w/1100,box.h/640)
    local w,h=box.w/scale,box.h/scale
    nvgSave(vg);nvgGlobalAlpha(vg,opacity);nvgTranslate(vg,box.x,box.y);nvgScale(vg,scale,scale)
    local tx=w/2-154
    D.Panel(vg,tx,14,308,63,10,{17,21,26,204},{17,21,26,153});D.Rect(vg,tx,75,308,2,gold)
    Text(vg,'断坝峡谷 · 打捞行动',tx+16,20,12,muted)
    Text(vg,Fmt(900-r.time),tx+62,36,26,900-r.time<120 and {255,106,77,255} or white,NVG_ALIGN_CENTER)
    Text(vg,'热度',tx+142,31,11,muted);Text(vg,math.floor(r.heat),tx+292,31,11,muted,NVG_ALIGN_RIGHT)
    D.Rect(vg,tx+142,50,150,6,{255,255,255,26});D.Rect(vg,tx+142,50,150*r.heat/100,6,gold)
    local cargo=run.hudCargo or {};local cx,cy=w-436,h-(self.session.touch and 304 or 184)
    Frame(vg,cx,cy,418,130)
    Text(vg,'货舱',cx+12,cy+12,16,gold);Text(vg,Loot.Used(r.cargo)..' / 20',cx+65,cy+13,15)
    Text(vg,'载重 '..math.floor(Loot.Mass(r.cargo))..' kg · 价值 '..D.Number(Loot.Value(r.cargo)),cx+406,cy+14,12,muted,NVG_ALIGN_RIGHT)
    local slots={};for _,row in ipairs(cargo) do
        local stack=Loot.Stack(row.id);local count=row.n
        while count>0 do local k=math.min(stack,count);slots[#slots+1]={id=row.id,n=k,size=Loot.Size(row.id)};count=count-k end
    end
    local at=0;local slotPositions={}
    for _,row in ipairs(slots) do
        if row.size==2 and at%10==9 then at=at+1 end
        if at+row.size>20 then break end
        local x,y=cx+12+(at%10)*40,cy+40+math.floor(at/10)*40;local size=row.size*40-4
        slotPositions[row.id]=slotPositions[row.id] or {x=x,y=y}
        local it=Data.items[row.id];local c=Color(it)
        D.Panel(vg,x,y,size,36,0,{c[1],c[2],c[3],5},{c[1],c[2],c[3],89});D.Rect(vg,x,y+33,size,3,c)
        local age=r.time-(run.revealed and run.revealed[row.id] or -100)
        nvgSave(vg)
        if age<.38 then local pop=age<.209 and .82+age/.209*.3 or 1.12-(age-.209)/.171*.12
            nvgTranslate(vg,x+size/2,y+18);nvgScale(vg,pop,pop);nvgTranslate(vg,-x-size/2,-y-18) end
        Icon(vg,it,x+(size-32)/2,y+2,32,c);Text(vg,row.n,x+size-2,y+20,11,white,NVG_ALIGN_RIGHT);nvgRestore(vg)
        at=at+row.size
    end
    for i=at,19 do D.Rect(vg,cx+12+(i%10)*40,cy+40+math.floor(i/10)*40,36,36,{255,255,255,8}) end
    D.Rect(vg,cx+12,cy+122,394,3,{255,255,255,20});D.Rect(vg,cx+12,cy+122,394*math.min(1,Loot.Used(r.cargo)/20),3,cyan)
    local search=r.search
    if search then
        local sx,sy=w-336,h*.22;local sh=74+#search.items*49;local color=search.o.ctype=='vault' and gold or cyan
        local elapsed=r.time-(self.searchAt or r.time);local fade=math.min(1,elapsed/.2)
        nvgSave(vg);nvgGlobalAlpha(vg,fade);nvgTranslate(vg,24*(1-require('ui.SourceButtonMotion').Ease(math.min(1,elapsed/.25),false)),0)
        Frame(vg,sx,sy,318,sh,color);Text(vg,search.title,sx+14,sy+11,18,color)
        Text(vg,D.Number(search.value),sx+304,sy+15,12,gold,NVG_ALIGN_RIGHT)
        for i,it in ipairs(search.items) do local y=sy+43+(i-1)*49;local item=Data.items[it.id];local c=Color(item);local known=it.state=='shown' or it.state=='full'
            D.Rect(vg,sx+10,y,298,44,{255,255,255,7})
            if known then
                D.Path(vg,{sx+10,y,sx+308,y,sx+308,y+44,sx+10,y+44});D.Gradient(vg,sx+10,y,298,44,{c[1],c[2],c[3],87},{c[1],c[2],c[3],20},true)
                D.Rect(vg,sx+10,y,3,44,c);Icon(vg,item,sx+14,y+3,38,c)
            else
                local scan=it.state=='scan' and (.5+.5*math.sin(r.time*math.pi/.3)) or 0
                D.Rect(vg,sx+13,y+3,38,38,{62,230,255,math.floor(8+scan*26)})
                Text(vg,'?',sx+32,y+11,18,it.state=='scan' and cyan or {108,114,123,255},NVG_ALIGN_CENTER)
            end
            local name=known and item.name or it.state=='scan' and '搜索中…' or '未搜索'
            Text(vg,name,sx+62,y+12,15,known and white or it.state=='scan' and {159,232,255,255} or {108,114,123,255})
            if known then Text(vg,it.state=='full' and '满了' or '×'..it.n,sx+298,y+13,14,it.state=='full' and {255,106,77,255} or muted,NVG_ALIGN_RIGHT) end
            if i==search.i then D.Rect(vg,sx+10,y+42,298*math.min(1,search.p),2,cyan) end
        end
        Text(vg,search.foot or '开远了会收起',sx+14,sy+sh-22,12,muted);nvgRestore(vg)
    end
    local prompt=r.prompt
    if prompt then local x,y=w/2-210,h-150
        D.Panel(vg,x,y,420,62,0,{17,21,26,224},{17,21,26,224})
        nvgBeginPath(vg);nvgCircle(vg,x+31,y+31,18);nvgStrokeColor(vg,nvgRGBA(255,255,255,34));nvgStrokeWidth(vg,4);nvgStroke(vg)
        if (prompt.progress or 0)>0 then nvgBeginPath(vg);nvgArc(vg,x+31,y+31,18,-math.pi/2,-math.pi/2+math.pi*2*math.min(1,prompt.progress),NVG_CW);nvgStrokeColor(vg,D.Color(cyan));nvgStroke(vg) end
        Text(vg,'E',x+31,y+21,16,white,NVG_ALIGN_CENTER);Text(vg,prompt.title,x+64,y+10,17)
        Text(vg,prompt.sub,x+64,y+35,12,prompt.blocked and {255,138,106,255} or muted)
    end
    if r.ex then
        Text(vg,math.ceil(r.ex.left),w/2,h*.26-42,84,cyan,NVG_ALIGN_CENTER)
        Text(vg,'正在撤离 · '..r.ex.e.name,w/2,h*.26+44,15,{230,251,255,255},NVG_ALIGN_CENTER)
    end
    local fy=self.session.touch and 136/scale or 140
    local shown=0;local feedLimit=self.session.touch and math.min(5,math.max(1,math.floor((box.h-196-136)/(54*scale)))) or 5
    for i=#run.feed,1,-1 do local e=run.feed[i]
        if e.untilAt>r.time then
            local age=r.time-(e.at or 0);local alpha=math.min(1,age/.3,(e.untilAt-r.time)/.3)
            nvgSave(vg);nvgGlobalAlpha(vg,alpha);local x=16-16*(1-math.min(1,age/.3))
            D.Rect(vg,x,fy,320,48,{17,21,26,204});D.Rect(vg,x,fy,3,48,cyan)
            nvgIntersectScissor(vg,x,fy,320,48)
            Text(vg,e.title,x+13,fy+6,11,cyan);Text(vg,e.text,x+13,fy+23,14);nvgRestore(vg);fy=fy+54
            shown=shown+1;if shown>=feedLimit then break end
        end
    end
    require('ui.SalvageLootMotion').Draw(run,vg,w,h,Icon,slotPositions)
    nvgRestore(vg)
end
function M.Result(session)
    local run=session.salvage;local result=run.result
    local m=Host.Open(session,result.ok and '撤离成功' or '行动失败',function() session.wantsReturn=true end,{width=780})
    m.DrawHeading=function(vg,x,y,w,title)
        local color=result.ok and {61,220,132,255} or {255,90,60,255}
        D.Rect(vg,x,y,4,74,color);D.Rect(vg,x,y+73,w,1,{255,255,255,20})
        D.Text(vg,title,x+28,y+20,30,color,nil,nil,1)
    end
    local T=require('ui.SalvagePaint').Text
    m:AddContent(T{text=result.title,fontSize=18,width='100%',height=30})
    local sum=UI.Panel{width='100%',flexDirection='row',flexWrap='wrap',gap=22,marginBottom=10}
    for _,stat in ipairs({{'用时',Fmt(result.time)},{'开箱',result.opened},{'击毁',result.kills},{result.ok and '带出价值' or '损失价值',D.Number(result.ok and result.value or result.lost)}}) do
        sum:AddChild(UI.Panel{flexDirection='row',gap=6,height=28,children={T{text=stat[1],fontSize=14,color=muted,width=#stat[1]/3*16,height=25},T{text=tostring(stat[2]),fontSize=20,color=gold,width=math.max(28,#tostring(stat[2])*12),height=25}}})
    end
    m:AddContent(sum)
    if result.ok then
        local list=UI.Panel{width='100%',flexDirection='row',flexWrap='wrap',gap=4}
        for _,row in ipairs(run.hudCargo or {}) do local it=Data.items[row.id];local c=Color(it)
            list:AddChild(UI.Panel{width='48%',height=30,borderRadius=0,borderLeftWidth=3,borderColor=c,backgroundColor={255,255,255,8},padding={4,8},flexDirection='row',children={T{text=it.name,fontSize=14,flexGrow=1,height=22,color=white},T{text='×'..row.n,fontSize=14,width=45,height=22,color=muted,alignRight=true}}})
        end
        if #(run.hudCargo or {})==0 then list:AddChild(T{text='两手空空',fontSize=16,width='100%',height=30}) end
        m:AddContent(UI.ScrollView{width='100%',height=math.min(300,math.max(30,math.ceil(#(run.hudCargo or {})/2)*34)),scrollY=true,children={list}})
    else
        m:AddContent(T{text=result.keepCar and '货舱里的东西全丢了，战车开回来了。' or '战车零件和货舱里的东西全丢了。蓝图还在车库里，缺的零件回大厅补买。',fontSize=16,width='100%',height=60,paragraph=true,lineHeight=24})
    end
    local error=T{text=run.saveError or '',fontSize=14,width='100%',height=24,color={255,106,77,255}};m:AddContent(error)
    local button=require('ui.SourceButton'){text=run.committed and '回大厅' or '重试保存',sourceKind='primary',width=120,height=40,onClick=function()
        if run:Commit() then session.wantsReturn=true else error.props.text=run.saveError or '保存失败' end
    end}
    m:AddContent(UI.Panel{width='100%',flexDirection='row',justifyContent='flex-end',marginTop=20,children={button}})
end
function M.Attach(session,root)
    local layer=Panel{position='absolute',width='100%',height='100%',pointerEvents='none'};layer.session=session;root:AddChild(layer)
    local state={layer=layer}
    function state.Update(dt)
        local run=session.salvage;local r=run.rules
        if layer.searchKey~=r.search then layer.searchKey=r.search;layer.searchAt=r.time end
        run.hudRefresh=(run.hudRefresh or 0)-(dt or 0)
        if run.hudRefresh<=0 then
            run.hudRefresh=.1;local list={};for id,n in pairs(r.cargo) do list[#list+1]={id=id,n=n} end
            table.sort(list,function(a,b) local ar,br=Data.items[a.id].rarity,Data.items[b.id].rarity;return ar==br and a.id<b.id or ar>br end);run.hudCargo=list
        end
        layer:SetVisible(not r.finished)
        if run.result and not session.dialog and not session.wantsReturn then M.Result(session) end
    end
    return state
end
return M

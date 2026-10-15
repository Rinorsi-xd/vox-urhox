-- Shared storyHud.css visuals. Parent pages only choose position and controls.
local D=require 'ui.SourceDraw'
local F=require 'ui.CommsFrame'
local Paragraph=require 'ui.SourceParagraph'
local Paint=require 'ui.WorkshopPaint'
local M={}
local styles={
    nono={name='诺诺',role='战术领航员',tab='INCOMING',channel='CH-07 · 加密频道',foot='CH-07 · 64 KBPS · ENC',
        color={70,200,255,255},line={226,232,238,158},led={61,220,132,255}},
    huhu={name='狐狐',role='狐狐海盗团团长',tab='INTERCEPT',channel='未知频段 · 信号拦截',foot='UNKNOWN · 12 KBPS · NOISE',
        color={255,59,70,255},line={255,196,198,140},led={255,59,70,255}},
    yun={name='小运',role='无人运输车 · 物流 AI',tab='LOGISTICS',channel='CH-12 · 物流频道',foot='CH-12 · 9.6 KBPS · 车载',
        color={255,176,46,255},line={255,226,170,140},led={61,220,132,255}},
    boss={name='董事长',role='星际前途 · 董事长办公室',tab='ENCRYPTED',channel='董事长办公室 · 加密',foot='EXEC · ENC-∞ · ████',
        color={207,200,186,255},line={220,214,204,102},accent={163,32,43,255},led={163,32,43,255}}
}
local contexts=setmetatable({},{__mode='k'})
local paragraphs={}
local portraits={}
local white={244,245,247,255}
local function ParagraphFor(who)
    if not paragraphs[who] then
        local group={}
        for _,key in ipairs({'text','shadow','height'}) do local p=Paragraph.New(19,30.4);p.font='vox-title';p.spacing=who=='boss' and 3 or 0;group[key]=p end
        paragraphs[who]=group
    end
    return paragraphs[who]
end
function M.Typed(card)
    if card.finishedTyping then return card.text end
    local total=utf8.len(card.text) or 0
    local n=math.max(0,math.min(total,math.floor(total*(card.age-(card.lead or 0))/math.max(.001,card.typing))))
    local offset=utf8.offset(card.text,n+1);return offset and card.text:sub(1,offset-1) or card.text
end
function M.Height(vg,card,width,minimum)
    return math.max(minimum or 196,ParagraphFor(card.who or 'nono').height:Measure(vg,card.text,width-206,white).height+90)
end
local function Background(vg,w,h,portrait,style)
    F.Shape(vg,w,h,portrait)
    if portrait then
        local c=style.accent or style.color
        nvgFillPaint(vg,nvgRadialGradient(vg,w*.5,h*.3,0,h*.9,nvgRGBA(c[1],c[2],c[3],56),nvgRGBA(6,12,18,240)));nvgFill(vg)
    else D.Gradient(vg,0,0,w,h,{30,32,36,230},{14,15,17,235}) end
    local handle=contexts[vg]
    if not handle then handle=nvgCreateImage(vg,'UI/Comms/dots.png',NVG_IMAGE_REPEATX|NVG_IMAGE_REPEATY);assert(handle>0,'Comms dot texture unavailable');contexts[vg]=handle end
    F.Shape(vg,w,h,portrait);nvgFillPaint(vg,nvgImagePatternTinted(vg,0,0,5,5,0,handle,portrait and nvgRGBA(style.color[1],style.color[2],style.color[3],31) or nvgRGBA(255,255,255,13)));nvgFill(vg)
end
local function Truck(vg,time,color)
    nvgSave(vg);nvgTranslate(vg,22,40-4*(.5-.5*math.cos(time*math.pi*2/1.6)));nvgScale(vg,1.65,1.65)
    for _,points in ipairs({{4,18,36,18,36,42,4,42},{36,26,50,26,60,36,60,42,36,42}}) do
        D.Path(vg,points);nvgFillColor(vg,nvgRGBA(color[1],color[2],color[3],41));nvgFill(vg);nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,2.5);nvgStroke(vg)
    end
    for _,cx in ipairs({14,48}) do nvgBeginPath(vg);nvgCircle(vg,cx,46,5);nvgStrokeWidth(vg,3);nvgStroke(vg) end
    for _,l in ipairs({{12,28,18,28},{22,28,28,28},{12,34,28,34}}) do D.Line(vg,l[1],l[2],l[3],l[4],color,3) end
    nvgRestore(vg)
end
-- Invert the source cubic-bezier(.16,1,.3,1) without a per-frame allocation.
local function Reveal(age)
    local x=math.max(0,math.min(1,age/.32));local lo,hi=0,1
    for _=1,12 do local t=(lo+hi)/2;local u=1-t;local bx=3*u*u*t*.16+3*u*t*t*.3+t*t*t;if bx<x then lo=t else hi=t end end
    return 1-(1-(lo+hi)/2)^3
end
function M.Draw(vg,card,x,y,width,height,scale,time,portraitHeight)
    local who=card.who or 'nono';local style=styles[who] or styles.nono
    local accent=style.accent or style.color;time=time or card.age;scale=scale or 1
    local reveal=Reveal(time-(card.enteredAt or 0));local cw=width-166
    nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,scale,scale)
    nvgGlobalAlpha(vg,math.min(1,(time-(card.enteredAt or 0))/.25)*(.3+.7*reveal))
    for _,portrait in ipairs({true,false}) do
        local pw=portrait and 150 or cw
        local ph=portrait and (portraitHeight or 196) or height
        nvgSave(vg);if not portrait then nvgTranslate(vg,166,0) end
        if reveal<.999 then nvgIntersectScissor(vg,-12,-12,pw+24,(ph+24)*reveal) end
        Background(vg,pw,ph,portrait,style)
        if portrait then
            nvgSave(vg);nvgIntersectScissor(vg,0,0,150,ph)
            if who=='yun' then Truck(vg,time,style.color)
            else
                local face=card.face or (who=='huhu' and 'huhu_talk' or who=='boss' and 'chairman' or 'nono_talk')
                local r=who=='huhu' and {x=-3,y=-16,w=156,h=195} or who=='boss' and {x=-4,y=2,w=158,h=196} or {x=-70,y=-2,w=330,h=410}
                if who=='nono' or who=='huhu' then
                    if not portraits[who] then portraits[who]=require('ui.CommsPortrait').New(who) end
                    local talking=not card.finishedTyping and card.age<card.typing+(card.lead or 0) or card.speakEnd and card.age<card.speakEnd
                    if portraits[who]:Prepare(time,face,talking) then portraits[who]:Draw(vg,r)
                    else Paint.Image(vg,'UI/Faces/'..face..'.png',r,1,1,nil,nil,.5) end
                else Paint.Image(vg,card.portraitPath or ('UI/Faces/'..face..'.png'),r,1,0,nil,nil,.5) end
            end
            local offset=who=='huhu' and math.floor(time/.25)*2%6 or who=='boss' and math.floor(time/.5)*2%6 or 0
            for yy=3,ph,3 do D.Rect(vg,0,yy+offset,150,1,who=='boss' and {0,0,0,82} or {style.color[1],style.color[2],style.color[3],18}) end
            nvgRestore(vg)
        else
            local led=style.led;local blink=who=='huhu' and .6 or who=='boss' and 1.4
            local lit=not blink or time%blink<blink/2
            if lit then
                nvgBeginPath(vg);nvgRect(vg,16,17,15,15);nvgFillPaint(vg,nvgRadialGradient(vg,23.5,24.5,1,10,D.Color(led),nvgRGBA(led[1],led[2],led[3],0)));nvgFill(vg)
                D.Rect(vg,20,21,7,7,led)
            end
            D.Text(vg,style.tab,36,16,16,style.color,'vox-display',nil,4)
            local tabW=D.Width(vg,style.tab,16,'vox-display',4)
            local name='· '..style.name;D.Text(vg,name,45+tabW,16,15,{232,236,239,255},'vox-title')
            local nameW=D.Width(vg,name,15,'vox-title')
            D.Text(vg,style.role,53+tabW+nameW,18,12,style.color,'vox-title',nil,1)
            local barsX=53+tabW+nameW+D.Width(vg,style.role,12,'vox-title',1)+9
            D.Text(vg,style.channel,cw-20,20,11,{108,115,124,255},'vox-title',NVG_ALIGN_RIGHT,1)
            for i,bh in ipairs({4,7,10,13,9}) do
                local alpha=.65+.35*math.cos((time-(i-1)*.1)*math.pi*2/.8)
                D.Rect(vg,barsX+(i-1)*5,19+13-bh,3,bh,{style.color[1],style.color[2],style.color[3],math.floor(alpha*255)})
            end
            for dx=20,cw-20,7 do D.Line(vg,dx,46,math.min(cw-20,dx+4),46,{style.color[1],style.color[2],style.color[3],71}) end
            local jitter=who=='huhu' and (time%2.4>2.352 and -2 or time%2.4>2.328 and 2 or 0) or 0
            local p=ParagraphFor(who);local text=M.Typed(card)
            local color=who=='huhu' and {255,227,228,255} or who=='boss' and {233,228,218,255} or white
            nvgSave(vg);nvgFontBlur(vg,3);p.shadow:Draw(vg,text,20+jitter,59,cw-40,{0,0,0,255});nvgRestore(vg)
            p.text:Draw(vg,text,20+jitter,58,cw-40,color)
            D.Text(vg,style.foot,20,height-22,10,{108,115,124,255},'vox-display',nil,3)
            for row=0,1 do for col=0,13 do if (row+col)%2==0 then D.Rect(vg,cw-94+col*4,height-20+row*4,4,4,{style.color[1],style.color[2],style.color[3],204}) end end end
        end
        F.Draw(vg,pw,ph,portrait,accent,style.line);nvgRestore(vg)
    end
    nvgRestore(vg)
end
function M.Tick()
    for _,portrait in pairs(portraits) do portrait:Queue() end
end
function M.GetPortrait(who) return portraits[who] end
function M.Dispose()
    for _,portrait in pairs(portraits) do portrait:Dispose() end;portraits={}
    for vg,image in pairs(contexts) do nvgDeleteImage(vg,image) end
    contexts=setmetatable({},{__mode='k'});paragraphs={}
end
return M

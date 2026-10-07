-- Drawing primitives for the source's fixed-size scene canvases (not screen UI).
-- Display faces come from H5; body face remains the bundled MiSans substitute.
local C={TEXT={238,242,246,255},DIM={134,150,168,255},LINE={46,168,255,128},
    ACCENT={46,168,255,255},BRAND={255,106,19,255},WARN={255,194,26,255},BAD={255,59,48,255},OK={61,220,132,255}}
function C.Init(vg)
    assert(nvgCreateFont(vg,'display','Fonts/BarlowCondensed-BoldItalic.ttf')>=0)
    assert(nvgCreateFont(vg,'title','Fonts/SmileySans-Oblique.ttf')>=0)
    assert(nvgCreateFont(vg,'body','Fonts/MiSans-Bold.ttf')>=0)
    nvgAddFallbackFont(vg,'display','title');nvgAddFallbackFont(vg,'title','body')
end
function C.Color(c) return nvgRGBA(c[1],c[2],c[3],c[4] or 255) end
function C.Rect(vg,x,y,w,h,c)
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h);nvgFillColor(vg,C.Color(c));nvgFill(vg)
end
function C.Path(vg,p,close)
    nvgBeginPath(vg);nvgMoveTo(vg,p[1],p[2]);for i=3,#p,2 do nvgLineTo(vg,p[i],p[i+1]) end
    if close~=false then nvgClosePath(vg) end
end
function C.Stroke(vg,c,width) nvgStrokeColor(vg,C.Color(c));nvgStrokeWidth(vg,width);nvgStroke(vg) end
function C.Fill(vg,c) nvgFillColor(vg,C.Color(c));nvgFill(vg) end
local function Runs(text,body)
    if body then return {{face='body',text=text}} end
    local runs={}
    for _,cp in utf8.codes(text) do
        local face=(cp<=255 or cp>=0x2010 and cp<=0x2027 or cp>=0x2030 and cp<=0x205e) and 'display' or 'title'
        local run=runs[#runs]
        if not run or run.face~=face then run={face=face,text=''};runs[#runs+1]=run end
        run.text=run.text..utf8.char(cp)
    end
    return runs
end
function C.Width(vg,text,size,body)
    nvgFontSize(vg,size);local width=0
    for _,r in ipairs(Runs(tostring(text),body)) do nvgFontFace(vg,r.face);width=width+nvgTextBounds(vg,0,0,r.text) end
    return width
end
function C.Text(vg,text,x,y,size,color,body,align,baseline)
    text=tostring(text);local width=C.Width(vg,text,size,body)
    if align==NVG_ALIGN_RIGHT then x=x-width elseif align==NVG_ALIGN_CENTER then x=x-width/2 end
    nvgTextAlign(vg,NVG_ALIGN_LEFT+(baseline or NVG_ALIGN_BASELINE));nvgFillColor(vg,C.Color(color or C.TEXT))
    for _,r in ipairs(Runs(text,body)) do nvgFontFace(vg,r.face);nvgText(vg,x,y,r.text);x=x+nvgTextBounds(vg,0,0,r.text) end
    return width
end
function C.Fit(vg,text,width,size,body)
    if C.Width(vg,text,size,body)<=width then return text end
    while utf8.len(text)>1 and C.Width(vg,text..'…',size,body)>width do text=text:sub(1,utf8.offset(text,-1)-1) end
    return text..'…'
end
function C.Number(n)
    local s=tostring(math.floor(n+.5)):reverse():gsub('(%d%d%d)','%1,'):reverse();return (s:gsub('^,',''))
end
function C.Frame(vg,title,slot)
    C.Path(vg,{3,3,984,3,1021,40,1021,637,3,637});C.Fill(vg,{14,22,32,235});C.Stroke(vg,C.LINE,3)
    C.Rect(vg,3,22,10,56,C.ACCENT)
    C.Text(vg,title,40,52,46,C.TEXT,false,nil,NVG_ALIGN_MIDDLE)
    C.Text(vg,slot and string.format('车位 %02d',slot) or '草稿 · 还没放进车位',960,54,30,C.DIM,false,NVG_ALIGN_RIGHT,NVG_ALIGN_MIDDLE)
    -- Canvas's three-stop gradient, split at the original 35% stop.
    for _,v in ipairs({{40,370.4,{46,168,255,204},{255,255,255,31}},{370.4,984,{255,255,255,31},{255,255,255,10}}}) do
        nvgBeginPath(vg);nvgRect(vg,v[1],94,v[2]-v[1],2)
        nvgFillPaint(vg,nvgLinearGradient(vg,v[1],94,v[2],94,C.Color(v[3]),C.Color(v[4])));nvgFill(vg)
    end
end
return C

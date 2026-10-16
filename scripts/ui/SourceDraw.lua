-- Source CSS/SVG primitives. UI or SourceLayer owns each context's frame/DPR.
-- These helpers never begin frames or create per-frame fonts.
local SourceFonts=require("ui.SourceFonts")

local M={white={237,246,255,255},muted={145,172,200,255},dim={83,123,156,255},orange={122,216,255,255},blue={40,121,235,255},green={142,227,208,255},ink={8,15,28,255}}
local contexts=setmetatable({},{__mode='k'})
local Typography=require 'ui.SourceTextLayout'
local icons=require('core.ResourceData').Read('UI/SourceIcons.json')
function M.Begin(vg)
    if contexts[vg] then return end
    local title=nvgCreateFont(vg,'vox-title','Fonts/VoxIndustrial-Bold.otf')
    local display=nvgCreateFont(vg,'vox-display','Fonts/BarlowCondensed-BoldItalic.ttf')
    local tabular=nvgCreateFont(vg,'vox-tabular','Fonts/VoxDisplayTabular-BoldItalic.ttf')
    local story=nvgCreateFont(vg,'vox-story','Fonts/SmileySans-Oblique.ttf')
    local fonts=SourceFonts.Resolve()
    local body=nvgCreateFont(vg,'vox-body',fonts.body)
    local code=nvgCreateFont(vg,'vox-code',fonts.code)
    assert(title>=0 and display>=0 and tabular>=0 and story>=0 and body>=0 and code>=0,'Source UI fonts failed to load')
    nvgAddFallbackFontId(vg,story,body)
    nvgAddFallbackFontId(vg,code,body)
    nvgAddFallbackFontId(vg,title,body)
    nvgAddFallbackFontId(vg,display,title);nvgAddFallbackFontId(vg,display,body)
    nvgAddFallbackFontId(vg,tabular,title);nvgAddFallbackFontId(vg,tabular,body)
    contexts[vg]={codeAdvance=fonts.codeAdvance,bodyMetrics=fonts.bodyMetrics}
end
function M.HudFont(vg)
    M.Begin(vg);local ctx=contexts[vg]
    if ctx.hud then return end
    local face=nvgCreateFont(vg,'vox-hud','Fonts/ChakraPetch-Bold.ttf')
    local medium=nvgCreateFont(vg,'vox-hud-medium','Fonts/ChakraPetch-Medium.ttf')
    assert(face>=0 and medium>=0,'Source HUD font failed to load')
    nvgAddFallbackFont(vg,'vox-hud','vox-title');nvgAddFallbackFont(vg,'vox-hud','vox-body')
    nvgAddFallbackFont(vg,'vox-hud-medium','vox-title');nvgAddFallbackFont(vg,'vox-hud-medium','vox-body')
    ctx.hud=true
end
function M.Color(c) return nvgRGBA(c[1],c[2],c[3],c[4] or 255) end
function M.Rect(vg,x,y,w,h,c)
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h);nvgFillColor(vg,M.Color(c));nvgFill(vg)
end
function M.Path(vg,points)
    nvgBeginPath(vg);nvgMoveTo(vg,points[1],points[2]);for i=3,#points,2 do nvgLineTo(vg,points[i],points[i+1]) end;nvgClosePath(vg)
end
function M.Gradient(vg,x,y,w,h,a,b,horizontal)
    nvgFillPaint(vg,nvgLinearGradient(vg,x,y,horizontal and x+w or x,horizontal and y or y+h,M.Color(a),M.Color(b)));nvgFill(vg)
end
function M.Panel(vg,x,y,w,h,cut,top,bottom)
    M.Path(vg,{x,y,x+w-cut,y,x+w,y+cut,x+w,y+h,x,y+h})
    M.Gradient(vg,x,y,w,h,top or {33,59,85,255},bottom or {18,38,59,255})
    M.Rect(vg,x,y,w-cut,1,{255,255,255,22});M.Rect(vg,x,y+h-3,w,3,{0,0,0,100})
end
-- Native fallback selection differs between bundled runtimes. Select the exact
-- source font per Unicode run instead of silently falling back to body type.
local runCache={};local runCount=0
local function Runs(text)
    if runCache[text] then return runCache[text] end
    local result={};local last=false
    for _,code in utf8.codes(text) do
        local face=(code<=255 or code>=0x2010 and code<=0x2027 or code>=0x2030 and code<=0x205e) and 'vox-display' or 'vox-title'
        if not last or last.face~=face then last={face=face,text=''};result[#result+1]=last end
        last.text=last.text..utf8.char(code)
    end
    if runCount>=256 then runCache={};runCount=0 end
    runCache[text]=result;runCount=runCount+1;return result
end
local function DirectFont(font) return font and font~='vox-display' and font~='vox-tabular' and font~='vox-legacy-display' and font~='vox-hud' and font~='vox-hud-medium' end
local function InlineFont(vg,font)
    if font=='vox-repair-symbol' then
        local ctx=contexts[vg]
        if not ctx.repairSymbol then
            local face=SourceFonts.ResolveRepairSymbol()
            assert(nvgCreateFont(vg,font,face.path)>=0,'Repair symbol font unavailable');ctx.repairSymbol=face
        end
        return
    end
    if font=='vox-help-symbol' then
        local ctx=contexts[vg]
        if not ctx.helpSymbol then
            local face=SourceFonts.ResolveHelpSymbol()
            assert(nvgCreateFont(vg,font,face.path)>=0,'Help symbol font unavailable');ctx.helpSymbol=face
        end
        return
    end
    if font~='vox-inline-code' then return end
    local ctx=contexts[vg];if ctx.inlineCode then return end
    local face=SourceFonts.ResolveInlineCode()
    assert(nvgCreateFont(vg,font,face.path)>=0,'Source inline code font unavailable')
    ctx.inlineCode=face
end
local function Face(run,font)
    if font=='vox-legacy-display' then return run.face=='vox-display' and 'vox-display' or 'vox-story' end
    return run.face=='vox-display' and (font or 'vox-display') or run.face
end
local codeCache={};local codeCount=0
local function CodeRuns(text)
    if codeCache[text] then return codeCache[text] end
    local runs={}
    for _,cp in utf8.codes(text) do
        local ascii=cp<128;local run=runs[#runs]
        if not run or run.ascii~=ascii then run={ascii=ascii,text=''};runs[#runs+1]=run end
        run.text=run.text..utf8.char(cp)
    end
    if codeCount>=256 then codeCache={};codeCount=0 end
    codeCache[text]=runs;codeCount=codeCount+1;return runs
end
local function CodeText(vg,text,size,spacing,x,y,font)
    font=font or 'vox-code';nvgFontFace(vg,font);nvgTextLetterSpacing(vg,0)
    local ctx=contexts[vg];local advance=ctx and ctx.codeAdvance
    if font=='vox-inline-code' then
        local em=ctx.inlineCode.advance
        -- Source Chromium uses SimSun's rounded logical-pixel ASCII advance.
        -- Keep that layout at higher DPR while allowing the glyph atlas to grow.
        advance=em and math.floor(math.floor(size+.5)*em+.5)/size or nil
    end
    local correction=advance and size*advance-nvgTextBounds(vg,0,0,'0') or 0
    local width=0
    for _,run in ipairs(CodeRuns(text)) do
        nvgTextLetterSpacing(vg,(spacing or 0)+(run.ascii and correction or 0))
        if x then nvgText(vg,x+width,y,run.text) end
        width=width+nvgTextBounds(vg,0,0,run.text)
    end
    return width
end
function M.Width(vg,text,size,font,spacing)
    font=font or 'vox-title';spacing=spacing or 0
    InlineFont(vg,font)
    text=tostring(text or '');nvgFontSize(vg,size);nvgTextLetterSpacing(vg,spacing or 0)
    local layout=Typography.Get(text,font)
    if layout then nvgTextLetterSpacing(vg,0);return Typography.Width(layout,size,spacing) end
    local width=0
    if font=='vox-code' or font=='vox-inline-code' then width=CodeText(vg,text,size,spacing,nil,nil,font)
    elseif DirectFont(font) then nvgFontFace(vg,font);width=nvgTextBounds(vg,0,0,text)
    else for _,run in ipairs(Runs(text)) do nvgFontFace(vg,Face(run,font));width=width+nvgTextBounds(vg,0,0,run.text) end end
    nvgTextLetterSpacing(vg,0);return width
end
-- Inline runs accumulate unrounded advances; only their final CSS box rounds.
function M.Advance(vg,text,size,font,spacing)
    text=tostring(text or '');local layout=Typography.Get(text,font)
    return layout and Typography.Advance(layout,size,spacing) or M.Width(vg,text,size,font,spacing)
end
function M.HasBodyAdvances(vg)
    local ctx=contexts[vg];return ctx and ctx.bodyMetrics and ctx.bodyMetrics.fractional or false
end
function M.FontMetrics(vg,size,font)
    if font=='vox-legacy-display' then return M.FontMetrics(vg,size,'vox-story') end
    InlineFont(vg,font)
    local inline=font=='vox-inline-code' and contexts[vg].inlineCode or font=='vox-help-symbol' and contexts[vg].helpSymbol or font=='vox-repair-symbol' and contexts[vg].repairSymbol
    if inline and inline.ascent then return math.floor(inline.ascent*size+.5+1e-8),math.floor(inline.descent*size+.5+1e-8) end
    local ascent,descent=Typography.Metrics(font,size)
    if ascent then return ascent,descent end
    local ctx=contexts[vg];local source=font=='vox-body' and ctx and ctx.bodyMetrics
    if source then return math.floor(source.ascent*size+.5),math.floor(source.descent*size+.5) end
    nvgSave(vg);nvgFontFace(vg,font or 'vox-display');nvgFontSize(vg,size)
    local a,d=nvgTextMetrics(vg);nvgRestore(vg);return a,-d
end
function M.Text(vg,text,x,y,size,color,font,align,spacing,atBaseline,lineHeight,shadows)
    if shadows then
        nvgSave(vg)
        for i=#shadows,1,-1 do local s=shadows[i]
            nvgFontBlur(vg,s.blur or 0)
            M.Text(vg,text,x+(s.x or 0),y+(s.y or 0),size,s.color,font,align,spacing,atBaseline,lineHeight)
        end
        nvgRestore(vg)
    end
    font=font or 'vox-title';spacing=spacing or 0
    if lineHeight and not atBaseline then
        local ascent,descent=M.FontMetrics(vg,size,font)
        y=y+(lineHeight-ascent-descent)/2
    end
    text=tostring(text or '');local width=M.Width(vg,text,size,font,spacing)
    if align==NVG_ALIGN_RIGHT then x=x-width elseif align==NVG_ALIGN_CENTER then x=x-width/2 end
    -- Native tracking preserves kerning and includes the CSS trailing spacing.
    -- Measuring and drawing use the same runs and font, including tnum variants.
    nvgTextLetterSpacing(vg,spacing or 0)
    nvgTextAlign(vg,NVG_ALIGN_LEFT+(atBaseline and NVG_ALIGN_BASELINE or NVG_ALIGN_TOP));nvgFillColor(vg,M.Color(color or M.white))
    local layout=Typography.Get(text,font)
    if layout then Typography.Draw(vg,layout,x,y,size,spacing,font,atBaseline)
    elseif font=='vox-code' or font=='vox-inline-code' then CodeText(vg,text,size,spacing,x,y,font)
    elseif DirectFont(font) then nvgFontFace(vg,font);nvgText(vg,x,y,text)
    else for _,run in ipairs(Runs(text)) do nvgFontFace(vg,Face(run,font));nvgText(vg,x,y,run.text);x=x+nvgTextBounds(vg,0,0,run.text) end end
    nvgTextLetterSpacing(vg,0);nvgTextAlign(vg,NVG_ALIGN_LEFT+NVG_ALIGN_TOP)
end
function M.Icon(vg,name,x,y,size,color,lineWidth)
    if name=='hook' then
        -- Original home.js HOOK path, including its three-quarter 4px arc.
        nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,size/24,size/24);nvgBeginPath(vg)
        nvgMoveTo(vg,12,2);nvgLineTo(vg,12,11);nvgMoveTo(vg,7,11);nvgLineTo(vg,17,11)
        nvgMoveTo(vg,12,11);nvgLineTo(vg,12,15)
        nvgBezierTo(vg,12,17.209139,10.209139,19,8,19);nvgBezierTo(vg,5.790861,19,4,17.209139,4,15);nvgBezierTo(vg,4,12.790861,5.790861,11,8,11)
        nvgStrokeWidth(vg,lineWidth or 2);nvgStrokeColor(vg,M.Color(color or M.white));nvgStroke(vg);nvgRestore(vg);return
    end
    local path=icons[name];if not path then return end
    nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,size/24,size/24);nvgBeginPath(vg)
    for _,cmd in ipairs(path) do
        local op=cmd[1]
        if op=='moveTo' then nvgMoveTo(vg,cmd[2],cmd[3])
        elseif op=='lineTo' then nvgLineTo(vg,cmd[2],cmd[3])
        elseif op=='curveTo' then nvgBezierTo(vg,cmd[2],cmd[3],cmd[4],cmd[5],cmd[6],cmd[7])
        elseif op=='closePath' then nvgClosePath(vg) end
    end
    nvgStrokeWidth(vg,lineWidth or 2);nvgLineCap(vg,NVG_SQUARE);nvgLineJoin(vg,NVG_MITER);nvgStrokeColor(vg,M.Color(color or M.white));nvgStroke(vg);nvgRestore(vg)
end
function M.Meter(vg,x,y,w,h,value,cap,segments)
    local ratio=cap>0 and value/cap or 0;local color=ratio>1 and {255,59,48,255} or ratio>.9 and {255,194,26,255} or M.orange
    if segments then
        for dx=0,w-1,11 do M.Rect(vg,x+dx,y,math.min(8,w-dx),h,{255,255,255,26});local fill=math.min(8,w*math.min(1,ratio)-dx);if fill>0 then M.Rect(vg,x+dx,y,fill,h,color) end end
    else M.Rect(vg,x,y,w,h,{255,255,255,26});M.Rect(vg,x,y,w*math.min(1,ratio),h,color) end
end
function M.Number(n)
    local a=tostring(math.floor(n+.5));local out=a:reverse():gsub('(%d%d%d)','%1,'):reverse();return (out:gsub('^,',''))
end
function M.Line(vg,x1,y1,x2,y2,color,width)
    nvgBeginPath(vg);nvgMoveTo(vg,x1,y1);nvgLineTo(vg,x2,y2);nvgStrokeWidth(vg,width or 1);nvgStrokeColor(vg,M.Color(color));nvgStroke(vg)
end
return M

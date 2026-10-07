-- CSS body line metrics and actual RichText glyph rows, using browser baselines.
local D=require 'ui.SourceDraw'
local Rich=require 'ui.SourceRichText'
local f=assert(io.open('tools/migration/fixtures/source-body-lines.json','r'))
local source=cjson.decode(f:read('*a'));f:close()
---@type NVGContextWrapper
local vg=nil
local scale=1
local layouts,results={},{}
local function Draw()
    nvgBeginFrame(vg,graphics.width/scale,graphics.height/scale,scale)
    D.Rect(vg,0,0,960,320,{38,42,49,255})
    for i,row in ipairs(source.samples) do
        local x=12+((i-1)%3)*320;local y=6+math.floor((i-1)/3)*80
        Rich.Draw(vg,layouts[i],x,y)
        nvgFontFace(vg,'vox-body');nvgFontSize(vg,row.size);nvgTextLetterSpacing(vg,0)
        nvgTextAlign(vg,NVG_ALIGN_LEFT+NVG_ALIGN_BASELINE);nvgFillColor(vg,D.Color(D.white))
        for _,glyph in ipairs(row.glyphs) do nvgText(vg,x+glyph.x,y+36+row.baseline,glyph.text) end
    end
    nvgEndFrame(vg)
end
local function Check()
    local im=Image:new();assert(graphics:TakeScreenShot(im))
    local crop=im:GetSubimage(IntRect(0,0,960*scale,320*scale));crop:SavePNG('docs/migration/evidence/pc-body-lines-'..scale..'.png');crop:Dispose()
    for i,row in ipairs(source.samples) do
        local x=(10+((i-1)%3)*320)*scale;local y=(6+math.floor((i-1)/3)*80)*scale
        local error,pixels=0,0
        for dy=0,30*scale-1 do for dx=0,300*scale-1 do
            local a,b=im:GetPixel(x+dx,y+dy),im:GetPixel(x+dx,y+dy+36*scale)
            if a.r>.2 or b.r>.2 then error=error+math.abs(a.r-b.r);pixels=pixels+1 end
        end end
        results[#results+1]={size=row.size,lineHeight=row.lineHeight,scale=scale,mean=error/math.max(1,pixels),pixels=pixels}
        V.assert(pixels>0 and error/pixels<.04,'body actual glyph baseline '..row.size..'/'..row.lineHeight..' DPR '..scale)
    end
    im:Dispose()
end
V.atFrame(20,function()
    vg=nvgCreate(1);nvgSetRenderOrder(vg,999980);D.Begin(vg)
    local FontMetrics=require 'core.BodyFontMetrics'
    local fallback=FontMetrics.Load('Fonts/MiSans-Regular.ttf')
    V.assert(fallback and fallback.format==12 and fallback:Glyph(utf8.codepoint('中'))>0,'packaged fallback font cmap is available')
    V.assert(fallback and not fallback.fractional and fallback:GetAdvance('A')==nil,'font with GPOS kerning keeps native fallback until shaping is supported')
    local malformed='.tmp/invalid-body-font.bin';local bad=File(malformed,FILE_WRITE);bad:WriteString('invalid');bad:Dispose()
    V.assert(FontMetrics.Load(malformed)==nil,'truncated font fails cleanly without retained file handle');fileSystem:Delete(malformed)
    local body=require('ui.SourceFonts').GetBodyFace()
    V.assert(body and body.fractional and body.bufferBytes<256*1024,'selected PC body face retains bounded metrics buffers')
    local expected=body:GetAdvance('中')
    for cp=0x4e00,0x5800 do body:GetAdvance(utf8.char(cp)) end
    V.assert(body.cacheCount<=2048 and body:GetAdvance('中')==expected,'body character cache remains bounded and repopulates correctly')
    for i,row in ipairs(source.samples) do
        layouts[i]=Rich.Layout(vg,{{{text=row.text,size=row.size,font='vox-body',color=D.white}}},310,row.lineHeight)
        local line=layouts[i].lines[1];local asc,desc=D.FontMetrics(vg,row.size,'vox-body')
        V.assert(#line.runs==1,'body line coalesces wrapping tokens into one styled run')
        V.assert(asc==row.ascent and desc==row.descent,'body font metrics '..row.size)
        V.assert(line.baseline==row.baseline,'body browser baseline '..row.size..'/'..row.lineHeight)
        V.assert(math.abs(layouts[i].height-row.actualHeight)<.001,'body browser height '..row.size..'/'..row.lineHeight)
    end
    for _,row in ipairs(source.menu) do
        local layout=Rich.Layout(vg,{{{text=row.text,size=12,font='vox-body'}}},245,16.796875)
        for i,top in ipairs(row.lineTops) do V.assert(math.abs(layout.lines[i].y-top)<.001,'source multi-line menu top '..i) end
    end
    local hover=Rich.Layout(vg,{{{text='放置 ',size=12.5,font='vox-body'},{text='轻型方块',size=16,lineHeight='normal'},{text=' · 6 点',size=12.5,font='vox-body'}}},500,20,{size=12.5,font='vox-body'})
    V.assert(hover.height==source.rich[1].height and hover.lines[1].baseline==source.rich[1].baseline,'mixed font hover matches original CSS line box')
    local toast=Rich.Layout(vg,{{{text='已保存战车 ABC 123',size=17}}},500,23.8)
    V.assert(toast.height==source.rich[2].height and toast.lines[1].baseline==source.rich[2].baseline,'toast matches original CSS line box')
    SubscribeToEvent(vg,'NanoVGRender',Draw)
end)
V.atFrame(30,function() Check();scale=2 end)
V.atFrame(35,function()
    Check();local out=assert(io.open('docs/migration/evidence/pc-body-line-placement.json','w'));out:write(cjson.encode(results));out:close()
    UnsubscribeFromEvent(vg,'NanoVGRender');nvgDelete(vg);vg=nil;V.finish()
end)

-- Actual glyph placement against original Chromium DOM Range positions.
-- Reference uses native font rasterization at browser-provided positions;
-- layout is tested independently of browser/FreeType antialias differences.
local D=require 'ui.SourceDraw'
local f=assert(io.open('tools/migration/fixtures/source-display-widths.json','r'))
local source=cjson.decode(f:read('*a'));f:close()
local samples={}
local function Select(tracking)
    samples={};for _,i in ipairs({1,3,9,21,43,55}) do samples[#samples+1]=source.samples[i+tracking] end
end
Select(0)
---@type NVGContextWrapper
local vg=nil
local scale=1
local results={}
local function Latin(cp) return cp<=255 or cp>=0x2010 and cp<=0x2027 or cp>=0x2030 and cp<=0x205e end
local function Draw()
    nvgBeginFrame(vg,graphics.width/scale,graphics.height/scale,scale)
    D.Rect(vg,0,0,960,320,{38,42,49,255})
    for i,row in ipairs(samples) do
        local x=20+((i-1)%3)*320;local y=12+math.floor((i-1)/3)*160
        local align=(i-1)%3==1 and NVG_ALIGN_CENTER or (i-1)%3==2 and NVG_ALIGN_RIGHT or NVG_ALIGN_LEFT
        local anchor=x+(align==NVG_ALIGN_CENTER and row.width/2 or align==NVG_ALIGN_RIGHT and row.width or 0)
        D.Text(vg,row.text,anchor,y,row.size,D.white,row.tabular and 'vox-tabular' or nil,align,row.spacing)
        nvgFontSize(vg,row.size);nvgTextLetterSpacing(vg,0);nvgTextAlign(vg,NVG_ALIGN_LEFT+NVG_ALIGN_BASELINE)
        for _,glyph in ipairs(row.glyphs) do
            nvgFontFace(vg,Latin(utf8.codepoint(glyph.text)) and (row.tabular and 'vox-tabular' or 'vox-display') or 'vox-title')
            nvgText(vg,x+glyph.x,y+64+row.ascent,glyph.text)
        end
    end
    nvgEndFrame(vg)
end
local function Check()
    local im=Image:new();assert(graphics:TakeScreenShot(im))
    local crop=im:GetSubimage(IntRect(0,0,960*scale,320*scale));crop:SavePNG('docs/migration/evidence/pc-title-placement-'..scale..'-'..samples[1].spacing..'.png');crop:Dispose()
    for i,row in ipairs(samples) do
        local x=(16+((i-1)%3)*320)*scale;local y=(12+math.floor((i-1)/3)*160)*scale
        local error,pixels,changed=0,0,0
        for dy=0,55*scale-1 do for dx=0,290*scale-1 do
            local a,b=im:GetPixel(x+dx,y+dy),im:GetPixel(x+dx,y+dy+64*scale)
            if a.r>.2 or b.r>.2 then
                local delta=math.max(math.abs(a.r-b.r),math.abs(a.g-b.g),math.abs(a.b-b.b))
                error=error+delta;pixels=pixels+1;if delta>.04 then changed=changed+1 end
            end
        end end
        results[#results+1]={text=row.text,size=row.size,scale=scale,spacing=row.spacing,mean=error/math.max(1,pixels),changed=changed,pixels=pixels}
        V.assert(pixels>0 and error/pixels<.04,'DPR '..scale..' actual glyph positions follow browser DOM: '..row.text)
    end
    im:Dispose()
end
V.atFrame(20,function()
    vg=nvgCreate(1);nvgSetRenderOrder(vg,999980);D.Begin(vg);SubscribeToEvent(vg,'NanoVGRender',Draw)
end)
V.atFrame(30,function() Check();scale=2 end)
V.atFrame(35,function() Check();scale=1;Select(1) end)
V.atFrame(40,function() Check();scale=2 end)
V.atFrame(45,function()
    Check();local out=assert(io.open('docs/migration/evidence/pc-title-placement.json','w'));out:write(cjson.encode(results));out:close()
    UnsubscribeFromEvent(vg,'NanoVGRender');nvgDelete(vg);vg=nil;V.finish()
end)

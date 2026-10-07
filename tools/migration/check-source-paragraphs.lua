-- Original Home DOM ranges at two PC sizes, not implementation-derived lines.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Paragraph=require 'ui.SourceParagraph'
local reports={}
---@type NVGContextWrapper
local drawContext=nil
local scale=1
local renderedWidths={}
local renderedImportWidths={}
local specimen=Paragraph.New(13,20.796875)
local specimenRuns={{text='粘贴别人分享的 '},{text='FKZC1:',font='vox-inline-code'},{text=' 蓝图码，放进一个新车位。'}}
local function Render()
    nvgBeginFrame(drawContext,graphics.width/scale,graphics.height/scale,scale);D.Begin(drawContext)
    D.Rect(drawContext,0,0,340,100,{38,42,49,255})
    specimen:Draw(drawContext,specimenRuns,20,20,285.328125)
    renderedWidths[scale]=D.Width(drawContext,'FKZC1:',13,'vox-inline-code')
    D.Text(drawContext,'FKZC1:',20,65,12.5,D.muted,'vox-inline-code')
    renderedImportWidths[scale]=D.Width(drawContext,'FKZC1:',12.5,'vox-inline-code')
    nvgEndFrame(drawContext)
end
local function Capture()
    local im=Image:new();assert(graphics:TakeScreenShot(im));local crop=im:GetSubimage(IntRect(0,0,340*scale,100*scale))
    assert(crop:SavePNG('docs/migration/evidence/pc-inline-code-'..scale..'.png'));crop:Dispose();im:Dispose()
    V.assert(math.abs(renderedWidths[scale]-42)<.02,'actual DPR '..scale..' render frame preserves original inline code advance')
    V.assert(math.abs(renderedImportWidths[scale]-42)<.02,'actual DPR '..scale..' render preserves Chromium rounded 12.5px import code advance')
end
V.atFrame(20,function()
    UI.Init({scale=1});local vg=UI.GetNVGContext();D.Begin(vg)
    for _,viewport in ipairs({1920,1440}) do
        local f=assert(io.open('tools/migration/fixtures/source-paragraphs-'..viewport..'.json','r'))
        local source=cjson.decode(f:read('*a'));f:close()
        for _,sample in ipairs(source.samples) do
            local height=sample.lineHeight=='normal' and 'normal' or math.floor(tonumber(sample.lineHeight:match('[%d.]+'))*64)/64
            local paragraph=Paragraph.New(sample.size,height);local runs={}
            for _,run in ipairs(sample.runs) do
                local font=run.font=='monospace' and 'vox-inline-code' or 'vox-body'
                runs[#runs+1]={text=run.text,size=run.size,font=font}
                local actual=D.Width(vg,run.text,run.size,font)
                V.assert(math.abs(actual-run.width)<.02,viewport..' '..sample.key..' actual font advance '..font)
                local asc,desc=D.FontMetrics(vg,run.size,font)
                V.assert(asc==run.ascent and desc==run.descent,viewport..' '..sample.key..' original font ascent/descent '..font)
            end
            local layout=paragraph:Measure(vg,runs,sample.width)
            V.assert(#layout.lines==#sample.lines,viewport..' '..sample.key..' original line count')
            local lines={}
            for index,line in ipairs(layout.lines) do
                local text='';for _,run in ipairs(line.runs) do text=text..run.text end;lines[#lines+1]=text
                local expected=sample.lines[index]
                V.assert(expected and text==expected.text,viewport..' '..sample.key..' line '..index..' equals browser text: '..text)
                local asc=D.FontMetrics(vg,sample.size,'vox-body')
                V.assert(expected and math.abs(line.y+line.baseline-asc-expected.top)<.02,viewport..' '..sample.key..' line '..index..' original baseline')
            end
            V.assert(paragraph:Measure(vg,runs,sample.width)==layout and paragraph.measurements==1,'unchanged '..sample.key..' reuses measured paragraph')
            paragraph:Measure(vg,runs,sample.width-20)
            V.assert(paragraph.measurements==2,'PC width change invalidates '..sample.key..' once')
            reports[#reports+1]={viewport=viewport,key=sample.key,lines=lines,height=layout.height}
        end
    end
    local normal=Paragraph.New(13,20.796875)
    local layout=normal:Measure(vg,'   A  B\nC   ',200)
    V.assert(#layout.lines==1 and layout.lines[1].runs[1].text=='A B C','CSS normal whitespace collapses spaces and newlines')
    normal.size=15;normal.lineHeight=24
    local resized=normal:Measure(vg,'   A  B\nC   ',200)
    V.assert(resized~=layout and resized.height==24 and normal.measurements==2,'font size or line height changes invalidate cached measurement')
    V.assert(D.Wrap==nil,'old per-frame native TextBox path removed')
    local out=assert(io.open('docs/migration/evidence/pc-source-paragraphs.json','w'));out:write(cjson.encode(reports));out:close()
    UI.Shutdown();drawContext=nvgCreate(1);nvgSetRenderOrder(drawContext,999980);SubscribeToEvent(drawContext,'NanoVGRender',Render)
end)
V.atFrame(25,function() Capture();scale=2 end)
V.atFrame(30,function()
    Capture()
    local out=assert(io.open('docs/migration/evidence/pc-inline-font.json','w'))
    out:write(cjson.encode(require('ui.SourceFonts').ResolveInlineCode()));out:close()
    UnsubscribeFromEvent(drawContext,'NanoVGRender');nvgDelete(drawContext);drawContext=nil;V.finish()
end)

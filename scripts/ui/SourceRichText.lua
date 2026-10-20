-- Small measured text runs for source hover/toast styling; no HTML interpreter.
-- Layout is cached by the owning surface, never rebuilt for pointer movement.
local D=require 'ui.SourceDraw'
local M={}
local noStart,noEnd={},{}
for _,cp in utf8.codes('，。、；：！？）》】」』〕〉”’％…,:;.!?)]}') do noStart[cp]=true end
for _,cp in utf8.codes('（《【「『〔〈“‘([{') do noEnd[cp]=true end
function M.Layout(vg,paragraphs,maxWidth,lineHeight,strut)
    strut=strut or paragraphs[1] and paragraphs[1][1] or {}
    local combineBody=D.HasBodyAdvances(vg)
    local metrics={}
    local function Limits(style)
        local size=style.size or 12.5;local lh=style.lineHeight or lineHeight
        local key=(style.font or 'vox-display')..':'..size..':'..tostring(lh)
        local known=metrics[key];if known then return known[1],known[2] end
        local asc,desc=D.FontMetrics(vg,size,style.font)
        -- 手机上小字被 D.Readable 抬大后字身可能高过固定行高，行与行会叠在一起；只在放不下时把行高撑到字身高
        local height=lh=='normal' and asc+desc or math.floor(lh*64+.5)/64
        if lh~='normal' and D.Readable(vg,size)~=size then height=math.max(height,asc+desc) end
        local baseline=asc+math.floor((height-asc-desc)/2)
        metrics[key]={baseline,height-baseline};return baseline,height-baseline
    end
    local function NewLine()
        local asc,desc=Limits(strut);return {runs={},width=0,ascent=asc,descent=desc}
    end
    local lines={};local line=NewLine();local widest,height=0,0
    local function Flush()
        -- CSS normal whitespace discards spaces at a line edge, including a
        -- space already measured before the following word caused the break.
        while #line.runs>0 do
            local run=line.runs[#line.runs]
            if run.swatch or not run.text:match(' $') then break end
            local trimmed=run.text:gsub(' +$','')
            local width=D.Advance(vg,trimmed,run.size,run.font,run.spacing)
            line.width=line.width-run.width+width;run.text=trimmed;run.width=width
            if trimmed~='' then break end
            table.remove(line.runs)
        end
        line.y=height;line.baseline=line.ascent;line.height=line.ascent+line.descent
        line.width=math.ceil(line.width*64-1e-8)/64
        height=height+line.height;lines[#lines+1]=line;widest=math.max(widest,line.width);line=NewLine()
    end
    local function Add(text,style,swatch)
        if text==' ' and line.width==0 then return end
        local size=style.size or 12.5;local spacing=style.spacing or 0
        local width=swatch and 15 or D.Advance(vg,text,size,style.font,spacing)
        if line.width>0 and line.width+width>maxWidth then Flush();if text==' ' then return end end
        if width>maxWidth and utf8.len(text)>1 then
            for _,code in utf8.codes(text) do Add(utf8.char(code),style) end;return
        end
        local last=line.runs[#line.runs]
        -- Body has no active kern feature on this PC face. Adjacent tokens can
        -- share a draw without changing the already-decided wrapping positions.
        if combineBody and not swatch and last and not last.swatch and style.font=='vox-body' and last.font==style.font
            and last.size==size and last.spacing==spacing and last.color==style.color then
            last.text=last.text..text;last.width=last.width+width
        else
            line.runs[#line.runs+1]={text=text,size=size,font=style.font,color=style.color,spacing=spacing,swatch=swatch,x=line.width,width=width}
        end
        if not swatch then
            local asc,desc=Limits(style);line.ascent=math.max(line.ascent,asc);line.descent=math.max(line.descent,desc)
        end
        line.width=line.width+width
    end
    for pi,paragraph in ipairs(paragraphs) do
        if pi>1 then Flush() end
        for _,run in ipairs(paragraph) do
            if run.swatch then Add('',run,run.swatch) else
                -- Keep closing punctuation with its preceding character and
                -- opening punctuation with the following word (CSS CJK breaks).
                local word='';local western,opening=false,false
                local function Word() if word~='' then Add(word,run);word='' end;western=false;opening=false end
                for _,code in utf8.codes(run.text or '') do
                    if code==10 then Word();Flush()
                    elseif code==32 then Word();Add(' ',run)
                    elseif noStart[code] then word=word..utf8.char(code);western=western and code<128;opening=false
                    elseif noEnd[code] then if not opening then Word() end;word=word..utf8.char(code);opening=true
                    elseif code>255 then
                        if not opening then Word() end
                        word=word..utf8.char(code);western=false;opening=false
                    else
                        if not western and not opening then Word() end
                        word=word..utf8.char(code);western=true;opening=false
                    end
                end
                Word()
            end
        end
    end
    Flush();return {lines=lines,width=widest,height=height,lineHeight=lineHeight}
end
function M.Draw(vg,layout,x,y,center)
    for i,line in ipairs(layout.lines) do
        local lx=x+(center and (layout.width-line.width)/2 or 0);local cy=y+line.y
        for _,run in ipairs(line.runs) do
            local tx=lx+run.x
            if run.swatch then
                D.Rect(vg,tx,cy+(line.height-10)/2,10,10,run.swatch)
                nvgBeginPath(vg);nvgRect(vg,tx+.5,cy+(line.height-10)/2+.5,9,9);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(255,255,255,102));nvgStroke(vg)
            else D.Text(vg,run.text,tx,cy+line.baseline,run.size,run.color,run.font,nil,run.spacing,true) end
        end
    end
end
return M

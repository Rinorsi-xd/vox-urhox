-- Owner-local CSS paragraph layout. One current measurement per surface;
-- movement and redraw reuse it, while text/width/style/context changes rebuild.
local D=require 'ui.SourceDraw'
local Rich=require 'ui.SourceRichText'
local M={};M.__index=M
function M.New(size,lineHeight) return setmetatable({size=size,lineHeight=lineHeight,measurements=0},M) end
function M:Measure(vg,content,width,color)
    width=math.max(1,width);color=color or D.muted
    local colorKey=table.concat(color,',')
    if self.layout and self.content==content and self.width==width and self.colorKey==colorKey and self.context==vg
        and self.measuredSize==self.size and self.measuredLineHeight==self.lineHeight and self.measuredMaxLines==self.maxLines then return self.layout end
    local runs={}
    if type(content)=='string' then
        runs[1]={text=content:gsub('%s+',' '):gsub('^ ',''):gsub(' $',''),font='vox-body',size=self.size,color=color}
    else
        for i,source in ipairs(content) do
            runs[i]={text=source.text,font=source.font or 'vox-body',size=source.size or self.size,color=source.color or color}
        end
    end
    self.layout=Rich.Layout(vg,{runs},width,self.lineHeight,{font='vox-body',size=self.size})
    if self.maxLines and #self.layout.lines>self.maxLines then
        local line=self.layout.lines[self.maxLines]
        local ellipsis='\u{2026}'
        while #line.runs>0 do
            local run=line.runs[#line.runs]
            local text=run.text:gsub(' +$','')
            while text~='' and run.x+D.Advance(vg,text..ellipsis,run.size,run.font,run.spacing)>width do
                text=text:sub(1,utf8.offset(text,-1)-1):gsub(' +$','')
            end
            if text~='' or run.x+D.Advance(vg,ellipsis,run.size,run.font,run.spacing)<=width then
                run.text=text..ellipsis;run.width=D.Advance(vg,run.text,run.size,run.font,run.spacing)
                line.width=run.x+run.width;break
            end
            table.remove(line.runs)
        end
        for i=#self.layout.lines,self.maxLines+1,-1 do self.layout.lines[i]=nil end
        self.layout.height=line.y+line.height
        local widest=0;for _,visible in ipairs(self.layout.lines) do widest=math.max(widest,visible.width) end
        self.layout.width=widest
    end
    self.content=content;self.width=width;self.colorKey=colorKey;self.context=vg;self.measurements=self.measurements+1
    self.measuredSize=self.size;self.measuredLineHeight=self.lineHeight
    self.measuredMaxLines=self.maxLines
    return self.layout
end
function M:Draw(vg,content,x,y,width,color,center)
    local layout=self:Measure(vg,content,width,color)
    Rich.Draw(vg,layout,x+(center and (width-layout.width)/2 or 0),y,center);return layout
end
return M

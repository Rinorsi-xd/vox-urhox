-- Owner-local CSS paragraph layout. One current measurement per surface;
-- movement and redraw reuse it, while text/width/style/context changes rebuild.
local D=require 'ui.SourceDraw'
local Rich=require 'ui.SourceRichText'
local M={};M.__index=M
function M.New(size,lineHeight) return setmetatable({size=size,lineHeight=lineHeight,measurements=0},M) end
function M:Measure(vg,content,width,color)
    width=math.max(1,width);color=color or D.muted
    if self.layout and self.content==content and self.width==width and self.color==color and self.context==vg
        and self.measuredSize==self.size and self.measuredLineHeight==self.lineHeight then return self.layout end
    local runs={}
    if type(content)=='string' then
        runs[1]={text=content:gsub('%s+',' '):gsub('^ ',''):gsub(' $',''),font='vox-body',size=self.size,color=color}
    else
        for i,source in ipairs(content) do
            runs[i]={text=source.text,font=source.font or 'vox-body',size=source.size or self.size,color=source.color or color}
        end
    end
    self.layout=Rich.Layout(vg,{runs},width,self.lineHeight,{font='vox-body',size=self.size})
    self.content=content;self.width=width;self.color=color;self.context=vg;self.measurements=self.measurements+1
    self.measuredSize=self.size;self.measuredLineHeight=self.lineHeight
    return self.layout
end
function M:Draw(vg,content,x,y,width,color,center)
    local layout=self:Measure(vg,content,width,color)
    Rich.Draw(vg,layout,x+(center and (width-layout.width)/2 or 0),y,center);return layout
end
return M

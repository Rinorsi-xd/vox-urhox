-- The source .hint paragraph uses CSS pixel sizes, independent of UI theme.
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Paragraph=require 'ui.SourceParagraph'
local Hint=Panel:Extend('VoxSourceHint')
function Hint:SetText(text) self.props.text=text;self.props.segments=nil;return self end
function Hint:GetText() return self.props.text or '' end
function Hint:Render(vg)
    D.Begin(vg);local layout=self:GetAbsoluteLayout();local k=self.props.sourceScale or 1
    nvgSave(vg);nvgScale(vg,k,k)
    local r={x=layout.x/k,y=layout.y/k,w=layout.w/k,h=layout.h/k};local text=self:GetText()
    local color=self.props.fontColor or {174,196,218,255}
    local segments=self.props.segments
    if self.measuredText~=text or self.measuredSegments~=segments or self.measuredWidth~=r.w or self.measuredContext~=vg then
        self.parts={};local x,height=0,0
        -- Original .hint is inline-flex: anonymous text and <code> are separate
        -- items with 7px gaps; whitespace at each item's edges is collapsed.
        for i,segment in ipairs(segments or {{text=text}}) do
            local value=segment.text:gsub('%s+',' '):gsub('^ ',''):gsub(' $','')
            local font=segment.font or 'vox-body'
            local content={{text=value,font=font}}
            local paragraph=Paragraph.New(12.5,21.25)
            local width=math.min(math.max(1,r.w-36),D.Width(vg,value,12.5,font))
            local layout=paragraph:Measure(vg,content,width,color)
            if i>1 then x=x+7 end
            self.parts[i]={x=x,paragraph=paragraph,content=content,width=width}
            x=x+width;height=math.max(height,layout.height)
        end
        self.contentWidth=x;self.contentHeight=height
        self.measuredText=text;self.measuredSegments=segments;self.measuredWidth=r.w;self.measuredContext=vg
    end
    local height=self.contentHeight+8
    if self.props.height~=height*k then self:SetHeight(height*k) end
    local width=math.min(r.w,self.contentWidth+36);self.drawnWidth=width
    nvgBeginPath(vg);nvgRect(vg,r.x,r.y,width,height)
    D.Gradient(vg,r.x,r.y,width*.6,height,{9,10,12,0},{9,10,12,209},true)
    for _,part in ipairs(self.parts) do
        part.paragraph:Draw(vg,part.content,r.x+34+part.x,r.y+4+(self.contentHeight-part.paragraph.layout.height)/2,part.width,color)
    end
    nvgRestore(vg)
end
return Hint

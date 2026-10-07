-- Original #colorPop: source CSS sizes for label and eight-column grid.
local Popover=require 'ui.SourcePopover'
local Paragraph=require 'ui.SourceParagraph'
local D=require 'ui.SourceDraw'
local Palette=Popover:Extend('VoxBuildPalette')
local label='选择颜色进入涂装；不会改变新放零件的配色'
function Palette:DrawBackground(vg)
    Popover.DrawBackground(self,vg)
    local r=self:GetAbsoluteLayout()
    self.paragraph=self.paragraph or Paragraph.New(12,'normal')
    self.paragraph:Draw(vg,label,r.x+12,r.y+12,r.w-24)
end
local M={swatchSize=29.625,stride=34.625,gridTop=37}
function M.Create()
    return Palette{position='absolute',left=0,bottom=108,width=296,height=113.25,padding=12,
        sourceEntryDuration=.18,sourceLayerOrder=999978,visible=false}
end
return M

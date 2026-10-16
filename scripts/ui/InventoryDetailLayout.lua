local D=require 'ui.SourceDraw'
local Rich=require 'ui.SourceRichText'
local M={}
local function Text(vg,text,width,size,lineHeight,color)
    return Rich.Layout(vg,{{{text=text,font='vox-body',size=size,color=color}}},width,lineHeight,{font='vox-body',size=size})
end
function M.Description(vg,text,width)
    return Text(vg,text:gsub('%s+',' '):gsub('^ ',''):gsub(' $',''),width,12,20.390625,{170,192,213,255})
end
function M.Row(vg,row,width)
    -- Source grid: 15px icon, two 8px gaps, then 1fr : 1.6fr.
    local labelWidth=math.max(54,math.floor((width-31)/2.6*64)/64)
    local valueWidth=math.max(0,width-31-labelWidth)
    local label=Text(vg,row[2],labelWidth,11,'normal',{156,184,210,255})
    local value=Text(vg,row[3],valueWidth,12,18.6,D.white)
    return {label=label,value=value,labelWidth=labelWidth,valueWidth=valueWidth,height=math.max(15,label.height,value.height)+19}
end
function M.Draw(vg,layout,x,y,width,right)
    for _,line in ipairs(layout.lines) do
        local left=x+(right and width-line.width or 0)
        for _,run in ipairs(line.runs) do
            D.Text(vg,run.text,left+run.x,y+line.y+line.baseline,run.size,run.color,run.font,nil,run.spacing,true)
        end
    end
end
return M

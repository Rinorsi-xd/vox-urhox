-- Frozen story.css flex flow, including intrinsic overflow when a best record exists.
local D=require 'ui.SourceDraw'
local M={}
-- 手机上小字会被 D.Readable 抬大：写死的标题行、标签框和行距按字号实际增量撑开，PC 不变
local function Grow(vg,size,base) return base+math.max(0,D.Readable(vg,size)-size) end
-- compact: 手机紧凑页把地点/时长/战车等事实排成一行多列、收紧段间距，省出竖向空间
function M.Measure(vg,level,progress,width,height,story,goals,enemy,measureEnemy,compact)
    local gap=compact and .6 or 1
    local out={story=158,goals={},goalMarks={},enemies={},facts={},width=width}
    local y=out.story+story:Measure(vg,level.story,width).height+16*gap
    out.objectives=y;y=y+Grow(vg,17,29)
    for i,text in ipairs(level.goals) do
        local layout=goals:Measure(vg,text,width-19)
        out.goals[i]=y;out.goalMarks[i]=layout.lines[1] and layout.lines[1].height/2 or 11
        y=y+layout.height+(i<#level.goals and (compact and 5 or 7) or 0)
    end
    y=y+14*gap;out.hostiles=y;y=y+Grow(vg,17,29)
    out.chipSub=7+Grow(vg,15,20);out.chipHeight=math.max(49,out.chipSub+Grow(vg,12,22))
    local x,rowHeight=0,0
    for i,item in ipairs(level.enemies) do
        local ew=math.min(width,measureEnemy(item))
        if x>0 and x+ew>width then x=0;y=y+rowHeight+6;rowHeight=0 end
        out.enemies[i]={x=x,y=y,w=ew,h=out.chipHeight};x=x+ew+6;rowHeight=out.chipHeight
    end
    y=y+rowHeight+16*gap;out.intercept=y
    out.quoteTop=Grow(vg,11,30)
    out.interceptHeight=out.quoteTop+10+enemy:Measure(vg,'「'..level.huhu..'」',width-28).height
    y=y+out.interceptHeight+14*gap
    out.facts={{'地点',level.place or '坠舰陨坑'},{'预计时长',level.minutes..' 分钟'},{'出战战车','任意'}}
    if progress then
        local seconds=math.max(0,progress.time or 0)
        out.facts[#out.facts+1]={'最佳记录',(progress.grade or '')..' · '..math.floor(seconds/60)..':'..string.format('%02d',math.floor(seconds%60))}
    end
    out.factsTop=y;out.columns=compact
    if compact then
        out.factValue=8+Grow(vg,14,20)+2;out.factRow=out.factValue+Grow(vg,17,22)+8
        out.go=math.max(height-26-74,y+out.factRow+16*gap)
    else
        out.factRow=Grow(vg,17,34);out.go=math.max(height-26-74,y+#out.facts*out.factRow+16)
    end
    out.overflow=math.max(0,out.go-(height-26-74))
    return out
end
return M

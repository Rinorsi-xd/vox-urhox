-- Frozen story.css flex flow, including intrinsic overflow when a best record exists.
local M={}
function M.Measure(vg,level,progress,width,height,story,goals,enemy,measureEnemy)
    local out={story=158,goals={},enemies={},facts={},width=width}
    local y=out.story+story:Measure(vg,level.story,width).height+16
    out.objectives=y;y=y+29
    for i,text in ipairs(level.goals) do
        out.goals[i]=y;y=y+goals:Measure(vg,text,width-19).height+(i<#level.goals and 7 or 0)
    end
    y=y+14;out.hostiles=y;y=y+29
    local x,rowHeight=0,0
    for i,item in ipairs(level.enemies) do
        local ew=measureEnemy(item)
        if x>0 and x+ew>width then x=0;y=y+rowHeight+6;rowHeight=0 end
        out.enemies[i]={x=x,y=y,w=ew,h=49};x=x+ew+6;rowHeight=49
    end
    y=y+rowHeight+16;out.intercept=y
    out.interceptHeight=40+enemy:Measure(vg,'「'..level.huhu..'」',width-28).height
    y=y+out.interceptHeight+14
    out.facts={{'地点',level.place or '坠舰陨坑'},{'预计时长',level.minutes..' 分钟'},{'出战战车','任意'}}
    if progress then
        local seconds=math.max(0,progress.time or 0)
        out.facts[#out.facts+1]={'最佳记录',(progress.grade or '')..' · '..math.floor(seconds/60)..':'..string.format('%02d',math.floor(seconds%60))}
    end
    out.factsTop=y;out.go=math.max(height-26-74,y+#out.facts*34+16)
    return out
end
return M

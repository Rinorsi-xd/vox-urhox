-- Source physical CSS-pixel sizes remain independent of the scaled HUD.
local M={}
function M.Calculate(width,height,cssWidth,cssHeight,safe,mode,actions)
    local k=width/math.max(1,cssWidth);safe=safe or {};local compact=cssWidth<=600 or cssHeight<=360
    local tiny=cssWidth<=360 and cssHeight<=360
    local stick=cssWidth<=300 and 76 or compact and 88 or 112
    local edge=cssWidth<=300 and 8 or compact and 10 or 18
    local col=tiny and 44 or compact and 48 or 56;local gap=tiny and 4 or compact and 6 or 8
    local columns=tiny and 1 or 2;local rows={};local filtered={}
    for _,id in ipairs(actions) do
        if not tiny or id~='scope' and id~='interact' and id~='slot-prev' and id~='slot-next' then filtered[#filtered+1]=id end
    end
    -- The final source .tc-actions button rule overrides .tc-primary's height.
    local buttonHeight=tiny and 44 or 48;local rowCount=math.ceil(#filtered/columns)
    local baseY=height-(safe.bottom or 0)-(edge+rowCount*buttonHeight+(rowCount-1)*gap)*k
    local baseX=width-(safe.right or 0)-(edge+columns*col+(columns-1)*gap)*k
    for i,id in ipairs(filtered) do rows[id]={left=baseX+(i-1)%columns*(col+gap)*k,top=baseY+math.floor((i-1)/columns)*(buttonHeight+gap)*k,width=col*k,height=buttonHeight*k} end
    local panelWidth=math.min(420*k,width-(safe.left or 0)-(safe.right or 0)-16*k)
    return {k=k,cssWidth=cssWidth,cssHeight=cssHeight,actions=rows,
        stick={left=(safe.left or 0)+edge*k,bottom=(safe.bottom or 0)+edge*k,width=stick*k,height=stick*k},
        toggle={left=mode=='edit' and width/2-24*k or (safe.left or 0)+8*k,top=(safe.top or 0)+8*k,width=48*k,height=44*k},
        panel={left=((safe.left or 0)+width-(safe.right or 0)-panelWidth)/2,top=(safe.top or 0)+62*k,width=panelWidth,height=math.max(1,height-(safe.top or 0)-(safe.bottom or 0)-70*k)},
        padding=(cssWidth<=300 and 8 or 12)*k,columns=cssWidth<=300 and 2 or 3}
end
return M

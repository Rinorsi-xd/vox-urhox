-- mobile-editor.css uses physical CSS pixels outside the 1920x1080 HUD.
local M={}
function M.Calculate(width,height,cssWidth,cssHeight,safe,size,aim,chipWidth)
    local k=width/math.max(1,cssWidth);safe=safe or {}
    local sx,sy=(safe.left or 0)/k,(safe.top or 0)/k
    local w,h=cssWidth-sx-(safe.right or 0)/k,cssHeight-sy-(safe.bottom or 0)/k
    local u=math.max(.78,math.min(1.35,math.min(w,h)/390))*(size or 1)
    local s=k*u;local narrow=cssWidth<=760
    local out={k=k,u=u,s=s,cssWidth=cssWidth,cssHeight=cssHeight,width=width,height=height,narrow=narrow,buttons={},slots={},sheets={},slotCount=narrow and 8 or 10}
    local function Rect(x,y,rw,rh) return {left=sx*k+x*s,top=sy*k+y*s,width=rw*s,height=rh*s} end
    local function Add(id,x,y,rw,rh) out.buttons[id]=Rect(x,y,rw,rh) end
    local right=w/u-10;local top=8
    Add('me-more',right-48,top,48,48);right=right-48-6
    local row=narrow and 42 or 81
    Add('me-save',right-row,top+4,row,40);right=right-row-6
    Add('me-test',right-row,top+4,row,40);right=right-row-6
    Add('me-redo',right-44,top+4,44,40);Add('me-undo',right-88,top+4,44,40)
    local x=10;local back=narrow and 42 or 81
    Add('me-back',x,top+4,back,40);x=x+back+6
    local available=right-88-6-x-6-(narrow and 0 or 40)-138
    local chip=math.max(110,math.min(chipWidth or (narrow and 188 or 230),available))
    Add('me-stats',x,top+4,chip,40);x=x+chip+6
    if not narrow then out.liftLabel=Rect(x,top+4,40,40);x=x+40 end
    Add('me-liftUp',x,top+4,69,40);Add('me-liftDown',x+69,top+4,69,40)
    local railX=w/u-10-48;local railY=58;local count=aim and 7 or 5
    local availableHeight=h/u-68-58;local buttonHeight=math.min(48,(availableHeight-count*4)/count)
    local spacer=math.max(0,availableHeight-count*(buttonHeight+4))
    for _,id in ipairs({'me-rotate','me-mirror','me-pick'}) do Add(id,railX,railY,48,buttonHeight);railY=railY+buttonHeight+4 end
    railY=railY+spacer+4
    if aim then Add('primary',railX,railY,48,buttonHeight);railY=railY+buttonHeight+4;Add('erase',railX,railY,48,buttonHeight);railY=railY+buttonHeight+4 end
    Add('up',railX,railY,48,buttonHeight);railY=railY+buttonHeight+4;Add('down',railX,railY,48,buttonHeight)
    local dw=narrow and 504 or 588;local dockWidth=(narrow and 505 or 587)+2/u;local dx=(w/u-dockWidth)/2;local dy=h/u-8-52
    out.dock=Rect(dx,dy,dockWidth,52);x=dx+6
    Add('me-tools',x,dy+4,50,44);x=x+54
    out.separators={Rect(x+1,dy+9,1/u,34)};x=x+6+1/u
    for i=1,out.slotCount do out.slots[i]=Rect(x,dy+7,38,38);x=x+41 end
    x=x-3+4;Add('me-bag',x,dy+4,44,44);x=x+48
    out.separators[#out.separators+1]=Rect(x+1,dy+9,1/u,34);x=x+6+1/u
    Add('me-paint',x,dy+4,50,44)
    out.hint=Rect(dx,h/u-66,dw,15)
    out.sheets.tools=Rect((w/u-dw)/2,h/u-68-232,320,232)
    out.sheets.paint=Rect((w/u+dw)/2-340,h/u-68-234,340,234)
    out.sheets.more=Rect(w/u-10-304,54,304,284)
    out.zone={sx,sy+h*.18,sx+w*.34,sy+h*.84}
    out.stick=Rect(92-54,h/u-120-54,108,108)
    out.home={sx+92*u,sy+h-120*u}
    return out
end
return M

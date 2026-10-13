-- Frozen matchLobby._bg: hex grid, radar, scan line and rising sparks.
local M={}
function M.Draw(vg,w,h,t,cx,cy)
    local k=w/1920;local radius=34*k;local step=radius*math.sqrt(3)
    local ox=(t*12*k)%step;local oy=(t*6*k)%(radius*3)
    nvgStrokeWidth(vg,1)
    for row=-1,math.ceil((h+radius*3)/(radius*1.5)) do
        for col=-1,math.ceil((w+step*2)/step) do
            local x=col*step+(row%2==1 and step/2 or 0)-ox;local y=row*radius*1.5-oy
            local d=math.sqrt((x-w/2)^2+(y-h*.45)^2)/w
            nvgBeginPath(vg)
            for i=0,5 do local a=i/6*math.pi*2+math.pi/6
                local px,py=x+math.cos(a)*radius*.94,y+math.sin(a)*radius*.94
                if i==0 then nvgMoveTo(vg,px,py) else nvgLineTo(vg,px,py) end
            end
            nvgClosePath(vg);nvgStrokeColor(vg,nvgRGBA(255,255,255,math.max(0,.06-d*.05)*255));nvgStroke(vg)
            local pulse=(t*.72+((row*1000+col)*.61803398875)%37)%37
            if pulse<1 then nvgFillColor(vg,nvgRGBA(168,215,242,(1-pulse)*.12*255));nvgFill(vg) end
        end
    end
    nvgStrokeWidth(vg,2*k)
    for i=0,2 do local p=(t*.35+i/3)%1
        nvgBeginPath(vg);nvgCircle(vg,cx,cy,(.18+p*.55)*math.min(w,h))
        nvgStrokeColor(vg,nvgRGBA(168,215,242,.22*(1-p)*255));nvgStroke(vg)
    end
    local sy=(t*.18%1)*h
    nvgBeginPath(vg);nvgRect(vg,0,sy-60*k,w,60*k)
    nvgFillPaint(vg,nvgLinearGradient(vg,0,sy-60*k,0,sy,nvgRGBA(46,168,255,0),nvgRGBA(46,168,255,26)));nvgFill(vg)
    nvgBeginPath(vg);nvgRect(vg,0,sy,w,1.2*k);nvgFillColor(vg,nvgRGBA(46,168,255,89));nvgFill(vg)
    for i=1,70 do
        local age=(t+i*.113)%4.17;local life=1-age/4.17
        local x=(i*.61803398875%1)*w+((i*.41421356%1)-.5)*30*k*age
        local y=h+10-(40+(i*.7320508%1)*90)*k*age
        nvgBeginPath(vg);nvgRect(vg,x,y,2.2*k,2.2*k);nvgFillColor(vg,nvgRGBA(168,215,242,life*.8*255));nvgFill(vg)
    end
end
return M

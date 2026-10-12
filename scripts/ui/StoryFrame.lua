-- Geometry port of frozen shared/ui/hudFrame.js; cuts stay fixed on resize.
local D=require 'ui.SourceDraw'
local M={ice={214,240,255,153},secondary={214,240,255,77},cyan={110,214,255,217},white={238,250,255,255}}
local K=2-math.sqrt(2)
local function Ring(w,h,c,o)
    o=o or 0;local x0,y0,x1,y1=-o,-o,w+o,h+o;local points={}
    local function Add(x,y) points[#points+1]=math.floor(x+.5)+.5;points[#points+1]=math.floor(y+.5)+.5 end
    local a,b,e,f=table.unpack(c)
    a=a>0 and a+o*K or 0;b=b>0 and b+o*K or 0;e=e>0 and e+o*K or 0;f=f>0 and f+o*K or 0
    if b>0 then Add(x1-b,y0);Add(x1,y0+b) else Add(x1,y0) end
    if e>0 then Add(x1,y1-e);Add(x1-e,y1) else Add(x1,y1) end
    if f>0 then Add(x0+f,y1);Add(x0,y1-f) else Add(x0,y1) end
    if a>0 then Add(x0,y0+a);Add(x0+a,y0) else Add(x0,y0) end
    return points
end
local function Path(vg,p,color,width,close)
    nvgBeginPath(vg);nvgMoveTo(vg,p[1],p[2]);for i=3,#p,2 do nvgLineTo(vg,p[i],p[i+1]) end
    if close then nvgClosePath(vg) end
    nvgStrokeWidth(vg,width or 1);nvgStrokeColor(vg,D.Color(color));nvgStroke(vg)
end
local function Corner(w,h,key,cut,o,l1,l2)
    local c=cut>0 and cut+o*K or 0;local a,b,z,t=-o,-o,w+o,h+o
    if key=='tl' then return {a,b+c+l1,a,b+c,a+c,b,a+c+l2,b}
    elseif key=='tr' then return {z-c-l1,b,z-c,b,z,b+c,z,b+c+l2}
    elseif key=='br' then return {z,t-c-l1,z,t-c,z-c,t,z-c-l2,t}
    else return {a+c+l1,t,a+c,t,a,t-c,a,t-c-l2} end
end
local function Hatch(vg,x,y,n,gap,len)
    for i=0,n-1 do D.Line(vg,x+i*gap,y+len,x+i*gap+len,y,{110,214,255,153},1.5) end
end
local function Node(vg,x,y,size) local s=size or 4;D.Rect(vg,x-s/2,y-s/2,s,s,{214,240,255,191}) end
function M.Fill(vg,x,y,w,h,cut,reverse,alpha)
    nvgSave(vg);nvgTranslate(vg,x,y)
    D.Path(vg,Ring(w,h,reverse and {0,cut,0,cut} or {cut,0,cut,0}))
    D.Gradient(vg,0,0,w,h,{3,10,18,alpha or 194},{3,10,18,118},true);nvgRestore(vg)
end
function M.Draw(vg,x,y,w,h,kind,tag,foot)
    local u=10.8;nvgSave(vg);nvgTranslate(vg,x,y)
    local cut=kind=='terminal' and 2.2*u or kind=='face' and 1.2*u or kind=='dialog' and 1.4*u or kind=='lv' and 1.3*u or .9*u
    local c=kind=='face' and {0,cut,0,cut} or (kind=='lv' or kind=='btn') and {0,0,cut,0} or {cut,0,cut,0}
    Path(vg,Ring(w,h,c),M.ice,1,true)
    if kind=='terminal' then
        Path(vg,Corner(w,h,'tl',cut,-5,.32*h,.4*w),M.secondary)
        Path(vg,Corner(w,h,'br',cut,-5,.26*h,.28*w),M.secondary)
        Path(vg,{w+1,.08*h,w+7,.08*h+6,w+7,.34*h,w+1,.34*h+6},M.secondary)
        for yy=h*.11,h*.31,1.1*u do D.Line(vg,w+7,yy,w+10,yy,M.secondary) end
        for yy=h*.5,h*.86,5 do D.Line(vg,-7,yy,-7,yy+1,{214,240,255,128},1.6) end
        Node(vg,w+7,.34*h+12);Node(vg,-7,.86*h+6)
        Path(vg,Corner(w,h,'tl',cut,4,5*u,10*u),M.white,3)
        Path(vg,Corner(w,h,'br',cut,4,3*u,7*u),M.cyan,2)
        Path(vg,{w-18*u,-3,w-17*u,-1.1*u-3,w-5*u,-1.1*u-3,w-4*u,-3},M.secondary)
        D.Text(vg,tag or 'MSN·01',w-11*u,-1.6*u,11.34,{214,240,255,107},'vox-tabular',NVG_ALIGN_CENTER)
        Hatch(vg,3*u,h+4,6,6,5)
        D.Text(vg,foot or 'MISSION BRIEF · ENC',3*u+44,h+8,11.34,{214,240,255,107},'vox-tabular')
    elseif kind=='lv' or kind=='btn' then
        D.Line(vg,-4,1,-4,h-2,M.white,3)
        if kind=='lv' then
            Path(vg,Corner(w,h,'tr',0,4,2.4*u,.4*h),M.cyan,2)
            D.Line(vg,w+1,h*.5,w+2.2*u,h*.5,M.secondary);Node(vg,w+2.2*u+3,h*.5)
            Path(vg,Corner(w,h,'br',cut,-5,.3*h,.22*w),M.secondary);Hatch(vg,w-9*u,h+3,4,5,4)
        else for xx=w*.3,w-1.2*u,5 do Node(vg,xx,h+5,1.6) end;Node(vg,w+4,-4) end
    elseif kind=='face' then
        Path(vg,Corner(w,h,'tr',cut,4,.4*w,.3*h),M.white,3)
        Path(vg,Corner(w,h,'bl',cut,4,.3*w,.2*h),M.cyan,2)
        for yy=.2*h,.8*h,1.1*u do D.Line(vg,-6,yy,-9,yy,M.secondary) end;Node(vg,-4,-4,5)
    elseif kind=='dialog' then
        Path(vg,{.46*w,h+1,.46*w+5,h+6,w-14*u,h+6},M.secondary);Node(vg,w-14*u+5,h+6)
        for xx=.5*w,.62*w,1.2*u do D.Line(vg,xx,h+6,xx,h+9,M.secondary) end
        Path(vg,{w-30*u,5,w-5,5,w-5,.5*h},M.secondary)
        Path(vg,Corner(w,h,'tl',cut,4,.42*h,3*u),M.white,3)
        Path(vg,Corner(w,h,'br',cut,4,1.6*u,9*u),M.cyan,2);Hatch(vg,w-21*u,-10,7,6,5)
        D.Text(vg,foot or 'CH-07 · 64 KBPS · ENC',2*u,h+10,11.34,{214,240,255,107},'vox-tabular')
    end
    nvgRestore(vg)
end
return M

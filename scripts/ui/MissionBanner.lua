-- Frozen storyHud.css sh-banner: three rows, title slam and centre strip wipe.
local D=require 'ui.SourceDraw'
local Ease=require('ui.SourceButtonMotion').Ease
local M={}
local colors={install={255,106,19,255},enemy={255,59,70,255},ok={61,220,132,255}}
function M.State(banner,time)
    local age=math.max(0,time-(banner.at or 0));local tail=time-banner.untilAt
    return {age=age,alpha=tail>0 and 1-Ease(math.min(1,tail/.25),'ease') or Ease(math.min(1,age/.25),'ease'),
        slam=Ease(math.min(1,age/.5)),wipe=Ease(math.max(0,math.min(1,(age-.08)/.6))),
        size=banner.kind=='install' and 54 or banner.kind=='enemy' and 60 or 74,color=colors[banner.kind] or {70,200,255,255}}
end
function M.Draw(vg,banner,time,no,w,h)
    if not banner or time>=banner.untilAt+.25 then return end
    local state=M.State(banner,time);local color=state.color;local size=state.size
    local width=math.max(540,D.Width(vg,banner.sub or '',14,'vox-display',3)+126)
    local fit=math.min(1,(w-40)/math.max(width,D.Width(vg,banner.title,size,'vox-display',4)*1.18))
    nvgSave(vg);nvgTranslate(vg,w/2,h*.12);nvgScale(vg,fit,fit);nvgGlobalAlpha(vg,state.alpha)
    local titleY=26;local titleHeight=size*.95;local stripY=titleY+titleHeight+14
    nvgSave(vg);nvgTranslate(vg,0,(stripY+34)/2);nvgScale(vg,(width+240)/2,(stripY+114)/2)
    nvgBeginPath(vg);nvgCircle(vg,0,0,1)
    nvgFillPaint(vg,nvgRadialGradient(vg,0,0,0,1,nvgRGBA(6,8,11,158),nvgRGBA(6,8,11,0)));nvgFill(vg);nvgRestore(vg)
    D.Text(vg,banner.kick or '',0,0,17,color,'vox-display',NVG_ALIGN_CENTER,3,false,nil,{{y=1,blur=4,color={0,0,0,255}}})
    nvgSave(vg);nvgTranslate(vg,0,titleY+titleHeight/2);local slam=1+.18*(1-state.slam);nvgScale(vg,slam,slam);nvgGlobalAlpha(vg,state.alpha*state.slam)
    nvgFontBlur(vg,6*(1-state.slam))
    D.Text(vg,banner.title,0,-titleHeight/2,size,{255,255,255,255},'vox-display',NVG_ALIGN_CENTER,4,false,titleHeight,
        {{y=4,color={0,0,0,89}},{blur=34,color={color[1],color[2],color[3],102}}})
    nvgRestore(vg)
    nvgSave(vg);nvgIntersectScissor(vg,-width*state.wipe/2,stripY,width*state.wipe,34)
    local x=-width/2;local edge={color[1],color[2],color[3],51};local dark={10,11,13,191}
    D.Rect(vg,x,stripY,width,34,dark)
    D.Path(vg,{x,stripY,x+width*.3,stripY,x+width*.3,stripY+34,x,stripY+34});D.Gradient(vg,x,stripY,width*.3,34,edge,dark,true)
    local rx=x+width*.7;D.Path(vg,{rx,stripY,x+width,stripY,x+width,stripY+34,rx,stripY+34});D.Gradient(vg,rx,stripY,width*.3,34,dark,{color[1],color[2],color[3],31},true)
    nvgBeginPath(vg);nvgRect(vg,x+.5,stripY+.5,width-1,33);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(color[1],color[2],color[3],204));nvgStroke(vg)
    D.Text(vg,'+',x+14,stripY+8,15,color,'vox-display');D.Text(vg,'//:',x+33,stripY+8,15,color,'vox-display')
    D.Text(vg,banner.sub or '',x+62,stripY+8,14,{232,236,239,255},'vox-display',nil,3)
    local numberWidth=D.Width(vg,no,18,'vox-display')+20
    D.Rect(vg,x+width-numberWidth-5,stripY+5,numberWidth,24,color)
    D.Text(vg,no,x+width-numberWidth/2-5,stripY+8,18,{11,12,14,255},'vox-display',NVG_ALIGN_CENTER)
    nvgRestore(vg);nvgRestore(vg)
end
return M

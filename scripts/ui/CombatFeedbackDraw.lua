local D=require 'ui.SourceDraw'
local R=require 'ui.ReticleDraw'
local M={}
local STREAK={'击毁','双连破','三连破','四连破','无人能挡'}
local COLORS={{255,59,48,255},{255,59,48,255},{232,237,240,255},{154,164,172,255},{255,106,90,255}}
local function Edge(vg,l,color,alpha,inner)
    if alpha<=0 then return end
    nvgSave(vg);nvgTranslate(vg,l.cx,l.cy);nvgScale(vg,l.width/l.height,1);nvgGlobalAlpha(vg,alpha)
    local radius=l.height*.71
    nvgBeginPath(vg);nvgRect(vg,-l.height/2,-l.height/2,l.height,l.height)
    nvgFillPaint(vg,nvgRadialGradient(vg,0,0,radius*inner,radius,nvgRGBA(0,0,0,0),D.Color(color)));nvgFill(vg);nvgRestore(vg)
end
function M.Render(vg,state,l)
    local k=l.k
    Edge(vg,l,{120,6,0,179},state.low,.5)
    local rep=state.repairAge/(state.repairFull and 1.2 or .9)
    if rep<1 then Edge(vg,l,{63,230,255,87},rep<.18 and rep/.18 or (1-rep)/.82,.58) end
    Edge(vg,l,{255,40,20,71},math.min(1,state.flash*5),.66)
    for _,h in ipairs(state.hits) do
        local alpha=(1-h.t)^2*(.45+.55*h.s);local span=(.2+h.s*.12)*180/math.pi;local a=h.a*180/math.pi-90
        nvgSave(vg);nvgGlobalAlpha(vg,alpha)
        R.Arc(vg,l.cx,l.cy,118*k,a-span,a+span,R.red,(7+h.s*9)*k,3*k)
        R.Arc(vg,l.cx,l.cy,(123+h.s*4)*k,a-span*.8,a+span*.8,{255,106,90,255},1.6*k);nvgRestore(vg)
    end
    local s=state.score;if not s or s.age>=2 then return end
    nvgSave(vg);nvgGlobalAlpha(vg,s.age<.12 and s.age/.12 or s.age>1.64 and (2-s.age)/.36 or 1)
    local top=l.cy+70*k;local scale=s.age<.192 and 2.2+( .92-2.2)*s.age/.192 or s.age<.32 and .92+.08*(s.age-.192)/.128 or 1
    if s.bump>0 then scale=scale*1.12 end
    local lift=s.age>1.64 and -12*k*(s.age-1.64)/.36 or 0
    nvgSave(vg);nvgTranslate(vg,l.cx,top+s.size*.5+lift);nvgScale(vg,scale,scale)
    D.Text(vg,'+'..math.floor(s.shown+.5),0,-s.size*.5,s.size,{255,210,74,255},'vox-display',NVG_ALIGN_CENTER);nvgRestore(vg)
    local label=STREAK[s.n];local labelSize=(s.n>1 and 24 or 16)*k;local nameSize=16*k
    local labelWidth=D.Width(vg,label,labelSize,'vox-title',labelSize*.25)
    local nameWidth=D.Width(vg,s.name,nameSize,'vox-title',nameSize*.12)
    local x=l.cx-(labelWidth+labelSize*.5+nameWidth)/2;local y=top+s.size+nameSize*.3+lift
    local labelAscent=D.FontMetrics(vg,labelSize,'vox-title');local nameAscent=D.FontMetrics(vg,nameSize,'vox-title')
    D.Text(vg,label,x,y,labelSize,R.red,'vox-title',NVG_ALIGN_LEFT,labelSize*.25)
    D.Text(vg,s.name,x+labelWidth+labelSize*.5,y+labelAscent-nameAscent,nameSize,R.white,'vox-title',NVG_ALIGN_LEFT,nameSize*.12)
    nvgRestore(vg)
    for _,c in ipairs(state.cubes) do
        local scale=c.t<c.fly and 1 or math.max(.35,1-(c.t-c.fly)*1.4);local size=c.size*scale
        nvgSave(vg);nvgTranslate(vg,c.x,c.y);nvgRotate(vg,c.rot)
        D.Rect(vg,-size/2,-size/2,size,size,c.core and c.color==5 and {255,207,58,255} or COLORS[c.color])
        D.Rect(vg,-size/2,-size/2,size,1,{0,0,0,64});nvgRestore(vg)
    end
end
return M

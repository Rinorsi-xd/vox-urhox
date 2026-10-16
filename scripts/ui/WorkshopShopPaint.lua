local D=require 'ui.SourceDraw'
local M={ink={11,41,70,255},muted={173,196,216,255},dim={125,153,179,255}}
function M.Credit(vg,x,y,size,color)
    nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,size/20,size/20)
    D.Path(vg,{10,1.8,17.2,6,17.2,14,10,18.2,2.8,14,2.8,6})
    nvgStrokeColor(vg,D.Color(color or D.orange));nvgStrokeWidth(vg,1.6);nvgStroke(vg)
    nvgBeginPath(vg);nvgArc(vg,9.991681,10,3.4,-.783673,.783673,NVG_CCW);nvgStroke(vg);nvgRestore(vg)
end
function M.Cost(vg,cost,x,y,size,color)
    local text=cost>0 and D.Number(cost) or '免费'
    if cost>0 then M.Credit(vg,x,y+(size-16)/2,16,color);x=x+20 end
    D.Text(vg,text,x,y,size,color,'vox-tabular')
end
function M.CostWidth(vg,cost,size)
    return D.Width(vg,cost>0 and D.Number(cost) or '免费',size,'vox-tabular')+(cost>0 and 20 or 0)
end
function M.Card(vg,shop,x,y,w,mini,hero)
    if not shop then return end
    local size=mini and 13 or 15;local pad=mini and 8 or 10
    local tw=M.CostWidth(vg,shop.cost,size);local width=tw+2*pad;local height=size*1.2+(mini and 6 or 8)
    local px=x+w-12-width;local py=y+(mini and 10 or hero and 52 or 14)
    D.Rect(vg,px,py,width,height,{8,10,14,199})
    local edge=shop.poor and {255,255,255,36} or {255,106,19,140}
    D.Line(vg,px+.5,py+.5,px+width-.5,py+.5,edge);D.Line(vg,px+.5,py+height-.5,px+width-.5,py+height-.5,edge)
    D.Line(vg,px+.5,py+.5,px+.5,py+height-.5,edge);D.Line(vg,px+width-.5,py+.5,px+width-.5,py+height-.5,edge)
    M.Cost(vg,shop.cost,px+pad,py+(mini and 3 or 4),size,shop.poor and M.muted or D.white)
end
function M.Wallet(vg,value,right,y)
    local width=M.CostWidth(vg,math.max(1,value),18)
    local x=right-width
    D.Text(vg,'余额',x-8,y+2,14,M.muted,'vox-body',NVG_ALIGN_RIGHT)
    M.Credit(vg,x,y+1,16,D.orange);D.Text(vg,D.Number(value),x+20,y,18,D.white,'vox-tabular')
end
function M.Subtitle(vg,shop,x,y)
    if shop.cost==0 then D.Text(vg,'免费 · 只有核心驾驶舱',x,y,12,{26,13,5,184},'vox-body');return end
    local color=shop.poor and M.dim or {26,13,5,184}
    D.Text(vg,'整车',x,y,12,color,'vox-body')
    local costX=x+D.Width(vg,'整车 ',12,'vox-body')
    M.Cost(vg,shop.cost,costX,y,12,color)
    local rest=' · 余额 '..D.Number(shop.wallet)
    if shop.poor then rest=rest..' · 还差 '..D.Number(shop.cost-shop.wallet) end
    D.Text(vg,rest,costX+M.CostWidth(vg,shop.cost,12),y,12,color,'vox-body')
end
return M

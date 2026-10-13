local D=require 'ui.SourceDraw'
local Images=require 'urhox-libs/UI/Core/ImageCache'
local Data=require('core.ResourceData').Read('UI/Workshop.json')
local Defs=require('parts.Defs').PARTS
local M={colors={{154,167,180,255},{95,211,138,255},{74,168,255,255},{183,123,255,255},{255,180,60,255}}}
local meta={};local bars={};local maxHp=0
function M.Meta(id)
    if meta[id] then return meta[id] end
    local st=Data.stats[id] or {};local bp=require('construction.Prefab').Create(require('construction.Blueprint').New(),id)
    local counts,hp={},0
    for _,p in ipairs(bp:List()) do
        local d=Defs[p.type];hp=hp+d.hp
        if d.cat=='weapon' or d.cat=='movement' or d.cat=='function' or d.cat=='shield' then counts[p.type]=(counts[p.type] or 0)+1 end
    end
    local items={};for id,count in pairs(counts) do items[#items+1]={id=id,count=count} end
    local order={weapon=0,movement=1,['function']=2,shield=3}
    table.sort(items,function(a,b) local x,y=order[Defs[a.id].cat],order[Defs[b.id].cat];return x==y and (a.count==b.count and a.id<b.id or a.count>b.count) or x<y end)
    meta[id]={hp=hp,items=items,stats=st,blueprint=bp:Stats()};return meta[id]
end
function M.Bars(id)
    if bars[id] then return bars[id] end
    local a=M.Meta(id);local st=a.stats
    if maxHp==0 then for _,p in ipairs(Data.prefabs) do maxHp=math.max(1,maxHp,M.Meta(p.id).hp) end end
    bars[id]={{'耐久','ARMOR',a.hp/maxHp,a.hp>0 and D.Number(a.hp) or '—'}, {'机动','MOBILITY',(st.speed or 0)/130,(st.speed or 0)>0 and st.speed..' km/h' or '—'},
        {'火力','FIREPOWER',math.min(1,(st.weapons or 0)*(st.tier or 1)/15),(st.weapons or 0)>0 and st.weapons..' 门' or '—'}}
    return bars[id]
end
function M.Image(vg,path,r,zoom,bias,points,tint,xBias,translateX)
    local handle=Images.Get(path);if not handle or handle<=0 then return end
    local iw,ih=Images.GetSize(path);if iw<=0 or ih<=0 then return end
    local scale=math.max(r.w/iw,r.h/ih);local dw,dh=iw*scale,ih*scale
    local z=zoom or 1;local x=r.x+(r.w-dw)*(xBias or .5);local y=r.y+(r.h-dh)*(bias or .62)
    x=r.x+r.w*.5+(x-r.x-r.w*.5)*z;y=r.y+r.h*.5+(y-r.y-r.h*.5)*z
    x=x+r.w*(translateX or 0)*z
    if points then D.Path(vg,points) else nvgBeginPath(vg);nvgRect(vg,r.x,r.y,r.w,r.h) end
    local paint=tint and nvgImagePatternTinted(vg,x,y,dw*z,dh*z,0,handle,D.Color(tint)) or nvgImagePattern(vg,x,y,dw*z,dh*z,0,handle,1)
    nvgFillPaint(vg,paint);nvgFill(vg)
end
function M.Radial(vg,points,cx,cy,rx,ry,color,stop)
    nvgSave(vg);nvgTranslate(vg,cx,cy);nvgScale(vg,rx,ry)
    nvgBeginPath(vg);nvgMoveTo(vg,(points[1]-cx)/rx,(points[2]-cy)/ry)
    for i=3,#points,2 do nvgLineTo(vg,(points[i]-cx)/rx,(points[i+1]-cy)/ry) end
    nvgClosePath(vg)
    nvgFillPaint(vg,nvgRadialGradient(vg,0,0,0,stop,D.Color(color),nvgRGBA(color[1],color[2],color[3],0)))
    nvgFill(vg);nvgRestore(vg)
end
function M.TrimImages(keep)
    for _,path in ipairs(Images.GetCachedPaths()) do
        if path:sub(1,11)=='UI/Prefabs/' and not keep[path] then Images.Release(path) end
    end
end
local function ClipProjection(points,dx,dy,limit,above)
    local result={};local px,py=points[#points-1],points[#points]
    local pd=px*dx+py*dy-limit;local inside=above and pd>=0 or not above and pd<=0
    for i=1,#points,2 do
        local x,y=points[i],points[i+1];local d=x*dx+y*dy-limit
        local current=above and d>=0 or not above and d<=0
        if inside~=current then
            local t=pd/(pd-d);result[#result+1]=px+(x-px)*t;result[#result+1]=py+(y-py)*t
        end
        if current then result[#result+1]=x;result[#result+1]=y end
        px,py,pd,inside=x,y,d,current
    end
    return result
end
function M.Sweep(vg,points,x,y,w,h,progress)
    local dx,dy=math.sin(math.rad(110)),-math.cos(math.rad(110))
    local length=dx*w+dy*h
    local ox=x+w*.5+w*(-1.2+2.4*progress)-dx*length*.5;local oy=y+h*.5-dy*length*.5
    for _,stop in ipairs({{.3,.45,0,46},{.45,.58,46,0}}) do
        local ax,ay=ox+dx*length*stop[1],oy+dy*length*stop[1]
        local bx,by=ox+dx*length*stop[2],oy+dy*length*stop[2]
        local clipped=ClipProjection(points,dx,dy,ax*dx+ay*dy,true)
        if #clipped>0 then clipped=ClipProjection(clipped,dx,dy,bx*dx+by*dy,false) end
        if #clipped>=6 then
            D.Path(vg,clipped)
            nvgFillPaint(vg,nvgLinearGradient(vg,ax,ay,bx,by,nvgRGBA(255,255,255,stop[3]),nvgRGBA(255,255,255,stop[4])))
            nvgFill(vg)
        end
    end
end
function M.Tier(vg,id,x,y)
    local st=Data.stats[id] or {};local t=st.tier or 1;local p
    for _,v in ipairs(Data.prefabs) do if v.id==id then p=v end end
    local c=M.colors[t];M.Glow(vg,x,y+7,34,4,12,c,.9);D.Rect(vg,x,y+7,34,4,c)
    local tier=require('Config').TIERS[t].name
    D.Text(vg,tier,x+44,y,14,c,nil,nil,2);D.Text(vg,'/  '..p.kind,x+44+D.Width(vg,tier,14,nil,2)+10,y,14,{219,238,255,140},nil,nil,2)
end
function M.Glow(vg,x,y,w,h,blur,c,opacity)
    if w<=0 or h<=0 then return end
    local pad=blur*1.5
    nvgBeginPath(vg);nvgRect(vg,x-pad,y-pad,w+pad*2,h+pad*2)
    nvgFillPaint(vg,nvgBoxGradient(vg,x,y,w,h,0,blur,nvgRGBA(c[1],c[2],c[3],255*opacity),nvgRGBA(c[1],c[2],c[3],0)));nvgFill(vg)
end
function M.Segments(vg,x,y,w,ratio,c)
    local step=w/20
    for i=0,19 do
        D.Rect(vg,x+i*step,y,step-3,10,{255,255,255,26})
        local fill=math.min(step-3,w*math.min(1,ratio)-i*step)
        if fill>0 then D.Rect(vg,x+i*step,y,fill,10,c) end
    end
end
return M

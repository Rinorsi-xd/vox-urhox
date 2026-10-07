-- Source logical-cell projections: +Z up in plan, +Z right in elevation.
local C=require 'render.HangarCanvas'
local PARTS=require('parts.Defs').PARTS
local M={}
local function Tint(hex,k) return {math.min(255,math.floor(((hex>>16)&255)*k)),math.min(255,math.floor(((hex>>8)&255)*k)),math.min(255,math.floor((hex&255)*k)),255} end
local function Panel(vg,x,y,w,h,label)
    for _,p in ipairs({{x,y,1,1},{x+w,y,-1,1},{x,y+h,1,-1},{x+w,y+h,-1,-1}}) do
        C.Path(vg,{p[1]+p[3]*22,p[2],p[1],p[2],p[1],p[2]+p[4]*22},false);C.Stroke(vg,C.LINE,3)
    end
    C.Text(vg,label,x,y-12,22,C.DIM,true)
end
function M.Build(parts)
    local p={top={},side={},x0=math.huge,x1=-math.huge,z0=math.huge,z1=-math.huge,y1=0,weapons={}}
    local top,side,counts={},{},{}
    for _,part in ipairs(parts) do
        local def=PARTS[part.type]
        if def.weapon then
            if not counts[part.type] then counts[part.type]={type=part.type,count=0};p.weapons[#p.weapons+1]=counts[part.type] end
            counts[part.type].count=counts[part.type].count+1
        end
        for _,cell in ipairs(part._cells) do
            local x,y,z=table.unpack(cell);local kt=x..','..z;local ks=z..','..y
            if not top[kt] then top[kt]={x=x,y=y,z=z,color=part.color};p.top[#p.top+1]=top[kt]
            elseif top[kt].y<y then top[kt].y=y;top[kt].color=part.color end
            if not side[ks] then side[ks]={x=x,y=y,z=z,color=part.color};p.side[#p.side+1]=side[ks]
            elseif side[ks].x<x then side[ks].x=x;side[ks].color=part.color end
            p.x0=math.min(p.x0,x);p.x1=math.max(p.x1,x);p.z0=math.min(p.z0,z);p.z1=math.max(p.z1,z);p.y1=math.max(p.y1,y)
        end
    end
    return p
end
function M.Draw(vg,info)
    C.Frame(vg,'蓝图扫描',info.slot);local p=info.projection
    if #p.top>0 then
        Panel(vg,48,150,430,430,'俯视 · 车头朝上')
        local nx,nz=p.x1-p.x0+1,p.z1-p.z0+1;local s=math.min(390/nx,390/nz)
        local ox,oy=48+(430-nx*s)/2,150+(430-nz*s)/2
        for _,v in ipairs(p.top) do C.Rect(vg,ox+(v.x-p.x0)*s,oy+(p.z1-v.z)*s,math.max(1,s-1),math.max(1,s-1),Tint(v.color,.55+.6*v.y/math.max(1,p.y1))) end
        local ax=ox+(.5-p.x0)*s
        for y=160,570,16 do C.Path(vg,{ax,y,ax,math.min(y+8,570)},false);C.Stroke(vg,{255,106,19,217},2) end
        Panel(vg,540,150,436,200,'侧视 · 车头朝右')
        local s2=math.min(396/nz,160/(p.y1+1));local ox2=540+(436-nz*s2)/2
        for _,v in ipairs(p.side) do C.Rect(vg,ox2+(v.z-p.z0)*s2,330-(v.y+1)*s2,math.max(1,s2-1),math.max(1,s2-1),Tint(v.color,.85)) end
    end
    C.Text(vg,'武器',540,396,22,C.DIM,true);C.Rect(vg,600,389,376,2,{255,255,255,31})
    if #p.weapons==0 then C.Text(vg,'没有武器',540,440,30,C.WARN) end
    for i,w in ipairs(p.weapons) do local y=440+(i-1)*42;if y>560 then break end
        C.Text(vg,PARTS[w.type].name,540,y,30);C.Text(vg,'× '..w.count,976,y,30,C.BRAND,false,NVG_ALIGN_RIGHT)
    end
    local st,conn=info.diag.stats,info.diag.conn
    C.Text(vg,'核心'..(conn.coreId and '已连接' or '缺失')..' · 悬空 '..conn.floatingCount..' · 推进器 '..st.thrusters..' · '..st.count..' 个零件',540,606,22,C.DIM,true)
end
return M

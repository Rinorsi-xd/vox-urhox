-- shared/scene/holoPanels.js drawStatsPanel, in its original 1024 x 640 space.
local C=require 'render.HangarCanvas'
local CELL=require('Config').CELL
local M={}
local function Level(k) return k>1 and C.BAD or k>.9 and C.WARN or nil end
local function Row(vg,x,y,w,label,value,cap,unit)
    unit=unit or '';local k=cap and value/cap or 0
    C.Text(vg,label,x,y,26,C.DIM,true)
    local tail=cap and ' / '..C.Number(cap)..unit or unit
    local tw=C.Text(vg,tail,x+w,y,26,C.DIM,false,NVG_ALIGN_RIGHT)
    C.Text(vg,C.Number(value),x+w-tw-4,y+2,38,Level(k),false,NVG_ALIGN_RIGHT)
    if cap then C.Rect(vg,x,y+14,w,5,{255,255,255,26});C.Rect(vg,x,y+14,w*math.min(1,k),5,Level(k) or C.BRAND) end
end
function M.Draw(vg,info)
    C.Frame(vg,'车辆数据',info.slot)
    local st,tier=info.diag.stats,info.tier;local errors={}
    for _,w in ipairs(info.diag.list) do if w.level~='warn' then errors[#errors+1]=w end end
    local fits=st.fitTier and st.fitTier.id<=tier.id;local ok=#errors==0 and fits
    local points={}
    for i=0,5 do local a=math.pi/6+i*math.pi/3;points[#points+1]=84+math.cos(a)*36;points[#points+1]=158+math.sin(a)*36 end
    C.Path(vg,points);C.Stroke(vg,fits and C.BRAND or C.BAD,4)
    C.Text(vg,'T'..tier.id,84,160,29,nil,false,NVG_ALIGN_CENTER,NVG_ALIGN_MIDDLE)
    C.Text(vg,tier.name,138,152,34,C.BRAND)
    local tag=ok and '可出战' or '不能出战';local tw=C.Width(vg,tag,24)
    C.Rect(vg,138,166,tw+22,32,ok and C.OK or C.BAD);C.Text(vg,tag,149,191,24,{11,13,16,255})
    if st.fitTier then C.Text(vg,'最低可进 T'..st.fitTier.id,138+tw+38,190,22,C.DIM,true) end
    C.Text(vg,C.Fit(vg,info.name,470,72),48,286,72)
    C.Text(vg,'预算',48,350,26,C.DIM,true)
    local cap=' / '..C.Number(tier.budget);C.Text(vg,cap,480,350,26,C.DIM,false,NVG_ALIGN_RIGHT)
    -- Source measures the cap again AFTER changing to 52px.
    C.Text(vg,C.Number(st.budget),480-C.Width(vg,cap,52)-6,352,52,Level(st.budget/tier.budget),false,NVG_ALIGN_RIGHT)
    local ratio=st.budget/tier.budget;local on=math.floor(math.min(1,ratio)*30+.5);local sw=(432-4*29)/30
    for i=0,29 do C.Rect(vg,48+i*(sw+4),366,sw,16,i<on and (Level(ratio) or C.BRAND) or {255,255,255,26}) end
    Row(vg,48,440,432,'质量',st.mass,tier.mass,' kg');Row(vg,48,506,432,'零件',st.parts,tier.parts);Row(vg,48,572,432,'武器',st.weapons,tier.weapons)
    local function Big(label,value,unit,y)
        C.Text(vg,label,560,y,26,C.DIM,true);local width=C.Text(vg,value,560,y+82,86)
        C.Text(vg,unit,572+width,y+80,30,C.DIM)
    end
    Big('耐久',C.Number(info.hp),'',160);Big('参考极速',st.topSpeed>0 and C.Number(st.topSpeed) or '—',st.topSpeed>0 and 'km/h' or '',300)
    C.Text(vg,'尺寸  长 × 宽 × 高',560,446,26,C.DIM,true)
    local function Metres(n) return (string.format('%.1f',n*CELL):gsub('%.0$','')) end
    C.Text(vg,Metres(st.dims.L)..' × '..Metres(st.dims.W)..' × '..Metres(st.dims.H)..' 米',560,500,44)
    local top=errors[1] or info.diag.list[1];C.Rect(vg,560,548,6,34,top and (#errors>0 and C.BAD or C.WARN) or C.OK)
    C.Text(vg,C.Fit(vg,top and (top.text or top.msg or top.title or '') or '车辆状态良好，可以出战',390,24,true),580,574,24,top and C.TEXT or C.DIM,true)
end
return M

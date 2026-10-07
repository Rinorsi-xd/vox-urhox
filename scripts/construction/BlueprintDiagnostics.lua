-- Data-only source warnings. UI owns presentation, highlighting and focus.
local Config=require 'Config'
local PARTS=require('parts.Defs').PARTS
local Rot=require 'core.Rotations'
local M={}
local function Keys(set)
    local out={};for id in pairs(set) do out[#out+1]=id end;table.sort(out);return out
end
local function Number(n)
    local s=string.format('%.3f',n):gsub('0+$',''):gsub('%.$','')
    local whole,fraction=s:match('^(%-?%d+)(.*)$');local sign=''
    if whole:sub(1,1)=='-' then sign='-';whole=whole:sub(2) end
    local groups={};while #whole>3 do table.insert(groups,1,whole:sub(-3));whole=whole:sub(1,-4) end
    table.insert(groups,1,whole);return sign..table.concat(groups,',')..fraction
end
function M.Compute(bp,tier)
    local adj=bp:Graph();local conn=bp:Connectivity(adj);local st=bp:Stats();local list={}
    local function Push(level,text,ids) list[#list+1]={level=level,text=text,ids=ids or {}} end
    local parts=bp:List();local intersecting={}
    for _,p in ipairs(parts) do if bp:Overlaps(p.type,p.pos,p.rot,p._cells,{[p.id]=true}) then intersecting[#intersecting+1]=p.id end end
    if #intersecting>0 then Push('error',#intersecting..' 个零件互相重叠；尺寸更新后原零件已保留，请移动调整',intersecting) end
    for _,text in ipairs(bp.migrationWarnings or {}) do Push('warn',text) end
    if st.count==0 then Push('error','蓝图是空的，先放一个核心驾驶舱');return {list=list,stats=st,conn=conn,outside={}} end
    if not conn.coreId then Push('error','缺少核心驾驶舱') end
    if conn.coreId and conn.floatingCount>0 then Push('error',conn.floatingCount..' 个零件没有连到核心（红色高亮）',Keys(conn.floating)) end
    local bounds=Config.TierBounds();local outside={}
    for _,p in ipairs(parts) do for _,c in ipairs(p._cells) do if not Config.InBounds(bounds,table.unpack(c)) then outside[p.id]=true end end end
    local ids=Keys(outside);if #ids>0 then Push('error',#ids..' 个零件超出建造区域',ids) end
    if st.budget>tier.budget then Push('error','预算超出 '..(st.budget-tier.budget)..' 点') end
    if st.mass>tier.mass then Push('error','总质量 '..Number(st.mass)..' kg，超出 '..tier.name..' 上限 '..Number(st.mass-tier.mass)..' kg（仍可试车）') end
    if st.parts>tier.parts then Push('error','零件数超出 '..(st.parts-tier.parts)..' 个') end
    if st.decor>tier.decor then Push('error','装饰件超出 '..(st.decor-tier.decor)..' 个（上限 '..tier.decor..'）') end
    if st.weapons>tier.weapons then Push('error','武器数超过上限（'..st.weapons..'/'..tier.weapons..'）') end
    local overTier={}
    for _,p in ipairs(parts) do if (PARTS[p.type].wtier or 0)>tier.id then overTier[#overTier+1]=p.id;outside[p.id]=true end end
    if #overTier>0 then Push('error',#overTier..' 件零件阶位高于 '..tier.name..'（橙色高亮）',overTier) end
    local width,height=st.dims.W*Config.CELL,st.dims.H*Config.CELL
    if width>Config.MAP_CLEARANCE.width then Push('warn',string.format('车宽 %.1f 米，超过地图主路宽度 %g 米，部分路线过不去',width,Config.MAP_CLEARANCE.width)) end
    if height>Config.MAP_CLEARANCE.height then Push('warn',string.format('车高 %.1f 米，超过地图主通道净高 %g 米，部分路线过不去',height,Config.MAP_CLEARANCE.height)) end
    if st.load==0 and st.thrusters==0 then Push('block','没有能工作的轮子、履带、悬浮器、节足或推进器，车辆无法移动') end
    if #st.badHovers>0 then Push('warn','悬浮器升力轴装歪，无法提供托力',st.badHovers) end
    if st.legCount>0 and st.legCount<4 then Push('warn','能工作的节足少于 4 条，只能拖行；不足 2 条无法站立') end
    if st.legCount>0 and st.L>1 then Push('warn','节足车负载率超过 1，无法爬墙') end
    local legs={};for _,p in ipairs(parts) do if PARTS[p.type].leg and Rot.ROTATIONS[p.rot].up[2]>.99 then legs[#legs+1]=p end end
    local crowded,gap={},0
    for i,a in ipairs(legs) do for j=i+1,#legs do
        local b=legs[j];local oa,ob=Rot.ApplyRot(a.rot,{1,0,0}),Rot.ApplyRot(b.rot,{1,0,0})
        if oa[1]==ob[1] and oa[2]==ob[2] and oa[3]==ob[3] then
            local need=math.max(PARTS[a.type].wtier,PARTS[b.type].wtier)>=5 and 1.5 or 1
            local dx,dy,dz=a.pos[1]-b.pos[1],a.pos[2]-b.pos[2],a.pos[3]-b.pos[3]
            if math.sqrt(dx*dx+dy*dy+dz*dz)*Config.CELL<need-1e-6 then crowded[a.id]=true;crowded[b.id]=true;gap=math.max(gap,need) end
        end
    end end
    local crowdedIds=Keys(crowded)
    if #crowdedIds>0 then Push('warn',string.format('%d 条节足同侧装得太密（间距不到 %g 米），走路时腿会互相穿插、步子变小；建议拉开间距',#crowdedIds,gap),crowdedIds) end
    if st.hoverLoad>0 and st.mass>st.hoverLoad*2 then Push('warn','悬浮托力不足：重量超过悬浮器最大托举能力') end
    if st.hoverOffCenter then Push('warn','重心超出悬浮支撑范围，车辆会倾斜；请分散布置悬浮器') end
    if st.liftRatio>0 and st.liftRatio<1 then Push('warn',string.format('升重比 %.2f：升力不足，无法起飞',st.liftRatio))
    elseif st.liftRatio>=1 and st.liftRatio<1.2 then Push('warn',string.format('升重比 %.2f：调平和前进的升力余量很小',st.liftRatio)) end
    if st.weapons==0 then Push('block','没有武器，不能进入标准对战') end
    if st.L>2 and st.load>0 then Push(st.thrusters>0 and 'warn' or 'block',string.format('负载率 %.2f 超过 2.0，轮子/悬浮器超载%s',st.L,st.thrusters>0 and '，推进器仍可工作' or '，车辆开不动'))
    elseif st.L>1.2 and st.load>0 then Push('warn',string.format('负载率 %.2f 偏高，车会明显变慢',st.L)) end
    if st.trackWidth>0 and st.comY-st.bb.minY>st.trackWidth*.75 then Push('warn','重心偏高，转弯时容易侧翻') end
    if st.load>0 then local low,high=math.min(st.loadL,st.loadR),math.max(st.loadL,st.loadR)
        if low==0 and high>0 or low>0 and high/low>1.8 then Push('warn','左右两侧承载差异较大') end
    end
    for _,p in ipairs(parts) do
        local def=PARTS[p.type]
        if def.barrel then
            local m,dir=Rot.ApplyRot(p.rot,def.barrel),Rot.ApplyRot(p.rot,{0,0,1})
            for k=1,3 do
                local key=bp.Key(p.pos[1]+m[1]+dir[1]*k,p.pos[2]+m[2]+dir[2]*k,p.pos[3]+m[3]+dir[3]*k)
                ---@type integer|nil
                local found
                for _,id in ipairs(bp.cellIds[key] or {}) do if id~=p.id then found=id;break end end
                if found then Push('warn',def.name..'的炮口前方被自己的车身挡住',{p.id,found});break end
            end
        end
    end
    require('construction.BuildClearance').Diagnostics(bp,parts,Push)
    for _,w in ipairs(bp:WeakLinks(adj,conn.coreId)) do Push('warn','有一处单点连接挂着 '..w.count..' 个零件，容易整块被打掉',{w.a,w.b}) end
    return {list=list,stats=st,conn=conn,outside=outside}
end
return M

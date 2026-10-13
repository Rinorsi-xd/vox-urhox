-- Frozen H5 editor.js rectangle/height and selectionTools.extrusionPlan.
-- Ray coordinates are blueprint world metres; integer cells are centred at
-- (x, y + .5, z). Preview plans never mutate the real blueprint.
local Blueprint=require 'construction.Blueprint'
local Placement=require 'construction.Placement'
local History=require 'construction.EditHistory'
local Defs=require('parts.Defs').PARTS
local Config=require 'Config'
local M={MAX=48}
local function Copy(v) return {table.unpack(v)} end
local function Clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function Axis(n) for i=1,3 do if n[i]~=0 then return i end end end
local function GridRay(o,d)
    return {o[1]/Config.CELL+.5,o[2]/Config.CELL,o[3]/Config.CELL+.5},
        {d[1]/Config.CELL,d[2]/Config.CELL,d[3]/Config.CELL}
end
function M.PlaneCell(s,origin,direction)
    local o,d=GridRay(origin,direction)
    if math.abs(d[2])<1e-6 then return s.cur end
    local t=(s.anchor[2]+.5-o[2])/d[2]
    if t<=0 or t*math.sqrt(d[1]^2+d[2]^2+d[3]^2)>80 then return s.cur end
    local c={}
    for a=1,3 do c[a]=a==2 and s.anchor[a] or Clamp(math.floor(o[a]+d[a]*t),s.anchor[a]-M.MAX+1,s.anchor[a]+M.MAX-1) end
    if s.a~=2 then c[s.a]=s.n[s.a]>0 and math.max(c[s.a],s.anchor[s.a]) or math.min(c[s.a],s.anchor[s.a]) end
    return c
end
function M.HeightAlong(s,origin,direction)
    local o,d=GridRay(origin,direction);local n=s.a==2 and s.n or {0,1,0}
    local A,B,D,E=0,0,0,0
    for a=1,3 do
        local centre=a==2 and s.anchor[a]+.5 or (math.min(s.anchor[a],s.cur[a])+math.max(s.anchor[a],s.cur[a])+1)/2
        local w=o[a]-centre
        A=A+d[a]^2;B=B+d[a]*n[a];D=D+d[a]*w;E=E+n[a]*w
    end
    local den=A-B*B;if den<1e-6*A or A==0 then return nil end
    return (A*E-B*D)/den
end
function M.Cells(s)
    local lo,hi=require('construction.SelectionTools').Bounds(s.anchor,s.cur);local cells={}
    for layer=0,s.h-1 do for x=lo[1],hi[1] do for y=lo[2],hi[2] do for z=lo[3],hi[3] do
        cells[#cells+1]={x+s.hd[1]*layer,y+s.hd[2]*layer,z+s.hd[3]*layer}
    end end end end
    return cells
end
function M.RectanglePlan(editor,s)
    local cells=M.Cells(s);local bad=false;local own={};local mirrors={}
    local lo,hi=Copy(cells[1]),Copy(cells[1])
    for _,c in ipairs(cells) do
        own[Blueprint.Key(table.unpack(c))]=true
        for a=1,3 do lo[a]=math.min(lo[a],c[a]);hi[a]=math.max(hi[a],c[a]) end
        if not bad then local res=editor.bp:Check(s.type,c,s.rot,editor.bounds,nil,false);bad=not res.ok and res.reason or false end
    end
    if editor.mirror then for _,c in ipairs(cells) do
        local m=Placement.Mirror(s.type,c,s.rot)
        if m and not own[Blueprint.Key(table.unpack(m.pos))] then mirrors[#mirrors+1]=m end
    end end
    return {cells=cells,mirrorCells=mirrors,lo=lo,hi=hi,bad=bad}
end
function M.ExtrusionPlan(editor,seeds,normal,layers)
    local axis=Axis(normal);assert(axis,'Stretch normal must name one axis')
    local front,columns={},{}
    for _,p in ipairs(seeds) do
        if not Defs[p.type].shape or Defs[p.type].panel then return {items={},bad='批量拉伸只支持实心结构块，请先取消选中设备或旧面片'} end
        local key={};for a=1,3 do if a~=axis then key[#key+1]=p.pos[a] end end;key=table.concat(key,',')
        if not front[key] then columns[#columns+1]=key end
        if not front[key] or p.pos[axis]*normal[axis]>front[key].pos[axis]*normal[axis] then front[key]=p end
    end
    if #columns*layers*(editor.mirror and 2 or 1)>4096 then return {items={},bad='一次最多新增 4096 格，请减少层数或选区'} end
    local temp=Blueprint.New();for _,p in ipairs(editor.bp:List()) do temp:Add(History.Snapshot(p)) end
    local items,seen={},{}
    local function Add(p,pos,rot)
        local key=Blueprint.Key(table.unpack(pos));if seen[key] then return end;seen[key]=true
        local res=temp:Check(p.type,pos,rot,editor.bounds,nil,false);if not res.ok then return res.reason end
        local data={type=p.type,pos=pos,rot=rot,color=p.color,shellColor=p.shellColor,g=p.g}
        temp:Add(data);items[#items+1]=data
    end
    for layer=1,layers do for _,key in ipairs(columns) do
        local p=front[key];local pos={}
        for a=1,3 do pos[a]=p.pos[a]+normal[a]*layer end
        local bad=Add(p,pos,p.rot);if bad then return {items=items,bad=bad} end
        if editor.mirror then local m=Placement.Mirror(p.type,pos,p.rot)
            if m then local source=Placement.MirrorPart(editor.bp,p) or p
                bad=Add(source,m.pos,m.rot);if bad then return {items=items,bad='镜像侧：'..bad} end
            end
        end
    end end
    return {items=items,bad=false}
end
function M.Start(editor)
    if next(editor.selection) then
        local hit=editor.hit
        if not hit or not editor.selection[hit.partId] then return false,'请点选中方块上要向外拉伸的面' end
        editor.stretch={phase='selection',seeds=editor:Selected(),n=Copy(hit.normal),h=1}
    else
        local pv=editor.preview
        if not pv or not pv.type then return false,'没有放置目标' end
        if not Defs[pv.type].shape then return false,'拉伸只能用方块（快捷栏换一格方块）' end
        if not pv.res.ok then return false,pv.res.reason end
        local axis=Axis(pv.normal)
        editor.stretch={phase='rect',type=pv.type,rot=pv.rot,n=Copy(pv.normal),a=axis,anchor=Copy(pv.pos),cur=Copy(pv.pos),h=1,adj=0,hd=axis==2 and Copy(pv.normal) or {0,1,0}}
    end
    M.Update(editor);return true
end
function M.Update(editor)
    local s=editor.stretch;if not s then return end
    if s.phase~='selection' and editor.rayOrigin then
        if s.phase=='rect' then s.cur=M.PlaneCell(s,editor.rayOrigin,editor.rayDirection)
        else
            local t=M.HeightAlong(s,editor.rayOrigin,editor.rayDirection)
            if t then
                if s.a==2 then s.base=math.max(1,1+math.floor(t+.5))
                else s.hd={0,t>=0 and 1 or -1,0};s.base=1+math.floor(math.abs(t)+.5) end
            end
        end
    end
    if s.phase=='height' then s.h=Clamp((s.base or 1)+s.adj,1,M.MAX) end
    local key=table.concat({editor.history.revision,tostring(editor.mirror),s.h,s.cur and table.concat(s.cur,',') or '',s.hd and table.concat(s.hd,',') or ''},'|')
    if key==s.key then return end;s.key=key;s.planVersion=(s.planVersion or 0)+1
    local plan=s.phase=='selection' and M.ExtrusionPlan(editor,s.seeds,s.n,s.h) or M.RectanglePlan(editor,s)
    for k,v in pairs(plan) do s[k]=v end
    editor.dirty=true
end
function M.Adjust(editor,step)
    local s=editor.stretch;if not s then return false end
    if s.phase=='selection' then s.h=Clamp(s.h+step,1,M.MAX)
    elseif s.phase=='height' then s.adj=s.adj+step end
    M.Update(editor);return true
end
function M.Cancel(editor) editor.stretch=nil;editor.preview=nil;editor.dirty=true end
function M.Right(editor)
    local s=editor.stretch;if not s then return false end
    if s.phase=='height' then s.phase='rect';M.Update(editor) else M.Cancel(editor) end
    return true
end
function M.Commit(editor)
    local s=editor.stretch
    -- Recheck the complete selection batch at confirmation, including mirrors.
    local plan=s.phase=='selection' and M.ExtrusionPlan(editor,s.seeds,s.n,s.h) or M.RectanglePlan(editor,s)
    if plan.bad then return false,(s.phase=='selection' and '无法拉伸：' or '放不下：')..plan.bad end
    local items=plan.items or {};local ops={};local id=editor.bp.nextId
    if s.phase~='selection' then
        local finish=editor:FinishFor(s.type)
        local g=editor.joinNew and editor.bp.nextGroup or 0
        for _,c in ipairs(plan.cells) do items[#items+1]={type=s.type,pos=c,rot=s.rot,color=finish.color,shellColor=finish.shellColor,g=g} end
        -- H5 skips occupied mirrored rectangle cells, while selection extrusion
        -- rejects either side atomically. Keep those distinct authored rules.
        local occupied={};for _,it in ipairs(items) do occupied[Blueprint.Key(table.unpack(it.pos))]=true end
        for _,m in ipairs(plan.mirrorCells) do
            local key=Blueprint.Key(table.unpack(m.pos));local res=editor.bp:Check(s.type,m.pos,m.rot,editor.bounds,nil,false)
            if res.ok and not occupied[key] then items[#items+1]={type=s.type,pos=m.pos,rot=m.rot,color=finish.color,shellColor=finish.shellColor,g=g>0 and g+1 or 0};occupied[key]=true end
        end
    end
    for _,it in ipairs(items) do local data=History.Snapshot({id=id,type=it.type,pos=it.pos,rot=it.rot,color=it.color,shellColor=it.shellColor,g=it.g})
        ops[#ops+1]={op='add',data=data};id=id+1
    end
    local selection=s.phase=='selection';local ok=editor.history:Commit(ops,not selection and editor.joinNew and require('construction.BuildGroups').JoinAdded or nil)
    if selection and ok then for _,op in ipairs(ops) do editor.selection[op.data.id]=true end;editor:SelectionChanged() end
    M.Cancel(editor);if selection then editor.tool='build';editor.stretchSelected=true end
    return ok
end
function M.Click(editor)
    local s=editor.stretch
    if not s then return M.Start(editor) end
    if s.phase=='rect' then s.phase='height';s.adj=0;s.base=s.h;editor.dirty=true;return true end
    return M.Commit(editor)
end
return M

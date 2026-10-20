-- Frozen storyMission._marker/_project and storyKinds marker selection.
local M={}
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
function M.Select(mission)
    local r=mission.rules;local s=r:StepSpec();local target=r:Target()
    if not s or not target or r.completeAt then return nil end
    local player=mission.player:Position();local near,d=nil,math.huge
    for i=2,#mission.entries do local e=mission.entries[i];if e.unit.alive then
        local distance=Flat(player,e.unit:Position());if distance<d then near=e;d=distance end
    end end
    local enemy=s.kind=='clear' and r.phase=='fight'
    local label,kind,lift,close='目标','goal',9,false
    if s.kind=='escort' then enemy=mission.convoy.blocked and near~=nil;label=mission.convoy.far and '运输车 · 等你' or '运输车 · 小运';lift=6
    elseif s.kind=='hold' then enemy=Flat(player,s.pos)<s.healR*1.8 and near~=nil;label='要塞护盾';lift=12
    elseif s.kind=='capture' then
        enemy=(r.cap.phase=='counter' or r.cap.phase=='cap' and Flat(player,s.pos)<s.r*2.5) and near~=nil
        label=r.cap.phase=='scrub' and '涂鸦' or '采集器 '..s.site;kind=r.cap.phase=='scrub' and 'install' or 'enemy';lift=10
    elseif s.kind=='boss' then
        local boss=mission.boss;if not boss or boss.flow.stage~='fight' then return nil end
        local shelter=boss:Threat() and not boss:UnderRoof(player,4) and boss:Shelter(player)
        label=shelter and '顶棚 · 躲进去' or '九尾狐';kind=shelter and 'goal' or 'enemy';lift=24
        close=not shelter and Flat(player,boss.unit:Position())<160
    elseif s.kind=='install' then label='采集器';kind='install'
    elseif s.kind=='pickup' then label='情报';kind='intel'
    elseif s.id=='home' then label='要塞' end
    if enemy then
        label=near and near.unit.name and near.unit.name:match('([^·]+)$') or '海盗';label=label:gsub('^[ \t\r\n]+',''):gsub('[ \t\r\n]+$','');kind='enemy';lift=3.5
    end
    return {target=target,label=label,kind=kind,lift=lift,enemy=enemy,close=close,excluded=enemy and near and near.unit or nil}
end
function M.Project(nx,ny,behind,w,h)
    local x,y=(nx*.5+.5)*w,(-ny*.5+.5)*h
    if behind then x=w-x;y=h-y end
    local m=70;local off=behind or x<m or x>w-m or y<m or y>h-m;local angle=0
    if off then
        local cx,cy=w/2,h/2;local dx,dy=x-cx,y-cy;if dy==0 then dy=1 end
        local k=math.min((cx-m)/math.max(1e-6,math.abs(dx)),(cy-m)/math.max(1e-6,math.abs(dy)))
        x=cx+dx*k;y=cy+dy*k;angle=math.atan(dy,dx)
    end
    return {x=x,y=y,off=off,angle=angle}
end
return M

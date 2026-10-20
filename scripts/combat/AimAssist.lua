-- Frozen shared/combat/aimAssist.js: soft lock selects exposed cells, never a hull centre.
local V=require 'core.Math3'
local CELL=require('Config').CELL
local Fallback=require 'combat.AimFallback'
local M={}
local function Position(u) return u.Position and u:Position() or u.pos end
-- touch（可选，仅手机端传入；PC 与源夹具不传，行为与源完全一致）：
--   ignoreGround 准星射线打到的不是车（地面 / 掩体前沿）时不拿它的距离裁候选，真实遮挡仍由可见性射线判定
--   keepCone     不按目标横向速度缩小吸附角，快速横穿的目标也吸得住
function M.Apply(origin,dir,hit,self,units,castRay,stats,wide,canReach,touch)
    local assist=stats and stats.assist;if not assist or not self or not self.vehicle then return nil end
    local from=Position(self);local range=stats.range;wide=wide or 1
    local function enemy(u) return u and u~=self and u.alive and u.vehicle and u.team~=self.team end
    local ref=hit and hit.owner and hit.owner.ref
    if enemy(ref) and V.Length(V.Sub(hit.point,from))<=range then return {point=nil,ref=ref,partId=nil,slow=assist.slow} end
    local near=hit and not (touch and touch.ignoreGround and not hit.owner) and hit.dist or math.huge;local candidates={};local ordinal=0
    for _,unit in ipairs(units or {}) do if enemy(unit) then
        local centre=Position(unit);local to=V.Sub(centre,origin);local along=V.Dot(to,dir)
        if along>1 then
            local body=unit.vehicle.body;local t,q,velocity=body.translation(),body.rotation(),body.linvel()
            local bounds=unit.vehicle.spec and unit.vehicle.spec.bounds;local radius=bounds and V.Length(V.Sub(bounds.max,bounds.min))/2 or 6
            local perp=V.Length(V.Sub(to,V.Scale(dir,along)));local vel={velocity.x,velocity.y,velocity.z};local side=V.Length(V.Sub(vel,V.Scale(dir,V.Dot(vel,dir))))
            local angle=assist.angle*wide/(touch and touch.keepCone and 1 or 1+side/math.max(1,along)/.6)
            if math.atan(math.max(0,perp-radius),along)<=angle and V.Length(V.Sub(centre,from))-radius<=range then
                local parts=unit.bp.List and unit.bp:List() or {};if not unit.bp.List then for _,part in pairs(unit.bp.parts) do parts[#parts+1]=part end;table.sort(parts,function(a,b)return a.id<b.id end) end
                for _,part in ipairs(parts) do
                    local best
                    for _,cell in ipairs(part._cells) do
                        local world=V.Rotate(q,{cell[1]*CELL,(cell[2]+.5)*CELL,cell[3]*CELL});local point={world[1]+t.x,world[2]+t.y,world[3]+t.z}
                        local delta=V.Sub(point,origin);local a=V.Dot(delta,dir)
                        if a>1 and a<=near+2 then
                            local ang=math.atan(math.max(0,V.Length(V.Sub(delta,V.Scale(dir,a)))-CELL*.5),a)
                            if ang<=angle and(not best or ang<best.ang) and V.Length(V.Sub(point,from))<=range then best={ang=ang,point=point} end
                        end
                    end
                    if best then ordinal=ordinal+1;best.unit=unit;best.id=part.id;best.ordinal=ordinal;candidates[#candidates+1]=best end
                end
            end
        end
    end end
    table.sort(candidates,function(a,b)return a.ang<b.ang or a.ang==b.ang and a.ordinal<b.ordinal end)
    for i=1,math.min(4,#candidates) do local candidate=candidates[i];local d=V.Sub(candidate.point,origin);local length=V.Length(d)
        local h=castRay(origin,V.Scale(d,1/length),length+CELL*2,self.vehicle.body)
        if h and h.owner and h.owner.ref==candidate.unit then
            local result={point=h.point,ref=candidate.unit,partId=candidate.id,slow=assist.slow}
            if canReach and not canReach(h.point,candidate.unit) then
                local selected={unit=candidate.unit,id=candidate.id,point=h.point}
                return Fallback.Find(origin,dir,near,self,selected,candidates,castRay,stats,wide,canReach,touch) or result
            end
            return result
        end
    end
end
return M

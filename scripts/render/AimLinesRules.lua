-- Frozen three/src/drive/aimLines.js selection and occlusion; no audio event.
local V=require 'core.Math3'
local function Linear(byte)
    local s=byte/255;return s<.04045 and s*.0773993808 or (s*.9478672986+.0521327014)^2.4
end
local M={RANGE=1000,ENEMY={1,Linear(59),Linear(48)},ALLY={Linear(46),Linear(168),1}}
function M.Scan(units,me,cast,camera,time,emit)
    local warnings={}
    for _,u in ipairs(units) do if u~=me and u.alive and u.vehicle and u.weapons then
        local b=u.vehicle.body;local t=b.translation();local pos={t.x,t.y,t.z}
        if V.Length(V.Sub(pos,camera))<=M.RANGE then
            local state={pos=pos,quat=b.rotation()};local enemy=me and u.team~=me.team
            for _,g in ipairs(u.weapons.groups) do for _,w in ipairs(g.weapons) do
                local wind=w.windup or 0;local k=wind>0 and 1 or w.charge or 0
                if w.stats.windup and k>=.5 and not u.weapons.offline then
                    local muzzle=u.weapons:Muzzle(w,state);local hit=cast(muzzle.pos,muzzle.dir,M.RANGE,b);local len=hit and hit.dist or M.RANGE
                    emit(muzzle.pos,muzzle.dir,hit,len,enemy,k,wind,camera,time)
                    if enemy and me.alive and me.vehicle then
                        local delta=V.Sub(me.pos,muzzle.pos);local along=V.Dot(delta,muzzle.dir)
                        local off=V.Length(V.Sub(delta,V.Scale(muzzle.dir,along)))
                        if along>0 and along<=len+3 and (off<2.5 or hit and hit.owner and hit.owner.ref==me) then
                            warnings[#warnings+1]={unit=u,pos=pos,progress=wind>0 and 1 or k,dist=along}
                        end
                    end
                end
            end end
        end
    end end
    return warnings
end
function M.Style(pos,camera,enemy,k,wind,time)
    local glow=(k-.5)*2;local pulse=wind>0 and .7+.3*math.sin(time*40) or 1
    local px=math.max(1,V.Length(V.Sub(pos,camera)))*.0012
    local flick=.8+.2*math.sin(time*13+pos[1])+(wind>0 and .25*math.sin(time*40) or 0)
    return {color=enemy and M.ENEMY or M.ALLY,width=2+wind*2,opacity=math.min(1,(.45+.35*glow+.3*wind)*pulse),
        glowSize=math.max(1.2,px*30)*(.8+.5*glow+.8*wind)*flick,glowOpacity=math.min(1,.55+.3*glow+.4*wind)}
end
return M

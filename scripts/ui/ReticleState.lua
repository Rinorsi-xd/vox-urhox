-- Frozen testDrive._fireState and reticle.js geometry, independent of rendering.
local M={}
local function Clamp(v) return math.max(0,math.min(1,v or 0)) end
M.Clamp=Clamp
M.zoom={laser=1.6,mg=1.3,sniper=4,missile=1.5}
function M.ScopeFov(base,kind) return 2*math.atan(math.tan(base*math.pi/360)/(M.zoom[kind] or 2))*180/math.pi end
function M.Layout(w,h)
    local k=math.min(w/1920,h/1080)
    return {k=k,cx=w/2,cy=h/2,radius=270*k,inner=254*k,width=w,height=h}
end
function M.TargetPlate(l,f)
    local k=l.k;local x=f.x+f.half+22*k
    if x+168*k>l.width-10*k then x=f.x-f.half-190*k end
    return math.max(10*k,math.min(l.width-178*k,x)),math.max(24*k,math.min(l.height-48*k,f.y-f.half*.8-16*k))
end
function M.Fire(wpn,firing,mark,dist,enemy,lock)
    local g=wpn:Group();if not g then return nil end
    local w=g.weapons[1];local st=w and w.stats or {};local ready=Clamp(wpn:Readiness(g))
    local function State(word,tone,frac,sub) return {word=word,tone=tone,frac=Clamp(frac),sub=sub or ''} end
    if st.drill then
        local d=wpn.drill
        if d:Latched() then return State('咬住','ok',1) end
        if d.active then return State('突进','ok',1) end
        if wpn.offline then return State('能量耗尽','warn',wpn.energy/wpn.energyMax,'等能量回来') end
        if w.cool>0 then return State('冷却','busy',1-w.cool/(w.interval or 1),string.format('%.1f 秒',w.cool)) end
        if d.held then return State('蓄力','busy',w.windup,'松开左键突进') end
        return State('就绪','ok',1,'长按左键蓄力')
    end
    if wpn.offline then return State('能量耗尽','warn',wpn.energy/wpn.energyMax,'停火等能量回来') end
    if g.kind=='missile' then
        local li=lock
        if li and li.cooling then return State('装填','busy',li.reload or ready) end
        if li and li.firing then return State('齐射','ok',1) end
        if li and not li.energyOk then return State('能量不足','warn',0,'至少够一枚') end
        local volley=li and string.format('齐射 %d/%d 枚',li.count or 0,li.tubes or 0) or ''
        if li and li.locked then return State('已锁定','ok',1,'开火 · '..volley) end
        if li and li.progress>0 then return State('锁定中','busy',li.progress,'目标留在框里 · '..volley) end
        return State('无目标','busy',0,'框住 100–350 米的敌人')
    end
    if firing and wpn.blocked>=#g.weapons then return State('射界外','warn',ready,'炮塔转不到这边') end
    if firing and mark=='blocked' then return State('被挡住','warn',ready,'炮口前有东西') end
    local far=enemy and dist>(st.range or math.huge) and ('超出 '..math.floor(st.range+.5)..' 米 · 伤害衰减') or ''
    if st.windup then
        if w.windup>0 then return State('蓄力','ok',w.windup,far) end
        if ready<1 then return State('充能','busy',ready,far~='' and far or (math.floor(ready*100+.5)..'%')) end
        return State('就绪','ok',1,far~='' and far or '按住左键蓄力开火')
    end
    if st.spinUp then
        if ready<1 and firing then return State('预热','busy',ready,far) end
        return State('就绪','ok',1,far)
    end
    return State(ready<1 and '冷却' or '就绪',ready<1 and 'busy' or 'ok',ready,far)
end
function M.Chips(layout,groups,current,story)
    local result={};local k=layout.k;local y=layout.cy+(story and -70 or 84)*k
    for i,g in ipairs(groups) do
        local selected=i==current;local w,h=story and 220 or selected and 236 or 150,story and 54 or selected and 56 or 38
        result[i]={x=layout.cx+layout.radius+(story and 56 or 34)*k+(i-1)%2*(story and 20 or 18)*k,y=y,w=w*k,h=h*k,selected=selected,special=not story and not selected and g.kind=='missile'}
        y=y+(story and 70 or h+(selected and 14 or 6))*k
    end
    return result
end
function M.Update(widget,dt)
    local s=widget.session;local w=s.weapons;local me=s.combat and s.combat.player
    widget.clock=(widget.clock or 0)+dt
    widget.hp=me and me:Health() or 1;widget.integrity=me and me:Integrity() or 1
    if widget.hp<(widget.lastHp or 1)-.002 then widget.hurtUntil=widget.clock+.12 end
    widget.lastHp=widget.hp
    widget.structure=me and me.structure and me.structMax>0 and Clamp(me.struct/me.structMax) or widget.integrity
    local feedback=s.hud and s.hud.overlay.feedback
    widget.repair=feedback and feedback.time-feedback.healAt<.4 and not feedback.full or false
    if feedback and feedback.repairFull and feedback.repairAge<.6 then widget.doneUntil=widget.clock+.01 end
    if widget.wasRepair and not widget.repair and widget.hp>=.995 then widget.doneUntil=widget.clock+.45 end
    widget.wasRepair=widget.repair
    local lock=w:LockInfo();widget.lock=lock
    local aim=s.aimPoint;local p=s.vehicle.body.translation()
    local dist=aim and math.sqrt((aim[1]+p.x)^2+(aim[2]-p.y)^2+(aim[3]-p.z)^2) or 0
    local owner=s.aimHit and s.aimHit.owner
    widget.fire=M.Fire(w,s.firing,widget.aimState,dist,owner and owner.ref and owner.ref.alive or false,lock)
    if widget.fire and widget.word~=widget.fire.word then widget.word=widget.fire.word;widget.wordAt=widget.clock end
    widget.chipStates=widget.chipStates or {}
    for _,g in ipairs(w.groups) do
        local out=g.output*10+#g.weapons;local state=widget.chipStates[g.kind] or {}
        if state.output and out<state.output-.01 then state.hurt=widget.clock+1.4
        elseif state.output and out>state.output+.01 then state.fix=widget.clock+1.2;state.hurt=0 end
        state.output=out;widget.chipStates[g.kind]=state
    end
end
return M

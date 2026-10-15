-- Frozen matchHud.kill: five entries, seven seconds, local-player highlight.
local D=require 'ui.SourceDraw'
local M={}
local weapons={mg='加特林',laser='激光',sniper='狙击',missile='飞弹'}
local function Now() return Time:GetSystemTime()/1000 end
function M.Push(owner,killer,victim,weapon,now)
    local rows=owner.killFeed or {};owner.killFeed=rows
    rows[#rows+1]={killer=killer,victim=victim,weapon=weapons[weapon] or '击毁',at=now or Now(),mine=killer and killer.me or victim.me}
    while #rows>5 do table.remove(rows,1) end
end
function M.Update(owner,now)
    now=now or Now()
    for i=#(owner.killFeed or {}),1,-1 do local row=owner.killFeed[i];row.age=now-row.at;if row.age>=7 then table.remove(owner.killFeed,i) end end
end
function M.Clear(owner) owner.killFeed={} end
function M.Draw(vg,owner,w)
    for i,row in ipairs(owner.killFeed or {}) do
        local age=row.age or 0;local t=math.min(1,age/.2);local ease=1-(1-t)^3
        local runs={}
        local function Name(unit) runs[#runs+1]={unit.name,14,unit.team=='blue' and {127,200,255,255} or {255,138,128,255},.5} end
        local function Em(text) runs[#runs+1]={text,11,{255,255,255,144},2} end
        if row.killer then Name(row.killer);Em('▸ '..row.weapon..' ▸');Name(row.victim) else Name(row.victim);Em('被击毁') end
        local width=24+(#runs-1)*8
        for _,run in ipairs(runs) do run.width=D.Width(vg,run[1],run[2],'vox-body',run[4]);width=width+run.width end
        local x=w-18-width+(1-ease)*20;local y=80+(i-1)*30
        nvgSave(vg);nvgGlobalAlpha(vg,ease)
        local c=row.mine and {255,106,19,80} or {11,13,17,208}
        D.Path(vg,{x,y,x+width*.18,y,x+width*.18,y+26,x,y+26});D.Gradient(vg,x,y,width*.18,26,{c[1],c[2],c[3],0},c,true)
        D.Rect(vg,x+width*.18,y,width*.82,26,c)
        if row.mine then D.Rect(vg,x+width-3,y,3,26,{255,106,19,255}) end
        local tx=x+12
        for _,run in ipairs(runs) do D.Text(vg,run[1],tx,y+(26-run[2])/2,run[2],run[3],'vox-body',nil,run[4],false,run[2]);tx=tx+run.width+8 end
        nvgRestore(vg)
    end
end
return M

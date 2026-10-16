local M={}
local Visibility=require 'render.NodeVisibility'
function M.Update(controller)
    local s=controller.session;local u=controller.player
    local changed=false;local removed=false;local spawned=false
    for _,event in ipairs(controller.world.viewEvents) do if event.unit==u then
        if event.type=='unitSpawn' then changed=true;spawned=true
        elseif event.type=='unitRebuilt' then changed=true
        elseif event.type=='unitKilled' or event.type=='unitRemoved' then removed=true end
    end end
    -- One batch can contain spawn, several restored parts, and a rebuild. Bind
    -- once to its final living body; never touch an already retired native body.
    if u.alive and u.vehicle and (changed or s.vehicle~=u.vehicle or s.weapons~=u.weapons) then
        s.vehicle=u.vehicle;s.weapons=u.weapons
        if spawned then s.view.view:Rebuild(u.bp,nil,true)
        else s.view.view:SyncBlueprint(u.bp) end
        s.view:Bind(u.bp,u.vehicle)
        Visibility.Set(s.view.view.root,true);s.aimHit=nil;s.aimRef=nil
        if s.hud then s.hud.meter.baseLayout=nil end
    elseif removed then Visibility.Set(s.view.view.root,false);s.firing=false end
end
return M

local M={}
function M.Update(controller)
    local s=controller.session;local u=controller.player
    for _,event in ipairs(controller.world.viewEvents) do if event.unit==u then
        if (event.type=='unitSpawn' or event.type=='unitRebuilt') and u.alive and u.vehicle then
            s.vehicle=u.vehicle;s.weapons=u.weapons;s.view.view:Rebuild(u.bp);s.view:Bind(u.bp,u.vehicle);s.view.view.root.enabled=true
            if s.hud then s.hud.meter.baseLayout=nil end
        elseif event.type=='unitKilled' then s.view.view.root.enabled=false end
    end end
end
return M

-- testDrive._hud: surviving player-hit parts get a depth-tested, non-pop shell.
local Shell=require 'render.RestoreFlash'
local M={};M.__index=M
local function Linear(v) v=v/255;return v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end
local WHITE={1,1,1}
local SHIELD={Linear(127),Linear(214),1}
function M.New(scene) return setmetatable({scene=scene,targets={}},M) end
function M:Consume(world,views)
    local player=world.feedbackPlayer
    for _,event in ipairs(world.viewEvents) do
        local unit=event.unit;local drive=unit and views[unit]
        if event.type=='unitDamaged' and unit~=player and (not event.source or event.source==player) and event.partId~=nil and drive then
            local part=unit.bp.parts[event.partId];local state=self.targets[unit]
            if part and world.time-(state and state.at or -9)>.08 then
                if not state then state={flash=Shell.New(self.scene,{poolSize=8,whiteBase=true})};self.targets[unit]=state end
                state.at=world.time;state.flash:Bind(drive.view)
                state.flash:Add(part,{color=event.shield and SHIELD or WHITE,pop=false})
            end
        end
    end
end
function M:Update(dt,views)
    for unit,state in pairs(self.targets) do
        local drive=views[unit];local flash=state.flash
        if not drive or drive.view~=flash.view or drive.view.visuals~=flash.generation then flash:Dispose();self.targets[unit]=nil
        else flash:Update(dt) end
    end
end
function M:Dispose()
    for _,state in pairs(self.targets) do state.flash:Dispose() end
    self.targets={};self.scene=nil
end
return M

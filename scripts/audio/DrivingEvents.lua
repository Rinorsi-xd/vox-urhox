-- Bridge actual old-controller contacts to the source's plant/launch/land cues.
-- It does not synthesize a walking timer or change the chassis physics.
local M={};M.__index=M
function M.New() return setmetatable({states=setmetatable({},{__mode='k'})},M) end
function M:Clear() self.states=setmetatable({},{__mode='k'}) end
function M:Observe(vehicle,dt,emit)
    local legs=vehicle.legControl;if not legs or #legs.list==0 then return end
    local state=self.states[vehicle]
    if not state then
        state={contacts={},air=0,fall=0};self.states[vehicle]=state
        for _,s in ipairs(legs.list) do state.contacts[s.leg.partId]=s.grounded end
        return
    end
    local supported=(vehicle.telemetry.legContacts or 0)>0
    local velocity=vehicle.body.linvel()
    if not supported then state.air=state.air+dt;state.fall=math.max(state.fall,-velocity.y) end
    if vehicle.telemetry.legJumped then emit('mech_push',1)
    elseif supported and state.air>.12 and state.fall>2 then emit('mech_land',math.max(.25,math.min(1,state.fall/10)))
    else for _,s in ipairs(legs.list) do
        if s.grounded and state.contacts[s.leg.partId]==false then emit('mech_step',math.min(1,.3+math.abs(vehicle.speed)/18)) end
    end end
    if supported then state.air=0;state.fall=0 end
    for _,s in ipairs(legs.list) do state.contacts[s.leg.partId]=s.grounded end
end
return M

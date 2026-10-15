-- Frozen damageMix.CollisionAudio: side contact plus horizontal delta-v.
--   floor: normal.y = 1 -> no cue; wall: abs(normal.y) < .6 -> eligible
-- Landing, braking without contact, triggers and rebuilt bodies stay silent.
local M={};M.__index=M
local function Detach(entry)
    if entry.body.isValid() then UnsubscribeFromEvent(entry.node,'NodeCollision') end
end
local function Contacts(entry,data)
    if data:GetBool('Trigger') then return end
    local contacts=data:GetBuffer('Contacts')
    while not contacts.eof do
        contacts:ReadVector3()
        local normal=contacts:ReadVector3()
        contacts:ReadFloat();contacts:ReadFloat()
        if math.abs(normal.y)<.6 then entry.side=true end
    end
end
function M.New() return setmetatable({entries={},last=setmetatable({},{__mode='k'}),generation=0},M) end
function M:BeforeStep(units,player)
    self.generation=self.generation+1
    local function Observe(unit)
        local vehicle=unit.vehicle
        if not vehicle or vehicle.disposed or not vehicle.body.isValid() then return end
        local entry=self.entries[unit]
        if entry and entry.body~=vehicle.body then Detach(entry);entry=nil end
        if not entry then
            entry={body=vehicle.body,node=vehicle.node}
            SubscribeToEvent(entry.node,'NodeCollision',function(_,data) Contacts(entry,data) end)
            self.entries[unit]=entry
        end
        entry.velocity=vehicle.body.linvel();entry.side=false;entry.generation=self.generation
    end
    for _,unit in ipairs(units) do Observe(unit) end
    if player then Observe(player) end
    for unit,entry in pairs(self.entries) do
        if entry.generation~=self.generation then Detach(entry);self.entries[unit]=nil end
    end
end
function M:AfterStep(time,events)
    for unit,entry in pairs(self.entries) do
        local vehicle=unit.vehicle
        if vehicle and vehicle.body==entry.body and entry.body.isValid() and time-(self.last[unit] or -math.huge)>=.25 then
            local v=vehicle.body.linvel();local dx,dz=v.x-entry.velocity.x,v.z-entry.velocity.z
            local delta=math.sqrt(dx*dx+dz*dz)
            if delta>=1.8 and entry.side then
                self.last[unit]=time;local p=vehicle.body.center()
                events[#events+1]={type='vehicleCollision',unit=unit,pos={p.x,p.y,p.z},strength=math.min(1,delta/7)}
            end
        end
    end
end
function M:Dispose()
    for _,entry in pairs(self.entries) do Detach(entry) end
    self.entries={};self.last=setmetatable({},{__mode='k'})
end
return M

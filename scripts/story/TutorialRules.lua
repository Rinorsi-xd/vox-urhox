-- Frozen tutorial routes and conditions, independent of input and rendering.
local M={};M.__index=M
function M.ValidRecord(r)
    return type(r)=='table' and (r.done==true or r.skipped==true or
        type(r.step)=='number' and r.step>=0 and r.step%1==0 and
        (r.path==nil or r.path=='intro' or r.path=='build' or r.path=='drive'))
end
function M.New(data,record,save)
    local self=setmetatable({},M);self:init(data,record,save);return self
end
function M:init(data,record,save)
    self.data=data;self.byId={};for _,s in ipairs(data.steps) do self.byId[s.id]=s end
    self.record=M.ValidRecord(record) and record or {};self.save=save
    self.running=false;self.replay=false;self.path='intro';self.flow=data.flows.intro;self.index=1
    self.elapsed=0;self.doneAt=false;self.revision=0;self.context={}
end
function M:Save() if not self.replay and self.save then self.save(self.record) end end
function M:StepSpec() return self.byId[self.flow[self.index]] end
function M:Go(index,state)
    if index>#self.flow then
        if not self.replay then self.record={done=true};self:Save() end
        self.running=false;self.replay=false;self.revision=self.revision+1;return
    end
    self.index=index;self.elapsed=0;self.doneAt=false;self.context={parts=state and state.parts or 0}
    if not self.replay then self.record={step=index-1,path=self.path~='intro' and self.path or nil};self:Save() end
    self.revision=self.revision+1
end
function M:Start(index,path,state)
    self.path=path or 'intro';self.flow=assert(self.data.flows[self.path]);self.running=true;self.replay=false
    self:Go(math.max(1,math.min(index or 1,#self.flow)),state)
end
function M:Resume(state)
    local r=self.record;if r.done or r.skipped or r.step==nil then return false end
    local flow=self.data.flows[r.path or 'intro'];local i=math.min(r.step+1,#flow)
    local s=self.byId[flow[i]]
    if s.resume then
        local found=false;for k,id in ipairs(flow) do if id==s.resume then i=k;found=true;break end end
        -- The build-first route omits "edit" after choosing. Return to its
        -- route choice when restarting outside, so "open bag" is reachable.
        if not found and s.resume=='edit' then i=4 end
    end
    self:Start(i,r.path,state);return true
end
function M:Replay(state)
    self.flow=self.data.flows.replay;self.replay=true;self.running=true;self:Go(1,state)
end
function M:Stop(skipped)
    if skipped and not self.replay then self.record.skipped=true;self:Save() end
    self.running=false;self.replay=false;self.revision=self.revision+1
end
function M:Condition(s,a)
    local id=s['until']
    if id=='choose' then return a.build and 'build' or a.tab=='battle' and 'drive' or false
    elseif id=='edit' then return a.build
    elseif id=='bag' then return a.inventory
    elseif id=='pick' then return not a.inventory
    elseif id=='place' then return a.parts~=self.context.parts
    elseif id=='save' then return a.saved
    elseif id=='back' then return not a.build and a.home
    elseif id=='battle' then return a.tab=='battle'
    elseif id=='story' then return a.tab=='story'
    elseif id=='go' then return a.drive and a.mission
    elseif id=='leave' then return a.tab~='story' end
    return false
end
function M:Tick(dt,state,busy)
    if not self.running then return end
    local s=self:StepSpec();self.elapsed=self.elapsed+math.max(0,dt)
    if busy then
        if s.observeHidden and not self.doneAt and self:Condition(s,state) then
            self.doneAt=self.elapsed
            if self.index==#self.flow then self:Go(self.index+1,state) end
        end
        return
    end
    if self.doneAt and self.elapsed-self.doneAt>.45 then self:Go(self.index+1,state);return end
    local got=not self.doneAt and self:Condition(s,state)
    if got then
        if s.choice then self.path=got;self.flow=self.data.flows[got] end
        self.doneAt=self.elapsed
    end
end
function M:Advance(state)
    if self.running and self:StepSpec().next=='button' then self:Go(self.index+1,state);return true end
    return false
end
return M

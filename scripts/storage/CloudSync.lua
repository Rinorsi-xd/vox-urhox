-- One writer per session. An ambiguous write stalls the queue: the SDK has
-- no cancellation/CAS, so advancing could let an old request overwrite new data.
local M={};M.__index=M
function M.New(options)
    local self=setmetatable({},M);self:init(options);return self
end
function M:init(o)
    self.options=o;self.state='idle';self.queue={};self.pending={};self.ack={}
    self.clock=0;self.nextWrite=0;self.window={};self.version=0;self.epoch=1
    self.active=false;self.reason='';self.onReady=false;self.notify=false
end
function M:IdentityMatches() return self.options.identity()==self.options.user end
function M:Block(reason)
    if self.state=='stopped' then return end
    if self.state=='blocked' and self.reason==reason then return end
    self.state='blocked';self.reason=reason;self.notify='blocked'
end
function M:Start(done)
    assert(self.state=='idle','Cloud sync already started')
    self.state='loading';self.onReady=done;self.deadline=self.clock+15
    local epoch=self.epoch
    local function Finish(records,reason)
        if self.epoch~=epoch or self.state~='loading' then return end
        if not self:IdentityMatches() then records=nil;reason='identity_changed' end
        self.state=records and 'ready' or 'blocked';self.reason=reason or ''
        self.onReady=false;done(records,reason)
    end
    local ok=pcall(self.options.transport.Read,self.options.transport,self.options.keys,{
        ok=function(values)
            if type(values)~='table' then Finish(nil,'invalid_response');return end
            local records={};local bytes=0
            for _,key in ipairs(self.options.keys) do
                local raw=values[key]
                if raw~=nil then
                    if type(raw)~='string' then Finish(nil,'invalid_record');return end
                    bytes=bytes+#raw
                    if bytes>16*1024*1024 then Finish(nil,'read_budget');return end
                    local decoded,record=pcall(self.options.decode,raw,key)
                    if not decoded or not record then Finish(nil,'invalid_record');return end
                    records[key]=record
                end
            end
            Finish(records)
        end,
        error=function() Finish(nil,'read_failed') end,
        timeout=function() Finish(nil,'read_timeout') end,
    })
    if not ok then Finish(nil,'read_failed') end
end
function M:Queue(key,text)
    if not self:IdentityMatches() then self:Block('identity_changed');return false end
    if self.state~='ready' and not (self.state=='blocked' and self.reason=='write_uncertain') then return false end
    if not self.options.allowed[key] or type(text)~='string' or #text>4*1024*1024 then self:Block('queue_rejected');return false end
    self.version=self.version+1
    if not self.pending[key] then self.queue[#self.queue+1]=key end
    self.pending[key]={text=text,version=self.version};self.notify=false;return true
end
function M:PendingCount()
    local n=self.active and 1 or 0;for _ in pairs(self.pending) do n=n+1 end;return n
end
function M:Update(dt)
    if self.state=='stopped' or self.state=='idle' then return end
    self.clock=self.clock+math.max(0,dt)
    if not self:IdentityMatches() then
        if self.state=='loading' then
            local done=self.onReady;self.onReady=false;self:Block('identity_changed');if done then done(nil,self.reason) end
        else self:Block('identity_changed') end
        return
    end
    if self.state=='loading' then
        if self.clock>=self.deadline then
            local done=self.onReady;self.onReady=false;self:Block('read_timeout');if done then done(nil,self.reason) end
        end
        return
    end
    if self.active then
        if self.clock>=self.active.deadline and self.state=='ready' then self:Block('write_uncertain') end
        return
    end
    if self.state~='ready' or self.clock<self.nextWrite or #self.queue==0 then return end
    local bytes=0
    for i=#self.window,1,-1 do
        if self.clock-self.window[i].time>=60 then table.remove(self.window,i) else bytes=bytes+self.window[i].bytes end
    end
    local key=self.queue[1];local item=self.pending[key]
    if bytes+#item.text>16*1024*1024 or #self.window>=60 then return end
    table.remove(self.queue,1);self.pending[key]=nil
    local request={key=key,item=item,deadline=self.clock+15,epoch=self.epoch}
    self.active=request;self.nextWrite=self.clock+1
    self.window[#self.window+1]={time=self.clock,bytes=#item.text}
    local function Current() return self.epoch==request.epoch and self.active==request and self:IdentityMatches() and self.state~='stopped' end
    local ok=pcall(self.options.transport.Write,self.options.transport,key,item.text,{
        ok=function()
            if not Current() then return end
            self.ack[key]=item.version;self.active=false
            if self.state=='blocked' and self.reason=='write_uncertain' then self.state='ready';self.reason='' end
            if self.state=='ready' and self:PendingCount()==0 then self.notify='saved' end
        end,
        error=function(code)
            if not Current() then return end
            if code==-429 and self.state=='ready' then
                self.active=false
                if not self.pending[key] then self.pending[key]=item;table.insert(self.queue,1,key) end
                self.nextWrite=self.clock+5
            else self:Block('write_uncertain') end
        end,
        timeout=function() if Current() then self:Block('write_uncertain') end end,
    })
    if not ok and Current() then self:Block('write_uncertain') end
end
function M:Stop()
    self.epoch=self.epoch+1;self.state='stopped';self.onReady=false;self.notify=false
end
return M

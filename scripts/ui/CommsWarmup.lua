-- Present the first actual speaker behind the loading cover, then retain its
-- targets and UI video handles for the normal CommsCard owner.
local Card=require 'ui.CommsCard'
local Portrait=require 'ui.CommsPortrait'
local Images=require 'urhox-libs/UI/Core/ImageCache'
local ResourceGate=require 'app.ResourceGate'
local M={};M.__index=M
local presentation={'width','height','glitch','nextGlitch','lastTime','face','ready','requested'}
local function Face(who,face) return (face or 'talk'):gsub('^'..who..'_','') end
function M.Dependencies(who,face)
    if who~='nono' and who~='huhu' then return {} end
    return {Portrait.Path(who,Face(who,face)),Portrait.Path(who,who=='huhu' and 'smug' or 'smile'),
        'Shaders/BLGL/UI/CommsPortrait.shader'}
end
function M.Begin(who,face)
    if who~='nono' and who~='huhu' then return nil,'Speaker has no GPU portrait: '..tostring(who) end
    local self=setmetatable({},M);self:init(who,face);return self
end
function M:init(who,face)
    self.who=who;self.face=Face(who,face);self.gate=ResourceGate.New()
    self.expected=Card.GetPortrait(who);self.frames=0;self.ready=false;self.retained=false
    self.created=false;self.disposed=false;self.downloaded=false
    self.failure=nil ---@type string?
    self.portrait=nil ---@type CommsPortrait?
    self.context=nil ---@type NVGContextWrapper?
    self.borrowedState=nil ---@type table?
    self.drawnFrame=nil ---@type integer?
    self.presentedFrame=nil ---@type integer?
    local ok,message=pcall(self.gate.Start,self.gate,M.Dependencies(who,self.face),function(loaded,errorMessage)
        if self.disposed then return end
        self.downloaded=loaded
        if not loaded then self.failure=tostring(errorMessage or 'Portrait download failed') end
    end)
    if not ok then self.failure=tostring(message) end
end
function M:RestoreBorrowed()
    local portrait,state=self.portrait,self.borrowedState
    if portrait and state and not portrait.disposed then
        for _,key in ipairs(presentation) do portrait[key]=state[key] end
    end
    self.borrowedState=nil
end
function M:Abort(message)
    self.failure=tostring(message);self:Dispose();return false,self.failure
end
function M:ValidOwner()
    return Card.GetPortrait(self.who)==self.expected and not (self.portrait and self.portrait.disposed)
end
function M:Draw(vg)
    if self.failure then return self:Abort(self.failure) end
    if self.disposed or self.ready then return self.ready end
    if not self:ValidOwner() then return self:Abort('Communications portrait owner changed during warmup') end
    if self.context and Images.GetContext()~=self.context then return self:Abort('Communications UI context changed during warmup') end
    if not self.downloaded or not vg or Images.GetContext()~=vg then return false end
    if self.drawnFrame==time.frameNumber then return false end
    if not self.portrait then
        if self.expected then
            self.portrait=self.expected;self.borrowedState={}
            for _,key in ipairs(presentation) do self.borrowedState[key]=self.portrait[key] end
        else
            local ok,portrait=pcall(Portrait.New,self.who)
            if not ok then return self:Abort(portrait) end
            self.portrait=portrait;self.created=true
        end
        self.context=vg
    end
    nvgSave(vg)
    local ok,message=pcall(function()
        local portrait=self.portrait
        if not portrait:Prepare(0,self.face,false) then error('Opening communications face unavailable: '..Portrait.Path(self.who,self.face)) end
        portrait:Queue();portrait:Draw(vg,{x=0,y=0,w=portrait.width,h=portrait.height})
    end)
    nvgRestore(vg)
    if not ok then return self:Abort(message) end
    self.drawnFrame=time.frameNumber
    return false
end
function M:Presented()
    if self.failure then return self:Abort(self.failure) end
    if self.disposed or self.ready then return self.ready end
    if not self:ValidOwner() then return self:Abort('Communications portrait owner changed during warmup') end
    if self.context and Images.GetContext()~=self.context then return self:Abort('Communications UI context changed during warmup') end
    if not self.drawnFrame or self.presentedFrame==self.drawnFrame then return false end
    self.presentedFrame=self.drawnFrame;self.frames=self.frames+1
    if self.frames<2 then return false end
    if not Card.RetainWarmPortrait(self.portrait,self.context,self.expected,self.face) then
        return self:Abort('Communications portrait handoff refused')
    end
    self.retained=true;self.ready=true;self:RestoreBorrowed()
    self.gate:Cancel()
    print('[CommsWarmup] Presented '..self.who..'/'..self.face..' frames='..self.frames..' borrowed='..tostring(not self.created))
    return true
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.gate:Cancel();self:RestoreBorrowed()
    if self.created and not self.retained and self.portrait then self.portrait:Dispose() end
    self.portrait=nil;self.expected=nil
end
return M

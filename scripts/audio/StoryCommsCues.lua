-- Shared communications feedback never downloads or decodes on a dialogue frame.
local ResourceGate=require("app.ResourceGate")

local Radio=require 'audio.StoryRadio'
local M={};M.__index=M
function M.Dependencies() return Radio.Dependencies() end
function M.New()
    local self=setmetatable({},M);self:init();return self
end
function M:init()
    self.disposed=false;self.preparing=false;self.radio=nil ---@type table|nil
    self.gate=ResourceGate.New()
    self.gate:Start(M.Dependencies(),function(ok,message)
        if self.disposed then return end
        -- Completion can hold the native download-manager lock.
        self.downloadReady=ok==true
        self.downloadError=not ok and tostring(message) or nil
    end)
end
function M:Ready()
    if self.disposed or not self.preparing then return end
    for _,cue in pairs(Radio.Data().cues) do if not cache:GetExistingResource('Sound',cue.path) then return end end
    self.preparing=false;self.radio=Radio.New()
end
function M:Play(name)
    -- Missed cues are discarded rather than played over a later speaker.
    if self.disposed or not self.radio then return false end
    return self.radio:Play(name)
end
function M:Update(dt,focus)
    if self.disposed then return end
    if self.downloadError then
        print('[StoryCommsCues] '..self.downloadError);self.downloadError=nil
    end
    if self.downloadReady then
        self.downloadReady=false;self.preparing=true
        for _,cue in pairs(Radio.Data().cues) do
            if not cache:GetExistingResource('Sound',cue.path) then cache:BackgroundLoadResource('Sound',cue.path,true) end
        end
    end
    self:Ready()
    if self.radio then self.radio:Update(dt,focus) end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.gate:Cancel()
    if self.radio then self.radio:Dispose();self.radio=nil end
end
return M

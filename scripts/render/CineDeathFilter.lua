-- Only the 2.8 s source death sequence owns this two-pass filter.
local SceneBackdrop=require("render.SceneBackdrop")

local Graph=require 'render.FilterGraph'
local UI=require 'urhox-libs/UI'
local Viewports=require 'render.WindowViewports'
local M={};M.__index=M
function M.New()
    local self=setmetatable({source=Viewports.Get(0)},M);self:Update(0);return self
end
function M:Update(amount)
    local w,h=UI.GetViewportSize();local pw,ph=graphics:GetWidth(),graphics:GetHeight()
    if not self.graph or self.w~=w or self.h~=h or self.pw~=pw or self.ph~=ph then
        local sw,sh=SceneBackdrop.Size(pw,ph,w,h)
        local graph=Graph.New({{viewport=self.source,width=sw,height=sh},{shader='Shaders/BLGL/Salvage/CineDeath.shader',inputs={source_map=1}}},sw,sh)
        local previous=self.graph;self.graph=graph;self.w=w;self.h=h;self.pw=pw;self.ph=ph
        Viewports.Set(0,graph.output);if previous then previous:Dispose() end
    end
    self.graph:Parameter(2,'amount',amount);self.graph:Queue()
end
function M:Dispose()
    if not self.graph then return end
    if Viewports.Get(0)==self.graph.output then Viewports.Set(0,self.source) end
    self.graph:Dispose();self.graph=nil;self.source=nil
end
return M

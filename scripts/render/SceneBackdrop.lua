-- Inventory owns a temporary, single-scene render chain. Filter distances are
-- CSS pixels; high-DPI displays do not allocate a full physical-resolution copy.
local Graph=require 'render.FilterGraph'
local UI=require 'urhox-libs/UI'
local M={};M.__index=M
local shader='Shaders/BLGL/UI/BackdropBlur.shader'
function M.Size(width,height,logicalW,logicalH)
    width,height=math.max(1,width),math.max(1,height)
    logicalW,logicalH=math.max(1,logicalW),math.max(1,logicalH)
    local scale=math.min(1,logicalW/width,logicalH/height,1920/width,1080/height)
    return math.max(1,math.floor(width*scale+.5)),math.max(1,math.floor(height*scale+.5))
end
function M.Specs(viewport,width,height,logicalW,logicalH)
    logicalW,logicalH=math.max(1,logicalW),math.max(1,logicalH)
    local w,h=M.Size(width,height,logicalW,logicalH)
    return {
        {viewport=viewport,width=w,height=h},
        {shader=shader,inputs={source_map=1},width=math.max(1,w//2),height=math.max(1,h//2),parameters={direction=Vector2(1/logicalW,0)}},
        {shader=shader,inputs={source_map=2},parameters={direction=Vector2(0,1/logicalH)}},
    },w,h
end
function M.New()
    local source=renderer:GetViewport(0)
    if not source then return nil end
    local self=setmetatable({source=source},M)
    local ok,err=pcall(self.Resize,self)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:Resize()
    local lw,lh=UI.GetViewportSize();local pw,ph=graphics:GetWidth(),graphics:GetHeight()
    if self.graph and self.lw==lw and self.lh==lh and self.pw==pw and self.ph==ph then return end
    local specs,w,h=M.Specs(self.source,pw,ph,lw,lh)
    local graph=Graph.New(specs,w,h);local previous=self.graph
    self.graph=graph;self.lw=lw;self.lh=lh;self.pw=pw;self.ph=ph
    renderer:SetViewport(0,graph.output)
    if previous then previous:Dispose() end
end
function M:Update()
    if self.disposed then return end
    -- Scene switches own the renderer. Never restore an obsolete hall viewport.
    if renderer:GetViewport(0)~=self.graph.output then self:Dispose();return end
    self:Resize();self.graph:Queue()
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.graph then
        if renderer:GetViewport(0)==self.graph.output then renderer:SetViewport(0,self.source) end
        self.graph:Dispose();self.graph=nil
    end
    self.source=nil
end
return M

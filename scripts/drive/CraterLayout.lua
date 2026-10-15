-- One logical layout; immutable bulk arrays arrive in bounded JSON pieces.
-- The world owns partial arrays before Fill can yield, so cancellation releases
-- them through normal world cleanup rather than leaving a suspended constructor.
local Data=require 'core.ResourceData'
local M={}
function M.Begin(namespace)
    local layout=Data.Read((namespace or 'Crater')..'/Layout.json');local manifest=assert(layout.dataParts)
    assert(manifest.version==1,'Unsupported crater layout version')
    layout.terrain.heights={};layout.blocks={};return layout
end
function M.Fill(layout,checkpoint)
    if layout.dataReady then return end
    local manifest=layout.dataParts
    for i,part in ipairs(manifest.parts) do
        local values=Data.Read(part.path)
        local target=part.field=='heights' and layout.terrain.heights or layout.blocks
        assert((part.field=='heights' or part.field=='blocks') and #target+1==part.first and #values==part.count,'Invalid crater layout piece '..part.path)
        table.move(values,1,#values,part.first,target)
        if checkpoint then checkpoint(i/#manifest.parts) end
    end
    assert(#layout.terrain.heights==manifest.heights and #layout.blocks==manifest.blocks,'Incomplete crater layout')
    layout.dataReady=true
end
function M.Read() local layout=M.Begin();M.Fill(layout);return layout end
return M

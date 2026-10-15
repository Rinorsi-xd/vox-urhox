-- Exact FNV-1a / Mulberry32 sequence used by shared/ai/driver.js.
local M={}
function M.New(seed)
    local s
    if type(seed)=='number' then s=math.floor(seed)&0xffffffff else
        s=2166136261
        for _,cp in utf8.codes(tostring(seed)) do s=((s~cp)*16777619)&0xffffffff end
    end
    return function()
        s=(s+0x6d2b79f5)&0xffffffff
        local t=((s~(s>>15))*(s|1))&0xffffffff
        t=t~((t+(((t~(t>>7))*(t|61))&0xffffffff))&0xffffffff)
        return ((t~(t>>14))&0xffffffff)/4294967296
    end
end
return M

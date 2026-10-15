-- Fast-math Runtime builds cannot safely detect NaN by comparing n with n.
local M={MAX_INTEGER=9007199254740991}
function M.NonNegative(n)
    if type(n)~='number' then return false end
    local bits=string.unpack('<I8',string.pack('<d',n))
    return bits & 0x7ff0000000000000 ~= 0x7ff0000000000000 and n>=0 and n<=M.MAX_INTEGER
end
function M.Count(n) return M.NonNegative(n) and n%1==0 end
function M.Generation(n) return M.Count(n) and n>=1 end
function M.Metadata(r)
    return type(r)=='table' and M.Count(r.v) and r.v==1 and M.Generation(r.generation)
        and (r.deleted==nil or r.deleted==true)
        and (r.time==nil or M.NonNegative(r.time))
        and (r.capture==nil or type(r.capture)=='table')
end
return M

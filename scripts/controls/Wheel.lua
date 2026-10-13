-- Web forwards signed CSS pixels; native SDL reports signed wheel notches.
local Platform=require 'urhox-libs.Platform.PlatformUtils'
local M={}
function M.Pixels(raw)
    return -raw*(Platform.IsWebPlatform() and 1 or 100)
end
function M.Zoom(distance,raw,min,max)
    return math.max(min,math.min(max,distance*1.0012^M.Pixels(raw)))
end
return M

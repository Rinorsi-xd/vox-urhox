-- NanoVG SetGlobalAlpha replaces the current value; opening groups compose here.
local M={}
local contexts=setmetatable({},{__mode='k'})
function M.Set(vg,alpha)
 local stack=contexts[vg]
 nvgGlobalAlpha(vg,(stack and stack[#stack] or 1)*alpha)
end
function M.Push(vg,alpha)
 local stack=contexts[vg]
 if not stack then stack={};contexts[vg]=stack end
 local parent=stack[#stack] or 1
 stack[#stack+1]=parent*alpha
 nvgSave(vg);nvgGlobalAlpha(vg,parent*alpha)
end
function M.Pop(vg)
 local stack=assert(contexts[vg],'Opening opacity group missing')
 assert(#stack>0,'Opening opacity group underflow')
 stack[#stack]=nil;nvgRestore(vg)
 if #stack==0 then contexts[vg]=nil end
end
function M.Exit(owner)
 if not owner.finishing then return 1 end
 local elapsed=owner.fadeOutElapsed
 if elapsed==nil then elapsed=owner.time-owner.fadeOutAt end
 return math.max(0,1-elapsed/owner.fadeOutDuration)
end
return M

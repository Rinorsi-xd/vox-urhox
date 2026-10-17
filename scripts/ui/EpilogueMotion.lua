-- CSS page retirement and WAAPI page shake use wall time, independent of narration.
local M={};M.__index=M
local Ease=require('ui.IntroComicMotion').Ease
function M.Now() return Time:GetSystemTime()/1000 end
function M.Approval(age)
    local elapsed=age-1.6
    return 2.4-1.4*Ease(elapsed/.22,.2,1.6,.4,1),.9*Ease(elapsed/.15,.25,.1,.25,1)
end
function M.OutroAlpha(age) return 1-Ease(age/.8,.25,.1,.25,1) end
function M.Panel(age)
    local eased=Ease(age/.32,.2,.9,.3,1.05)
    return eased,-4*(1-eased),math.max(0,math.min(1,eased))
end
function M.Impact(age,delay,rotation)
    local eased=Ease((age-delay)/.22,.2,.9,.3,1.3)
    return 2.4-1.4*eased,(rotation or -6)-12*(1-eased),math.max(0,math.min(1,eased))
end
function M.Character(age,height)
    return .02*height*(1-Ease(age/1.6,.2,.8,.2,1))
end
function M.New() return setmetatable({pages={},current=nil},M) end
function M:Add(entry,newPage,now)
    now=now or M.Now()
    if newPage or not self.current then
        if self.current then self.current.outAt=now end
        self.current={panels={},shakeStarts={}}
        self.pages[#self.pages+1]=self.current
    end
    self.current.panels[#self.current.panels+1]=entry
    local start=now+.26
    self.current.shakeStarts[#self.current.shakeStarts+1]=start
    return self.current.panels
end
function M:Update(now)
    now=now or M.Now()
    for i=#self.pages,1,-1 do
        local page=self.pages[i]
        for j=#page.shakeStarts,1,-1 do
            if now>=page.shakeStarts[j]+.26 then table.remove(page.shakeStarts,j) end
        end
        if page.outAt and now>=page.outAt+.5 then
            page.panels={};table.remove(self.pages,i)
        end
    end
end
function M.Alpha(page,now)
    if not page.outAt then return 1 end
    local t=math.min(1,math.max(0,(now-page.outAt)/.45))
    if t==0 or t==1 then return 1-t end
    -- CSS transition defaults to ease = cubic-bezier(.25,.1,.25,1).
    local lo,hi=0,1
    for _=1,16 do
        local u=(lo+hi)/2;local v=1-u
        if 3*v*v*u*.25+3*v*u*u*.25+u^3<t then lo=u else hi=u end
    end
    local u=(lo+hi)/2;local v=1-u
    return 1-(3*v*v*u*.1+3*v*u*u+u^3)
end
function M.Offset(page,height,now)
    local t=nil
    for i=#page.shakeStarts,1,-1 do
        local age=(now-page.shakeStarts[i])/.26
        if age>=0 and age<1 then t=age;break end
    end
    if not t then return 0,0 end
    -- Four equally spaced keyframes, default linear interpolation, no fill.
    local x,y
    if t<1/3 then local k=t*3;x=.6*k;y=-.4*k
    elseif t<2/3 then local k=t*3-1;x=.6-k;y=-.4+.7*k
    else local k=t*3-2;x=-.4*(1-k);y=.3*(1-k) end
    return x*height/100,y*height/100
end
function M:Dispose()
    for _,page in ipairs(self.pages) do page.panels={};page.shakeStarts={} end
    self.pages={};self.current=nil
end
return M

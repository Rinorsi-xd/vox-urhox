-- Frozen mvpShow.js timing, springs and camera keyframes (9086244).
local M={T={rise=2.1,pop=2.4,spiral0=2.55,spiral1=5.1,rod=4.9,unroll0=5.35,unroll1=6.9,title=6.3,settle=14}}
function M.Clamp(x) return math.max(0,math.min(1,x)) end
function M.Smooth(x) local u=M.Clamp(x);return u*u*(3-2*u) end
function M.InOut(x) local u=M.Clamp(x);return u<.5 and 4*u*u*u or 1-(-2*u+2)^3/2 end
function M.Back(x,s) local u=M.Clamp(x)-1;return 1+(s+1)*u^3+s*u*u end
function M.PodY(t,S,h)
    local y0=-S*.9-h-S*.3;local y1=S*.9
    if t<2.1 then return y0+(y1-y0)*M.InOut(t/2.1) end
    if t<2.55 then return y1 end
    return y1+S*2.2*M.InOut((t-2.55)/2.55)
end
function M.PodRot(t)
    return .35*math.sin(math.min(t,2.1)*.8)*(1-M.Clamp(t/2.1))+math.pi*2*1.25*M.InOut((t-2.55)/2.55)+math.max(0,t-5.7)*.22*M.Smooth((t-5.7)/1.5)
end
local keys={{0,.5,.2,7.2,0,.2,0},{2.1,1.2,.55,5.6,0,.45,0},{2.55,1,.7,5.4,0,.5,0},{5.1,-1.9,.25,5,0,.55,0},{6.9,-.6,.7,9,0,1.45,-1.2},{14,.6,.75,9.5,0,1.45,-1.2}}
function M.Camera(t,S,h)
    local i=1;while i<#keys-1 and t>keys[i+1][1] do i=i+1 end
    local a,b=keys[i],keys[i+1];local k=M.InOut((t-a[1])/(b[1]-a[1]))
    local function L(j) return (a[j]+(b[j]-a[j])*k)*S end
    local base=math.max(M.PodY(t,S,h),S*.45)
    return {-L(2),math.max(1.2,base+L(3)+h*.5),L(4)},{-L(5),base+L(6)+h*.4,L(7)}
end
function M.Spring(k,c) return {k=k,c=c,x=0,v=0} end
function M.Step(s,dt,f)
    local n=math.max(1,math.ceil(dt/.008));local h=dt/n
    for _=1,n do s.v=s.v+(-s.k*s.x-s.c*s.v+(f or 0))*h;s.x=s.x+s.v*h end
    return s.x
end
function M.Beat(time,beats)
    local lo,hi=1,#beats+1
    while lo<hi do local mid=math.floor((lo+hi)/2);if beats[mid][1]<=time then lo=mid+1 else hi=mid end end
    local pulse,bounce,lean,twist=0,0,0,0
    for i=lo-1,1,-1 do
        local age=time-beats[i][1];if age>2 then break end
        local strength,side=beats[i][2],(i-1)%2==0 and 1 or -1
        local fade=math.exp(-age*4.5)*M.Clamp((2-age)/.4)
        bounce=bounce-strength*math.sin(age*13)*fade;lean=lean+side*strength*math.sin(age*9)*fade
        twist=twist+side*strength*math.sin(age*12)*fade;pulse=pulse+strength*math.max(0,math.sin(age*12))*fade
    end
    return {index=lo-2,pulse=pulse,bounce=bounce,lean=lean,twist=twist}
end
function M.Score(st) return st.kills*300+(st.assists or 0)*120+st.damage*.02 end
function M.Winner(entries,stats)
    local best,score=false,-math.huge
    for _,e in ipairs(entries) do local n=M.Score(stats[e.unit]);if n>score then best=e;score=n end end
    return best
end
return M

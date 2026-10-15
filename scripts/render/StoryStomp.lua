-- Frozen effects.js stomp(): radial dust and loose chips use the existing limits.
local M={}
function M.Emit(fx,pos,k)
    local n=math.floor(5+10*k+.5);local size=.7+1.5*k
    for i=0,n-1 do
        local a=(i/n+math.random()*.15)*math.pi*2;local speed=(2.5+5*k)*(.6+math.random()*.6)
        local g=.36*(.85+math.random()*.3)
        local particle={pos={pos[1]+math.cos(a)*.6,pos[2]+.15,pos[3]+math.sin(a)*.6},
            vel={math.cos(a)*speed,.3+math.random()*1.2*k,math.sin(a)*speed},
            color={g,g*.95,g*.88},size=size*(.7+math.random()*.6),life=(.9+.8*k)*(.7+math.random()*.6),
            grow=size*1.6,drag=2.2,grav=0,age=0}
        if #fx.smoke<fx.maxSmoke then fx.smoke[#fx.smoke+1]=particle end
    end
    for _=1,math.floor(6*k+.5) do
        local a=math.random()*math.pi*2;local speed=2+math.random()*5
        fx.chips:Emit({pos[1],pos[2]+.2,pos[3]},{math.cos(a)*speed,3+math.random()*5*k,math.sin(a)*speed},
            .05+math.random()*.1,0x6d6458,.8+math.random()*.6)
    end
end
return M

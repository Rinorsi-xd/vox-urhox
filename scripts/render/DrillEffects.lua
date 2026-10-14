-- Frozen effects.js drill events, bounded by the shared particle/chip pools.
local V=require 'core.Math3'
local M={}
function M.Event(fx,e)
    local impact,grind=e.stage=='impact',e.stage=='grind'
    local color=e.easter and {6,1.2,3.5} or {8,3.5,.7}
    fx:Flash(e.pos,impact and 3.2 or grind and 1.1 or 1.7,impact and .14 or .09,e.easter and {1,.188,.521} or {1,.716,.296})
    fx:Burst(e.pos,impact and 150 or grind and 42 or 25,impact and 22 or 14,color,nil,impact and .10 or .055,impact and .75 or .4)
    if not impact and not grind then return end
    fx.light:Emit(e.pos,impact and 150 or 65,e.easter and 0xff65ab or 0xffc378)
    fx:Puff(e.pos,impact and 7 or 2,impact and .85 or .3,1.2,.3)
    local axis=e.dir;local side=V.Normalize(V.Cross(math.abs(axis[2])<.9 and {0,1,0} or {1,0,0},axis));local up=V.Cross(axis,side)
    for _=1,impact and 32 or 10 do
        local angle=math.random()*math.pi*2;local speed=9+math.random()*17
        local velocity=V.Add(V.Add(V.Scale(side,math.cos(angle)*speed),V.Scale(up,math.sin(angle)*speed)),V.Scale(axis,-3-math.random()*8))
        fx.chips:Emit(e.pos,velocity,.025+math.random()*.05,e.easter and 0xff8bbb or 0xffb74f,.45+math.random()*.45)
    end
end
return M

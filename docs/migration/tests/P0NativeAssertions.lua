-- Functional checks only; image readback is a separate visual check.
local stage='loading'
local damagedFrame
for tick=2,310 do
    local frame=tick
    V.atFrame(frame,function()
        if stage=='loading' and P0Failure then V.assert(false,P0Failure);stage='failed'
        elseif stage=='loading' and P0Ready then
            P0ValidateDamage();damagedFrame=frame;stage='damaged'
        elseif stage=='damaged' and frame>=damagedFrame+4 then
            V.assert(P0ValidateRepair()>15,'native cache, damage and repair checks completed');stage='done'
        end
    end)
end
V.atFrame(315,function() V.assert(stage=='done','resource gate and full native sequence completed');V.finish() end)

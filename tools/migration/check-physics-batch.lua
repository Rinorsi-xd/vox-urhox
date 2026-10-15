local finish=V.finish
V.finish=function()end
dofile('tools/migration/check-current-integration.lua')
dofile('tools/migration/check-drive-rebuild.lua')
dofile('tools/migration/check-camera-feedback.lua')
dofile('tools/migration/check-player-visibility.lua')
dofile('tools/migration/check-pointer-delay.lua')
dofile('tools/migration/check-view-slicing.lua')
dofile('tools/migration/check-damage-credit.lua')
V.atFrame(190,function()finish()end)

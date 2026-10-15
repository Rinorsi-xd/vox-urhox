local finish=V.finish
V.finish=function() end
dofile('tools/migration/check-migration-integration.lua')
dofile('tools/migration/check-record-numbers.lua')
dofile('tools/migration/check-story-enemy.lua')
dofile('tools/migration/check-story-marker.lua')
dofile('tools/migration/check-garage-create.lua')
dofile('tools/migration/check-combat-ability.lua')
V.atFrame(45,function() finish() end)

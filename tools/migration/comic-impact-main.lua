-- Isolated QA entry based on scaffold-2d: no game/bootstrap/scene/audio imports.
if not rawget(_G,'_tr') then require('urhox-libs/Engine/i18n') end
local UI=require 'urhox-libs/UI'
function Start()
 UI.Init({theme='default-dark',scale=UI.Scale.DEFAULT,
  fonts={{family='sans',weights={normal='Fonts/VoxIndustrial-Bold.otf',bold='Fonts/VoxIndustrial-Bold.otf'}}}})
 COMIC_IMPACT_APP_STARTED=true
 print('[ComicImpactRaster] isolated UI main started')
end
function Stop()
 COMIC_IMPACT_APP_STARTED=false
 UI.Shutdown()
end

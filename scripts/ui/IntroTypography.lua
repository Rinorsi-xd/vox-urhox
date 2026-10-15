-- Frozen style.css GameFont, independent from the legacy SmileySans UI face.
local D=require 'ui.SourceDraw'
local M={face='vox-intro-game'}
local contexts=setmetatable({},{__mode='k'})
function M.Dependencies()return {'Intro/Fonts/Font.json','Intro/Fonts/GameFont.ttf'}end
function M.Begin(vg)
 D.Begin(vg);if contexts[vg] then return end
 local data=require('core.ResourceData').Read('Intro/Fonts/Font.json')
 assert(nvgCreateFont(vg,M.face,data.game)>=0,'Original opening GameFont unavailable')
 nvgAddFallbackFont(vg,M.face,'vox-title');nvgAddFallbackFont(vg,M.face,'vox-body')
 contexts[vg]={glyphs=data.glyphs}
end
function M.Warm(vg)
 M.Begin(vg);local context=contexts[vg];if context.warmed then return end
 D.Text(vg,context.glyphs,0,0,48,{255,255,255,255},M.face)
 context.warmed=true
end
return M

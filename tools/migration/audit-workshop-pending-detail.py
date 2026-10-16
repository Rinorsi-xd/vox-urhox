"""Reproduce the actual pending artwork/detail race without rendering or production edits."""
import hashlib
import json
from pathlib import Path
import runpy
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
environment = runpy.run_path(str(ROOT / 'tools/migration/verify-workshop-shop-offline.py'))
lua = environment['lua']
result = dict(lua.execute(r'''
package.loaded['ui.WorkshopCarousel']=nil
package.preload['ui.WorkshopCarousel']=nil
package.loaded['ui.Workshop']=nil
local jobs={}
package.preload['app.ResourceGate']=function() return {New=function()
 local gate={generation=0}
 function gate:Cancel() self.generation=self.generation+1 end
 function gate:Start(paths,callback)
  self:Cancel();local generation=self.generation
  jobs[#jobs+1]={path=paths[1],finish=function(ok) if self.generation==generation then callback(ok,'failed') end end}
 end
 return gate
end} end
package.preload['urhox-libs/UI/Core/ImageCache']=function() return {Release=function() end} end
local Workshop=require 'ui.Workshop'
local Carousel=require 'ui.WorkshopCarousel'
local shown
local owner={width=1920,height=1080,usedCount=1,revision=0,
 workshop={view='feature',selected='scorpion',group='all',sort='rec',elapsed=0},
 app={lobby='arena',HomeView=function() end},Track=function(widget) return widget end,
 workshopPreview={auto=true,Show=function(_,id) shown=id end,SetAuto=function() end,Reset=function() end}}
owner.CreateVehicle=function(id) owner.purchased=id end
Workshop.Create(owner);jobs[#jobs].finish(true)
Carousel.Select(owner,'fox');local late=jobs[#jobs]
assert(owner.workshop.pending=='fox' and owner.workshop.selected=='scorpion','real artwork transfer remains pending')
owner.WorkshopChange('detail','scorpion','feature')
assert(owner.workshop.view=='detail' and shown=='scorpion','actual Change mounts requested detail preview')
late.finish(true)
local page=Workshop.Create(owner)
page.purchaseButtons[1].props.onClick()
local mismatch=owner.workshop.selected~=shown or owner.purchased~=shown
return {result=mismatch and 'CONFIRMED_BUG' or 'NO_BUG',view=owner.workshop.view,
 selected=owner.workshop.selected,displayedDetails=page.item.id,preview=shown,purchased=owner.purchased,
 sourceContract='Frozen Workshop.heroI and detailId are independent; detail updates preview.show(bp). A feature artwork completion must not mutate the detail or purchase identity.',
 reproduction='Mount scorpion feature; Select fox with deferred ResourceGate; actual WorkshopChange(detail,scorpion,feature); finish fox resource callback; actual Workshop.Create and purchase click.',
 boundary='Actual Lua Workshop.Create/Change and WorkshopCarousel with existing widget/paint/shop doubles and a cancellable ResourceGate completion double; no GPU or browser.'}
'''))
result['production'] = {file: hashlib.sha256((ROOT / file).read_bytes()).hexdigest() for file in
                        ['scripts/ui/Workshop.lua', 'scripts/ui/WorkshopCarousel.lua']}
stamp = datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace(':', '-').replace('.', '-')
output = ROOT / f'docs/migration/evidence/workshop-pending-detail-audit-{stamp}.json'
output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))

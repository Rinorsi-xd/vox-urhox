"""Exercise actual Workshop pages across the real UI render traversal, without GPU."""
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
env = runpy.run_path(str(ROOT / 'tools/migration/verify-workshop-shop-offline.py'))
lua = env['lua']
ui_source = (ROOT / 'urhox-libs/UI/Core/UI.lua').read_text(encoding='utf-8')
start = ui_source.index('local function renderWidgetTree(widget, nvg)')
end = ui_source.index('--- Render a widget subtree', start)
lua.execute('''
local renderingFixed_=false
local function hasTransform() return false end
local function trySaveNVGState() return true end
local function restoreNVGState() end
''' + ui_source[start:end] + '\nRenderWorkshopTree=renderWidgetTree')
lua.execute(r'''
local UI=require 'urhox-libs/UI'
function UI.Panel:GetRenderChildren() return self.lifecycleChildren or {} end
package.loaded['ui.WorkshopCarousel']=nil;package.preload['ui.WorkshopCarousel']=nil
package.loaded['app.ResourceGate']=nil
JOBS={}
package.preload['app.ResourceGate']=function() return {New=function()
 local gate={generation=0}
 function gate:Cancel() self.generation=self.generation+1 end
 function gate:Start(paths,done)
  self:Cancel();local generation=self.generation
  JOBS[#JOBS+1]={path=paths[1],finish=function(ok) if self.generation==generation then done(ok,'failed') end end}
 end
 return gate
end} end
package.preload['urhox-libs/UI/Core/ImageCache']=function() return {Release=function() end} end
package.preload['render.WorkshopPreview']=function() return {New=function()
 return {auto=true,Show=function(self,id) self.shown=id end,Dispose=function(self) self.disposed=true end,SetAuto=function() end,Reset=function() end}
end} end
IMAGES={}
require('ui.WorkshopPaint').Image=function(_,path,rect,zoom) IMAGES[#IMAGES+1]={path=path,zoom=zoom} end
function LifecycleOwner()
 local s={width=1920,height=1080,usedCount=1,revision=0,
  workshop={view='feature',selected='scorpion',group='all',sort='rec',elapsed=0},
  app={lobby='arena',HomeView=function() end},Track=function(w) return w end}
 s.CreateVehicle=function(id) s.purchased=id end;return s
end
function PrepareTree(page)
 page.renderProps_={}
 local child=require('urhox-libs/UI').Panel{}
 child.renderProps_={}
 function child:Render() CHILD_DRAWS=(CHILD_DRAWS or 0)+1 end
 page.lifecycleChildren={child}
 return page
end
function LoadWorkshop(text)
 package.loaded['ui.Workshop']=assert(load(text,'@scripts/ui/Workshop.lua'))()
 return package.loaded['ui.Workshop']
end
''')
old_path = ROOT / '.tmp/outgame-cached-1792083383263/scripts/ui/Workshop.lua'
old = old_path.read_text(encoding='utf-8')
assert hashlib.sha256(old_path.read_bytes()).hexdigest() == 'c791e839d20824ef4482b5976e3fd6308dd63baf1ea1bce15ba4fd40867df178'
lua.globals().WORKSHOP_TEXT = old
before = dict(lua.execute(r'''
local Workshop=LoadWorkshop(WORKSHOP_TEXT)
local s=LifecycleOwner();local page=PrepareTree(Workshop.Create(s));JOBS[#JOBS].finish(true)
RenderWorkshopTree(page,1)
s.WorkshopChange('detail','fox','feature')
local ok,err=pcall(RenderWorkshopTree,page,1)
return {result=ok and 'UNEXPECTED_PASS' or 'REPRODUCED',error=tostring(err)}
'''))
assert before['result'] == 'REPRODUCED' and 'WorkshopCarousel.lua:98' in before['error'], before
lua.globals().WORKSHOP_TEXT = (ROOT / 'scripts/ui/Workshop.lua').read_text(encoding='utf-8')
check_start = lua.globals().CHECKS
lua.execute(r'''
local Workshop=LoadWorkshop(WORKSHOP_TEXT)
local Carousel=require 'ui.WorkshopCarousel'
for _,destination in ipairs({'detail','browse','leave'}) do
 local s=LifecycleOwner();local page=PrepareTree(Workshop.Create(s));JOBS[#JOBS].finish(true)
 IMAGES={};CHILD_DRAWS=0;RenderWorkshopTree(page,1)
 Check(#IMAGES>0 and CHILD_DRAWS==1,'mounted feature and descendants render before '..destination)
 Check(IMAGES[1].zoom>1.12,'original Ken Burns starts at source zoom')
 local requests=#JOBS
 Carousel.Select(s,'fox');local late=JOBS[#JOBS]
 if destination=='leave' then Workshop.Leave(s)
 else s.WorkshopChange(destination,'fox','feature') end
 Check(not page:IsVisible() and s.workshopPage==nil,'departing tree synchronously retires before '..destination)
 Check(s.workshop.slides==nil and s.workshop.imageGate==nil,'released carousel does not remain resident')
 local draws=#IMAGES;local children=CHILD_DRAWS
 RenderWorkshopTree(page,1)
 Check(#IMAGES==draws and CHILD_DRAWS==children,'actual UI traversal skips old page and descendants after '..destination)
 Check(#JOBS==requests+1,'retired render starts no replacement download')
 late.finish(true)
 Check(s.workshop.pending==nil and s.workshop.slides==nil,'late completion cannot revive released carousel')
 if destination=='detail' then
  local detail=PrepareTree(Workshop.Create(s));Check(detail:IsVisible(),'new detail remains visible')
  Check(detail.item.id=='fox' and s.workshopPreview.shown=='fox','requested detail identity survives pending feature cancellation')
  detail.purchaseButtons[1].props.onClick();Check(s.purchased=='fox','detail purchase uses shown identity')
  s.WorkshopChange('feature');Check(not detail:IsVisible(),'detail tree retires on return')
 elseif destination=='browse' then
  local browse=PrepareTree(Workshop.Create(s));Check(browse:IsVisible(),'new browse remains visible')
  s.WorkshopChange('feature');Check(not browse:IsVisible(),'browse tree retires on return')
 end
 local returned=PrepareTree(Workshop.Create(s));JOBS[#JOBS].finish(true)
 Check(returned:IsVisible() and returned.item.id=='scorpion','return preserves independent hero after '..destination)
 IMAGES={};RenderWorkshopTree(returned,1);Check(#IMAGES>0,'carousel artwork renders again after '..destination)
 Carousel.Step(s,.1);Check(s.workshop.caption.elapsed>.0 and s.workshop.shelf.elapsed>.0,'caption and shelf animations retained')
end
local s=LifecycleOwner();Workshop.Create(s);JOBS[#JOBS].finish(true)
local nextPage=PrepareTree(Workshop.Create(s))
Check(s.workshopPage==nextPage and nextPage:IsVisible(),'normal same-view refresh stays visible')
Workshop.Leave(s);Workshop.Leave(s)
Check(not nextPage:IsVisible(),'external leave retires the most recent tree idempotently')
''')
report = {
    'result': 'PASS', 'checks': lua.globals().CHECKS - check_start,
    'before': before, 'baseline': env['oracle']['baseline'],
    'scripts': {file: hashlib.sha256((ROOT / file).read_bytes()).hexdigest() for file in
                ['scripts/ui/Workshop.lua', 'scripts/ui/WorkshopCarousel.lua']},
    'rendererSha256': hashlib.sha256(ui_source[start:end].encode()).hexdigest(),
    'boundary': 'Actual old/current Workshop and current Carousel execute through the unmodified engine renderWidgetTree function. Widget layouts, NVG drawing and cancellable resource completion use doubles. Covers same-frame departure rendering, descendant suppression, late callback cancellation, detail/purchase identity, reentry and retained animations. Web visual acceptance remains required.'
}
output = ROOT / 'docs/migration/evidence/workshop-lifecycle-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))

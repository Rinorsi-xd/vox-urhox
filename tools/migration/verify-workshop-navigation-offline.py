"""Compare actual frozen H5 detail/view and actual Lua page navigation."""
import hashlib
import json
from pathlib import Path
import runpy

ROOT=Path(__file__).resolve().parents[2]
env=runpy.run_path(str(ROOT/'tools/migration/verify-workshop-shop-offline.py'))
lua=env['lua'];before=lua.globals().CHECKS
lua.execute(r'''
package.loaded['ui.WorkshopCarousel']=nil;package.preload['ui.WorkshopCarousel']=nil
package.loaded['ui.Workshop']=nil
package.loaded['app.ResourceGate']=nil
package.preload['app.ResourceGate']=function() return {New=function()
 return {Cancel=function() end,Start=function(_,_,done) done(true) end}
end} end
package.preload['urhox-libs/UI/Core/ImageCache']=function() return {Release=function() end} end
local function Preview()
 return {auto=true,Show=function(self,id) self.shown=id end,Dispose=function(self) self.disposed=true end,SetAuto=function() end,Reset=function() end}
end
package.preload['render.WorkshopPreview']=function() return {New=Preview} end
local Workshop=require 'ui.Workshop'
local function Owner(hero)
 local s={width=1920,height=1080,usedCount=1,revision=0,
  workshop={view='feature',selected=hero,group='all',sort='rec',elapsed=0},
  app={lobby='arena',HomeView=function() end},Track=function(w) return w end}
 s.CreateVehicle=function(id) s.purchased=id end;return s
end
for _,expected in ipairs(ORACLE.featureReturn) do
 local s=Owner(expected.hero);Workshop.Create(s)
 if expected.from=='browse' then s.WorkshopChange('browse');Workshop.Create(s) end
 s.WorkshopChange('detail',expected.detail,expected.from)
 local page=Workshop.Create(s)
 Check(page.item.id==expected.detailId and s.workshopPreview.shown==expected.shown,'source detail identity '..expected.hero..'/'..expected.detail)
 page.purchaseButtons[1].props.onClick();Check(s.purchased==expected.detailId,'detail purchase remains independent of featured hero')
 PRESSED={[KEY_ESCAPE]=true};Workshop.Key(s);PRESSED={};Workshop.Create(s)
 if expected.from=='browse' then
  PRESSED={[KEY_ESCAPE]=true};Workshop.Key(s);PRESSED={}
 end
 page=Workshop.Create(s)
 Check(s.workshop.view=='feature' and page.item.id==expected.returnedHero,'source feature selection restored after '..expected.from..'/'..expected.detail)
 Check(s.workshop.slides[page.item.id]~=nil and s.workshop.imagesReady[page.item.id],'restored feature has its actual carousel image')
 page.purchaseButtons[1].props.onClick();Check(s.purchased==expected.returnedHero,'feature purchase identity matches restored picture')
end
local s=Owner('scorpion');Workshop.Create(s)
local Carousel=require 'ui.WorkshopCarousel';Carousel.Select(s,'fox')
Check(Workshop.Create(s).item.id=='fox','ready carousel selection survives page rebuild')
s.WorkshopChange('detail','miniScout','feature');Workshop.Create(s);Workshop.Leave(s)
local saved={};for _,key in ipairs({'view','selected','group','sort','from'}) do saved[key]=s.workshop[key] end
local returned=Owner('scorpion');returned.workshop=saved;Workshop.Create(returned)
returned.WorkshopChange('feature');local page=Workshop.Create(returned)
Check(page.item.id=='fox','existing GarageHud persisted keys preserve original hero across leaving detail tab')
local stale=Owner('miniScout');page=Workshop.Create(stale)
Check(page.item.id==Carousel.ids[1] and stale.workshop.slides[page.item.id]~=nil,'old invalid feature state recovers to a real featured vehicle')
''')
report={'result':'PASS','checks':lua.globals().CHECKS-before,'sourceCases':len(env['oracle']['featureReturn']),
 'baseline':env['oracle']['baseline'],'scripts':{'scripts/ui/Workshop.lua':hashlib.sha256((ROOT/'scripts/ui/Workshop.lua').read_bytes()).hexdigest()},
 'boundary':'Actual frozen Workshop.detail/view vs actual Lua Workshop.Create/Change/Key/Leave and actual Carousel. UI/render APIs and immediately ready resource downloads are substituted; not Web/native visual acceptance.'}
out=ROOT/'docs/migration/evidence/workshop-navigation-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))

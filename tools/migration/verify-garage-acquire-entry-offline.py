"""Exercise actual GarageHud.Create/s.CreateVehicle, not a purchase-module proxy."""
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
env = runpy.run_path(str(ROOT / 'tools/migration/verify-workshop-shop-offline.py'))
lua = env['lua']
before = lua.globals().CHECKS
lua.execute(r'''
local UI=require 'urhox-libs/UI';local Base=UI.Panel
function Base:SetVisible(v) self.props.visible=v end
function Base:SetOpen(v) self.open=v end
function Base:ClearChildren() self.children={} end
function Base:Destroy() self.node=nil end
local root
UI.SetRoot=function(v) root=v end;UI.GetRoot=function() return root end
UI.GetSafeAreaInsets=function() return {} end
local function Module(name,value) package.loaded[name]=value;package.preload[name]=function() return value end end
local noop=function() end
Module('controls.TouchMode',{Apply=noop})
Module('parts.Dependencies',{FromBlueprint=function() return {} end})
Module('ui.GarageLayout',{Apply=noop})
Module('ui.VoxTheme',{TrimThumbnails=noop,Thumbnail=function() return '' end})
Module('ui.HomeChrome',Base)
Module('ui.HomePages',{Create=function() return Base{} end})
Module('ui.BayPreviews',{New=function() return {Dispose=noop} end})
Module('ui.MusicBoxVisual',{Console=Base})
Module('ui.HomeNewMenu',{Create=function() return Base{} end})
Module('ui.MusicBox',{Close=noop})
Module('ui.LiveryPage',{Leave=noop})
Module('ui.StoryPage',{Leave=noop})
Module('ui.Workshop',{Leave=noop})
local salvageTabs={}
Module('ui.SalvagePage',{Leave=noop,Tab=function(s,tab) s.salvage=s.salvage or {};s.salvage.tab=tab;salvageTabs[#salvageTabs+1]=tab end})
local Host=require 'ui.DialogHost';Host.Dispose=noop
local opened=0;local originalOpen=Host.Open
Host.Open=function(...) opened=opened+1;return originalOpen(...) end
local Buy=require 'ui.SalvageBuy';local bought=0;local originalBuy=Buy.Car
Buy.Car=function(...) bought=bought+1;return originalBuy(...) end
local Hud=require 'ui.GarageHud'
local function App(lobby,fail)
 local app={lobby=lobby,homeTab=lobby=='salvage' and 'salvage' or 'workshop',
   vehicleGate={Cancel=noop},toasts={Push=noop,SetText=noop},previews={},music={},builds=0,calls=0,
   blueprint={ToTable=function() return {parts={}} end},salvageLobby={data={credits=10000},Usage=function() return {} end,Loose=function() return 0 end}}
 app.bays={FirstEmpty=function() return 1 end,CreateVehicle=function(_,id,_,discard) app.calls=app.calls+1;app.created=id;app.discard=discard;return not fail,'injected failure' end}
 function app:EnterBuild() self.builds=self.builds+1 end
 function app:HomeView(tab) self.homeView=tab end
 app.vehicleSwitch={CancelDownload=noop,Begin=function(_,fn,done) local ok,err=fn();done(ok,err);return true end}
 return app
end
local app=App('salvage');Hud.Create(app);local s=Hud.GetState();local oldOpened=opened
s.CreateVehicle('empty')
Check(app.created=='empty' and app.calls==1,'real salvage entry creates empty chassis once')
Check(opened==oldOpened and not s.dialog,'real free acquisition has no purchase dialog')
Check(s.tab=='salvage' and app.homeTab=='salvage' and app.homeView=='salvage' and s.salvage.tab=='garage','real salvage acquisition returns to salvage garage')
Check(app.builds==0 and app.salvageLobby.data.credits==10000,'free salvage acquisition neither enters build nor debits credits')
local arena=App('arena');Hud.Create(arena);s=Hud.GetState();s.CreateVehicle('empty')
Check(arena.created=='empty' and arena.calls==1 and arena.builds==1,'arena empty still creates and enters build')
Check(s.tab=='hangar' and arena.homeView=='hangar','arena empty preserves hangar navigation')
local full=App('salvage');Hud.Create(full);s=Hud.GetState();local previous=bought;oldOpened=opened
s.CreateVehicle('rat')
Check(bought==previous+1 and opened==oldOpened+1 and s.dialog~=nil,'nonempty actual entry still delegates to real SalvageBuy.Car confirmation')
Check(full.calls==0 and full.builds==0 and full.salvageLobby.data.credits==10000,'confirmation does not create or debit before decision')
local failed=App('salvage',true);Hud.Create(failed);s=Hud.GetState();s.CreateVehicle('empty')
Check(failed.calls==1 and failed.builds==0 and s.salvage==nil,'failed free creation never triggers garage success navigation')
Hud.Dispose()
''')
files = ['scripts/ui/GarageHud.lua']
report = {'result': 'PASS', 'checks': lua.globals().CHECKS-before,
          'baseline': env['oracle']['baseline'],
          'scripts': {f: hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in files},
          'boundary': 'Actual GarageHud.Create and installed s.CreateVehicle/s.Run/SetTab callbacks, actual SalvageBuy.Car on nonempty. Widget/engine and vehicle-switch/storage are substituted; not Web/native acceptance.'}
out = ROOT/'docs/migration/evidence/garage-acquire-entry-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))

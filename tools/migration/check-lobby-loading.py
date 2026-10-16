"""Exercise actual lobby preparation and overlay gates with controlled engine I/O."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

FIXTURE = r'''
package.path=project..'/scripts/?.lua;'..package.path
local count=0
local function check(value,label) assert(value,label);count=count+1 end
Time={GetSystemTime=function() return 1000 end}
local web=false
package.loaded['urhox-libs/UI']={}
package.loaded['ui.LoadingPage']={New=function() return {Open=function() end,Close=function() end,Dispose=function() end} end}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function() return web end}
package.loaded['app.ResourceGate']={New=function() return {total=0,completed=0,Start=function(self,paths,done) done(true) end,Cancel=function() end} end}
package.loaded['urhox-libs/UI/Core/ImageCache']={Release=function() end}
package.loaded['parts.Dependencies']={FromBlueprint=function() return {} end}
package.loaded['ui.VoxTheme']={Thumbnail=function(id) return id end}
package.loaded['core.ResourceData']={Read=function() return {items={['part:cube']={part='cube'}}} end}
package.loaded['ui.GarageHud']={Refresh=function() end}
local switchCount=0
package.loaded['app.SalvageLobby']={VehicleData=function() return {parts={}} end,Switch=function(app,mode) switchCount=switchCount+1;app.lobby=mode;return true end}
local activation=0
package.loaded['scene.Warehouse']={New=function(app,options)
 check(options.deferActivation,'warehouse waits for actual light stage')
 return {cursor=1,Update=function(self) self.cursor=self.cursor+1;self.built=self.cursor>=4 end,
 Activate=function(self) activation=activation+1;self.ready=true end,Dispose=function(self) self.disposed=true end}
end}
package.loaded['render.SceneWarmup']={New=function() return {items={},skipped=0,batches=1,Rendered=function() return true end,Restore=function() end} end}
renderer={GetViewport=function() return nil end}
cache={GetResource=function() return {} end}
local Flow=require 'app.LoadingFlow';local Lobby=assert(load(LOBBY_SOURCE,'@app/LobbyLoading.lua'))()
local function setup()
 local app={mode='hangar',loader={state='ready'},vehicleSwitch={Finish=function() return true end},
  graphicsSettings={SetSceneVisible=function() end},camera={Apply=function() end,Step=function() end},bays={active=1,Slots=function() return {{parts={}}} end},
  blueprint={ToTable=function() return {parts={}} end},salvageLobby={Owned=function() return 1 end},
  previews={Request=function(self,data,done) self.done=done;return {} end,Cancel=function(self) self.cancelled=true end},
  toasts={Push=function() end},HomeView=function() end}
 app.loadingFlow=Flow.New(app);app.lobbyLoading=Lobby.New(app);return app,app.loadingFlow,app.lobbyLoading
end
local function present(flow) flow:PageRendered();flow:FramePresented() end
local app,flow,lobby=setup();local done=0
check(lobby:Begin(function() done=done+1 end),'public request accepted')
check(flow.map.id=='salvage-lobby' and #flow.steps==6 and flow.map.loadingColor[1]==122,'own source loading identity')
check(not lobby:Begin(),'reentrant request rejected')
lobby:Update(.1);check(switchCount==0,'no saved car work during cover')
flow:Advance(.55);flow:Advance(.59)
present(flow);lobby:Update(.1);check(switchCount==0,'one presented frame cannot start storage work')
present(flow);lobby:Update(.1);check(switchCount==1 and lobby.index==2,'save executes after real presentation')
for index=2,6 do
 check(lobby.index==index,'exact row order '..index)
 lobby:Update(.1);check(lobby.index==index,'next row cannot skip presentation '..index)
 present(flow);lobby:Update(.1);check(lobby.index==index,'row requires second presented frame '..index)
 present(flow)
 for _=1,10 do
  lobby:Update(.05)
  if index==6 and app.previews.done then app.previews.done({Dispose=function() end}) end
  if lobby.index~=index then break end
 end
 check(lobby.index==index+1,'real task completes row '..index)
end
check(activation==1 and done==1 and flow.finished and not lobby.active,'successful install publishes only once')
flow:Rendered();flow:Rendered();flow:Advance(.1);check(flow.phase=='ready','rendered frames gate ready')
flow:Advance(.45);flow:Advance(.55);flow:Advance(.59);check(not flow.active,'overlay closes normally')
for _,index in ipairs({1,2,4,6}) do
 app,flow,lobby=setup();lobby:Begin();flow:Advance(.55);flow:Advance(.59);present(flow);present(flow)
 if index>1 then lobby:Update(.1) end
 if index==6 then lobby.thumbnail={};app.previews.done=function() end end
 local before=switchCount;flow:Back();lobby:Update(.1)
 check(not lobby.active and flow.cancelled,'cancel retires task '..index)
 check(app.lobby~='salvage','cancel restores previous inventory namespace '..index)
 check(switchCount<=before+1,'cancel does not duplicate storage switch '..index)
 if index==6 then check(app.previews.cancelled,'cancel retires thumbnail observer') end
end
app,flow,lobby=setup();app.vehicleSwitch.Finish=function() return false end
check(not lobby:Begin() and not flow.active,'busy vehicle transaction cannot open page')
app,flow,lobby=setup();lobby:Begin();flow:Advance(.55);flow:Advance(.59);present(flow);present(flow)
package.loaded['app.SalvageLobby'].Switch=function() return false,'save failed' end
lobby:Update(.1);check(flow.failed and flow.error:find('save failed',1,true),'concrete save failure remains on loading page')
flow:Back();check(not lobby.active,'failure can return')

-- Real Web mask ownership, with enough drawables for multiple render batches.
package.loaded['app.SalvageLobby'].Switch=function(app,mode) switchCount=switchCount+1;app.lobby=mode;return true end
package.loaded['render.SceneWarmup']=nil
web=true
OUTSIDE=0
local function sceneFor()
 local models={};for i=1,12 do models[i]={viewMask=i%3+1,enabledEffective=true,worldBoundingBox={}}end
 return {models=models,GetComponents=function(self,kind) return kind=='StaticModel' and self.models or {} end}
end
local function openWeb()
 local a,f,l=setup();a.scene=sceneFor();a.previews.updates=0
 function a.previews:Update() self.updates=self.updates+1 end
 check(l:Begin(),'Web request starts');f:Advance(.55);f:Advance(.59);present(f);present(f)
 return a,f,l
end
local function tickWeb(a,f,l)
 present(f);present(f);l:Update(.05);a.previews:Update(.05)
end
local function reachWeb(a,f,l,target)
 for i=1,100 do
  if l.index==target then return end
  tickWeb(a,f,l);f:Rendered()
 end;error('Stage did not arrive: '..target)
end
for _,target in ipairs({1,2,3,4,5,6})do
 local a,f,l=openWeb();reachWeb(a,f,l,target)
 tickWeb(a,f,l)
 if target==5 then
  check(f.renderWarmup~=nil and f.keepSceneVisible,'Web shader stage creates actual warmup while preserving scene visibility')
  local hidden=0;for _,m in ipairs(a.scene.models)do if m.viewMask==0 then hidden=hidden+1 end end
  check(hidden>0,'Actual SceneWarmup hides batches outside current submission')
 elseif target==6 then check(l.thumbnail~=nil and a.previews.updates>0,'Actual thumbnail stage waits while app capture update remains available')end
 f:Back();l:Update(.05)
 check(not l.active and f.cancelled and not f.renderWarmup,'Reached stage cancel retires Web task and warmup '..target)
 for i,m in ipairs(a.scene.models)do check(m.viewMask==i%3+1,'Cancel restores exact drawable mask '..target..'/'..i)end
 check(a.lobby~='salvage','Reached stage cancel restores arena context '..target)
 if target==6 then
  check(a.previews.cancelled,'Actual reached thumbnail cancels pending observer')
  local disposed=false;a.previews.done({Dispose=function()disposed=true end})
  check(disposed and not l.active and not f.finished,'Late canceled thumbnail releases image without completing abandoned page')
 end
end
local a,f,l=openWeb();reachWeb(a,f,l,5);tickWeb(a,f,l)
check(f.renderWarmup~=nil,'Web successful path starts actual multi-batch warmup')
f:Rendered();check(f.renderWarmup~=nil,'First presented batch does not finish twelve drawables')
f:Rendered();check(f.renderWarmup==nil,'Second presented batch restores real masks')
reachWeb(a,f,l,6);tickWeb(a,f,l);local captured=a.previews.done
captured({Dispose=function()end});tickWeb(a,f,l)
check(f.finished and f.scenePrepared and not f.renderWarmup and not l.active,'Custom Finish does not recreate already completed Web warmup')
f:Rendered();f:Rendered();f:Advance(.1);check(f.phase=='ready','Web custom flow waits two post-install rendered frames')
f:Advance(.45);f:Advance(.55);f:Advance(.59);check(not f.active and a.lobby=='salvage','Successful Web close retains selected salvage context')
local selected=a.lobby;local warehouse=a.warehouse;l:Dispose()
check(a.lobby==selected and a.warehouse==warehouse,'Disposing finished controller cannot roll back transferred warehouse')
-- Deliver an abandoned thumbnail into a fresh generation of the same owner.
a,f,l=openWeb();reachWeb(a,f,l,6);tickWeb(a,f,l);local obsolete=a.previews.done
f:Back();f:Close();check(l:Begin(),'Same controller can begin a new page after cancellation')
f:Advance(.55);f:Advance(.59);present(f);present(f)
reachWeb(a,f,l,6);tickWeb(a,f,l)
check(l.thumbnailReady==false,'New generation waits for its own thumbnail')
local freed=false;obsolete({Dispose=function()freed=true end},'old failure')
check(freed and l.thumbnailReady==false,'Old thumbnail callback frees pixels without completing new generation')
a.previews.done({Dispose=function()end});tickWeb(a,f,l)
check(f.finished and not l.active,'Current thumbnail completes current generation normally')
-- Ordinary scene loading retains the original six phases and one preparation.
a,f=setup();a.scene=sceneFor();f:Open({id='ordinary'},function()end)
check(#f.steps==6 and f.steps[1].id=='download' and f.steps[6].id=='activate','Default phases remain original map loader phases')
f:Finish();local initial=f.renderWarmup
check(initial~=nil and f.scenePrepared,'Default Finish still prepares real scene warmup')
f:Fail('controlled failure');check(not f.renderWarmup and f.failed,'Default failure restores exact mask owner')
for i,m in ipairs(a.scene.models)do check(m.viewMask==i%3+1,'Default failure restores drawable '..i)end
f:Close();check(not f.active,'Default Close remains available after failure')
return count
'''


def execute(source):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().project = root.as_posix()
    runtime.globals().LOBBY_SOURCE = source
    runtime.globals().print = lambda *args: None
    return runtime.execute(FIXTURE)


source = (root / 'scripts/app/LobbyLoading.lua').read_text(encoding='utf-8')
checks = execute(source)
negative_controls = []
for label, before, after in [
    ('stale-generation', 'or self.generation~=generation', ''),
    ('finished-owner-retained', 'self.active=false;self.switched=false', 'self.active=false'),
    ('missing-visibility', 'flow.keepSceneVisible=true;', ''),
    ('cancel-no-mask-restore', 'flow.renderWarmup:Restore();flow.renderWarmup=nil', 'flow.renderWarmup=nil'),
]:
    assert before in source, label
    try:
        execute(source.replace(before, after))
    except Exception as error:
        negative_controls.append({'name': label, 'failure': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control passed: ' + label)

paths = ['scripts/app/LobbyLoading.lua', 'scripts/app/LoadingFlow.lua', 'scripts/app/HangarApp.lua', 'scripts/render/SceneWarmup.lua',
         'scripts/ui/GarageHud.lua', 'scripts/ui/LoadingPage.lua', 'scripts/scene/Warehouse.lua']
report = {'result': 'PASS', 'checks': checks,
          'negativeControls': negative_controls,
          'boundary': 'Actual Lua controller, LoadingFlow and SceneWarmup in non-Web and Web branches. Actual reached-stage cancellation, real mask batching/restoration, custom/default Finish and stale generation callbacks. Engine resources/warehouse/storage/preview capture are controlled; host preview Update order is reviewed separately. No GPU screenshots or load-time acceptance.',
          'productionHashes': {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths},
          'testInputs': {str(Path(__file__).relative_to(root)).replace('\\', '/'): hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}}
output = root / 'docs/migration/evidence/lobby-loading-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': checks}))

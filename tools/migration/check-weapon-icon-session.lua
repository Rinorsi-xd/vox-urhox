local UI=require 'urhox-libs/UI'
local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Trial=require 'app.TrialSession'
local session=nil;local scene=nil;local player=nil;local restoredId=nil
local function Check(ok,message) V.assert(ok,'Icon gate / RestoreFlash: '..message) end
local function Command() return {throttle=0,steer=0,aim={0,2,70}} end
V.atFrame(2,function()
    local Icons=require 'ui.WeaponIconResources'
    Check(#Icons.For(nil)==0 and #Icons.For({})==0,'empty equipment has no icon dependencies')
    Check(#Icons.For({{type='core'},{type='cube'},{type='wheel1'},{type='unknown'}})==0,'non-weapons and unknown types have no icon dependencies')
    local drill=Icons.For({{type='fuyuanDrill'},{type='tianyuanDrill'},{type='fuyuanDrill'}})
    Check(#drill==2 and drill[1]=='UI/WeaponIcons/tianyuanDrill.png' and drill[2]=='UI/WeaponIcons/Hurt/tianyuanDrill.png','both drill types map and deduplicate to original icon')
    Check(#Icons.For({{'mg3',0,0,0,0},{type='mg3'},{type='cube'}})==2,'serialized blueprint and weapon specs share deduplicated contract')
    local catalog=require('parts.Defs').LIST;local count=0
    for _,def in ipairs(catalog) do if def.weapon then
        count=count+1;local paths=Icons.For({{type=def.id}})
        Check(#paths==2 and cache:Exists(paths[1]) and cache:Exists(paths[2]),'all Catalog normal/Hurt files exist: '..def.id)
    end end
    Check(count==17,'all seventeen Catalog weapon types checked')
    local request=nil;local finish=nil;local loaded={};local ready=false
    local backend={Exists=function(_,path)return loaded[path]==true end,
        DownloadResources=function(_,paths,done) request=paths;finish=done;return 173 end,
        CancelDownloadGroup=function()end}
    local gate=require('app.ResourceGate').New(backend);gate:Start(Icons.For({{type='mg3'},{type='mg3'}}),function(ok)ready=ok end)
    Check(not ready and gate.state=='loading' and #request==2 and request[2]=='UI/WeaponIcons/Hurt/mg3.png','actual ResourceGate cold backend blocks and requests only equipped normal/Hurt paths')
    for _,path in ipairs(request) do loaded[path]=true end;finish(true,0)
    Check(ready and gate.state=='ready' and gate.completed==2,'actual ResourceGate completes icon preparation before activation')
    local fonts=require('ui.SourceFonts').Resolve()
    UI.Init({theme='default-dark',scale=UI.Scale.DEFAULT,fonts={{family='sans',weights={normal=fonts.body,bold=fonts.bold}}}})
    scene=Scene();scene:CreateComponent('Octree')
    local app={store={Read=function() return nil end},toasts={Push=function() end}}
    session=Trial.New(scene,Prefab.BuildRaceCar(BP.New()),app)
    player=session.practice.player
    Check(session.restoreFlash~=nil and #session.restoreFlash.items==0,'TrialSession owns one empty RestoreFlash at spawn')
    local parts=require('ui.WeaponIconResources').For(player.bp:List())
    local seen={};for _,path in ipairs(parts) do Check(not seen[path],'icon dependency list is deduplicated');seen[path]=true;Check(cache:Exists(path),'cold entry gate sees '..path) end
    Check(#parts>0,'actual starter blueprint has weapon icons')
end)
V.atFrame(4,function()
    local wheel=player.spec.wheels[1];Check(wheel~=nil,'actual starter vehicle has movement part')
    player:Destroy(wheel.partId);session:Tick(1/60,Command())
    Check(#session.restoreFlash.items==0,'lost movement part does not create restoration shell')
    local restored=player:RestoreMissing(1);restoredId=restored[1];session:Tick(1/60,Command())
    Check(#restored>0 and #session.restoreFlash.items==#restored,'actual TrialSession recovery creates one shell per restored part')
    Check(session.restoreFlash.view==session.view.view,'RestoreFlash is rebound to the final DriveView generation')
    session.view.view:Rebuild(player.bp);session.view:Bind(player.bp,player.vehicle);session:Tick(1/60,Command())
    Check(#session.restoreFlash.items==0 and session.view.view.visuals[restoredId]~=nil,'rebuild clears stale FX without touching current view')
    local wheel2=player.spec.wheels[1];player:Destroy(wheel2.partId);session:Tick(1/60,Command())
    player:RestoreMissing(1);session:Tick(1/60,Command())
    Check(#session.restoreFlash.items>0,'second real recovery can remain active during teardown')
    local view=session.view;view:Dispose();session.view=require('render.DriveView').New(scene,player.bp,player.vehicle)
    session.restoreFlash:Consume(player,session.view.view,{})
    Check(#session.restoreFlash.items==0 and session.restoreFlash.view==session.view.view,'whole DriveView replacement safely retires previous shell references')
    session.restoreFlash:Add(player.bp.parts[wheel2.partId]);session.restoreFlash:Update(.05)
    Check(#session.restoreFlash.items==1,'new view generation supports an active restoration shell')
end)
V.atFrame(6,function()
    local fx=session.restoreFlash;session:Dispose()
    Check(fx.disposed and session.restoreFlash==nil,'TrialSession disposes RestoreFlash before DriveView/world teardown')
    scene:Dispose();scene=nil;UI.Shutdown();V.finish()
end)
function Start() engine.maxInactiveFps=120 end

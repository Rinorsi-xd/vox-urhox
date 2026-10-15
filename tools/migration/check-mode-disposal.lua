local M={}
function M.Run()
    local count={};local function Resource(name,check)
        return {Dispose=function() if check then check() end;count[name]=(count[name] or 0)+1 end}
    end
    local native={kinematic=true};local scene={};local session={scene=scene};local world={units={}}
    local cine=setmetatable({run={},session=session,heldNative=native,wasKinematic=false,playing=true,blocking=true,
        shot={},approachShot={},view=Resource('cineView',function() V.assert(not native.kinematic,'cinematic releases held body before native view disposal') end)},require('salvage.Cinematics'))
    local unit=Resource('unit',function() V.assert(cine.disposed and not native.kinematic,'salvage releases cinematic hold before player vehicle disposal') end)
    local entry={unit=unit,env={world=world},driver={world=world}};local entries={entry};local encounter={units={entry},left={entry}}
    local director={entries=entries,encounters={encounter},run={},world=world}
    local run=setmetatable({cine=cine,audio=Resource('audio'),view=Resource('view'),fx=Resource('fx'),explosion=Resource('explosion'),
        player=unit,session=session,world=world,entries=entries,director=director,weighBody=native},require('salvage.Run'))
    run:Dispose();run:Dispose();cine:Dispose()
    V.assert(count.unit==1 and count.cineView==1 and count.audio==1 and count.view==1 and count.fx==1 and count.explosion==1,'salvage repeated disposal releases each native owner exactly once')
    V.assert(#entries==0 and #encounter.units==0 and not entry.env and not entry.driver and not entry.unit and not director.world and not director.run and #director.encounters==0,'salvage clears original director entries and encounter retaining chains')
    V.assert(not run.world and not run.session and not run.player and not run.director and not run.weighBody and not cine.view and not cine.run and not cine.session and not cine.shot,'disposed salvage controller and cinematics release scene and held body references')
    local damage=function() end;local eworld={RecordDamage=function() end};local leave=0
    local endless=setmetatable({world=eworld,session=session,player={},baseDamage=damage,shieldTarget={},specCache={},entries={{unit=unit,env={world=eworld}}},
        pending={{}},edit={Leave=function() leave=leave+1;V.assert(eworld.RecordDamage~=damage,'endless exits active editor before detaching combat world') end},view=Resource('endlessView'),audio=Resource('endlessAudio')},require('app.EndlessSession'))
    endless:Dispose();endless:Dispose()
    V.assert(leave==1 and eworld.RecordDamage==damage and count.endlessView==1 and count.endlessAudio==1,'endless disposal is idempotent and restores original world damage handler')
    V.assert(not endless.world and not endless.session and not endless.player and not endless.view and not endless.audio and not endless.baseDamage and not endless.shieldTarget and #endless.entries==0,'endless clears retaining closures while leaving unit ownership to world')
    local view=setmetatable({drops={{visual=Resource('drop')}},warnings={{}},geometry=Resource('geometry'),root=Resource('endlessRoot'),coinMaterial=Resource('coin')},require('endless.View'))
    view:Dispose();view:Dispose()
    V.assert(count.drop==1 and count.geometry==1 and count.endlessRoot==1 and count.coin==1 and not view.root and not view.geometry and not next(view.drops),'endless dropped-item native owners dispose once and detach')
    local salvageView=setmetatable({root=Resource('salvageRoot'),exits={{material=Resource('exitMaterial')}},crates={{}},run=run,data={world=world}},require('render.SalvageView'))
    salvageView:Dispose();salvageView:Dispose()
    V.assert(count.salvageRoot==1 and count.exitMaterial==1 and not salvageView.root and not salvageView.run and not salvageView.data,'salvage map view disposes once and detaches world data')
end
return M

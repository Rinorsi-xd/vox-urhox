package.path='scripts/?.lua;'..package.path
local checks={};local function Check(ok,name)assert(ok,name);checks[#checks+1]=name end
for _,name in ipairs(imports) do package.loaded[name]={} end
local Effects=require 'render.CombatEffects'
local Weapon=require 'render.WeaponEffects'
local Trial=require 'app.TrialSession'
local function Copy(t)local out={};for k,v in pairs(t)do out[k]=v end;return out end
for i,g in ipairs(golden.cases)do
    local visual,feedback={},{}
    local own={fx=g.events,projectiles=g.own}
    local fx=setmetatable({events=0,onEvent=function(e)feedback[#feedback+1]=e end,
        Shot=function(_,e)visual[#visual+1]=e end,Beam=function(_,e)visual[#visual+1]=e end},Effects)
    fx:SetFirstPerson(g.fp,own)
    -- Production callers supply a separate array for each actor, unlike H5's merged stepFx.
    for _,e in ipairs(g.events)do
        local events={e};if e.own then own.fx=events end
        local remote=not e.own;fx:Consume(events,remote)
    end
    Check(#visual==#g.visual,'source visual event count '..i)
    for j,e in ipairs(visual)do
        Check(e.type==g.visual[j].type,'source visual event order '..i..'/'..j)
        if e.from then for k=1,3 do Check(math.abs(e.from[k]-g.visual[j].from[k])<1e-10,'source beam start '..i..'/'..j..'/'..k)end end
    end
    Check(#feedback==#g.audio,'unfiltered feedback/audio event count '..i)
    Check(g.events[3].from[3]==4,'simulation beam event immutable '..i)
    local all={};for _,p in ipairs(g.own)do all[#all+1]=p end;for _,p in ipairs(g.remote)do all[#all+1]=p end
    local visible=fx:Projectiles(all)
    Check(#visible==#g.projectiles,'source projectile count '..i)
    for j,p in ipairs(visible)do
        Check(p.id==g.projectiles[j].id,'source projectile identity '..i..'/'..j)
        Check(math.abs(p.dist-g.projectiles[j].dist)<1e-10,'source projectile distance '..i..'/'..j)
    end
    Check(g.own[3].dist==12.01 and g.own[7].dist==6.01,'simulation projectile distance immutable '..i)
    Check(visible[#visible]==g.remote[#g.remote],'remote projectile reference preserved '..i)
    if not g.fp then Check(visible==all,'third person no copied list '..i)end
    local boss={type='shot',kind='sniper'};fx:Consume({boss})
    Check(visual[#visual]==boss,'unmarked boss/world effect remains remote '..i)
    local original={type='shot',kind='mg'};local ownFx={original};own.fx=ownFx
    local count=#visual;fx:Consume(ownFx)
    Check(#visual==count+(g.fp and 0 or 1),'trial nil remote local array identity '..i)
    fx:SetFirstPerson(false,own)
    Check(fx.ownWeapons==nil and fx:Projectiles(all)==all,'release clears ownership and restores projectiles '..i)
end
local sibling=setmetatable({batches={Glow={count=3,mesh={enabled=true}},Ribbon={count=0,mesh={enabled=false}}}},Weapon)
sibling:SetVisible(false);Check(not sibling.batches.Glow.mesh.enabled,'scope hides sibling batch')
sibling:SetVisible(true);Check(sibling.batches.Glow.mesh.enabled and not sibling.batches.Ribbon.mesh.enabled,'release restores populated batches only')
-- Full Update must not re-enable freshly rebuilt world-space batches during scope.
Vector3={RIGHT={},UP={},FORWARD={}}
local rotation=setmetatable({},{__mul=function()return{x=0,y=0,z=1}end})
graphics={GetHeight=function()return 1080 end}
local mockBatch={count=3,mesh={},Begin=function()end,Finish=function(b)b.mesh.enabled=true end}
local update=setmetatable({batches={Glow=mockBatch},view={visuals={}},visible=false},Weapon)
update:Update(1/60,{camera={worldPosition={x=0,y=0,z=0},worldRotation=rotation}})
Check(not mockBatch.mesh.enabled,'hidden sibling stays hidden after full update')
update:SetVisible(true);Check(mockBatch.mesh.enabled,'rebuilt sibling restores on release')
local group={weapons={{pivot={1,2,3}}}}
local weapon={Group=function()return group end,projectiles={}}
local fx=setmetatable({},Effects)
local trial=setmetatable({weapons=weapon,effects=fx,scope=true,firstPerson=false,
    endless={run={state='over'}},accumulator=0},Trial)
trial:Tick(0,{})
Check(fx.firstPerson and fx.ownWeapons==weapon,'current scope first tick')
trial.scope=false;trial.firstPerson=true;trial:Tick(0,{})
Check(not fx.firstPerson and fx.ownWeapons==nil,'current release first tick')
trial.scope=true;trial.combat={player={alive=false}};trial:Tick(0,{})
Check(not fx.firstPerson and fx.ownWeapons==nil,'dead player clears first person ownership')
trial.combat=nil;group.weapons[1]={muzzle={4,5,6}};local pivot=trial:ScopePivot()
Check(pivot==group.weapons[1].muzzle,'muzzle fallback matches camera')
group.weapons={};trial:Tick(0,{});Check(not fx.firstPerson,'destroyed scoped weapon restores ordinary effects')
local native={};native.__index=native
native.__add=function(a,b)return setmetatable({x=a.x+b.x,y=a.y+b.y,z=a.z+b.z},native)end
local function Vec(x,y,z)return setmetatable({x=x,y=y,z=z},native)end
package.loaded['core.Coord'].Vec=Vec
local function Node()
    return {enabled=true,position=Vec(0,0,0),rotation=rotation,
        GetChildren=function()return{}end,SetEnabledRecursive=function(n,on)n.enabled=on end}
end
package.loaded['controls.ChaseCamera'].Apply=function()end
package.loaded['ui.ReticleState'].ScopeFov=function()return 48 end
local weaponFx=setmetatable({batches={Glow={count=2,mesh={enabled=true}}}},Weapon)
local camera={fov=48};local cameraNode={worldPosition=Vec(0,0,0)}
local post=setmetatable({scope=true,weapons=weapon,effects=fx,frameDt=1/60,yaw=0,pitch=0,
    view={view={root=Node(),weaponEffects=weaponFx}},restoreFlash={root=Node()},
    chase={Pose=function()return{}end},camera={GetCamera=function()return camera end,GetNode=function()return cameraNode end},
    cameraFeedback={Flush=function()end,Apply=function()end,Discard=function()end},
    drillSpeed={Update=function()end,Clear=function()end},speedFov={Step=function()return 48 end},
    pointer={captured=true},vehicle={},drivingAudio={},fxContext={},CameraCenter=function()return{0,0,0}end},Trial)
weapon.drill={};group.weapons={{pivot={1,2,3}}}
post:PostUpdate(1/60)
Check(post.firstPerson and not post.view.view.root.enabled and not weaponFx.batches.Glow.mesh.enabled,'actual PostUpdate scope hides vehicle and sibling together')
post.scope=false;post:PostUpdate(1/60)
Check(not post.firstPerson and post.view.view.root.enabled and weaponFx.batches.Glow.mesh.enabled,'actual PostUpdate release restores vehicle and sibling together')
post.scope=true;post:PostUpdate(1/60);post.combat={player={alive=false},entries={}}
post:PostUpdate(1/60)
Check(not fx.firstPerson and not weaponFx.batches.Glow.mesh.enabled,'actual PostUpdate death removes cached ownership and sibling')
-- Exercise the full render consumer, with only the renderer sinks adapted.
local rendered={};package.loaded['render.CombatSourceFx'].Bolt=function(_,_,p)rendered[#rendered+1]=p end
local near={fx='bolt',dist=12};local far={fx='bolt',dist=18};local enemy={fx='missile',dist=1}
local missiles
local updating=setmetatable({time=0,chips={Update=function()end},batches={},light={Update=function()end},
    missiles={Update=function(_,_,p)missiles=p end},flares={},trails={},beams={},zaps={},rings={},flashes={},particles={},smoke={}},Effects)
updating:SetFirstPerson(true,{projectiles={near,far}})
updating:Update(1/60,{near,far,enemy},{worldPosition=Vec(0,0,0),worldRotation=rotation})
Check(#rendered==1 and rendered[1].dist==6,'actual Update filters near bolt and clips rendered tail')
Check(#missiles==2 and missiles[2]==enemy,'actual Update preserves remote missile before missile renderer')
local disposed=setmetatable({ownWeapons=weapon,firstPerson=true,batches={},root={Dispose=function()end},
    light={Dispose=function()end},chips={Dispose=function()end},missiles={Dispose=function()end},Clear=function()end},Effects)
disposed:Dispose();Check(disposed.ownWeapons==nil and not disposed.firstPerson,'dispose releases own weapon reference')
return checks

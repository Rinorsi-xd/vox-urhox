local app=nil ---@type HangarApp|nil
local work=nil ---@type thread|nil
local stage='boot'
local disposedRefs={} ---@type table
local function Rules()
    local data=require('core.ResourceData').Read('Story/Mission/Level5.json');local B=require 'story.BossRules'
    local file=File('tools/migration/source-boss-fixtures.json',FILE_READ);local fixtures=cjson.decode(file:ReadString());file:Dispose()
    for i,c in ipairs(fixtures.cases) do
        local test=B.New(data.boss,20000/95);test:Go(c.state);test.braceUntil=c.braceUntil
        for j,n in ipairs(test.nodes) do n.pos={j*20,0,0};n.broken=j<=(c.broken or 0) end
        local damage=test:Hit(c.point,c.damage,c.armor and {armor=c.armor}, {0,0,60});local expected=c.expected
        V.assert(math.abs(damage-expected.amount)<.001 and math.abs(test.hp-expected.hp)<.001 and test.state==expected.state,'original onHit golden fixture '..i)
        for j,n in ipairs(test.nodes) do V.assert(n.broken==expected.nodes[j].broken and math.abs(n.hp-expected.nodes[j].hp)<.001,'original node golden fixture '..i..'/'..j) end
    end
    local r=B.New(data.boss,100);V.assert(r.hpMax==14250,'source boss HP clamps full firepower to 150 DPS')
    for i,n in ipairs(r.nodes) do n.pos={i*20,0,0} end;r:Go('fight')
    local hp=r.hp;local dealt=r:Hit({0,0,50},1000,nil,{0,0,60});V.assert(math.abs(dealt-450)<.001 and r.hp==hp-450,'unbroken cockpit shield admits 45 percent body damage')
    dealt=r:Hit({0,0,50},1000,{armor=.6},{0,0,60});V.assert(math.abs(dealt-780)<.001,'sniper pierce independently bypasses remaining shield')
    local n=r.nodes[1];hp=r.hp;r:Hit(n.pos,n.hp,nil,{0,0,60});V.assert(n.broken and r.state=='kneel' and r.hp==hp,'node destruction permanently breaks leg without direct boss HP loss')
    dealt=r:Hit({0,0,60},100,nil,{0,0,60});V.assert(dealt==400,'kneeling cockpit receives authored fourfold damage')
    dealt=r:Hit({0,0,90},100,nil,{0,0,60});V.assert(dealt==300,'kneeling body receives authored threefold damage')
    dealt=r:Hit({0,0,60},1e6,nil,{0,0,60});V.assert(math.abs(r.kneelDealt-r.hpMax*.18)<.001 and r.state=='rise','one kneel has exact 18 percent cap and forces rise')
    r:Step(1.6,{pos={0,0,0}});V.assert(r.state=='fight' and r:Braced(),'rise sets 20-second protection window')
    local other=r.nodes[2];hp=other.hp;r:Hit(other.pos,100,nil,{0,0,60});V.assert(other.hp==hp,'braced nodes cannot be re-broken immediately')
    local spec=require('story.MissionData').levels[5];V.assert(spec.map=='enginePit' and #spec.steps==2 and spec.epilogue.version==6,'source Level5 remains original EnginePit, two objectives, version-six ending')
    local epi=require('story.EpilogueRules').New(spec.epilogue);epi:Step(.9,false);V.assert(epi.current.kind=='place','epilogue keeps original 900ms opening delay')
    epi:Step(2.4,false);epi:Step(.7,false);V.assert(epi.current.kind=='panel' and epi.current.panel.rect[3]==97,'first comic panel keeps source full-screen width')
end
local function Exercise(s)
    local m=s.story;local update=s.Update;s.Update=function() end;s.HasFocus=function() return true end
    local world=s.world;local points=world.layout.enginePit.points
    local roof=world.layout.enginePit.ceilings[1];V.assert(roof and world:UnderRoof(roof.center[1],roof.center[3],0),'original roof polygon classifies actual shelter')
    local ground=world:CastRay({points.floorCentre[1],60,points.floorCentre[3]},{0,-1,0},150,nil)
    V.assert(ground~=nil,'real EnginePit terrain supports downward collision ray')
    V.assert(s.map.id=='story5' and s.world.layout.enginePit and #s.world.layout.nav.edges>0,'real fifth mission uses imported EnginePit collision and roads')
    m.voice:Hide();m.rules:Go(2);m:Events();s.combatView:Consume(s.world);local b=m.boss
    V.assert(b and b.unit.alive and #b.unit.bp:List()>2000,'original 2227-part FOX assembly survives Blueprint/spec validation')
    local feet=b.unit.vehicle.mechControl or b.unit.vehicle.legControl
    print('[BossQA] physical mech feet='..(feet and #feet.list or 0))
    V.assert(feet and #feet.list==4,'actual boss has four native T5 mechanical feet')
    b.rules:Go('fight');b.flow.stage='fight';b.time=100
    local function Step(n)
        for i=1,n do m:Update(1/60);s:Tick(1/60,{throttle=0,steer=0,handbrake=true});s:PostUpdate(1/60);if i%12==0 then coroutine.yield() end end
    end
    Step(30);b:Nodes();local first=b.rules.nodes[1];local hp=b.rules.hp;local parts=b.unit.bp:Size()
    b:Hit(first.pos,first.hp);Step(6);V.assert(first.broken and b.rules.state=='kneel' and b.rules.hp==hp,'real foot node breaks and opens authored kneel window')
    b:Hit(b:Cockpit(),100);V.assert(b.rules.hp==hp-400 and b.unit.bp:Size()==parts,'cockpit boss damage leaves source vehicle parts intact')
    local retained=b.rules.hp;m.player.bodyHp=0;m.player.kill='Boss QA';m.player.dirty=true;m.player:Flush();Step(200)
    V.assert(m.player.alive and b.rules.hp<=retained and b.rules.nodes[1].broken,'checkpoint respawn preserves boss damage and permanent node state')
    b.rules:Phase(2);b:Events();Step(120);local drills=0;for _,e in ipairs(m.entries) do if e.tag=='drill' then drills=drills+1 end end
    V.assert(drills==3,'source second phase spawns three original drill blueprints')
    b:StartRaid();Step(60);V.assert(b.raid~=nil and #b.view.planes==3,'actual third-phase raid draws three imported bombers')
    b.rules.state='kneel';b.rules.kneelDealt=0;b.rules.hp=1;b:Hit(b:Cockpit(),1);Step(3)
    V.assert(b.flow.stage=='ending' and b.cinematic,'boss death switches to source cinematic ending')
    local at=b:Cockpit();local eye={at[1]+42,at[2]+10,at[3]+38};local camera=s.camera:GetCamera();camera.node.worldPosition=require('core.Coord').Vec(table.unpack(eye));camera.node:LookAt(require('core.Coord').Vec(table.unpack(at)),Vector3.UP)
    coroutine.yield();coroutine.yield();local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/boss-native.png');image:Dispose()
    b:Key(KEY_RETURN,1);Step(3);V.assert(b.done and not b.cinematic,'long Enter skips ending without blocking mission completion')
    local E=require 'ui.Epilogue';local ui=require 'urhox-libs/UI';local ep=E.Attach(s.scene,ui.GetRoot(),function() end);ep.rules:Next();ep.rules:Next();ep.rules:Next();ep:Update(.01,true)
    for i=1,50 do ep:Update(1/60,true);coroutine.yield() end
    V.assert(#ep.panels==1 and ep.rules.time>.8,'ending renders source first panel after full screen and panel fade-in')
    local picture=Image:new();graphics:TakeScreenShot(picture);picture:SavePNG('docs/migration/evidence/epilogue-native.png');picture:Dispose()
    ep:Key(KEY_ESCAPE);ep:Update(.81,true);V.assert(not ep.active,'epilogue Escape exits and releases shared dialogue ownership')
    disposedRefs={mission=m,boss=b,view=b.view,missionView=m.view}
    s.Update=update;app:Reload();stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then app=VOX_HANGAR.app;Rules();V.assert(app:EnterTrial('story5'),'production story5 entry starts source loading gate');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then work=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then local ok,err=coroutine.resume(work);if not ok then V.assert(false,debug.traceback(work,tostring(err)));stage='failed';V.finish();engine.maxFps=1000 end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active and not app.pendingAssetRelease then
        local m,b,v,mv=disposedRefs.mission,disposedRefs.boss,disposedRefs.view,disposedRefs.missionView
        V.assert(m.disposed and m.world==nil and m.session==nil and m.player==nil,'disposed Mission retains no world session or player ownership')
        V.assert(b.disposed and b.world==nil and b.session==nil and b.mission==nil and b.unit==nil,'disposed Boss releases unit override closure ownership')
        V.assert(v.disposed and v.boss==nil and v.root==nil and next(v.objects)==nil,'disposed BossView releases native and parent references')
        V.assert(mv.disposed and mv.onLand==nil and mv.root==nil,'disposed MissionView releases session capture callback and native root')
        m:Dispose();b:Dispose();v:Dispose();mv:Dispose();V.assert(true,'story ownership cleanup is idempotent after real scene return')
        disposedRefs={};stage='done';V.finish();engine.maxFps=1000
    end
end
for frame=40,1400 do V.atFrame(frame,Poll) end
V.atFrame(1405,function() V.assert(stage=='done','boss native complete lifecycle');V.finish() end)

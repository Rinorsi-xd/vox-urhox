-- Headless allocation/CPU benchmark. Not shipped; deleted after measurement.
local digest=0
function Digest(str) for i=1,#str do digest=(digest*31+str:byte(i))%4294967291 end end
local function Bench()
    math.randomseed(12345)
    local scene=Scene();scene:CreateComponent('Octree');scene:CreateComponent('PhysicsWorld')
    local World=require 'drive.TrackWorld';local CarUnit=require 'combat.CarUnit'
    local Arena=require 'combat.ArenaData';local RotorMotion=require 'drive.RotorMotion'
    local Vehicle=require 'drive.Vehicle';local VehicleRay=require 'combat.VehicleRay'
    local WeaponSystem=require 'combat.WeaponSystem';local Space=require 'physics.Space'
    print('[bench] init');local world=World.New(scene);print('[bench] world ready')
    for _,u in ipairs(world.units) do u:Dispose() end;world.units={}
    local keys={'blue:5:assault:0','blue:5:heavy:0','blue:5:hover:0','blue:5:sniper:0','red:5:assault:0','red:5:heavy:0','red:5:hover:0','red:5:sniper:0'}
    for i,k in ipairs(keys) do
        local a=(i-1)/#keys*math.pi*2
        local u=CarUnit.New(world,Arena.prefabs[k],{name=k,spawn={pos={math.cos(a)*30,0,math.sin(a)*30},yaw=a+math.pi},team=i<=4 and 'blue' or 'red',combat=true,autoRespawn=true,externalControl=true})
        world.units[#world.units+1]=u
    end
    print('[bench] units ready')
    -- per-module accounting (GC stopped during a step)
    local acc={}
    local function Wrap(mod,name,label)
        local f=mod[name];mod[name]=function(...)
            local k=collectgarbage('count');local t=os.clock()
            local a,b,c,d=f(...)
            local e=acc[label] or {kb=0,ms=0,n=0};acc[label]=e
            e.kb=e.kb+collectgarbage('count')-k;e.ms=e.ms+(os.clock()-t)*1000;e.n=e.n+1
            return a,b,c,d
        end
    end
    Wrap(Vehicle,'Step','Vehicle.Step');Wrap(VehicleRay,'Cast','VehicleRay.Cast');Wrap(Space,'Raycast','Space.Raycast')
    Wrap(WeaponSystem,'Step','Weapons.Step');Wrap(CarUnit,'Flush','CarUnit.Flush');Wrap(Space,'Step','Space.Step')
    Wrap(world,'CastRay','World.CastRay')
    local RS=require 'drive.RaySuspension';Wrap(RS,'Sample','Susp.Sample');Wrap(RS,'Apply','Susp.Apply')
    local CC=require 'drive.ContactControl';Wrap(CC,'Step','Contact.Step')
    local HC=require 'drive.HoverControl';Wrap(HC,'Step','Hover.Step');Wrap(HC,'Motion','Hover.Motion')
    local ST=require 'drive.ChassisStability';if ST.Step then Wrap(ST,'Step','Stability.Step') end
    local TC=require 'drive.ThrusterControl';Wrap(TC,'Step','Thrusters.Step')
    local WC=require 'drive.WingControl';Wrap(WC,'Step','Wing.Step')
    local LC=require 'drive.LegControl';Wrap(LC,'Step','Leg.Step')
    local LH=require 'drive.LegHitboxes';Wrap(LH,'Update','LegHit.Update')
    local MC=require 'drive.MechControl';Wrap(MC,'Step','Mech.Step')
    local MH=require 'drive.MechHitboxes';Wrap(MH,'Update','MechHit.Update')
    Wrap(RotorMotion,'Step','Rotor.Step');Wrap(Vehicle,'ApplyRotors','ApplyRotors');Wrap(Vehicle,'StepRotors','StepRotors')
    Wrap(WeaponSystem,'Aim','Weapons.Aim');Wrap(WeaponSystem,'Integrate','Weapons.Integrate');Wrap(WeaponSystem,'Fire','Weapons.Fire')
    local Missiles=require 'combat.MissileWeapons';Wrap(Missiles,'Lock','Missile.Lock');Wrap(Missiles,'Step','Missile.Step')
    local Drill=require 'combat.DrillAttack';if Drill.Step then Wrap(Drill,'Step','Drill.Step') end
    Wrap(world.debris,'CapturePoses','Debris.Capture');Wrap(world.metrics,'Step','Metrics.Step')
    local steps=tonumber(os.getenv and os.getenv('BENCH_STEPS') or '') or 300
    local totalKB,worst,totalMs=0,0,0
    local dt=1/60
    for step=1,steps do
        collectgarbage('stop');local k0=collectgarbage('count');local t0=os.clock()
        for i,u in ipairs(world.units) do if u.alive then
            local v=u.vehicle
            -- nearest enemy as target
            local best,bd=nil,math.huge;local p=u:Position()
            for _,o in ipairs(world.units) do if o.alive and o.team~=u.team then local q=o:Position();local d=(q[1]-p[1])^2+(q[3]-p[3])^2;if d<bd then bd=d;best=q end end end
            local aim=best and {best[1],best[2]+.8,best[3]} or {0,0,0}
            local cmd={throttle=.6,steer=math.sin(world.time*.7+i),handbrake=false,boost=false}
            v:StepRotors(aim,false,dt);RotorMotion.Weapons(v.rotors,u.weapons)
            v:Step(cmd,dt)
            local pp,vel=v.body.translation(),v.body.linvel()
            world.attacker=u
            u.weapons:Step(dt,{firing=best~=nil,aim=aim,pos={pp.x,pp.y,pp.z},quat=v.body.rotation(),vel={vel.x,vel.y,vel.z},body=v.body,team=u.team,live=true},world.env)
            world.attacker=nil
            u.weapons.fx={}
        end end
        world:Step(dt);world.viewEvents={};world.fx={};world.debris.events={}
        for _,u in ipairs(world.units) do if u.alive and u.vehicle then
            local b=u.vehicle.body;local t,r,l=b.translation(),b.rotation(),b.linvel()
            Digest(string.format('%.17g%.17g%.17g%.17g%.17g%.17g%.17g%.17g%.17g%.17g%.17g',t.x,t.y,t.z,r.x,r.y,r.z,r.w,l.x,l.y,l.z,u.bodyHp or 0))
        else Digest('dead') end end
        local ms=(os.clock()-t0)*1000;local kb=collectgarbage('count')-k0
        if step>60 then totalKB=totalKB+kb;totalMs=totalMs+ms;worst=math.max(worst,ms) end
        collectgarbage('restart');collectgarbage('step',0)
        if step%60==0 then local alive=0;for _,u in ipairs(world.units) do if u.alive then alive=alive+1 end end;print(string.format('[bench] step %d alive %d',step,alive)) end
    end
    local n=steps-60
    print(string.format('[bench] per step: %.1f KB alloc, %.2f ms avg, %.1f ms worst (stats incl. wrapper overhead)',totalKB/n,totalMs/n,worst))
    local rows={};for k,e in pairs(acc) do rows[#rows+1]={k,e} end;table.sort(rows,function(a,b) return a[2].kb>b[2].kb end)
    for _,r in ipairs(rows) do print(string.format('[bench] %-16s calls/step %6.1f  KB/step %7.1f  B/call %6.0f  ms/step %.3f',r[1],r[2].n/steps,r[2].kb/steps,r[2].kb*1024/math.max(1,r[2].n),r[2].ms/steps)) end
    Digest(string.format('%d %d %d %.17g',world.stats.shots,world.stats.hits,world.stats.kills,world.stats.damage))
    print('[bench] DIGEST '..digest)
    print(string.format('[bench] world stats shots=%d hits=%d kills=%d',world.stats.shots,world.stats.hits,world.stats.kills))
end
function Start()
    local ok,err=pcall(Bench)
    if not ok then log:Write(LOG_ERROR,'[bench] '..tostring(err)) end
    engine:Exit()
end

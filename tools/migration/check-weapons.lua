local Weapons=require "combat.WeaponSystem"
local Math=require "core.Math3"
local file=assert(io.open("tools/migration/source-weapon-fixtures.json","r"))
local fixtures=cjson.decode(file:read("*a"));file:close()
local fields={"id","cool","yaw","pitch","prevYaw","prevPitch","err","limited","spin","spinRate","spinAngle","charge","windup","barrel","shotAt","dryAt","rate","interval"}
local missileFields={'open','lock','lockIn','lockLost','mphase','readyAt','reloadT','reload','volley','volleyAt','fired','tubes','lofting','aimPitch'}
local projectileFields={'pos','vel','life','dist','bright','seed','age','path','end','aim','arrived','trail'}
local function Equal(actual,expected,path)
    if type(expected)=="number" then
        if type(actual)~="number" or math.abs(actual-expected)>1e-7*math.max(1,math.abs(expected)) then
            return false,path..": "..tostring(actual).." != "..tostring(expected)
        end
    elseif type(expected)=="table" then
        if type(actual)~="table" then return false,path..": missing table" end
        for k,v in pairs(expected) do local ok,why=Equal(actual[k],v,path.."."..tostring(k));if not ok then return false,why end end
        for k in pairs(actual) do if expected[k]==nil then return false,path..": unexpected "..tostring(k) end end
    elseif actual~=expected then return false,path..": "..tostring(actual).." != "..tostring(expected) end
    return true,path
end
V.atFrame(55,function()
    local Loadout=require "combat.WeaponLoadout"
    for _,case in ipairs(fixtures.mounts) do
        local actual=Loadout.Part(case.part);local expected=case.expected
        -- q and -q represent the same orientation; compare their basis vectors.
        for _,axis in ipairs({{1,0,0},{0,1,0},{0,0,1}}) do
            local ok,why=Equal(Math.Rotate(actual.quat,axis),Math.Rotate(expected.quat,axis),case.part.type.." rotation "..case.part.rot)
            V.assert(ok,why)
        end
        actual.quat=nil;expected.quat=nil
        local ok,why=Equal(actual,expected,case.part.type.." mount "..case.part.rot);V.assert(ok,why)
    end
    local BP=require "construction.Blueprint";local Prefab=require "construction.Prefab"
    for key,build in pairs({buildRaceCar=Prefab.BuildRaceCar,buildTank=Prefab.BuildTank}) do
        local actual=Loadout.Build(build(BP.New())).weapons
        local ok,why=Equal(actual,fixtures.prefabs[key],key.." complete loadout");V.assert(ok,why)
    end
    V.assert(not Loadout.Build(BP.New()).ok,"empty blueprint rejects loadout")
    for _,case in ipairs(fixtures.cases) do
        local seed=12345
        local ws=Weapons.New(case.spec,function() seed=(seed*1664525+1013904223)&0xffffffff;return seed/4294967296 end)
        if case.energy then ws.energy=case.energy end
        local hits,impulses,blasts={},{},{}
        local targets=case.targets or {}
        local body={applyImpulseAtPoint=function(impulse,point,wake) impulses[#impulses+1]={impulse=impulse,point=point,wake=wake} end}
        local env={stats={shots=0}}
        env.castRay=function(origin,dir,length,excluded)
            assert(excluded==body,"self exclusion lost")
            if not case.plane or case.plane==cjson.null or math.abs(dir[3])<1e-12 then return nil end
            local distance=(case.plane-origin[3])/dir[3]
            if distance<0 or distance>length then return nil end
            return {dist=distance,point=Math.Add(origin,Math.Scale(dir,distance)),normal={0,0,-1},owner={type="target"}}
        end
        env.hit=function(hit,damage,dir,impulse,pierce) hits[#hits+1]={damage=damage,dir=dir,impulse=impulse,pierce=pierce,dist=hit.dist} end
        env.lockables=function() local out={};for _,t in ipairs(targets) do if t.alive~=false then out[#out+1]=t end end;return out end
        env.explode=function(point,radius,damage,excluded) assert(excluded==body,'blast exclusion lost');blasts[#blasts+1]={point=point,radius=radius,damage=damage} end
        local frame,sampleIndex=0,1
        for _,segment in ipairs(case.segments) do
            if segment.select then ws:Select(segment.select) end
            if segment.targetPos then targets[1].pos={table.unpack(segment.targetPos)} end
            if segment.targetAlive~=nil then targets[1].alive=segment.targetAlive end
            if segment.replaceTarget then targets={segment.replaceTarget} end
            segment.state.body=body
            for _=1,segment.frames do
                if segment.velocity then for j=1,3 do targets[1].pos[j]=targets[1].pos[j]+segment.velocity[j]/60 end end
                hits={};impulses={};blasts={};ws:Step(1/60,segment.state,env);frame=frame+1
                local expected=case.samples[sampleIndex]
                if expected and expected.frame==frame then
                    local weapons,readiness,projectiles={},{},{}
                    for _,g in ipairs(ws.groups) do
                        readiness[#readiness+1]=ws:Readiness(g)
                        for _,w in ipairs(g.weapons) do
                            local v={};for _,key in ipairs(fields) do v[key]=w[key] end
                            if w.stats.homing then
                                for _,key in ipairs(missileFields) do v[key]=w[key] end
                                v.lockTarget=w.lockRef and w.lockRef.id;v.volleyTarget=w.volleyTarget and w.volleyTarget.id;v.plan=ws:VolleyPlan(w)
                            end
                            weapons[#weapons+1]=v
                        end
                    end
                    for _,p in ipairs(ws.projectiles) do local v={};for _,key in ipairs(projectileFields) do v[key]=p[key] end;v.target=p.target and p.target.id;projectiles[#projectiles+1]=v end
                    local lock=ws:LockInfo();if lock then lock.ref=lock.ref and lock.ref.id end
                    local actual={frame=frame,shots=env.stats.shots,energy=ws.energy,offline=ws.offline,sinceUse=ws.sinceUse,blocked=ws.blocked,turning=ws.turning,current=ws.current,weapons=weapons,fx=ws.fx,hits=hits,impulses=impulses,blasts=blasts,projectiles=projectiles,readiness=readiness,lockInfo=lock}
                    local ok,why=Equal(actual,expected,case.name.." frame "..frame)
                    V.assert(ok,why);sampleIndex=sampleIndex+1
                end
            end
        end
        V.assert(sampleIndex==#case.samples+1,case.name.." all source samples checked")
    end
    V.finish()
end)

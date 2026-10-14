local Weapons=require 'combat.WeaponSystem'
local Math=require 'core.Math3'
local f=assert(io.open('tools/migration/source-drill-fixtures.json','r'));local data=cjson.decode(f:read('*a'));f:close()
local fields={'cool','charge','windup','spinAngle','drillPhase','shotAt'}
local function Equal(a,e,path)
    if e==cjson.null then return a==nil or a==cjson.null,path..': expected nil' end
    if type(e)=='number' then return type(a)=='number' and math.abs(a-e)<1e-7*math.max(1,math.abs(e)),path..': '..tostring(a)..' != '..e end
    if type(e)=='table' then
        if type(a)~='table' then return false,path..': expected table' end
        for k,v in pairs(e) do local ok,why=Equal(a[k],v,path..'.'..tostring(k));if not ok then return ok,why end end
        for k in pairs(a) do if e[k]==nil then return false,path..': extra '..tostring(k) end end
        return true,path
    end
    return a==e,path..': '..tostring(a)..' != '..tostring(e)
end
V.atFrame(55,function()
    for _,case in ipairs(data.cases) do
        local ws=Weapons.New(case.spec);ws.energy=case.energy or 100
        local p,lv,av,q={x=0,y=0,z=0},{x=0,y=0,z=0},{x=0,y=0,z=0},{x=0,y=0,z=0,w=1}
        local kinematic,ccd=false,false;local count,frame,index=0,0,1
        local target={};local hits={}
        local body={translation=function() return p end,rotation=function() return q end,linvel=function() return lv end,angvel=function() return av end,
            mass=function() return case.mass or 100 end,isValid=function() return true end,bodyType=function() return kinematic end,isCcdEnabled=function() return ccd end,
            setTranslation=function(v) p={x=v.x,y=v.y,z=v.z} end,setRotation=function(v) q={x=v.x,y=v.y,z=v.z,w=v.w} end,
            setLinvel=function(v) lv={x=v.x,y=v.y,z=v.z} end,setAngvel=function(v) av={x=v.x,y=v.y,z=v.z} end,
            setBodyType=function(v) kinematic=v end,enableCcd=function(v) ccd=v end,resetForces=function() end,resetTorques=function() end,applyImpulseAtPoint=function() end}
        body.setNextKinematicTranslation=body.setTranslation;body.setNextKinematicRotation=body.setRotation
        body.applyImpulse=function(v) for _,k in ipairs({'x','y','z'}) do lv[k]=lv[k]+v[k]/body.mass() end end
        local env={stats={shots=0},castRay=function() return nil end}
        env.hit=function(h,damage,dir,impulse,pierce) hits[#hits+1]={damage=damage,point=h.point,dir=dir,impulse=impulse,pierce=pierce} end
        env.sweepDrill=function(tip,dir,dist,excluded,cutters)
            assert(excluded==body,'self exclusion lost');count=count+1
            if case.contact=='miss' or case.contact=='late' and count<73 or case.contact=='intermittent' and count%5<3 then return nil end
            return {dist=.12,point=Math.Add(tip,Math.Scale(dir,.12)),normal={0,0,-1},collider={translation=function() return {x=0,y=1,z=6} end},
                owner={type=case.contact=='wall' and 'obstacle' or case.contact=='debris' and 'debris' or 'car',ref=target}}
        end
        for _,seg in ipairs(case.segments) do
            if seg.select then ws:Select(seg.select) end;if seg.refit then ws:Refit(case.spec) end
            for _=1,seg.frames do
                hits={};ws:Step(1/60,{firing=seg.fire,live=seg.live,aim={0,1,100},pos={p.x,p.y,p.z},quat=q,vel={lv.x,lv.y,lv.z},body=body},env)
                if not kinematic then for _,k in ipairs({'x','y','z'}) do p[k]=p[k]+lv[k]/60 end end
                frame=frame+1;local expected=case.samples[index]
                if expected and expected.frame==frame then
                    local weapons,readiness={},{}
                    for _,g in ipairs(ws.groups) do readiness[#readiness+1]=ws:Readiness(g)
                        for _,w in ipairs(g.weapons) do local t={};for _,k in ipairs(fields) do t[k]=w[k] end;weapons[#weapons+1]=t end
                    end
                    local a=ws.drill.active
                    local actual={frame=frame,energy=ws.energy,offline=ws.offline,sinceUse=ws.sinceUse,current=ws.current,shots=env.stats.shots,p=p,lv=lv,av=av,q=q,kinematic=kinematic,ccd=ccd,
                        active=a and {phase=a.phase,charge=a.charge,elapsed=a.elapsed,cutTime=a.cutTime,cuts=a.cuts,speed=a.speed,engaged=a.engaged,grinding=a.grinding},
                        held=ws.drill.held and ws.drill.held.id,hint=ws.drill:Hint(),readiness=readiness,weapons=weapons,hits=hits,fx=ws.fx}
                    local ok,why=Equal(actual,expected,case.name..' frame '..frame);V.assert(ok,why);index=index+1
                end
            end
        end
        V.assert(index==#case.samples+1,case.name..' every H5 sample checked')
    end
    V.finish()
end)

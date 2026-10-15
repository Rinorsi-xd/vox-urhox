-- Full legacy/current controller replay. Source fixtures provide actual Rapier
-- casts and body samples; this process never opens an engine or browser.
package.path='scripts/?.lua;'..package.path
local V=require 'core.Math3'
package.loaded['Config']={CELL=LEG_CELL}
package.loaded['parts.PartAssets']={Get=function(kind)return assert(LEG_RIGS[kind],kind)end}
package.loaded['drive.TerrainObstacles']={SUPPORT_MASK=0xffff}
local assertions=0
local function Copy(value)
    if type(value)~='table' then return value end
    local out={};for k,v in pairs(value)do out[k]=Copy(v)end;return out
end
local function Compare(a,b,label,tolerance)
    assertions=assertions+1
    assert(type(a)==type(b),label..' type '..type(a)..'/'..type(b))
    if type(a)=='table' then
        for k,v in pairs(b)do Compare(a[k],v,label..'.'..tostring(k),tolerance)end
        if not tolerance then for k in pairs(a)do assert(b[k]~=nil,label..' unexpected '..tostring(k))end end
    elseif type(a)=='number' then
        assert(a==b or tolerance and math.abs(a-b)<=tolerance*math.max(1,math.abs(b)),label..' '..tostring(a)..'/'..tostring(b))
    else assert(a==b,label..' '..tostring(a)..'/'..tostring(b))end
end
local function Modules(root)
    local ik=assert(loadfile(root..'/scripts/parts/LegIK.lua'))();local count={solve=0}
    local solve=ik.Solve;ik.Solve=function(...)count.solve=count.solve+1;return solve(...)end
    package.loaded['parts.LegIK']=ik
    package.loaded['drive.LegGait']=assert(loadfile(root..'/scripts/drive/LegGait.lua'))()
    local legs=assert(loadfile(root..'/scripts/drive/LegControl.lua'))()
    return {ik=ik,legs=legs,count=count}
end
local old=Modules(LEG_BEFORE_ROOT);local new=Modules('.')
local function Snapshot(c)
    local out={legs={}}
    for k,v in pairs(c)do if k~='v'and k~='list'and k~='states'and k~='info'and k~='ikScope'and k~='ikCache'and type(v)~='function'then out[k]=Copy(v)end end
    for i,s in ipairs(c.list)do
        local row={legId=s.leg.partId,neighbours={}}
        for k,v in pairs(s)do if k~='leg'and k~='nb'then row[k]=Copy(v)end end
        for j,n in ipairs(s.nb)do row.neighbours[j]=n.leg.partId end
        out.legs[i]=row
    end
    return out
end
local function Replay(mod,case)
    local env={state={},forces={},rays={},rayIndex=0,velocities={},velocityIndex=0}
    local v={spec=Copy(case.spec),com=Copy(case.com),mass=case.mass,inertiaY=case.inertiaY,capabilities=Copy(case.capabilities),legMode=case.legMode}
    v.body={rotation=function()return env.state.q end,translation=function()return env.state.p end,
        linvel=function()return env.state.lv end,angvel=function()return env.state.av end,center=function()return env.state.com end,
        velocityAtPoint=function(p)
            env.velocityIndex=env.velocityIndex+1;local row=assert(env.velocities[env.velocityIndex],'extra velocity sample')
            Compare(p,row.p,'source velocity point',2e-5);return Copy(row.result)
        end}
    for _,method in ipairs({'addForce','addForceAtPoint','addTorque','applyImpulse'})do v.body[method]=function(a,b)
        env.forces[#env.forces+1]={method=method,args=method=='addForceAtPoint'and{Copy(a),Copy(b)}or{Copy(a)}}
        if method=='applyImpulse'then env.state.lv=Copy(env.afterImpulse.lv);env.state.av=Copy(env.afterImpulse.av)end
    end end
    local c=mod.legs.New(v)
    c.Cast=function(_,p,d,distance)
        env.rayIndex=env.rayIndex+1;local ray=assert(env.rays[env.rayIndex],'extra ray '..env.rayIndex)
        Compare({p=p,d=d,length=distance},{p=ray.p,d=ray.d,length=ray.length},'source ray '..env.rayIndex,2e-5)
        return Copy(ray.hit)
    end
    return c,env
end
function LEG_RUN_CASE(case)
    local a,ae=Replay(old,case);local b,be=Replay(new,case)
    local before,after=old.count.solve,new.count.solve;local rays=0;local jumps=0
    for frame,sample in ipairs(case.samples)do
        local results={}
        for i,pair in ipairs({{a,ae},{b,be}})do local c,e=pair[1],pair[2]
            e.state=Copy(sample.state);e.forces={};e.rays=sample.rays;e.rayIndex=0;e.velocities=sample.velocities;e.velocityIndex=0;e.afterImpulse=sample.afterImpulse
            local result=c:Step(sample.command,1/60,sample.support)
            Compare(e.rayIndex,#sample.rays,'source total rays');Compare(e.velocityIndex,#sample.velocities,'source total velocities')
            Compare(result,sample.telemetry,'source telemetry',2e-5);Compare(e.forces,sample.forces,'source forces',2e-5)
            Compare({phase=c.phase,cadence=c.cadence},{phase=sample.phase,cadence=sample.cadence},'source gait',2e-5)
            for j,s in ipairs(c.list)do
                Compare({id=s.leg.partId,foot=s.foot,previous=s.previous,target=s.target,bladeAngle=s.bladeAngle,grounded=s.grounded,mode=s.mode,force=s.force},sample.states[j],'source IK state '..j,2e-5)
            end
            results[i]={telemetry=result,forces=e.forces,state=e.state,controller=Snapshot(c)}
            if i==2 then assert(c.ikCache==nil,'cache retained after Step');assertions=assertions+1 end
        end
        Compare(results[1],results[2],case.name..'/'..case.scenario..'/'..frame)
        rays=rays+#sample.rays;if sample.telemetry.legJumped then jumps=jumps+1 end
    end
    return {name=case.name,scenario=case.scenario,steps=#case.samples,rays=rays,jumps=jumps,beforeSolve=old.count.solve-before,afterSolve=new.count.solve-after}
end
local function Analytic(mod,case)
    local state={p={x=0,y=0,z=-20},q={x=0,y=0,z=0,w=1},lv={x=0,y=0,z=0},av={x=0,y=0,z=0},com={x=0,y=2.25,z=-20}}
    local env={state=state,forces={},rays={},kind='ground'}
    local v={spec=Copy(case.spec),com=Copy(case.com),mass=case.mass,inertiaY=case.inertiaY,capabilities=Copy(case.capabilities),legMode=case.legMode}
    v.body={rotation=function()return state.q end,translation=function()return state.p end,linvel=function()return state.lv end,angvel=function()return state.av end,center=function()return state.com end,
        velocityAtPoint=function(point)return V.Vec(V.Add(V.Array(state.lv),V.Cross(V.Array(state.av),V.Sub(V.Array(point),V.Array(state.com)))))end}
    for _,method in ipairs({'addForce','addForceAtPoint','addTorque','applyImpulse'})do v.body[method]=function(a,b)
        env.forces[#env.forces+1]={method=method,args=method=='addForceAtPoint'and{Copy(a),Copy(b)}or{Copy(a)}}
        if method=='applyImpulse'then state.lv=V.Vec(V.Add(V.Array(state.lv),V.Scale(V.Array(a),1/v.mass)))end
    end end
    local function Build()
        local c=mod.legs.New(v)
        c.Cast=function(_,p,d,distance)
            env.rays[#env.rays+1]={p=Copy(p),d=Copy(d),length=distance}
            if env.kind=='air'then return nil end
            local best
            local function Plane(axis,value,normal,id)
                if math.abs(d[axis])<1e-9 then return end
                local t=(value-p[axis])/d[axis]
                if t>1e-7 and t<=distance and(not best or t<best.distance)then best={distance=t,normal=normal,point=V.Add(p,V.Scale(d,t)),collider=id}end
            end
            Plane(2,0,{0,1,0},1)
            if env.kind=='wall'then Plane(3,0,{0,0,-1},2)end
            return best
        end
        return c
    end
    return Build(),env,v,Build
end
function LEG_RUN_MIXED(case)
    local a,ae,av,ab=Analytic(old,case);local b,be,bv,bb=Analytic(new,case)
    local before,after=old.count.solve,new.count.solve;local rays,jumps,air,wall,damaged,restores=0,0,0,0,0,0
    local savedA,savedB
    for frame=1,420 do
        local kind=frame>100 and frame<=145 and'air'or frame>180 and frame<=280 and'wall'or'ground'
        if frame==300 then
            -- Runtime destruction replaces the control with the surviving spec.
            for i=#av.spec.legs,3,-1 do av.spec.legs[i]=nil;bv.spec.legs[i]=nil end
            a=ab();b=bb();damaged=#av.spec.legs
        end
        if frame==80 then savedA=a:Snapshot();savedB=b:Snapshot()end
        if frame==150 then a:Restore(savedA);b:Restore(savedB);restores=restores+1 end
        if frame==285 then a:Reset();b:Reset()end
        local results={}
        for i,row in ipairs({{a,ae,av},{b,be,bv}})do local c,e,v=row[1],row[2],row[3]
            e.kind=kind;e.rays={};e.forces={};local s=e.state
            -- Reuse and mutate each body array in place, like source setters.
            s.p.x=frame>330 and 2 or 0;s.p.y=kind=='air'and 8 or 0;s.p.z=kind=='wall'and-1.4 or-20
            local angle=kind=='wall'and .22 or .04*math.sin(frame*.02)
            s.q.x=math.sin(angle/2);s.q.w=math.cos(angle/2)
            s.lv.x=frame>330 and-1 or .2;s.lv.y=kind=='air'and-3 or 0;s.lv.z=frame>30 and frame<360 and 4 or 0;s.av.y=.15
            s.com.x=s.p.x+v.com[1];s.com.y=s.p.y+v.com[2];s.com.z=s.p.z+v.com[3]
            local cmd={throttle=frame>30 and frame<360 and 1 or 0,strafe=frame>330 and-.6 or 0,steer=frame>230 and .4 or 0,jump=frame==65 or frame==185}
            local result=c:Step(cmd,1/60,frame>360 and v.mass*3 or 0)
            results[i]={controller=Snapshot(c),telemetry=result,rays=e.rays,forces=e.forces,state=s}
            if i==2 then
                assert(c.ikCache==nil,'mixed scope retained');assertions=assertions+1
                rays=rays+#e.rays;if result.legJumped then jumps=jumps+1 end;if kind=='air'then air=air+1 end;if kind=='wall'then wall=wall+1 end
            end
        end
        Compare(results[1],results[2],'mixed/'..frame)
    end
    return {name='mixed setters/air/wall/jump/restore/damage',steps=420,rays=rays,jumps=jumps,airSteps=air,wallSteps=wall,survivingLegs=damaged,restores=restores,beforeSolve=old.count.solve-before,afterSolve=new.count.solve-after}
end
function LEG_RUN_BOUNDARIES(case)
    local c,e,v=Analytic(new,case);local s=c.list[1];local q={x=0,y=0,z=0,w=1};local p={0,0,0};local foot=Copy(s.leg.toe)
    local function Fresh()
        local target=c:Target(s,foot,q,p);return new.ik.Solve(c.info[s.leg.type],target)
    end
    local function Mutations()
        local scope <close> = c.ikScope;c.ikCache={}
        for _,mutate in ipairs({function()end,function()foot[1]=foot[1]+.2 end,function()q.y=math.sin(.1);q.w=math.cos(.1)end,function()p[2]=.3 end,function()s.leg.origin[3]=s.leg.origin[3]+.2 end,function()s.leg.rot=(s.leg.rot+1)%24 end})do
            mutate();c:Reachable(s,foot,q,p);c:Clear(s,foot,q,p)
            Compare(c.ikCache[s].pose,Fresh(),'in-place evaluation matches fresh Solve')
        end
        error('expected gait failure')
    end
    local ok,message=pcall(Mutations)
    assert(not ok and message:find('expected gait failure',1,true)and c.ikCache==nil,'error clears cache without swallowing');assertions=assertions+1
    local outside=new.count.solve;c:Clear(s,foot,q,p);c:Clear(s,foot,q,p)
    Compare(new.count.solve-outside,2,'outside Step does not cache')
    local originalCast=c.Cast;c.Cast=function()error('expected ray failure')end
    ok,message=pcall(c.Step,c,{},1/60,0)
    assert(not ok and message:find('expected ray failure',1,true)and c.ikCache==nil,'actual Step exception clears cache');assertions=assertions+1;c.Cast=originalCast
    return {errorScope=true,outsideScopeFresh=true,inPlaceFootPoseOriginRotation=true}
end
function LEG_ASSERTIONS()return assertions end

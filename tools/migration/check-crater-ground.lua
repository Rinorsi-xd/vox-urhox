local app,trial,field
local stage='boot';local task
local function Near(a,b) return math.abs(a-b)<.00002 end
local function Point(a,b) return Near(a[1],b[1]) and Near(a[2],b[2]) and Near(a[3],b[3]) end
local function Shot(name)
    local im=Image:new();V.assert(graphics:TakeScreenShot(im),'capture '..name)
    V.assert(im:SavePNG('docs/migration/evidence/crater-ground-'..name..'.png'),'save '..name);im:Dispose()
end
engine.maxInactiveFps=120
local function Exercise()
    trial.Update=function() end
    local world=trial.world;field=world.visualGround
    local f=File('tools/migration/source-crater-ground.json',FILE_READ);local oracle=cjson.decode(f:ReadString());f:Dispose()
    V.assert(field.buffer.size==410881*4,'height data stays in one compact 32-bit native buffer')
    for i,p in ipairs(oracle.points) do V.assert(Near(world:GroundAt(p.x,p.z),p.h),'source visual terrain sample '..i) end
    local chips=trial.effects.chips
    local random=math.random;math.random=function() return .5 end
    local ok,err=pcall(function()
        for i,c in ipairs(oracle.trajectories) do
            chips:Clear();chips:Emit({table.unpack(c.pos)},{table.unpack(c.vel)},c.size,c.color,c.life)
            for j,s in ipairs(c.states) do
                chips:Update(s.dt);local actual=chips.slots[1]
                V.assert(Point(actual.pos,s.pos) and Point(actual.vel,s.vel) and Near(actual.age,s.age) and Near(actual.spin,s.spin),'original chip trajectory '..i..'/'..j)
            end
        end
    end)
    math.random=random;assert(ok,err)
    -- Map-ground integration: keep visual sparks below sea level; weightless
    -- smoke remains free. This corrects a zero-height limitation in H5 itself.
    local low=oracle.trajectories[1].pos;local x,z=low[1],low[3];local y=world:GroundAt(x,z)
    local fx=trial.effects;fx:Clear()
    fx.particles={{pos={x,y-1,z},vel={0,-2,0},color={4,2,1},size=.1,life=1,age=0,drag=0,grav=9.81}}
    fx.smoke={{pos={x,y-1,z},vel={0,0,0},color={.3,.3,.3},size=.1,life=1,age=0,drag=0,grav=0}}
    fx:Update(.016,{},trial.camera:GetNode())
    V.assert(y< -10 and Near(fx.particles[1].pos[2],y+.02) and fx.particles[1].vel[2]>0,'sparks bounce at negative crater ground')
    V.assert(Near(fx.smoke[1].pos[2],y-1),'weightless smoke is not snapped to terrain')
    fx:Clear()
    local start=os.clock();local sum=0
    for _=1,20 do for _,p in ipairs(oracle.points) do sum=sum+world:GroundAt(p.x,p.z) end end
    local elapsed=os.clock()-start
    local metrics={samples=#oracle.points*20,cpu_seconds=elapsed,checksum=sum,buffer_bytes=field.buffer.size}
    local out=assert(io.open('docs/migration/evidence/crater-ground-cost.json','w'));out:write(cjson.encode(metrics));out:close()
    -- Real map framing, then the same negative-height break event with only the
    -- old/new ground callback changed. No alternative game or authored objects.
    trial:GoTo('东洼地');trial.pointer.SetMouseMode=function() end;trial:Resume()
    for _=1,120 do trial:Tick(1/60,{throttle=0,steer=0}) end
    trial:PostUpdate(1);trial.hud.Update(trial,0);trial.PostUpdate=function() end
    local p=trial.vehicle.body.translation();local camera=trial.camera:GetNode().worldPosition
    local dx,dz=-camera.x-p.x,camera.z-p.z;local length=math.sqrt(dx*dx+dz*dz)
    local point={p.x+dx/length*5,0,p.z+dz/length*5}
    point[2]=world:GroundAt(point[1],point[3])+.5
    -- Vehicle body is in source coordinates; chips convert at render boundary.
    local function Break(flat)
        fx:Clear();local old=math.random;local seed=1367
        math.random=function() seed=(seed*1664525+1013904223)&0xffffffff;return seed/4294967296 end
        local original=chips.groundAt
        chips.groundAt=flat and function() return 0 end or original
        fx:Consume({{type='break',pos=point,dir={0,0,0},cells=5,color=0xffaa22}})
        for _=1,42 do chips:Update(1/60) end
        chips.groundAt=original;math.random=old
        return chips.slots[1].pos[2]
    end
    local correct=Break(false);coroutine.yield();coroutine.yield();Shot('correct')
    local legacy=Break(true);coroutine.yield();coroutine.yield();Shot('legacy-zero')
    V.assert(correct< -5 and legacy>=0,'real pit chip stays near pit floor instead of jumping to sea level')
    fx:Clear();stage='return';app:Reload()
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app;V.assert(app:EnterTrial('crater'),'request actual crater session');stage='loading'
    elseif stage=='loading' and app.trial then trial=app.trial;task=coroutine.create(Exercise);stage='exercise'
    elseif stage=='exercise' and coroutine.status(task)~='dead' then local ok,err=coroutine.resume(task);assert(ok,err)
    elseif stage=='return' and app.mode=='hangar' and not app.pendingAssetRelease then
        V.assert(trial.disposed and field.disposed and field.buffer.size==0,'leaving map clears native height storage')
        V.assert(not trial.effects.groundAt and not trial.effects.chips.groundAt,'effect callbacks no longer retain map owner')
        V.assert(app:EnterTrial('trial'),'original flat trial still opens');stage='flat'
    elseif stage=='flat' and app.trial then
        V.assert(app.trial.world:GroundAt(70,10)==0,'original trial retains flat-ground contract')
        stage='done';V.finish()
    end
end
for frame=45,680 do V.atFrame(frame,Poll) end
V.atFrame(690,function() V.assert(stage=='done','ground integration and release complete');V.finish() end)

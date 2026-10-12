local app,trial ---@type table?,table?
local function Near(a,b) return math.abs(a-b)<.00002 end
local function Point(a,b) return Near(a[1],b[1]) and Near(a[2],b[2]) and Near(a[3],b[3]) end
local function Position(p) return {-p.x,p.y,p.z} end
engine.maxInactiveFps=120
local function Shot(name)
    local im=Image:new();V.assert(graphics:TakeScreenShot(im),'capture '..name)
    local quality=require('render.Quality').current.name
    V.assert(im:SavePNG('docs/migration/evidence/combat-presentation-'..quality..'-'..name..'.png'),'save '..name);im:Dispose()
end
V.atFrame(45,function() app=assert(VOX_HANGAR).app;V.assert(app:EnterTrial(),'request actual game session') end)
V.atFrame(90,function()
    trial=assert(app.trial)
    local file=File('tools/migration/source-combat-presentation.json',FILE_READ)
    local data=cjson.decode(file:ReadString());file:Dispose()
    local fx=trial.effects;local light=fx.light
    local oldRandom=math.random;math.random=function() return .5 end
    local ok,err=pcall(function()
        for _,case in ipairs(data.cases) do
            fx:Clear();light.node.position=Vector3.ZERO;light.light.color=require('Config').HexLinear(0xffa050)
            for index,s in ipairs(case.states) do
                local cmd=s.cmd
                if cmd.op=='consume' then fx:Consume(cmd.events)
                elseif cmd.op=='update' then fx:Update(cmd.dt,{},trial.camera:GetNode())
                elseif cmd.op=='light' then local o=cmd.options or {};light:Emit(cmd.pos,cmd.intensity,cmd.color,o.decay,o.smooth)
                elseif cmd.op=='clear' then fx:Clear();fx:Update(0,{},trial.camera:GetNode()) end
                local color=light.light.color
                V.assert(Near(light.intensity,s.intensity) and Near(light.light.brightness,s.brightness)
                    and Point(Position(light.node.position),s.pos) and Point({color.r,color.g,color.b},s.color),case.name..' light '..index)
                V.assert(#fx.zaps==#s.zaps and #fx.trails==#s.trails,case.name..' transient count '..index)
                -- Native pools compact by swapping the last entry; source filter keeps order.
                -- Compare each live arc once, independently of storage order.
                local matched={}
                for i,z in ipairs(s.zaps) do
                    local found=false
                    for j,actual in ipairs(fx.zaps) do
                        if not matched[j] and Point(actual.a,z.a) and Point(actual.b,z.b) and Near(actual.age,z.age)
                            and Near(actual.life,z.life) and Near(actual.width,z.w) then
                            matched[j]=true;found=true;break
                        end
                    end
                    V.assert(found,case.name..' arc '..index..'/'..i)
                end
            end
        end
    end)
    math.random=oldRandom;assert(ok,err)
    V.assert(light.light.range==22 and not light.light.castShadows and not light.light.useTemperature,'one 22 metre shadow-free source light')
    V.assert(#fx.root:GetComponents('Light',true)==1,'effect stream does not allocate a light per shot')
    fx:Consume({{type='beam',kind='sniper',tier=5,from={28,2,8},to={48,2,8},dir={1,0,0},hit=false}})
    fx:Update(.1,{},trial.camera:GetNode())
    V.assert(fx.batches.Arc and fx.batches.Arc.count>0,'T5 ionized trail emits real arc geometry')
    V.assert(fx.batches.Arc.material:GetSurfaceShader().name=='Shaders/BLGL/WeaponFx/Ribbon.shader','secondary arcs reuse source no-noise shader')
    fx:Clear();V.assert(not light.light.enabled and light.light.brightness==0,'reset immediately removes transient lighting')
    -- Real mounted vehicle shot for the rendered on/off check.
    trial.vehicle:Place({28,0,8},math.pi/2);trial.view:ResetPose();trial.weapons:Select(2)
    trial.yaw=-72;trial.pitch=9
    for _=1,180 do trial:Tick(1/60,{throttle=0,steer=0,aim={48,1.6,8}}) end
    trial:PostUpdate(1)
    local count=trial.world.stats.shots
    for _=1,180 do
        trial:Tick(1/60,{throttle=0,steer=0,firing=true,aim={48,1.6,8}})
        if trial.world.stats.shots>count then break end
    end
    V.assert(light.light.enabled and light.light.brightness>0,'mounted weapon event illuminates the actual game scene')
    trial.Update=function() end;trial.PostUpdate=function() end
end)
V.atFrame(100,function() Shot('light-on');trial.effects.light.light.enabled=false end)
V.atFrame(105,function() Shot('light-off');trial.effects:Clear() end)
V.atFrame(110,function() app:Reload() end)
V.atFrame(160,function()
    V.assert(trial.disposed and trial.effects.light.disposed,'leaving game disposes light owner')
    V.assert(not app.scene:GetChild('CombatFlashLight',true),'garage has no leaked battle light')
    V.finish()
end)

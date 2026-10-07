local View=require 'render.VehicleView'
local FX=require 'render.WeaponEffects'
local Batch=require 'render.EffectBatch'
local Presentation=require 'render.WeaponPresentation'
local Rig=require 'render.PartRig'
local Coord=require 'core.Coord'
local Rot=require 'core.Rotations'
local Q=require('render.Quality').current
local kind,phase,flowCheck='laser','active',false
for _,arg in ipairs(GetArguments()) do
    kind=arg:match('^%-weapon%-kind=(.+)$') or kind;phase=arg:match('^%-weapon%-phase=(.+)$') or phase
    if arg=='-weapon-flow-check' then flowCheck=true end
end
---@type table|nil
local app,display=nil,nil
---@type Node|nil
local camera=nil
local function Near(a,b) return math.abs(a-b)<2e-5*math.max(1,math.abs(b)) end
local function Source(p) return {-p.x,p.y,p.z} end
local function CheckPoint(p,expected,head)
    local native=head:WorldToLocal(Coord.Vec(table.unpack(p)));local a=Source(native)
    return Near(a[1],expected[1]) and Near(a[2],expected[2]) and Near(a[3],expected[3])
end
engine.maxInactiveFps=120
V.atFrame(45,function()
    app=assert(VOX_HANGAR).app;app.Update=function()end;app.PostUpdate=function()end
    app.car:SetVisible(false);camera=app.camera.node
    app.hangar.scan.enabled=false
    camera.position=Vector3(3,3,4.8);camera:LookAt(Vector3(0,1.6,0))
    if Q.name=='desktop' then
        local file=assert(io.open('tools/migration/source-weapon-effects.json'));local fixture=cjson.decode(file:read('*a'));file:close()
        for _,case in ipairs(fixture.cases) do
            local view=View.New(VOX_HANGAR.scene,'SourceWeaponFx');view.root.rotation=Quaternion(17,36,8)
            local vis=view:AddPart({id=1,type=case.type,pos={0,2,0},rot=Rot.IDENTITY,color=0xffcc22})
            local fx=FX.New(view,function()return .5 end);local ctx={camera=camera,time=0,fov=60}
            local captured={};local original=Batch.Disc
            Batch.Disc=function(b,p,size,color,alpha,right,up,gain)
                local list=captured[b.node.name] or {};captured[b.node.name]=list;list[#list+1]={p=p,size=size,gain=gain}
                return original(b,p,size,color,alpha,right,up,gain)
            end
            for i,s in ipairs(case.steps) do
                captured={};for k,v in pairs(s.state) do vis.weaponMotion[k]=v end
                Rig.SetWeapon(vis,math.sin(i*.02)*.4,.15,0,.03,.02)
                ctx.time=s.time;fx:Update(s.dt,ctx);local item=fx.items[1];local ok=true
                if type(s.bands)=='table' then for j,e in ipairs(s.bands) do
                    local a=captured.Band[j];ok=ok and CheckPoint(a.p,e.p,vis.head) and Near(a.size,e.r) and Near(a.gain,e.alpha)
                end end
                if type(s.motes)=='table' then for j,a in ipairs(captured.Glow or {}) do
                    local n=(j-1)*3;local point={s.motes.pos[n+1],s.motes.pos[n+2],s.motes.pos[n+3]}
                    local expectedSize=s.motes.size[j]*.5*.9*2*math.tan(math.pi/6)
                    local moteOk=CheckPoint(a.p,point,vis.head) and Near(a.gain,s.motes.alpha[j]) and Near(a.size,expectedSize)
                    ok=ok and moteOk
                end end
                if type(s.arcs)=='table' then
                    ok=ok and #item.arcs==#s.arcs
                    for j,e in ipairs(s.arcs) do local a=item.arcs[j];if a then
                        for _,k in ipairs({'a0','a1','za','zb','life','age','amp','w'}) do ok=ok and Near(a[k],e[k]) end
                    end end
                end
                V.assert(ok,case.type..' original persistent effects '..i)
            end
            Batch.Disc=original
            local item=fx.items[1];local old=item;fx:Update(.01,ctx);V.assert(fx.items[1]==old,'stable per weapon state')
            vis.weaponMotion.offline=true;for _=1,600 do fx:Update(.1,ctx) end
            vis.weaponMotion.offline=false;vis.weaponMotion.windup=1;fx:Update(.1,ctx)
            V.assert(#fx.items[1].arcs<=Q.weaponArcsPerRig and fx.items[1].arcTimer>=0,'bounded long offline recovery')
            for _,b in pairs(fx.batches) do V.assert(b.count<=b.limit,'bounded batch '..b.node.name) end
            fx:Reset();local empty=next(fx.items)==nil
            for _,b in pairs(fx.batches) do empty=empty and not b.mesh.enabled end
            V.assert(empty,'reset hides GPU geometry');fx:Dispose();fx:Dispose();view:Dispose()
        end
    end
    display=View.New(VOX_HANGAR.scene,'WeaponFxEvidence')
    for i=1,2 do display:AddPart({id=i,type=kind..(i+3),pos={(i==1 and -1 or 1)*3,2,0},rot=Rot.IDENTITY,color=0xffcc22}) end
    local ctx={camera=camera,time=0,fov=app.camera.camera.fov}
    for i=1,180 do
        local time=i/60
        for _,vis in pairs(display.visuals) do
            local w={charge=.95,windup=kind=='sniper' and .8 or 0,spin=kind=='mg' and 1 or 0,spinRate=12,spinAngle=time*8,shotAt=math.floor(i/15),barrel=1}
            local off=phase=='offline' and i>90 or phase=='boot' and i>90 and i<168
            Presentation.Update(vis,1/60,time,w,{offline=off},true)
            Rig.SetWeapon(vis,.18,.08,w.spinAngle,vis.weaponMotion.recoil,vis.weaponMotion.kick);Presentation.Apply(vis)
        end
        ctx.time=time;display:UpdateWeaponEffects(1/60,ctx)
    end
    local fx=display.weaponEffects
    for _,b in pairs(fx.batches) do V.assert(b.count<=b.limit,'rendered '..b.node.name..' within mobile/desktop budget') end
    V.assert(next(fx.batches)~=nil,'rendered persistent effect geometry exists')
    if flowCheck then
        fx:Reset();app.hangar.root.enabled=false
        for _,vis in pairs(display.visuals) do
            Rig.SetWeapon(vis,0,0,0,0,0)
            for _,material in pairs(vis.weaponMaterials) do
                material:SetShaderParameter('emission_strength',Variant(.5))
                material:SetShaderParameter('flow_state',Variant(Vector4(0,2.6,.9,1)))
                material:SetShaderParameter('flow_sweep',Variant(Vector2(-1,0)))
            end
        end
    end
end)
local function CaptureFlow(name)
    local shot=Image:new();local ok=graphics:TakeScreenShot(shot)
    V.assert(ok and shot:SavePNG('docs/migration/evidence/weapon-flow-'..name..'.png'),'capture flow '..name);shot:Dispose()
end
V.atFrame(80,function()
    if not flowCheck then return end
    CaptureFlow('origin')
    -- Rebuild at different vehicle-local placement, compensate at root. Identical
    -- world pose must produce identical light flow, including the angular base.
    local saved={}
    for id,vis in pairs(display.visuals) do saved[id]=vis.weaponMotion end
    display:Clear();display.root.position=Vector3(6.5,0,8.5)
    for i=1,2 do
        local vis=display:AddPart({id=i,type=kind..(i+3),pos={(i==1 and -1 or 1)*3+13,2,-17},rot=Rot.IDENTITY,color=0xffcc22})
        vis.weaponMotion=saved[i];Presentation.Apply(vis);Rig.SetWeapon(vis,0,0,0,0,0)
        for _,material in pairs(vis.weaponMaterials) do
            material:SetShaderParameter('emission_strength',Variant(.5))
            material:SetShaderParameter('flow_state',Variant(Vector4(0,2.6,.9,1)))
            material:SetShaderParameter('flow_sweep',Variant(Vector2(-1,0)))
        end
    end
end)
V.atFrame(95,function()
    if not flowCheck then return end;CaptureFlow('placement')
    for _,vis in pairs(display.visuals) do for _,material in pairs(vis.weaponMaterials) do
        material:SetShaderParameter('flow_state',Variant(Vector4(.35,2.6,.9,1)))
    end end
end)
V.atFrame(110,function() if flowCheck then CaptureFlow('phase') end end)
V.atFrame(135,function()
    if flowCheck then display:Dispose();V.finish();return end
    local fx=display.weaponEffects;display:RemovePart(1)
    display:UpdateWeaponEffects(.01,{camera=camera,time=4,fov=60})
    V.assert(fx.items[1]==nil and fx.items[2]~=nil,'removed weapon releases persistent state; survivor retained')
    local remaining=display.visuals[2];local old=remaining.weaponMotion
    old.recoilS.x=.3;old.kickS.v=4;local shot=old.lastShot;local charge=old.charge
    display:ResetWeaponPresentation()
    V.assert(remaining.weaponMotion.recoil==0 and remaining.weaponMotion.kick==0 and remaining.weaponMotion.charge==charge and remaining.weaponMotion.lastShot==shot,'reset clears visual springs without resetting physical weapon state')
    camera.position=Vector3(10000,10000,10000);display:UpdateWeaponEffects(.1,{camera=camera,time=5})
    local hidden=true;for _,b in pairs(fx.batches) do hidden=hidden and not b.mesh.enabled end
    V.assert(hidden and next(fx.items)==nil,'distance unload clears visual state and hides batches')
    display:RemovePart(2)
    V.assert(display.weaponEffects==nil and fx.disposed,'last removed weapon releases FX resources before vehicle disposal')
    display:Dispose();V.assert(fx.disposed and next(fx.batches)==nil,'dispose releases all owned FX batches');V.finish()
end)

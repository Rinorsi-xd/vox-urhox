local UI=require 'urhox-libs/UI'
local BP=require 'construction.Blueprint'
local Flash=require 'render.RestoreFlash'
local Weapons=require 'ui.ReticleWeapons'
local scene,space,unit,drive,fx,root,widget,joined
local beforeScale,wheelId,weaponId,output
for _,arg in ipairs(GetArguments()) do output=arg:match('^%-feedback%-out=(.+)$') or output end
local function Near(a,b) return math.abs(a-b)<1e-5 end
local function Sync()
    drive.view:Rebuild(unit.bp);drive:Bind(unit.bp,unit.vehicle)
    fx:Consume(unit,drive.view,unit.env.viewEvents);unit.env.viewEvents={}
end
local function Shot(name)
    local image=Image();V.assert(graphics:TakeScreenShot(image),'actual native rendered '..name)
    V.assert(image:SavePNG(output..'/'..name..'.png'),'saved '..name);image:Dispose()
end
V.atFrame(2,function()
    local data=assert(io.open('tools/migration/source-restore-feedback.json'));local source=cjson.decode(data:read('*a'));data:close()
    for _,sample in ipairs(source.samples) do
        local _,_,alpha=Weapons.Feedback({hurt=1.4},sample.ms/1000,true)
        V.assert(Near(alpha,sample.opacity),'original Chromium CSS steps(2) sample '..sample.ms..'ms')
    end
    local hurt,fix,alpha=Weapons.Feedback({hurt=1.4,fix=1.2},.175,false)
    V.assert(hurt and not fix and Near(alpha,.3),'original hurt class takes precedence over fix')
    local _,fixed,opacity=Weapons.Feedback({hurt=0,fix=1.2},.1,false)
    V.assert(fixed and opacity==1,'repaired weapon slot is full-opacity cyan')
    scene=Scene();scene:CreateComponent('Octree');space=require('physics.Space').New(scene)
    local zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100))
    zone.ambientSource=AMBIENT_COLOR;zone.ambientColor=Color(.32,.32,.32);zone.fogColor=Color(.025,.03,.04)
    local light=scene:CreateChild('Sun');light.direction=Vector3(.4,-1,.3);light:CreateComponent('Light').lightType=LIGHT_DIRECTIONAL
    local env={scene=scene,space=space,time=0,viewEvents={},fx={},debris=require('combat.Debris').New(space)}
    function env:NewVehicle(spec) return require('drive.Vehicle').New(space,spec) end
    function env:RecordDamage() end
    function env:RecordKill() end
    unit=require('combat.CarUnit').New(env,require('construction.Prefab').BuildRaceCar(BP.New()):ToTable(),{
        name='Actual restored car',spawn={pos={0,2,0},yaw=0},combat=true,externalControl=true,externalView=true})
    drive=require('render.DriveView').New(scene,unit.bp,unit.vehicle)
    fx=Flash.New(scene);fx:Consume(unit,drive.view,env.viewEvents);env.viewEvents={}
    V.assert(unit.alive and #fx.items==0,'actual CarUnit spawn does not flash every part')
    wheelId=unit.spec.wheels[1].partId;weaponId=unit.spec.weapons[1].partId
    unit:Destroy(wheelId);unit:Destroy(weaponId);unit:Flush();Sync()
    V.assert(unit.alive and not unit.bp.parts[wheelId] and not unit.bp.parts[weaponId] and #fx.items==0,'actual wheel and weapon loss produce no obsolete text/restore shell')
    local ids=unit:RestoreMissing(2);unit:Flush();Sync()
    V.assert(#ids>=2 and #fx.items==#ids,'one actual recovery batch flashes every restored part after final body/view rebuild')
    V.assert(drive.vehicle==unit.vehicle and drive.view.visuals[wheelId] and drive.view.visuals[weaponId],'restored real vehicle and visual bind to final native body')
    local n=0;for _,item in ipairs(fx.items) do n=n+#item.models;V.assert(Near(item.alpha,1.1),'source initial additive alpha 1.1') end
    V.assert(n>2,'actual articulated wheel/weapon meshes form detailed restoration shells')
    fx:Update(.1);local item=fx.items[1];beforeScale=item.baseScale
    V.assert((fx.root.worldScale-drive.view.root.worldScale):Length()<1e-7,'shell root preserves actual half-metre CELL world scale')
    for _,entry in ipairs(fx.items) do V.assert((entry.node.worldPosition-entry.vis.node.worldPosition):Length()<1e-5,'shell origin aligns to actual restored part world origin') end
    V.assert(Near(item.vis.node.scale.x,beforeScale.x*1.07),'source restored part peaks at seven-percent pop at .1 seconds')
    V.assert(Near(item.node.scale.x,beforeScale.x*(1+.14*(1-(1-.1/.34)^3))),'source shell cubic ease-out growth matches at .1 seconds')
    V.assert(Near(item.alpha,1.1*(1-.1/.34)^1.5),'source shell fade exponent matches at .1 seconds')
    local snapshot=item.models[1].node.transform
    if item.vis.rig.head then item.vis.rig.head.rotation=Quaternion(35,Vector3.UP) end
    fx:Update(0)
    V.assert(item.models[1].node.transform==snapshot,'restoration shell is a fixed geometry snapshot, not an animated turret duplicate')
    local fonts=require('ui.SourceFonts').Resolve()
    UI.Init({theme='default-dark',scale=UI.Scale.DEFAULT,fonts={{family='sans',weights={normal=fonts.body,bold=fonts.bold}}}})
    root=UI.Panel{width='100%',height='100%',pointerEvents='none'}
    local layer=UI.Panel:Extend('RestoreFeedbackSpecimen')
    widget={session={weapons=unit.weapons},clock=10,chipStates={}}
    for _,g in ipairs(unit.weapons.groups) do widget.chipStates[g.kind]={hurt=11.4} end
    local specimen=layer{position='absolute',width='100%',height='100%'}
    specimen.Render=function(self,vg)
        require('ui.SourceDraw').HudFont(vg);local b=self:GetAbsoluteLayout();Weapons.Render(vg,widget,require('ui.ReticleState').Layout(b.w,b.h,false))
    end
    root:AddChild(specimen)
    UI.SetRoot(root)
    local camera=scene:CreateChild('Camera');camera.position=Vector3(-11,8,-13);camera:LookAt(Vector3(0,3,0))
    local c=camera:CreateComponent('Camera');c.farClip=100;c.fov=48;renderer:SetViewport(0,Viewport:new(scene,c))
end)
V.atFrame(4,function() Shot('restored-parts-hurt-bright');widget.clock=10.175 end)
V.atFrame(6,function()
    Shot('weapon-lost-hurt-dim')
    for _,state in pairs(widget.chipStates) do state.hurt=0;state.fix=11.2 end
    fx:Update(.10001)
    V.assert(Near(fx.items[1].vis.node.scale.x,beforeScale.x),'source pop finishes at .2 seconds without moving rig pivots')
    fx:Update(.14);V.assert(#fx.items==0,'source shell nodes and model copies retire at .34 seconds')
    local part=unit.bp.parts[wheelId];fx:Add(part);fx:Update(.1)
    require('render.NodeVisibility').Set(drive.view.root,false,true);fx:Update(0)
    local hidden=not fx.root.enabled;for _,child in ipairs(fx.root:GetChildren(true)) do hidden=hidden and not child.enabled end
    V.assert(hidden,'first-person hides all shell nodes, not only FX parent')
    require('render.NodeVisibility').Set(drive.view.root,true);fx:Update(0)
    local visible=fx.root.enabled;for _,child in ipairs(fx.root:GetChildren(true)) do visible=visible and child.enabled end
    V.assert(visible,'third-person restores original shell visibility mask')
    fx:Clear();V.assert(#fx.items==0 and Near(drive.view.visuals[wheelId].node.scale.x,1),'explicit cancellation restores part scale and releases shell')
    joined=BP.New():Add({id=90001,type='cube',pos={7,2,0},g=1})
    drive.view:AddPart(joined);fx:Add(joined);fx:Update(.12)
    V.assert(fx.items[1].geometry and not fx.items[1].pop and Near(drive.view.visuals[joined.id].node.scale.x,1),'joined blocks use exact shape shell without popping merged structure')
    V.assert(Near(fx.items[1].material:GetShaderParameter('joined_alpha'):GetFloat(),1.1*(1-.12/.34)^1.5),'joined CustomGeometry uses its own correct fade uniform')
end)
V.atFrame(8,function()
    Shot('restored-weapon-fix-and-joined-shell')
    local old=drive.view.visuals;local item=fx.items[1]
    drive.view:Rebuild(unit.bp);drive:Bind(unit.bp,unit.vehicle);fx:Update(0)
    V.assert(old~=drive.view.visuals and #fx.items==0,'visual rebuild discards stale shells without dereferencing disposed part nodes')
    fx:Add(unit.bp.parts[wheelId]);fx:Consume(unit,drive.view,{{type='unitKilled',unit=unit}})
    V.assert(#fx.items==0,'actual death event clears restoration effects')
    fx:Add(unit.bp.parts[wheelId]);fx:Dispose();fx:Dispose()
    V.assert(fx.disposed and #fx.items==0 and fx.view==nil,'FX dispose is idempotent and releases owning references')
    drive:Dispose();unit:Dispose();unit.env.debris:Clear();space:Dispose();UI.Shutdown();scene:Dispose();V.finish()
end)

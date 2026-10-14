local original=HandleUpdate
VOX_SKIP_TUTORIAL=true
local UI=require 'urhox-libs/UI'
local frames=0;local previous='';local samples={}
local sampleMode=''
local function FrameStats()
    if #samples<10 then return nil end
    table.sort(samples);local n=#samples
    local data={count=n,p50=samples[math.ceil(n*.5)]*1000,p95=samples[math.ceil(n*.95)]*1000,p99=samples[math.ceil(n*.99)]*1000,max=samples[n]*1000}
    samples={};return data
end
local function ResourceStats()
    local data={luaKiB=collectgarbage('count'),resourceBytes=cache:GetTotalMemoryUse(),
        modelBytes=cache:GetMemoryUse(StringHash('Model')),arrayBytes=cache:GetMemoryUse(StringHash('Texture2DArray')),
        retiredTargets=require('render.RenderTargetLifetime').PendingCount()}
    return data
end
local function DumpTrial(app)
    local s=app.trial;local w,h=UI.GetViewportSize()
    local p=(not s.combat or s.combat.player.alive) and s.vehicle and s.vehicle.body.translation();local c=s.camera:GetNode().position
    local data={mode='trial',map=s.map.id,width=w,height=h,touch=s.touch,
        loadingFlow=app.loadingFlow:Snapshot(),sceneVisible=renderer:GetViewport(0)~=nil,
        pointer={captured=s.pointer.captured,pending=s.pointer.pending,ready=s.pointer.ready,skip=s.pointer.skip,left=input:GetMouseButtonDown(MOUSEB_LEFT),fire=s.controls.held.fire},
        camera={position={c.x,c.y,c.z},yaw=s.yaw,pitch=s.pitch,dist=s.cameraDistance},
        vehicle=p and {position={p.x,p.y,p.z},speed=s.vehicle.speed} or false,
        weapons={energy=s.weapons.energy,shots=s.world.stats.shots,hits=s.world.stats.hits,kills=s.world.stats.kills,blocked=s.weapons.blocked,turning=s.weapons.turning},
        widgets={},performance=ResourceStats(),frames=FrameStats()}
    data.performance.batches=renderer.numBatches;data.performance.primitives=renderer.numPrimitives
    if s.drivingAudio then data.drivingAudio=s.drivingAudio:Snapshot() end
    data.rotors={}
    for _,r in ipairs(s.vehicle.rotors) do data.rotors[#data.rotors+1]={id=r.partId,mode=r.mode,angle=r.angle,target=r.target} end
    if s.feedbackAudio then data.feedbackAudio=s.feedbackAudio:Snapshot() end
    local rt=s.hud.vitals
    data.reticle={hp=rt.hp,structure=rt.structure,fire=rt.fire,clock=rt.clock,hit=rt.hit,repair=rt.repair,
        scope=s.scope,fov=s.camera:GetCamera().fov,selected=s.weapons.current,groups=#s.weapons.groups,
        layout=require('ui.ReticleState').Layout(w,h),legacyMeter=s.hud.meter:IsVisible()}
    local feedback=s.hud.overlay.feedback
    data.combatFeedback={hits=#feedback.hits,cubes=#feedback.cubes,repairAge=feedback.repairAge,repairFull=feedback.repairFull,score=feedback.score and feedback.score.shown or false}
    data.performance.fixedSteps=s.fixedSteps;data.performance.droppedSeconds=s.droppedTime
    data.performance.effects={particles=#s.effects.particles,smoke=#s.effects.smoke,beams=#s.effects.beams,flashes=#s.effects.flashes}
    local mouse=input.mousePosition;local hit=UI.FindWidgetAt(mouse.x/UI.GetScale(),mouse.y/UI.GetScale())
    local lock=s.weapons:LockInfo()
    local models=0;for _,vis in pairs(s.view.view.visuals) do if vis.weaponMotion and vis.weaponMotion.kind=='missile' then models=models+#vis.models end end
    data.missile={group=s.weapons:Group() and s.weapons:Group().kind,lock=lock and lock.progress,phase=lock and lock.phase,target=lock and lock.ref and lock.ref.pos,
        projectiles=#s.weapons.projectiles,visible=s.effects.missiles.view and s.effects.missiles.view.count or 0,models=models,energy=s.weapons.energy}
    if s.weaponAudio then data.weaponAudio={counts=s.weaponAudio.counts,voices=#s.weaponAudio.slots,active=s.weaponAudio.active,loops={}}
        for id,loop in pairs(s.weaponAudio.loops) do data.weaponAudio.loops[id]={playing=loop.source.playing,gain=loop.source.gain,frequency=loop.source.frequency} end
    end
    if s.hud.touchControls then
        data.touchRects={}
        local r=s.hud.touchControls.stick:GetAbsoluteLayoutForHitTest();data.touchRects.stick={r.x,r.y,r.w,r.h}
        for id,button in pairs(s.hud.touchControls.buttons) do local r=button:GetAbsoluteLayoutForHitTest();data.touchRects[id]={r.x,r.y,r.w,r.h} end
    end
    data.mouse={x=mouse.x,y=mouse.y,scale=UI.GetScale(),hit=hit and hit.props.text or 'other',overlay=UI.GetTopOverlay()~=nil}
    local function Walk(widget)
        if not widget:IsVisible() then return end
        if widget.props.onClick then local r=widget:GetAbsoluteLayoutForHitTest()
            data.widgets[#data.widgets+1]={text=widget.props.text or '',kind=widget.props.kind,rect={r.x,r.y,r.w,r.h}} end
        for _,child in ipairs(widget.children or {}) do Walk(child) end
    end
    local root=UI.GetRoot();if root then Walk(root) end
    local overlay=UI.GetTopOverlay();if overlay then
        Walk(overlay)
        if overlay.contentContainer_ then Walk(overlay.contentContainer_) end
        if overlay.footerWidget_ then Walk(overlay.footerWidget_) end
    end
    if s.battle then data.battle=s.battle:Snapshot() end
    if s.salvage then data.salvageRun=s.salvage:Snapshot() end
    if s.story then
        data.story=s.story:Snapshot()
        data.story.collectorModels=#s.story.view.collectors
        data.story.voicePlayed=#s.story.voice.log
        data.story.voicePlaying=s.story.voice.source.playing
        data.story.saved=s.story.saved
        data.story.target=s.story.rules:Target()
    end
    data.intro=s.intro and {active=not s.intro.done,shot=s.intro.index,time=s.intro.time,full=s.intro.full,skipRect=s.intro.page and s.intro.page.skipRect} or false
    print('OUTGAME_STATE '..cjson.encode(data))
end
local function Dump(app)
    local w,h=UI.GetViewportSize()
    local home=require('ui.GarageHud').GetState()
    local data={width=w,height=h,physical={graphics:GetWidth(),graphics:GetHeight()},dpr=graphics:GetDPR(),
        touch=require('controls.TouchMode').Enabled(),tab=home and home.tab or '',build=app.build~=nil,
        inventory=app.build and app.build.inventoryPanel~=nil or false,dialog=(app.build and app.build.dialog~=nil or home and home.dialog~=nil) or false,blueprint=app.blueprint.name,parts=app.blueprint:Size(),
        widgets={},quality=require('render.Quality').current.name}
    if app.tutorial then data.tutorial=app.tutorial:Snapshot() end
    data.performance=ResourceStats();data.performance.batches=renderer.numBatches;data.performance.primitives=renderer.numPrimitives
    local c=app.camera;local p=c.node.position;local t=c.cur.target
    data.camera={position={p.x,p.y,p.z},target={t.x,t.y,t.z},yaw=c.cur.yaw,pitch=c.cur.pitch,dist=c.cur.dist,fov=c.camera.fov}
    data.camera.desiredDist=c.dist
    local f=c.node.rotation*Vector3.FORWARD;data.camera.forward={f.x,f.y,f.z}
    if app.build then
        local b=app.build
        local backdrop=b.inventoryPanel and b.inventoryPanel.backdrop
        if backdrop and backdrop.graph then
            data.backdrop={passes=backdrop.graph.passCount,width=backdrop.graph.width,height=backdrop.graph.height,
                bytes=backdrop.graph.colorBytes,logical={backdrop.lw,backdrop.lh},active=renderer:GetViewport(0)==backdrop.graph.output}
        end
        data.buildInput={mode=b.buildCamera.mode,captured=b.buildCamera.captured,slot=b.inventory.active,
            tool=b.editor.tool,channel=b.editor.paintChannel,color=b.editor.color,autoColor=b.editor.autoColor}
        local preview=b.editor.preview
        data.buildInput.preview=preview and preview.type and {type=preview.type,pos=preview.pos,rot=preview.rot,ok=preview.res.ok,reason=preview.res.reason} or false
        local stretch=b.editor.stretch
        data.buildStretch=stretch and {phase=stretch.phase,h=stretch.h,anchor=stretch.anchor,cur=stretch.cur,lo=stretch.lo,hi=stretch.hi,
            bad=stretch.bad,items=stretch.items and #stretch.items or #stretch.cells,mirror=stretch.mirrorCells and #stretch.mirrorCells or 0,
            version=stretch.planVersion,ghostModels=#b.ghost.pool} or false
        local ids={};for id in pairs(b.editor.selection) do ids[#ids+1]=id end;table.sort(ids)
        local drag=b.controls.dragSelection
        data.buildSelection={active=b.selecting==true,ids=ids,revision=b.editor.history.revision,
            hit=b.editor.hit and {id=b.editor.hit.partId,cell=b.editor.hit.cell} or false,
            drag=drag and {anchor=drag.anchor,lo=drag.lo,hi=drag.hi,pending=#drag.parts} or false,
            hover=b.hud.hover and b.hud.hover.info or false}
        local joined=b.car.joined
        local groups={};for _,p in ipairs(b.editor.bp:List()) do if p.g>0 then groups[#groups+1]={id=p.id,g=p.g,type=p.type} end end
        data.buildGroups={joinNew=b.editor.joinNew,parts=groups,vertices=joined.vertices or 0,rebuilds=joined.rebuilds,xray=app.buildXray==true}
        local rotor=b.hud.rotor
        data.rotorHud={mode=rotor.mode,visible=rotor.info~=nil,bounds=rotor.bounds,load=rotor.info and rotor.info.count}
        if b.selecting then
            local parts={}
            for _,part in ipairs(b.editor.bp:List()) do parts[#parts+1]={id=part.id,type=part.type,pos=part.pos,rot=part.rot,_cells=part._cells,g=part.g,color=part.color} end
            data.buildSelection.parts=parts;data.buildSelection.mirror=b.editor.mirror
        end
        local badge=b.hud.modeBadge
        if badge then
            local vg=UI.GetNVGContext();require('ui.SourceDraw').Begin(vg);badge:Layout(vg)
            data.buildBadge={mode=badge.renderMode or '',active=badge.mode~=false,opacity=badge.fadeTween.value,
                offset=badge.offsetTween.value,popTime=badge.popTime,width=badge.badgeWidth or 0,color=badge.color,
                items=badge.parts,rect={(w-(badge.badgeWidth or 0))/2,72+badge.offsetTween.value,badge.badgeWidth or 0,38}}
        end
    end
    data.hangar={grid=app.hangar.grid,frame=app.hangar.frame,gridTarget=app.hangar.gridTarget,frameTarget=app.hangar.frameTarget,scan=app.hangar.scan.enabled,time=rawget(_G,'VOX_DEBUG') and VOX_DEBUG.time or app.hangar.time}
    data.hangar.lights={};data.hangar.shadows=renderer.drawShadows
    data.hangar.panelIsolation=app.hangar.qaPanelsOff or false
    data.hangar.materialUpdates={total=#app.hangar.materials,animated=#app.hangar.animatedMaterials}
    for _,light in ipairs(app.scene:GetComponents('Light',true)) do
        data.hangar.lights[#data.hangar.lights+1]={name=light.node.name,type=light.lightType,brightness=light.brightness,shadow=light.castShadows}
    end
    data.anchors={}
    for _,point in ipairs({{0,0,0},{0,3,0},{6,0,0},{-6,0,0},{0,0,6},{0,0,-6}}) do
        local q=c.camera:WorldToScreenPoint(Vector3(-point[1],point[2],point[3]))
        data.anchors[#data.anchors+1]={q.x,q.y}
    end
    if home then
        data.homeRects={}
        local widgets={nav=home.nav,info=home.info,loadout=home.loadout,cta=home.cta,edit=home.buttons.edit,battle=home.buttons.battle,trial=home.buttons.trial,mode=home.modeStrip,strip=home.bayScroll,card=home.cards[1],new=home.buttons.new,save=home.buttons.save,music=home.musicConsole}
        if home.newOpen then
            widgets.menu=home.menu;widgets.menuHeader=home.menu.children[1];widgets.menuEmpty=home.menu.children[2];widgets.menuImport=home.menu.children[3];widgets.menuWorkshop=home.menu.children[4]
            data.menuVisuals={}
            local vg=UI.GetNVGContext();require('ui.SourceDraw').Begin(vg)
            for i,key in ipairs({'empty','import','workshop'}) do
                local item=home.menu.children[i+1]
                data.menuVisuals[key]={layout=item:GetSourceLayout(vg),hovered=item.state.hovered or false,
                    hover=item.hoverMotion and item.hoverMotion.value or 0,bar=item.barMotion and item.barMotion.value or 0,arrow=item.arrowMotion and item.arrowMotion.value or 0}
            end
        end
        for name,widget in pairs(widgets) do
            if widget:IsVisible() then local r=widget:GetAbsoluteLayoutForHitTest();data.homeRects[name]={r.x,r.y,r.w,r.h} end
        end
    end
    if home and home.workshop then
        local ws=home.workshop;data.workshop={}
        data.workshop.tabMotions=ws.tabMotions
        for _,key in ipairs({'selected','pending','view','group','sort','elapsed','hold','from','slides','imagesReady'}) do
            data.workshop[key]=ws[key]
        end
        if ws.caption then
            data.workshop.caption={elapsed=ws.caption.elapsed,distance=ws.caption.distance,groups={}}
            for i=1,6 do
                local alpha,offset=require('ui.WorkshopCarousel').Caption(ws,i)
                data.workshop.caption.groups[i]={opacity=alpha,translateX=offset}
            end
        end
        if ws.shelf then
            data.workshop.shelf={elapsed=ws.shelf.elapsed,groups={}}
            for i=1,9 do
                local alpha,offset=require('ui.WorkshopCarousel').Shelf(ws,i)
                data.workshop.shelf.groups[i]={opacity=alpha,translateY=offset}
            end
        end
        if ws.entrance then
            data.workshop.entrance={kind=ws.entrance.kind,elapsed=ws.entrance.elapsed,groups={},fill=require('ui.WorkshopEntrance').Fill(ws)}
            local count=ws.view=='detail' and 7 or 21
            for i=1,count do
                local alpha,dx,dy=require('ui.WorkshopEntrance').Group(ws,i)
                data.workshop.entrance.groups[i]={opacity=alpha,translateX=dx,translateY=dy}
            end
        end
    end
    if home and home.musicBox then
        local mb=home.musicBox;local p=mb.player
        data.music={filter=mb.filter,query=mb.query,count=#mb.tracks,mode=p.playMode,paused=p.userPaused,volume=p.volume,status=p:Status(),pending=p.pending,
            track=p:Track() and p:Track().id,position=p:Position(),duration=p:Duration(),favorites=p.favorites,errors=p.errors,layout=mb.layout,
            menu=mb.modeMenu:IsVisible(),rects={}}
        for name,widget in pairs({search=mb.search,seek=mb.seek,volume=mb.volume,frame=mb.frame,list=mb.list}) do
            local r=widget:GetAbsoluteLayoutForHitTest();data.music.rects[name]={r.x,r.y,r.w,r.h}
        end
    end
    if home and home.livery then
        local lv=home.livery;local session=lv.session;local layer=app.car.livery
        data.livery={group=lv.group,selected=session.sel,pick=session.pick,list=session:List(),count=#session:List(),hi=session.hi,history=#session.history,
            propHeight=lv.propHeight,meshes=0,vertices=0,rects={},surfaces={},gizmo=lv.controls:Gizmo()}
        for _,mesh in pairs(layer.meshes) do data.livery.meshes=data.livery.meshes+1;data.livery.vertices=data.livery.vertices+#mesh.vertices end
        for name,widget in pairs({lib=lv.lib,props=lv.props,grid=lv.grid,layers=lv.layers,size=lv.sliders.size,rotation=lv.sliders.rotation}) do
            local r=widget:GetAbsoluteLayoutForHitTest();data.livery.rects[name]={r.x,r.y,r.w,r.h}
        end
        for _,visual in pairs(app.car.visuals) do if require('render.LiveryModel').Fixed(visual.part) then
            local p=visual.part;local screen=lv.controls:Screen({p.pos[1],p.pos[2]+1,p.pos[3]})
            if screen and screen.x>340 and screen.x<w-340 and screen.y>80 and screen.y<h-130 then
                local hit=lv.controls:Surface(screen.x,screen.y)
                if hit then data.livery.surfaces[#data.livery.surfaces+1]={screen.x,screen.y,hit};if #data.livery.surfaces>=8 then break end end
            end
        end end
    end
    data.modeChoice=home and home.modeChoice;data.storyLevel=home and home.storyLevel
    data.salvage=home and home.salvage;data.lobby=app.lobby or 'arena';data.mapPreview=app.mapPreview~=nil
    data.previewMap=app.mapPreview and app.mapPreview.map.id;data.sceneVisible=renderer:GetViewport(0)~=nil
    data.loading={state=app.loader.state,phase=app.loader.phase,progress=app.loader.progress,
        pending=app.pendingMap and app.pendingMap.id,downloads=app.loader.gate.total,completed=app.loader.gate.completed}
    data.mode='hangar';data.loadingFlow=app.loadingFlow:Snapshot()
    data.loadingFlow.backRect=app.loadingFlow.page.backRect
    data.craterModelResident=cache:GetExistingResource('Model','Crater/mesh-0.bin')~=nil
    data.vehicleLoading={busy=app.vehicleSwitch and app.vehicleSwitch:IsBusy() or false,
        ready=app.vehicleSwitch and app.vehicleSwitch.pending and app.vehicleSwitch.pending.ready or false,
        state=app.vehicleSwitch and app.vehicleSwitch.gate.state or '',draft=app.vehicleGate.state}
    data.garage={used=home and home.usedCount or 0,active=app.bays.active}
    data.garage.slots={}
    for i,slot in ipairs(app.bays:Slots()) do data.garage.slots[i]=slot and {name=slot.name,parts=#slot.parts} or false end
    data.carVisuals=0
    for _ in pairs(app.car.visuals) do data.carVisuals=data.carVisuals+1 end
    if app.build then
        local ghost=app.build.ghost
        data.ghost={ready=ghost.ready,state=ghost.gate.state,type=app.editor.type,warmKey=ghost.warmKey,pool=#ghost.pool}
    end
    if app.warehouse then data.warehouse={ready=app.warehouse.ready,cursor=app.warehouse.cursor,hallVisible=app.hangar.root.enabled,
        effects=app.warehouse.effects and {time=app.warehouse.effects.time,uploads=app.warehouse.effects.uploads,particles=#app.warehouse.effectData.dust.positions}} end
    local scale=app.graphicsSettings.sceneScale
    if scale then data.render={scale.graph.width,scale.graph.height} end
    local preview=home and home.workshopPreview
    if home and home.storyHolo then data.story={ready=home.storyHolo.ready,cursor=home.storyHolo.cursor,gate=home.storyHolo.gate.state,completed=home.storyHolo.gate.completed,total=home.storyHolo.gate.total,level=home.storyHolo.level,az=home.storyHolo.view.az,el=home.storyHolo.view.el,zoom=home.storyHolo.view.zoom} end
    if preview then data.preview={ready=preview.ready,cursor=preview.cursor,total=#preview.parts,complete=preview.ready and preview.cursor>#preview.parts} end
    local mouse=input.mousePosition;local hit=UI.FindWidgetAt(mouse.x/UI.GetScale(),mouse.y/UI.GetScale())
    data.mouse={x=mouse.x,y=mouse.y,scale=UI.GetScale(),hit=hit and hit.props.text or 'other',overlay=UI.GetTopOverlay()~=nil}
    local function Walk(widget,shown)
        shown=shown and widget:IsVisible()
        if not shown then return end
        local p=widget.props
        if p.onClick then
            local r=widget:GetAbsoluteLayoutForHitTest()
            if r.w>0 and r.h>0 then
                local motion=widget.cardMotion
                local inv=widget.inventoryMotion;local feedback=widget.inventoryFeedback
                data.widgets[#data.widgets+1]={text=p.text or '',icon=p.icon or '',part=p.partType,kind=p.sourceKind or p.kind,styleWidth=p.width,styleHeight=p.height,selected=p.selected,disabled=p.disabled,rect={r.x,r.y,r.w,r.h},
                    entrance={opacity=p.opacity or 1,translateX=p.translateX or 0,translateY=p.translateY or 0},
                    card=motion and {hovered=widget.state.hovered or false,lift=motion.lift.value,image=motion.image.value,reveal=motion.reveal.value,opacity=motion.opacity.value},
                    heroTitleSize=widget.heroTitleSize,
                    sourceMotion=widget.sourceMotion,hovered=widget.state.hovered,pressed=widget.state.pressed,
                    inventoryMotion=inv and {entry=inv.entry,image={value=inv.image.value},budget={value=inv.budget.value},hover={value=inv.hover.value}},
                    inventoryFeedback=feedback and {y=feedback.y.value,hover=feedback.hover.value,active=feedback.active and feedback.active.value},dropTarget=p.dropTarget,
                    focused=UI.GetFocus()==widget,
                    tabContent=widget.GetTabContent and widget:GetTabContent(UI.GetNVGContext()),
                    shelfContent=widget.GetShelfContent and widget:GetShelfContent(UI.GetNVGContext())}
            end
        end
        for _,child in ipairs(widget.children or {}) do Walk(child,shown) end
    end
    local root=UI.GetRoot();if root then Walk(root,true) end
    local modal=app.build and app.build.dialog or home and home.dialog
    if modal then
        Walk(modal,true)
        if modal.contentContainer_ then Walk(modal.contentContainer_,true) end
        if modal.footerWidget_ then Walk(modal.footerWidget_,true) end
    end
    local inventory=app.build and app.build.inventoryPanel
    if inventory then
        local focus=UI.GetFocus()
        local fp=focus and focus.props or {}
        data.inventoryState={current=inventory.model:Current(),active=inventory.model.active,hotbar=inventory.model.hotbar,
            drag=inventory.dragType,dragPoint=inventory.dragPoint,
            shown=inventory.shown,query=inventory.model.query,scroll=inventory.list.scrollOffset_,pool=inventory.list:GetPoolStats(),
            last=inventory.results[#inventory.results] and inventory.results[#inventory.results].id,
            focus=focus and {part=fp.partType,kind=fp.kind,slot=fp.inventoryStyle and fp.index,
                search=focus==inventory.search,close=focus==inventory.closeButton} or false}
        Walk(inventory.body,true)
        local close=inventory.closeButton
        local r=close:GetAbsoluteLayoutForHitTest()
        if r.w>0 and r.h>0 then data.widgets[#data.widgets+1]={text='关闭',rect={r.x,r.y,r.w,r.h}} end
    end
    data.frames=FrameStats()
    if VOX_QA_MISSILES then data.widgets=nil;data.homeRects=nil;data.hangar=nil;data.anchors=nil end
    print('OUTGAME_STATE '..cjson.encode(data))
end
function HandleUpdate(et,ed)
    original(et,ed)
    local app=VOX_HANGAR and VOX_HANGAR.app or VOX_TRIAL and VOX_TRIAL.app
    if not app then return end
    frames=frames+1
    local mode=app.trial and app.trial.map.id or app.build and 'build' or 'hangar'
    if mode~=sampleMode or app.loadingFlow.active then samples={};sampleMode=mode
    else local dt=ed:GetFloat('TimeStep');if dt>0 then samples[#samples+1]=dt end end
    if app.trial then
        local salvage=app.trial.salvage
        if salvage and not salvage.rules.finished then
            local session=app.trial
            if input:GetKeyPress(KEY_F4) then
                for _,o in ipairs(salvage.rules.objects) do if o.ctype=='supply' and not salvage.rules.opened[o.id] then
                    salvage.qaCrate=o
                    session.vehicle:Place({o.g[1],o.g[2]+2,o.g[3]},0);session.view:ResetPose();session:PostUpdate(.1);break
                end end
            end
            if input:GetKeyPress(KEY_F11) and salvage.qaCrate then
                -- Deterministic rare reveal fixture; production SearchStep owns pickup.
                local id;for key,item in pairs(require('core.ResourceData').Read('UI/Outgame.json').items) do if item.rarity==4 then id=key;break end end
                salvage.rules:Open(salvage.qaCrate)
                local search=salvage.rules.search;search.items={{id=id,n=1,r=4,t=1,state='hidden'}};search.i=1;search.p=0;search.wait=0;search.held=false;search.done=false
            end
            if input:GetKeyPress(KEY_F7) then
                for _,e in ipairs(salvage.rules.extracts) do if not e.needs and not e.maxWidth and not e.loud then
                    salvage.rules.time=math.max(salvage.rules.time,(e.openAt or 0)+1)
                    session.vehicle:Place({e.g[1],e.g[2]+2,e.g[3]},0);session.view:ResetPose();session:PostUpdate(.1);break
                end end
            end
        end
        local story=app.trial.story
        if story then
            if input:GetKeyPress(KEY_F3) and story.player.alive then
                local u=story.player;u.struct=0
                u:Damage(u.bp:CoreParts()[1].id,u.bodyHpMax*.2,u:Position());u:Flush()
            end
            if story.rules.cap and input:GetKeyPress(KEY_F10) then
                for i=2,#story.entries do local entry=story.entries[i];local u=entry.unit
                    if entry.flee then for _,p in ipairs(u.bp:List()) do if p.type~='core' and u:Integrity()>=.59 then u:Destroy(p.id) end end end
                end
            end
            if story.rules.hold and input:GetKeyPress(KEY_F9) then
                local r=story.rules
                r.stepT=r.stepT<8 and 8 or r.stepT<36 and 36 or r.stepT<56 and 56 or r.stepT<66 and 66 or r.stepT<84 and 84 or r.stepT<104 and 104 or 126
                r.hold.left=r.stepT>=126 and .001 or math.max(1,124-r.stepT)
                story:Place({pos={0,6,-234},yaw=0});app.trial.view:ResetPose();app.trial.view:Update(1)
            end
            if story.rules.hold and input:GetKeyPress(KEY_F10) then
                story.rules.hold.energy=.00001
                story:Spawn({enemies={{at={0,8,-234},role='assault',name='QA shield attacker'}}})
            end
            if story.convoy and input:GetKeyPress(KEY_F9) then
                local c=story.convoy;local p=c.d/c.total;local nextP=p<.15 and .16 or p<.5 and .51 or p<.76 and .77 or .99999
                c.d=c.total*nextP;c.pos=c:Along(c.d);story.rules.progress=nextP
                story:Place({pos=c.pos,yaw=c.yaw});app.trial.view:ResetPose();app.trial.view:Update(1)
            end
            if story.convoy and input:GetKeyPress(KEY_F10) then
                local c=story.convoy;c.hp=.00001
                story:Spawn({enemies={{at={c.pos[1],c.pos[2],c.pos[3]},role='assault',target='truck',name='QA transport attacker'}}})
            end
            if input:GetKeyPress(KEY_F4) and story.player.alive then
                local spec=story.rules:StepSpec();local target=story.rules.cap and spec and spec.pos or story.rules:Target()
                if target then story:Place({pos=target,yaw=0});app.trial.view:ResetPose();app.trial.view:Update(1);app.trial:PostUpdate(.1) end
            end
            if input:GetKeyPress(KEY_F2) then
                for i=2,#story.entries do local u=story.entries[i].unit;u.kill='QA combat destruction';u.dirty=true;u:Flush() end
            end
            if input:GetKeyPress(KEY_F6) and story.player.alive then
                local u=story.player;u.struct=0;u:Damage(u.bp:CoreParts()[1].id,1e9,u:Position());u:Flush()
            end
        end
        if input:GetKeyPress(KEY_F3) and not app.trial.combat then
            local s=app.trial;local target=s.world.targets[1]
            target.node.position=Vector3(-155,10.4,20);target.native.position=target.node.position;target.pos={155,12,20};target.hp=10000
            s.vehicle:Place({155,0,-140},0);s.view:ResetPose();s.yaw=0;s.pitch=0;s.follow=false;s:PostUpdate(1)
            for i,g in ipairs(s.weapons.groups) do if g.kind=='missile' then s.weapons:Select(i) end end
        end
        local key=app.loadingFlow.phase..':'..tostring(app.trial.pointer.captured)..':'..tostring(app.trial.pointer.pending)
        if frames%30==0 or input:GetKeyPress(KEY_F8) then previous=key;DumpTrial(app) end
        return
    end
    if input:GetKeyPress(KEY_F2) then
        if app:EnterTrial('trial') then app.loader.options.prepare=function() error('QA intentional preparation failure') end end
    end
    if input:GetKeyPress(KEY_F3) then
        _G.VOX_QA_MISSILES=true
        local bp=require('construction.Prefab').Create(require('construction.Blueprint').New(),'miniHeavy'):ToTable()
        app:WithVehicle(bp,function() return app:LoadBlueprint(bp) end)
    end
    if input:GetKeyPress(KEY_F12) and app.tutorial and not app.build and require('ui.GarageHud').GetState().tab=='hangar' then app.tutorial:Start() end
    if input.mouseMoveWheel~=0 then print('OUTGAME_WHEEL '..cjson.encode({raw=input.mouseMoveWheel,dist=app.camera.dist,build=app.build~=nil})) end
    if input:GetKeyPress(KEY_F6) then app:PreviewMap(app.selectedMap or 'trial') end
    if input:GetKeyPress(KEY_F7) then app:PreviewMap('crater') end -- QA only: exercises the production map gate.
    if input:GetKeyPress(KEY_F9) then
        -- Fixed source station/time for scene comparison; this probe never ships.
        _G.VOX_DEBUG={time=10}
        local pose=require('controls.HomeStations').Get(app.blueprint:Stats(),'hangar',app.camera.maxDist)
        app:View(pose);app.hangar:SetGrid(false);app.hangar:UpdateGrid(1)
    end
    if input:GetKeyPress(KEY_F10) then renderer.drawShadows=not renderer.drawShadows end
    if input:GetKeyPress(KEY_F11) then
        app.hangar.qaPanelsOff=not app.hangar.qaPanelsOff
        for _,material in ipairs(app.hangar.materials) do
            local value=material:GetShaderParameter('panel_on')
            if value.type~=VAR_NONE then
                if material:GetShaderParameter('qa_original_panel').type==VAR_NONE then material:SetShaderParameter('qa_original_panel',value) end
                material:SetShaderParameter('panel_on',app.hangar.qaPanelsOff and Variant(0) or material:GetShaderParameter('qa_original_panel'))
            end
        end
    end
    local home=require('ui.GarageHud').GetState()
    if input:GetKeyPress(KEY_INSERT) and home and home.tab=='hangar' and not app.build then
        local bp=require('construction.Blueprint').New();local id=require('core.Rotations').IDENTITY
        for _,p in ipairs({{type='core',pos={0,3,0},rot=id},{type='rotorStep',pos={0,4,0},rot=id},
            {type='cube',pos={0,5,0},rot=id,g=7},{type='cube',pos={1,5,0},rot=id,g=7},
            {type='cube',pos={2,5,0},rot=id,g=7},{type='laser1',pos={0,6,0},rot=id}}) do bp:Add(p) end
        app.qaRotorGate=require('app.ResourceGate').New()
        local scene=app.scene
        app.qaRotorGate:Start(require('parts.Dependencies').For(bp:List()),function(ready,message)
            if not ready then error(message) end
            if app.scene~=scene or app.stopped then return end
            local ok,why=app:LoadBlueprint(bp:ToTable());assert(ok,why)
            app:EnterBuild();app.build.editor.mirror=false
            local fly=app.build.buildCamera;local ry=(app.blueprint.parts[2].pos[2]+.5)*require('Config').CELL
            fly:FocusAt(Vector3(0,ry,0),5)
            if fly.mode=='fp' then
                fly.flight=require('controls.FreeFlight').New({4,ry,-5},require('core.Math3').Normalize({-4,0,5}),fly.flight.limit);fly:Apply()
            end
            print('[RotorQA] Authored fixture ready after model gate')
        end)
    end
    if input:GetKeyPress(KEY_F4) and home and home.tab=='workshop' then home.WorkshopOpen('megaMech') end
    if home and home.workshop and home.workshop.view=='feature' then
        local ws=home.workshop
        if input:GetKeyPress(KEY_F12) then
            ws.qaCaptionStep=(ws.qaCaptionStep or 0)%5+1
            ws.qaCaptionTime=({.08,.3,.46,.62,false})[ws.qaCaptionStep]
        end
        if ws.caption and ws.qaCaptionTime then
            ws.caption.elapsed=math.min(.46,ws.qaCaptionTime);ws.caption.distance=24
            ws.shelf.elapsed=ws.qaCaptionTime
            home.page:Update(0)
        end
    end
    if home and home.workshop and home.workshop.view~='feature' then
        local ws=home.workshop
        if input:GetKeyPress(KEY_F12) then
            ws.qaEntranceStep=(ws.qaEntranceStep or 0)%6+1
            ws.qaEntranceTime=({.08,.3,.5,.74,.9,false})[ws.qaEntranceStep]
        end
        if ws.entrance and ws.qaEntranceTime then
            ws.entrance.elapsed=math.min(ws.entrance.kind=='detail' and .9 or ws.entrance.kind=='grid' and .82 or .74,ws.qaEntranceTime)
            home.page:Update(0)
        end
    end
    local preview=home and home.workshopPreview
    local key=tostring(home and home.tab)..':'..tostring(home and home.workshop and home.workshop.view)..':'..tostring(home and home.salvage and home.salvage.tab)..':'..tostring(app.mapPreview~=nil)..':'..tostring(preview and preview.ready and preview.cursor>#preview.parts)..':'..tostring(app.build~=nil)..':'..tostring(app.build and app.build.inventoryPanel~=nil)..':'..graphics:GetWidth()..':'..graphics:GetHeight()
    local story=home and home.storyHolo
    key=key..':'..tostring(story and story.ready)..':'..tostring(story and story.gate.state)..':'..tostring(story and story.level)
    key=key..':'..tostring(app.warehouse and app.warehouse.ready)..':'..tostring(app.build and app.build.dialog~=nil)
    key=key..':'..app.loader.state..':'..app.loader.phase..':'..app.loader.gate.completed
    key=key..':'..app.loadingFlow.phase..':'..tostring(app.loadingFlow.failed)..':'..tostring(app.loadingFlow.match and app.loadingFlow.match.stage)
    key=key..':'..tostring(app.vehicleSwitch and app.vehicleSwitch.pending~=nil)..':'..app.blueprint.name..':'..app.bays.revision
    key=key..':'..app.vehicleGate.state
    if app.build then key=key..':'..app.editor.type..':'..app.build.ghost.gate.state end
    key=key..':'..tostring(home and home.workshop and home.workshop.selected)..':'..tostring(home and home.workshop and home.workshop.pending)..':'..tostring(home and home.musicBox~=nil)
    local mb=home and home.musicBox
    if mb then key=key..':'..tostring(mb.player.pending)..':'..tostring(mb.player:Track() and mb.player:Track().id)..':'..mb.filter..':'..mb.query..':'..tostring(mb.player.userPaused)..':'..mb.player.playMode..':'..tostring(mb.modeMenu:IsVisible())..':'..tostring(mb.player.volume) end
    if frames%30==0 and key~=previous or input:GetKeyPress(KEY_F8) then previous=key;Dump(app) end
end

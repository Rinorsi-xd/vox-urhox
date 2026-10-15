-- Native candidate fixture. No fake Material, StaticModel, VehicleView or xray objects.
-- Damage calls below are explicit isolated-fixture actions, not live battle inputs.
local UI=require 'urhox-libs/UI'
local View=require 'render.VehicleView'
local Xray=require 'render.BuildXray'
local Shell=require 'render.ShellMaterials'
local Materials=require 'parts.Materials'
local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Config=require 'Config'
local reportPath,out
for _,arg in ipairs(GetArguments())do
    reportPath=arg:match('^%-shell%-native%-output=(.+)$') or reportPath
    out=arg:match('^%-shell%-native%-directory=(.+)$') or out
end
assert(reportPath and out,'native shell output paths required')
local report={schema=1,complete=false,checks={},captures={},materials={},cycles={},
    graphicsApi=graphics.apiName,thresholdMs=100,
    boundary='Native isolated rendered production material/view fixture. Explicit fixture Damage/Flush, no public-input combat, Web, mobile, whole-game parity or performance acceptance. Not manifest706d.'}
local function Write()
    local file=assert(io.open(reportPath,'wb'));file:write(cjson.encode(report));file:close()
end
local function Stage(name)report.stage=name;Write()end
local function Check(ok,label)
    report.checks[#report.checks+1]={name=label,pass=ok==true};Write();V.assert(ok,label);assert(ok,label)
end
local function Pause(frames)for _=1,frames do coroutine.yield()end end
local function SameColor(a,b)
    return math.abs(a.r-b.r)<1e-6 and math.abs(a.g-b.g)<1e-6 and math.abs(a.b-b.b)<1e-6 and math.abs(a.a-b.a)<1e-6
end
local function Snapshot(material,name)
    local floats={'roughness_value','metallic_value','clearcoat_value','clearcoat_roughness_value','hemi_intensity'}
    local snapshot={name=name,parameters={},vertexDefines=material:GetVertexShaderDefines(),pixelDefines=material:GetPixelShaderDefines(),
        cull=material:GetCullMode(),shadowCull=material:GetShadowCullMode(),fill=material:GetFillMode(),
        alphaToCoverage=material:GetAlphaToCoverage(),lineAntiAlias=material:GetLineAntiAlias(),
        renderOrder=material:GetRenderOrder(),occlusion=material:GetOcclusion(),specular=material:GetSpecular(),
        shader=material:GetSurfaceShader():GetName(),techniques=material:GetNumTechniques()}
    for _,key in ipairs(floats)do snapshot.parameters[key]=material:GetShaderParameter(key):ToString()end
    for _,key in ipairs({'hemi_sky','hemi_ground'})do snapshot.parameters[key]=material:GetShaderParameter(key):ToString()end
    local color=material:GetShaderParameter('base_color'):GetColor();snapshot.baseColor={color.r,color.g,color.b,color.a}
    local filename=out..'/'..name..'.material.json'
    Check(material:SaveJSON(filename),'serialize exact native material '..name)
    report.materials[#report.materials+1]=snapshot;Write();return snapshot
end
local function ExactExceptColor(base,variant,label)
    local a,b=Snapshot(base,label..'-base'),Snapshot(variant,label..'-variant')
    -- Compare values structurally; JSON object key order is intentionally ignored.
    local function Same(x,y)
        if type(x)~=type(y)then return false end
        if type(x)~='table'then return x==y end
        for k,v in pairs(x)do if not Same(v,y[k])then return false end end
        for k in pairs(y)do if x[k]==nil then return false end end
        return true
    end
    local exact=true
    for key,value in pairs(a)do if key~='name' and key~='baseColor' and not Same(value,b[key])then exact=false end end
    Check(exact,label..' retains exact native shader/parameters/render state')
    for _,unit in ipairs({TU_DIFFUSE,TU_NORMAL,TU_SPECULAR,TU_EMISSIVE,TU_ENVIRONMENT})do
        Check(base:GetTexture(unit)==variant:GetTexture(unit),label..' exact native texture identity '..unit)
    end
end
local scene,camera,viewport,oldViewport,oldRoot,fixtureRoot
local owners={};local created,retired={},{}
local originalApply,originalRelease=Shell.Apply,Shell.Release
local observing=false
local function Observe()
    -- Observe Lua leases while every operation still uses actual native Material.
    -- Overriding tolua native class methods is unsupported and can recurse.
    Shell.Apply=function(vis,...)
        local result=originalApply(vis,...)
        if vis.shellLease then created[vis.shellMaterial]=vis.shellLease end
        for material,lease in pairs(created)do if lease.refs==0 then retired[material]=true end end
        return result
    end
    Shell.Release=function(vis,...)
        local result=originalRelease(vis,...)
        for material,lease in pairs(created)do if lease.refs==0 then retired[material]=true end end
        return result
    end
    observing=true
    Check(Materials.Get('armorWhite'):GetTypeName()=='Material','production shell base is actual native Material')
end
local function StopObserving()
    if not observing then return end
    Shell.Apply=originalApply;Shell.Release=originalRelease;observing=false
end
local function NewOwner(name)
    local view=View.New(scene,name);owners[#owners+1]=view;return view
end
local function Forget(view)
    for i,owner in ipairs(owners)do if owner==view then table.remove(owners,i);break end end
end
local function DisposeOwner(view)view:Dispose();Forget(view)end
local function AliveClones()
    local n=0;for material in pairs(created)do if not retired[material]then n=n+1 end end;return n
end
local damage
local function Cleanup()
    if damage then
        if damage.unit then damage.unit:Dispose()end
        damage.world.debris:Clear();damage.view:Consume(damage.world);damage.view:Dispose()
        damage.world.space:Dispose();damage=nil
    end
    for i=#owners,1,-1 do owners[i]:Dispose();owners[i]=nil end
    if oldViewport then renderer:SetViewport(0,oldViewport)end
    if oldRoot then UI.SetRoot(oldRoot,false)end
    if fixtureRoot then fixtureRoot:Destroy();fixtureRoot=nil end
    if scene then scene:Dispose();scene=nil end
    StopObserving()
end
local function Shot(name)
    Check(not VOX_HANGAR.app.loadingFlow.active and not VOX_HANGAR.app.loadingFlow.pageVisible,'loading overlay actually closed before '..name)
    Check(renderer:GetViewport(0)==viewport and UI.GetRoot()==fixtureRoot,'fixture owns actual native viewport and root '..name)
    local image=Image:new();assert(graphics:TakeScreenShot(image),'native screenshot readback')
    local w,h=image:GetWidth(),image:GetHeight();local min,max,sum,sum2=1,0,0,0;local count=0
    for y=math.floor(h*.15),math.floor(h*.85),math.max(1,math.floor(h/60))do
        for x=math.floor(w*.15),math.floor(w*.85),math.max(1,math.floor(w/100))do
            local c=image:GetPixel(x,y);local l=(c.r+c.g+c.b)/3
            min=math.min(min,l);max=math.max(max,l);sum=sum+l;sum2=sum2+l*l;count=count+1
        end
    end
    local variance=sum2/count-(sum/count)^2
    local path=out..'/'..name..'.png';Check(image:SavePNG(path),'save native rendered '..name);image:Dispose()
    report.captures[#report.captures+1]={name=name,path=path,width=w,height=h,min=min,max=max,variance=variance,
        batches=renderer.numBatches,primitives=renderer.numPrimitives}
    Check(max-min>.04 and variance>.00005 and renderer.numBatches>0,'nonblank native 3D pixels '..name);Write()
end
local function Frame(view)
    view.joined:Update();view.livery:Update()
    local box=view:GetWorldBounds();local center=box.center;local size=box.size
    local radius=math.max(size.x,size.y,size.z,2)
    camera.position=center+Vector3(radius*.9,radius*.65,-radius*1.2)
    camera:LookAt(center)
end
local function Build(name,x)
    local bp=Prefab.Create(BP.New(),name);local view=NewOwner(name)
    view:Rebuild(bp);view.root.position=Vector3(x or 0,0,0);return bp,view
end
local function ShellParts(view,bp)
    local found={}
    for _,part in ipairs(bp:List())do
        local vis=view.visuals[part.id]
        if #vis.shellSlots>0 and part.shellColor~=nil and part.shellColor~=cjson.null then found[#found+1]=part end
    end
    return found
end
local function CheckBindings(vis,expected,label)
    for _,slot in ipairs(vis.shellSlots)do Check(slot.model:GetMaterial(slot.index)==expected,label)end
end
local function NativeDamage()
    local Space=require 'physics.Space';local Track=require 'drive.TrackWorld';local Debris=require 'combat.Debris'
    local Unit=require 'combat.CarUnit';local Combat=require 'render.CombatView'
    local world=setmetatable({scene=scene,space=Space.New(scene),time=0,viewEvents={},fx={},units={},
        stats={shots=0,hits=0,damage=0,kills=0},metrics=require('drive.TrialMetrics').New({})},Track)
    world.debris=Debris.New(world.space)
    damage={world=world,view=Combat.New(scene)}
    local bp=Prefab.Create(BP.New(),'scorpion')
    damage.unit=Unit.New(world,bp:ToTable(),{name='Native shell damage fixture',spawn={pos={0,0,0},yaw=0},
        combat=false,autoRespawn=false,externalControl=true},nil,function(unit)damage.unit=unit end)
    world.units={damage.unit};damage.view:Consume(world)
    local drive=assert(damage.view.units[damage.unit]);local shells=ShellParts(drive.view,damage.unit.bp)
    Check(#shells>1,'real native combat vehicle contains authored colored shell parts')
    local target=shells[#shells];local before=drive.view.visuals[target.id];local material=before.shellMaterial
    Frame(drive.view);Pause(4);Shot('damage-before')
    local start=Time:GetSystemTime()
    local amount=damage.unit:Damage(target.id,1e9,{0,0,0});damage.unit:Flush();damage.view:Consume(world)
    report.damage={targetId=target.id,type=target.type,amount=amount,wallMs=(Time:GetSystemTime()-start)&0xffffffff,
        alive=damage.unit.alive,debris=#world.debris.pieces,transferred=damage.view.lastTransferred}
    Check(amount>0,'actual production Damage/Flush removes shell target')
    local living=damage.view.units[damage.unit]
    Check(not living or living.view.visuals[target.id]==nil,'damaged part absent from surviving actual native vehicle view')
    for _,piece in pairs(damage.view.pieces)do
        for _,vis in pairs(piece.view.visuals)do
            if vis.shellMaterial then Check(not retired[vis.shellMaterial],'actual detached native visual keeps live shell material')end
        end
    end
    Pause(4);Shot('damage-after')
    damage.unit:Dispose();damage.unit=nil;damage.view:Consume(world)
    world.debris:Clear();damage.view:Consume(world);damage.view:Dispose();world.space:Dispose();damage=nil
    Check(retired[material]==true,'actual damage/debris teardown retires former shell material')
end
local function Run()
    while not (rawget(_G,'VOX_HANGAR') and VOX_HANGAR.app and VOX_HANGAR.app.car)do Pause(1)end
    Stage('wait for real boot overlay to close')
    while VOX_HANGAR.app.loadingFlow and (VOX_HANGAR.app.loadingFlow.active or VOX_HANGAR.app.loadingFlow.pageVisible)do Pause(1)end
    Stage('capture existing viewport/root')
    oldViewport=renderer:GetViewport(0);oldRoot=UI.GetRoot()
    Stage('replace fixture UI root')
    fixtureRoot=UI.Panel{width='100%',height='100%',pointerEvents='none'};UI.SetRoot(fixtureRoot,false)
    Stage('create retained native scene')
    scene=Scene();scene:CreateComponent('Octree')
    Stage('create native zone')
    local zone=scene:CreateChild('ShellFixtureZone'):CreateComponent('Zone')
    zone.boundingBox=BoundingBox(Vector3(-500,-100,-500),Vector3(500,200,500));zone.ambientSource=AMBIENT_COLOR
    zone.ambientColor=Color(.3,.3,.3);zone.fogColor=Color(.04,.05,.07)
    Stage('create native lighting')
    local light=scene:CreateChild('ShellFixtureSun');light.rotation=Quaternion(35,-35,0)
    local sun=light:CreateComponent('Light');sun.lightType=LIGHT_DIRECTIONAL;sun.color=Color(1,.95,.9);sun.brightness=1.3
    Stage('create native camera/viewport')
    camera=scene:CreateChild('ShellFixtureCamera');local cam=camera:CreateComponent('Camera');cam.fov=50;cam.farClip=1000
    viewport=Viewport:new(scene,cam);renderer:SetViewport(0,viewport)
    Stage('observe production Lua lease lifecycle')
    Observe()
    for _,name in ipairs({'scorpion','fox','trooper','manta'})do
        Stage('native preset '..name)
        local bp,a=Build(name,0);local other,b=Build(name,0);b.root.enabled=false
        local shells=ShellParts(a,bp);report.cycles[#report.cycles+1]={preset=name,parts=bp:Size(),coloredShellParts=#shells}
        Check(#shells>1,name..' has multiple authored shell parts')
        local first=shells[1];local av=a.visuals[first.id];local bv=b.visuals[first.id];local shared=av.shellMaterial
        Check(shared~=nil and shared==bv.shellMaterial,name..' shares exact native shell across two vehicles')
        local unique,count={},0
        for _,part in ipairs(shells)do local vis=a.visuals[part.id];unique[vis.shellMaterial]=true
            Check(SameColor(vis.shellMaterial:GetShaderParameter('base_color'):GetColor(),Config.HexLinear(part.shellColor)),name..' actual native shell color '..part.id)
        end
        for _ in pairs(unique)do count=count+1 end
        report.cycles[#report.cycles].uniqueMaterials=count
        ExactExceptColor(Materials.Get('armorWhite'),shared,name)
        Frame(a);Pause(4);Shot(name..'-shared')
        local originalColor=first.shellColor;first.shellColor=0x19bf63;a:Repaint(first)
        Check(av.shellMaterial~=shared and bv.shellMaterial==shared and not retired[shared],name..' native repaint isolates other vehicle')
        CheckBindings(av,av.shellMaterial,name..' native repaint binds all shell slots')
        Pause(3);Shot(name..'-repaint')
        -- Machinery shell slots intentionally stay solid; directly attach an
        -- actual production xray original record to verify its SetBase route.
        local xr=Xray.New();local oldInstanced=av.instanced;av.instanced=true
        for _,model in ipairs(av.models)do
            if not av.materialSlots[model]then
                av.materialSlots[model]={};for i=0,model:GetNumGeometries()-1 do av.materialSlots[model][i+1]='armorWhite'end
            end
        end
        xr:Attach(av);local xrayOriginals=av.xrayOriginals
        Check(xrayOriginals~=nil,name..' production xray attaches actual native models')
        first.shellColor=0xf0a020;a:Repaint(first)
        for _,slot in ipairs(av.shellSlots)do
            Check(slot.model:GetMaterial(slot.index)==xr.other,name..' xray stays bound during shell repaint')
            Check(xrayOriginals[slot.model].materials[slot.index+1]==av.shellMaterial,name..' hidden original updated')
        end
        Pause(3);Shot(name..'-xray')
        Xray.Restore(av);av.instanced=oldInstanced;xr:Dispose()
        CheckBindings(av,av.shellMaterial,name..' xray restores new native shell')
        first.shellColor=cjson.null;a:Repaint(first)
        CheckBindings(av,Materials.Get('armorWhite'),name..' null restores exact native base')
        first.shellColor=originalColor;a:Repaint(first)
        Check(av.shellMaterial==shared,name..' repaint rejoins live shared native material')
        a:RemovePart(first.id);Check(not retired[shared],name..' removal retains other native owner')
        av=a:AddPart(first);Check(av.shellMaterial==shared,name..' restored native part rejoins same material')
        Pause(3);Shot(name..'-restored')
        DisposeOwner(a);DisposeOwner(b)
        Check(retired[shared]==true,name..' last real owner reaches production zero-ref native disposal path')
        Check(AliveClones()==0,name..' no clone retained after both actual vehicles retire')
    end
    Stage('actual native damage fixture');NativeDamage()
    for cycle=1,3 do
        local bp,view=Build('fox',0);Frame(view);Pause(2);view:Clear();view:Rebuild(bp);Pause(2)
        DisposeOwner(view);Check(AliveClones()==0,'native repeated rebuild/clear cycle '..cycle..' releases clones')
    end
    local remaining=scene:GetNumChildren(true)
    report.sceneChildrenBeforeCleanup=remaining;report.clonesCreated=0;report.clonesDisposed=0
    for material in pairs(created)do report.clonesCreated=report.clonesCreated+1;if retired[material]then report.clonesDisposed=report.clonesDisposed+1 end end
    Check(report.clonesCreated==report.clonesDisposed,'every native shell lease reaches production zero-ref disposal path')
    Cleanup();report.complete=true;Write();V.finish()
end
local worker=coroutine.create(Run)
for frame=20,620 do V.atFrame(frame,function()
    if coroutine.status(worker)=='dead'then return end
    local ok,err=coroutine.resume(worker)
    if not ok then
        report.error=tostring(err)
        if debug and debug.traceback then report.traceback=debug.traceback(worker,tostring(err))end
        Write();local cleaned,why=pcall(Cleanup)
        if not cleaned then report.cleanupError=tostring(why);Write()end
        error(err)
    end
end)end
V.atFrame(625,function()Check(report.complete,'native shell fixture completed');V.finish()end)

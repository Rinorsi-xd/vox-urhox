-- Actual equipment, resource and batch modules; only native drawing APIs doubled.
COMBAT_WARMUP_TEST_HELPERS=true
local helper=assert(loadfile('tools/migration/check-combat-warmup.lua'))()
COMBAT_WARMUP_TEST_HELPERS=nil
cjson={null={}}
local Quality=require('render.Quality').current
Quality.exhaustParticles=256;Quality.equipmentFar=150
Quality.thrusterSteps=24;Quality.hoverSteps=12
local checks=0
local function check(value,label) assert(value,label);checks=checks+1 end
local materials={};local createMaterial=Material.new
function Material:new()
    local m=createMaterial(self);materials[#materials+1]=m
    function m:SetSurfaceTexture(name,value) self.textures=self.textures or {};self.textures[name]=value end
    return m
end
function cache:ReleaseResource() end
local createComponent=helper.Node.CreateComponent
function helper.Node:CreateComponent(kind)
    local d=createComponent(self,kind)
    function d:DefineNormal(value) self.normal=value end
    function d:DefineColor(value) self.color=value end
    function d:DefineTexCoord(value) self.uv=value end
    return d
end
local Equipment=require 'render.EquipmentEffects'
local Resources=require 'render.EquipmentResources'
local Warm=EQUIPMENT_WARMUP_SOURCE and assert(load(EQUIPMENT_WARMUP_SOURCE))() or require 'render.EquipmentWarmup'
local function drive(scene,family)
    local segments={[family]=true,info={nozzles={{p={0,0,0},radius=.2,dir={0,-1,0}}},joints={knee={0,0,0}}}}
    local emission={instanceCustomData=Vector4(.7,0,0,0)}
    local vis={data={segments=segments},emissionModels={emission},emissionDefault=.7}
    local e=Equipment.New(scene);e:Bind({visuals={[1]=vis}},{identity=family})
    local item=e.items[1];item.power=.31;item.credit=.63;e.random=13579;e.particles={{sentinel=true}}
    return {equipment=e},item,emission
end
local function fixture()
    local s=helper.session()
    local a,jet,emission=drive(s.scene,'thruster')
    local b,hover=drive(s.scene,'hover');local c,leg=drive(s.scene,'leg')
    s.view=a;s.combatView={units={[{}]=b,[{}]=c}}
    local p=a.equipment:Proxy(jet,1,'Thruster');p.model.instanceCustomData=Vector4(.31,.2,5,24)
    Resources.materials.Thruster:SetShaderParameter('clock',Variant(9.25))
    local state={users=Resources.users,material=Resources.materials.Thruster,proxy=p,
        position=p.node.position,custom=p.model.instanceCustomData,clock=Resources.materials.Thruster:GetShaderParameter('clock'),
        owner=a.equipment,items=a.equipment.items,particles=a.equipment.particles,emission=emission.instanceCustomData}
    return s,state,jet,hover,leg,emission
end
local function unchanged(s,state,jet,emission)
    check(state.owner.items==state.items and state.owner.particles==state.particles,'live collections unchanged')
    check(jet.power==.31 and jet.credit==.63 and state.owner.random==13579,'live power credit RNG unchanged')
    check(state.proxy.node.position==state.position and state.proxy.model.instanceCustomData==state.custom,'live proxy untouched')
    check(emission.instanceCustomData==state.emission,'live emissive setting untouched')
    check(state.material:GetShaderParameter('clock')==state.clock and not state.material.disposed,'shared material untouched')
    check(state.owner.vehicle.identity=='thruster','live vehicle untouched')
end
local function cleanup(s)
    s.view.equipment:Dispose()
    for _,d in pairs(s.combatView.units) do d.equipment:Dispose() end
    s.effects:Dispose();s.scene:Dispose()
    check(Resources.users==0,'all resource owners balanced')
end
local oldUpdate=Equipment.Update;local oldThruster=Equipment.Thruster
Equipment.Update=function() error('warmup called live simulation') end
Equipment.Thruster=function() error('warmup emitted exhaust') end
local random=math.random;math.random=function() error('warmup consumed global RNG') end
do
    local s=helper.session();check(Warm.New(s)==nil,'empty equipment skips all probes');s.effects:Dispose();s.scene:Dispose()
end
for cancelAt=0,2 do
    local s,state,jet,hover,leg,emission=fixture();local w=Warm.New(s)
    check(Resources.users==state.users+1,'one independent resource owner')
    check(not w.owner.root.enabled,'probes initially hidden')
    check(w:Snapshot().batches==4 and w:Snapshot().volumes==2,'all six real equipment shader families')
    unchanged(s,state,jet,emission)
    local ownedMaterials={};for _,b in pairs(w.owner.batches)do ownedMaterials[#ownedMaterials+1]=b.material end
    for _,copies in ipairs(cancelAt==0 and {} or cancelAt==1 and {4} or {4,1}) do
        w:Show(copies)
        check(w.owner.root.enabled,'probes enabled for presentation')
        for kind,b in pairs(w.owner.batches) do
            check(b.material.shader=='Shaders/BLGL/Equipment/'..kind..'.shader','production batch shader path')
            check(b.count==copies and b.mesh.enabled and b.mesh.commits>0 and b.mesh.vertices==copies*6,'batch actually committed and visible')
            check(b.mesh.normal and b.mesh.color and b.mesh.uv,'production normal color UV layout')
            if kind=='Flare' then check(b.mesh.normal.x==1 and b.mesh.normal.y==.37 and b.mesh.normal.z==1,'actual Flare power seed axial channels') end
        end
        for kind,item in pairs(w.kinds) do
            for i=1,4 do
                local p=item.proxies[i]
                check(p.model.material==Resources.materials[kind] and p.model.model==Resources.Box(),'actual shared volume model material')
                check(p.node.enabled==(i<=copies) and p.model.enabled==(i<=copies),'single and instanced volume visibility')
                check(p.model.instanceCustomData.x==1 and p.model.castShadows==false,'actual volume instance attributes')
                check(p.node.position.z==8,'volume in actual camera frustum')
            end
        end
        unchanged(s,state,jet,emission)
    end
    local root=w.owner.root;w:Dispose();w:Dispose();w:Show(4)
    check(root.disposed and w.owner==nil and w.camera==nil,'cancel and repeat disposal releases probes')
    for _,m in ipairs(ownedMaterials) do check(m.disposed,'owned batch material released') end
    check(Resources.users==state.users,'cancel balances only probe ownership')
    unchanged(s,state,jet,emission);cleanup(s)
end
do
    local s,state,jet,hover,leg,emission=fixture();local before=Resources.users
    local bind=Equipment.Bind
    Equipment.Bind=function(self,...) bind(self,...);error('injected bind failure') end
    local ok,err=pcall(Warm.New,s);Equipment.Bind=bind
    check(not ok and tostring(err):find('injected bind failure',1,true),'constructor failure propagates')
    check(Resources.users==before,'partial constructor releases equipment owner')
    unchanged(s,state,jet,emission);cleanup(s)
end
do
    local s,state,jet,hover,leg,emission=fixture();local w=helper.Warm.New(s);local phases={}
    local warm=w.equipmentWarmup;local root=warm.owner.root
    while not w.disposed do
        phases[#phases+1]=w.phase;check(#phases<40,'bounded presented progression')
        if w.phase=='equipment-instanced' or w.phase=='equipment-single' then
            check(warm.owner.root.enabled,'equipment phase is visible before Presented')
            local n=w.phase=='equipment-instanced' and 4 or 1
            check(warm.owner.batches.Mote.count==n,'presented phase retains actual Mote vertices')
        elseif #phases>1 then check(not warm.owner.root.enabled,'equipment hidden outside its own draw stages') end
        w:Presented()
    end
    local joined=table.concat(phases,'|')
    check(joined:find('equipment%-instanced|equipment%-single'),'both stages presented in order')
    check(w.completed and root.disposed and Resources.users==state.users,'completion disposes equipment before input')
    unchanged(s,state,jet,emission);cleanup(s)
end
do
    local s,state,jet,hover,leg,emission=fixture();local w=helper.Warm.New(s)
    local warm=w.equipmentWarmup;local root=warm.owner.root
    warm.owner.batches.Mote.mesh.Commit=function() error('injected equipment upload failure') end
    local ok,err=pcall(function() while not w.disposed do w:Presented() end end)
    check(not ok and tostring(err):find('injected equipment upload failure',1,true),'present failure propagates')
    check(w.disposed and not w.completed and root.disposed and Resources.users==state.users,'failed draw cancels complete warmup')
    unchanged(s,state,jet,emission);cleanup(s)
end
for cancelAt=0,16 do
    local s,state,jet,hover,leg,emission=fixture();local w=helper.Warm.New(s)
    local root=w.equipmentWarmup.owner.root
    for _=1,cancelAt do if not w.disposed then w:Presented() end end
    w:Dispose();w:Dispose()
    check(root.disposed and Resources.users==state.users,'every presentation boundary balances equipment owner')
    unchanged(s,state,jet,emission);cleanup(s)
end
do
    local s,state,jet,hover,leg,emission=fixture()
    s.camera:GetCamera().frustum.IsInsideFast=function() return OUTSIDE end
    local w=helper.Warm.New(s);check(#w.groups==0,'empty world fixture')
    local phases={}
    while not w.disposed do phases[#phases+1]=w.phase;w:Presented();check(#phases<10,'empty world progression bounded') end
    check(table.concat(phases,'|'):find('equipment%-instanced|equipment%-single'),'empty world still presents both equipment variants')
    check(w.completed and Resources.users==state.users,'empty world completion releases equipment owner')
    unchanged(s,state,jet,emission);cleanup(s)
end
do
    local s=helper.session();s.view=drive(s.scene,'mech')
    local w=Warm.New(s);w:Show(4)
    check(w.kinds.Thruster~=nil and w.owner.batches.Flare.count==4 and w.owner.batches.Mote.count==4,'mech jets use actual thruster family')
    w:Dispose();s.view.equipment:Dispose();s.effects:Dispose();s.scene:Dispose()
    check(Resources.users==0,'mech owner balanced')
end
Equipment.Update=oldUpdate;Equipment.Thruster=oldThruster;math.random=random
return {checks=checks,result='PASS'}

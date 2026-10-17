-- Actual production scheduler with native instance setter side effects and grouped map sources.
COMBAT_WARMUP_TEST_HELPERS=true
local helpers=assert(loadfile('tools/migration/check-combat-warmup.lua'))()
local Warm=require('render.CombatWarmup')
local Signature=require('render.WarmupSignature')
local Probes=require('render.MapWarmupProbes')
local checks=0
local function check(ok,label)assert(ok,label);checks=checks+1 end
local function eq(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local originalCreate=helpers.Node.CreateComponent
function helpers.Node:CreateComponent(kind)
    local c=originalCreate(self,kind)
    local native={instanceColor=c.instanceColor,instanceCustomData=Vector4(0,0,0,0),
        useInstanceColor=c.useInstanceColor,useInstanceCustomData=c.useInstanceCustomData}
    for key in pairs(native)do rawset(c,key,nil)end
    local old=getmetatable(c)
    setmetatable(c,{__index=function(t,key)
        if native[key]~=nil then return native[key]end
        return old.__index(t,key)
    end,__newindex=function(t,key,value)
        if key=='instanceColor'or key=='instanceCustomData'then
            native[key]=value
            native[key=='instanceColor'and'useInstanceColor'or'useInstanceCustomData']=true
        elseif key=='useInstanceColor'or key=='useInstanceCustomData'then native[key]=value
        else rawset(t,key,value)end
    end})
    return c
end
local function material(name,shader)
    local m={name=name,surface={name=shader or 'Shaders/BLGL/Crater/Scatter.shader'}}
    function m:GetSurfaceShader()return self.surface end
    function m:GetNumTechniques()return 1 end
    return setmetatable(m,{__tostring=function(v)return v.name end})
end
local function model(name,stride)
    local m={name=name,numMorphs=0,numGeometries=1,skeleton={numBones=0},lods=1,
        boundingBox={size=Vector3(4,2,8),center=Vector3(2,1,4)}}
    local buffer={vertexSize=stride or 32,elements={{type=3,semantic=0,index=0,perInstance=false,offset=0},
        {type=3,semantic=1,index=0,perInstance=false,offset=12},{type=2,semantic=4,index=0,perInstance=false,offset=24}}}
    function buffer:GetElements()return self.elements end
    m.geometry={empty=false,numVertexBuffers=1,primitiveType=0,buffer=buffer}
    function m.geometry:GetVertexBuffer()return self.buffer end
    function m:GetGeometry()return self.geometry end
    function m:GetNumGeometryLodLevels()return self.lods end
    return setmetatable(m,{__tostring=function(v)return v.name end})
end
local function drawable(s,kind,m,mat,label)
    local d=s.scene:CreateChild(label):CreateComponent(kind);d.model=m;d.material=mat
    d.outlineEnabled=false;d.drawDistance=220;d.shadowDistance=90;d.lodBias=1
    d.occluder=false;d.occludee=true;d.occlusionLodLevel=0;d.castShadows=true
    d.instanceColor=Color(.2,.3,.4,.5);d.useInstanceColor=false
    d.instanceCustomData=Vector4(7,8,9,10);d.useInstanceCustomData=false
    d.numInstanceNodes=3;d.instanceNodes={}
    for i=1,3 do d.instanceNodes[i]=d.node:CreateChild('Instance'..i)end
    return d
end
local function fixture(chunks)
    local s=helpers.session();local sources={}
    local m=model('scatter-a');local equivalent=model('scatter-equivalent')
    local mat=material('scatter-mat-a');local matB=material('scatter-mat-b')
    for i=1,chunks or 24 do
        sources[#sources+1]=drawable(s,'StaticModelGroup',i%2==0 and m or equivalent,mat,'chunk'..i)
    end
    sources[#sources+1]=drawable(s,'StaticModelGroup',model('scatter-stride-36',36),mat,'other-layout')
    sources[#sources+1]=drawable(s,'StaticModelGroup',m,matB,'other-material')
    local flags=drawable(s,'StaticModelGroup',m,mat,'other-flags');flags.useInstanceColor=true
    sources[#sources+1]=flags
    local excluded=drawable(s,'StaticModelGroup',m,material('other-shader','Shaders/BLGL/Other.shader'),'not-scatter')
    sources[#sources+1]=excluded
    return s,sources
end
local function snapshot(sources)
    local out={}
    for i,d in ipairs(sources)do
        out[i]={drawable=d,model=d.model,material=d.material,mask=d.viewMask,position=d.node.position,
            rotation=d.node.rotation,scale=d.node.scale,color=d.instanceColor,custom=d.instanceCustomData,
            colorEnabled=d.useInstanceColor,dataEnabled=d.useInstanceCustomData,instances=d.numInstanceNodes,nodes={}}
        for j,n in ipairs(d.instanceNodes)do out[i].nodes[j]=n end
    end
    return out
end
local function restored(s,saved,w)
    for _,v in ipairs(saved)do
        local d=v.drawable
        eq(d.model,v.model,'source model preserved');eq(d.material,v.material,'source material preserved')
        eq(d.viewMask,v.mask,'source mask restored');eq(d.node.position,v.position,'source position preserved')
        eq(d.node.rotation,v.rotation,'source rotation preserved');eq(d.node.scale,v.scale,'source scale preserved')
        eq(d.instanceColor,v.color,'source color preserved');eq(d.instanceCustomData,v.custom,'source data preserved')
        eq(d.useInstanceColor,v.colorEnabled,'source color flag preserved');eq(d.useInstanceCustomData,v.dataEnabled,'source data flag preserved')
        eq(d.numInstanceNodes,v.instances,'group instance count preserved')
        for j,n in ipairs(v.nodes)do eq(d.instanceNodes[j],n,'group node identity preserved');eq(n.disposed,nil,'source instance retained')end
    end
    eq(w.proxyRoot,nil,'proxy ownership released')
    for _,p in ipairs(w.proxies)do eq(p.node.disposed,true,'probe disposed')end
    eq(s.effects.light.light.enabled,false,'light restored')
    eq(#s.scene:GetComponents('CollisionShape',true),0,'no physics probes')
    for _,name in ipairs({'beams','flares','rings','particles','smoke','flashes','zaps','trails'})do eq(#s.effects[name],0,'no live '..name)end
end
do
    local s=helpers.session();local d=s.scene:GetComponents('StaticModel',true)[1]
    d.instanceColor=Color(.5,.6,.7,1);eq(d.useInstanceColor,true,'native color setter enables consumption')
    d.useInstanceColor=false;eq(d.useInstanceColor,false,'native explicit false disables consumption')
    d.instanceCustomData=Vector4(1,2,3,4);eq(d.useInstanceCustomData,true,'native custom setter enables consumption')
end
local s,sources=fixture();local saved=snapshot(sources)
local w=Warm.New(s,{batchSize=4})
eq(w.mapProbeStats.sources,#sources,'all source groups classified')
eq(w.mapProbeStats.probes,4,'chunk count deduplicated by actual layout material and flags')
eq(w.mapProbeStats.rejected,1,'unmeasured shader excluded');eq(w.mapProbeStats.errors,0,'supported binding succeeds')
eq(#w.volumeGroups,#w.groups+4,'ordinary probes added only to existing volume schedule')
local activeMap,frames,instancedFrames,singleFrames={},0,0,0
while not w.disposed do
    if w.phase=='point-volume-instanced'or w.phase=='point-volume-single'then
        if w.phase=='point-volume-instanced'then instancedFrames=instancedFrames+1 else singleFrames=singleFrames+1 end
        local actual={}
        for _,p in ipairs(w.proxies)do if p.node.enabled then
            local d=p.drawable
            local source
            for _,g in ipairs(w.volumeGroups)do if g.kind=='StaticModel'and g.items[1].drawable.model==d.model
                and g.items[1].drawable:GetMaterial(0)==d:GetMaterial(0)and g.items[1].drawable.useInstanceColor==d.useInstanceColor then
                source=g.items[1].drawable;break
            end end
            check(source~=nil,'proxy has real source')
            eq(d.useInstanceColor,source.useInstanceColor,'instance color flag matches actual source after setters')
            eq(d.useInstanceCustomData,source.useInstanceCustomData,'instance data flag matches actual source after setters')
            eq(d.instanceColor,source.instanceColor,'instance color value copied')
            eq(d.instanceCustomData,source.instanceCustomData,'instance data value copied')
            eq(d.castShadows,source.castShadows,'shadow participation copied')
            eq(d.lightMask,source.lightMask,'light mask copied');eq(d.shadowMask,source.shadowMask,'shadow mask copied')
            if d.model.geometry then
                eq(w.phase,'point-volume-single','group instanced variants do not add repeated stages')
                local key=tostring(d.model.geometry)..'|'..tostring(d.material)
                check(not actual[key],'ordinary probes cannot auto-instance across differing states');actual[key]=true
                activeMap[d.model.name..'|'..d.material.name..'|'..tostring(d.useInstanceColor)]=true
            end
        end end
    end
    frames=frames+1;check(frames<60,'finite bounded schedule');w:Presented()
end
eq(instancedFrames,1,'no added instanced map frame')
check(singleFrames>=2 and singleFrames<=3,'four exact map signatures add at most two single frames')
local seen=0;for _ in pairs(activeMap)do seen=seen+1 end
eq(seen,4,'every exact accepted single signature presented')
restored(s,saved,w)
for cancel=0,frames do
    local cs,ds=fixture(4);local before=snapshot(ds);local warm=Warm.New(cs,{batchSize=4})
    for _=1,cancel do if not warm.disposed then warm:Presented()end end
    warm:Dispose();warm:Dispose();restored(cs,before,warm)
end
do
    local cs,ds=fixture(308);local warm=Warm.New(cs,{batchSize=8})
    eq(warm.mapProbeStats.probes,4,'308 chunks still use four exact probes')
    warm:Dispose()
    local group={kind='StaticModelGroup',items={{drawable=ds[1],mask=7}}}
    local compact,stats=Signature.Compact({group})
    eq(compact[1],group,'original Compact still rejects StaticModelGroup');eq(stats.rejected,1,'original rejection unchanged')
    local key=Signature.GroupProbeCandidate(group)
    check(key~=nil,'explicit group helper validates supported layout')
    group.kind='CustomGeometry';eq(Signature.GroupProbeCandidate(group),nil,'helper cannot expand unknown drawable kinds')
end
do
    local cs,ds=fixture(2);ds[1].model.GetGeometry=function()error('native API unavailable')end
    local warm=Warm.New(cs,{batchSize=4})
    check(warm.mapProbeStats.errors>0,'binding failure reported without guessing layout')
    warm:Dispose()
end
do
    local cs,ds=fixture(4);local before=snapshot(ds);local warm=Warm.New(cs,{batchSize=4})
    while warm.phase~='point-volume-instanced'do check(not warm:Presented(),'volume phase reached')end
    warm.proxies[1].drawable.SetMaterial=function()error('map probe upload failure')end
    eq(pcall(warm.Presented,warm),false,'probe error propagates');eq(warm.disposed,true,'failed upload releases probes')
    restored(cs,before,warm)
end
return {result='PASS',checks=checks,frames=frames,instancedVolumeFrames=instancedFrames,singleVolumeFrames=singleFrames,
    exactMapSignatures=seen,cancellationBoundaries=frames+1,
    boundary='Actual Lua collector, scheduler and lifecycle with strict native setter and layout adapters. No actual engine shader compile, load timing, visual or mobile performance claim.'}

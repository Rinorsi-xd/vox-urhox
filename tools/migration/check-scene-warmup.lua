-- Offline ownership and grouping checks only; shader coverage needs Web QA.
package.path='scripts/?.lua;'..package.path
OUTSIDE=0
LIGHT_DIRECTIONAL=1
local Warm=require 'render.SceneWarmup'
local checks=0
local function Check(value,label) assert(value,label);checks=checks+1 end
local function Model(lods,morphs)
    return {numGeometries=2,numMorphs=morphs or 0,GetNumGeometryLodLevels=function()return lods or 1 end}
end
local sharedModel=Model();local materials={{},{}}
local function Drawable(kind,patch)
    local d={kind=kind or 'StaticModel',model=sharedModel,enabledEffective=true,viewMask=7,lightMask=3,shadowMask=5,zoneMask=9,
        zone='same-zone',castShadows=false,maxLights=4,useInstanceColor=false,useInstanceCustomData=false,
        drawDistance=0,shadowDistance=0,lodBias=1,outlineEnabled=false,outlineThickness=1,outlineZBias=0,
        occluder=false,occludee=true,occlusionLodLevel=0,worldBoundingBox={outside=false},materials=materials}
    function d:GetMaterial(i)return self.materials[i+1]end
    for key,value in pairs(patch or {})do d[key]=value end
    return d
end
local camera={frustum={IsInsideFast=function(_,box)return box.outside and OUTSIDE or 1 end}}
local function Scene(items,lights)
    return {GetComponents=function(_,kind)if kind=='Light'then return lights or {} end;local out={};for _,d in ipairs(items)do if d.kind==kind then out[#out+1]=d end end;return out end}
end
local function Finish(w,items)
    local n=0
    repeat n=n+1;Check(n<200,'warmup is bounded') until w:Rendered()
    for _,d in ipairs(items)do Check(d.viewMask==d.originalMask,'completion restores every original mask')end
    return n
end
local function New(items,batchSize,accept,lights)
    for _,d in ipairs(items)do d.originalMask=d.viewMask end
    return Warm.New(Scene(items,lights),batchSize,camera,accept)
end
for _,lights in ipairs({{{enabledEffective=true,lightType=LIGHT_DIRECTIONAL}},
    {{enabledEffective=false,lightType=2}},{{enabledEffective=true,lightType=2}},{{lightType=LIGHT_DIRECTIONAL}}})do
    local items={};for i=1,10 do items[i]=Drawable()end
    local w=New(items,8,nil,lights);local eligible=lights[1].enabledEffective~=nil
        and(not lights[1].enabledEffective or lights[1].lightType==LIGHT_DIRECTIONAL)
    Check(#w.items==(eligible and 4 or 10),'only confirmed effective directional lighting permits representatives')
    Finish(w,items)
end
for count=1,8 do
    local items={};for i=1,count do items[i]=Drawable()end
    local w=New(items);Check(#w.items==count and #w.groups==count and #w.singles==0,'low-duplicate group preserves exact original path '..count)
    Finish(w,items)
end
for _,missing in ipairs({'zone','maxLights','occludee','material','enabledEffective'})do
    local items={};for i=1,10 do
        items[i]=Drawable()
        if missing=='material'then items[i].materials={materials[1]}else items[i][missing]=nil end
    end
    local w=New(items);Check(#w.items==10 and #w.singles==0,'unknown public state falls back '..missing);Finish(w,items)
end
do
    local items={};for i=1,10 do items[i]=Drawable(nil,{enabledEffective=i>4})end
    local w=New(items);Check(#w.items==10 and #w.singles==0,'disabled objects cannot replace enabled shader representatives')
    Finish(w,items)
end
do
    local items={};for i=1,25 do items[i]=Drawable()end
    local w=New(items,8)
    Check(#w.groups==1 and #w.items==4 and #w.singles==1,'twenty-five exact duplicates keep four real representatives and one single pass')
    for i,d in ipairs(items)do Check((d.viewMask~=0)==(i<=4),'instanced phase uses four original objects')end
    Check(not w:Rendered() and w.single,'instanced phase cannot skip single presentation')
    for i,d in ipairs(items)do Check((d.viewMask~=0)==(i==1),'single phase uses one original object')end
    Finish(w,items)
end
for _,key in ipairs({'viewMask','lightMask','shadowMask','zoneMask','zone','castShadows','maxLights','useInstanceColor',
    'useInstanceCustomData','drawDistance','shadowDistance','lodBias','outlineEnabled','outlineThickness','outlineZBias',
    'occluder','occludee','occlusionLodLevel'})do
    local items={};for i=1,10 do items[i]=Drawable()end
    local b=items[10];local old=b[key]
    b[key]=type(old)=='boolean' and not old or type(old)=='number' and old+1 or 'other-zone'
    local w=New(items);Check(#w.items==5 and #w.groups==2,'state difference remains separate: '..key);Finish(w,items)
end
for slot=1,2 do
    local items={};for i=1,10 do items[i]=Drawable()end
    local b=items[10];b.materials={materials[1],materials[2]};b.materials[slot]={}
    local w=New(items);Check(#w.items==5 and #w.groups==2,'every material slot affects grouping '..slot);Finish(w,items)
end
for _,patch in ipairs({{model=Model(2)},{model=Model(1,1)},{model={numGeometries=2,numMorphs=0}},
    {model=Model(),outlineEnabled=true}})do
    local items={};for i=1,10 do items[i]=Drawable(nil,patch)end;local w=New(items)
    Check(#w.groups==10,'LOD, morph, unknown API and outline retain object identity');Finish(w,items)
end
for _,kind in ipairs({'StaticModelGroup','AnimatedModel','CustomGeometry','BillboardSet','Terrain','Skybox'})do
    local items={};for i=1,10 do items[i]=Drawable(kind)end;local w=New(items)
    Check(#w.groups==10,'special drawable retains identity '..kind);Finish(w,items)
end
do
    local a,b,c,d=Drawable(),Drawable(),Drawable(),Drawable(nil,{viewMask=0})
    b.worldBoundingBox.outside=true
    local w=New({a,b,c,d},8,function(item)return item~=c end)
    Check(#w.items==1 and w.skipped==1,'offscreen, filtered and already hidden remain omitted')
    Check(a.viewMask==7 and b.viewMask==0 and c.viewMask==0 and d.viewMask==0,'only accepted visible representative submits')
    w:Restore();for _,item in ipairs({a,b,c,d})do Check(item.viewMask==item.originalMask,'cancel restores filtered and omitted objects')end
    w:Restore()
end
do
    local items={};for i=1,18 do items[i]=Drawable(nil,{model=Model()})end
    local w=New(items,8)
    Check(#w.groups==18 and #w.items==18 and #w.singles==0,'unique model resources cannot merge')
    Check(Finish(w,items)==3,'unique models preserve three presented batches')
end
print('SceneWarmup offline: '..checks..' checks PASS; no GPU or performance claim')
return checks

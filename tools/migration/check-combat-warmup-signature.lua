-- Real warmup schedule and conservative native-layout adapters, without a renderer.
COMBAT_WARMUP_TEST_HELPERS=true
local helpers=assert(loadfile('tools/migration/check-combat-warmup.lua'))()
local Compact=require('render.WarmupSignature')
local Warm=require('render.CombatWarmup')
local checks=0
local function check(ok,label)assert(ok,label);checks=checks+1 end
local function eq(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function material(name,techniques)
 local m={name=name,techniques=techniques or 1}
 function m:GetSurfaceShader()return self.surface end
 function m:GetNumTechniques()return self.techniques end
 return setmetatable(m,{__tostring=function(v)return v.name end})
end
local shared=material('shared');local other=material('other')
local function model(name,layout)
 local m={name=name,numMorphs=0,numGeometries=1,skeleton={numBones=0},lods=1,
  boundingBox={size=Vector3(4,2,8),center=Vector3(2,1,4)}}
 local b={vertexSize=layout or 32,elements={{type=3,semantic=0,index=0,perInstance=false,offset=0},
  {type=3,semantic=1,index=0,perInstance=false,offset=12},{type=2,semantic=4,index=0,perInstance=false,offset=24}}}
 function b:GetElements()return self.elements end
 m.geometry={empty=false,numVertexBuffers=1,primitiveType=0,buffer=b}
 function m.geometry:GetVertexBuffer()return self.buffer end
 function m:GetGeometry()return self.geometry end
 function m:GetNumGeometryLodLevels()return self.lods end
 return setmetatable(m,{__tostring=function(v)return v.name end})
end
local function drawable(s,m,mat,label)
 local d=s.scene:CreateChild(label):CreateComponent('StaticModel');d.model=m;d.material=mat or shared
 d.outlineEnabled=false;d.drawDistance=0;d.shadowDistance=0;d.lodBias=1
 d.occluder=false;d.occludee=true;d.occlusionLodLevel=0
 return d
end
local function group(d,key,count)
 local items={};for i=1,count or 1 do items[i]={drawable=d,mask=d.viewMask}end
 return {key=key,kind='StaticModel',items=items}
end
local function fixture()
 local s=helpers.session()
 for i=1,60 do
  local m=model('model-'..i,i%3==0 and 36 or 32)
  local mat=i%5==0 and other or shared
  for j=1,i%4+1 do drawable(s,m,mat,'eligible-'..i..'-'..j)end
 end
 return s
end
local a,b=fixture(),fixture()
local old=Warm.New(a,{groupEquivalent=false});local current=Warm.New(b)
check(#current.groups<#old.groups,'real production collection compacts supported models')
eq(old.originalGroups,current.originalGroups,'same source atoms')
eq(current.signatureStats.eligible,60,'real eligible summary')
eq(current.signatureStats.rejected,2,'real fallback summary')
eq(current.signatureStats.errors,0,'real no-error summary')
check(current.signatureStats.firstReject~=nil,'first fallback reason retained')
local function obligation(d,kind,copies,phase)
 if kind~='StaticModel'then return kind..'|'..phase end
 local m=d.model;local mat=d:GetMaterial(0)
 local layout=m.geometry and m.geometry.buffer.vertexSize or m.name
 local materialName=mat and(mat.name or mat.shader)or 'none'
 return tostring(layout)..'|'..tostring(materialName or 'fallback-material')..'|'..tostring(d.zone)..'|'..phase..'|'..(copies>1 and 'instanced' or 'single')
end
local function run(w,s)
 local covered={};local frames=0
 while not w.disposed do
  local phase=w.phase
  if phase=='point-light-instanced' or phase=='point-light-single' then
   local native={};local active={}
   for _,g in ipairs(w.groups)do
    local visible=0
    for _,item in ipairs(g.items)do if item.drawable.viewMask~=0 then visible=visible+1 end end
    if visible>0 then
     local d=g.items[1].drawable
     covered[obligation(d,g.kind,visible,'point-world')]=true
     if phase=='point-light-single' and g.singleKeys then
      for _,key in ipairs(g.singleKeys)do check(not native[key],'single source cannot re-instance across groups');native[key]=true end
      active[#active+1]=g
     end
    end
   end
  elseif phase=='point-volume-instanced' or phase=='point-volume-single' then
   local atoms={}
   for _,proxy in ipairs(w.proxies)do if proxy.node.enabled then
    local d=proxy.drawable;local key=tostring(d.model)..'|'..tostring(d.material)
    local atom=atoms[key]or{d=d,count=0};atoms[key]=atom;atom.count=atom.count+1
   end end
   for _,atom in pairs(atoms)do covered[obligation(atom.d,'StaticModel',atom.count,'point-volume')]=true end
  end
  frames=frames+1;w:Presented();check(frames<1000,'bounded schedule')
 end
 for _,item in ipairs(w.all)do eq(item.drawable.viewMask,item.mask,'source mask restored')end
 return covered,frames
end
local before,oldFrames=run(old,a);local after,newFrames=run(current,b)
for key in pairs(before)do check(after[key],'every fixture shader obligation retained '..key)end
for key in pairs(after)do check(before[key],'no fixture shader obligation invented '..key)end
check(newFrames<oldFrames,'supported scene presents fewer frames')
for cancelAt=0,newFrames do
 local session=fixture();local light=session.effects.light.light
 local saved={range=light.range,brightness=light.brightness,enabled=light.enabled}
 local warm=Warm.New(session)
 for i=1,cancelAt do if not warm.disposed then warm:Presented()end end
 warm:Dispose();warm:Dispose()
 for _,item in ipairs(warm.all)do eq(item.drawable.viewMask,item.mask,'compacted cancellation restores mask '..cancelAt)end
 eq(light.range,saved.range,'compacted cancellation light range')
 eq(light.brightness,saved.brightness,'compacted cancellation light brightness')
 eq(light.enabled,saved.enabled,'compacted cancellation light enabled')
 for _,batch in pairs(session.effects.batches)do eq(batch.count,0,'compacted cancellation removes synthetic effect geometry')end
 for _,node in ipairs(session.effects.missiles.view.slots)do check(not node.enabled,'compacted cancellation missile disabled')end
 if warm.proxyRoot then error('Compacted cancellation retained proxy root')end
end
local s=helpers.session();local base=model('base');local d=drawable(s,base,shared,'base')
local sameLayout=drawable(s,model('same-layout'),shared,'same-layout')
local groups={group(d,'a',1),group(sameLayout,'b',4)}
local compact=Compact.Compact(groups)
eq(#compact,1,'same complete layout and material across models')
eq(compact[1].items,groups[2].items,'retain largest original same-model atom')
for _,item in ipairs(compact[1].items)do eq(item.drawable.model,sameLayout.model,'never mix models as native instances')end
local rejects={
 {'stride',function(x)x.model.geometry.buffer.vertexSize=40 end,false},
 {'primitive',function(x)x.model.geometry.primitiveType=1 end,false},
 {'offset',function(x)x.model.geometry.buffer.elements[2].offset=16 end,false},
 {'type',function(x)x.model.geometry.buffer.elements[2].type=4 end,false},
 {'semantic',function(x)x.model.geometry.buffer.elements[2].semantic=3 end,false},
 {'index',function(x)x.model.geometry.buffer.elements[2].index=1 end,false},
 {'per-instance',function(x)x.model.geometry.buffer.elements[2].perInstance=true end,true},
 {'missing offset',function(x)x.model.geometry.buffer.elements[2].offset=nil end,true},
 {'missing primitive',function(x)x.model.geometry.primitiveType=nil end,true},
 {'zero-based elements',function(x)x.model.geometry.buffer.elements[0]=x.model.geometry.buffer.elements[1]end,true},
 {'sparse elements',function(x)x.model.geometry.buffer.elements[2]=nil end,true},
 {'stream count',function(x)x.model.geometry.numVertexBuffers=2 end,false},
 {'geometry count',function(x)x.model.numGeometries=2 end,false},
 {'unknown native API',function(x)x.model.GetGeometry=function()error('unsupported')end end,true},
 {'morph',function(x)x.model.numMorphs=1 end,true},
 {'bones',function(x)x.model.skeleton.numBones=2 end,true},
 {'geometry LOD',function(x)x.model.lods=2 end,true},
 {'outline',function(x)x.outlineEnabled=true end,true},
 {'unknown state',function(x)x.occludee=nil end,true},
 {'material',function(x)x.material=other end,false},
 {'technique LOD',function(x)x.material=material('multi-technique',2)end,true},
 {'light mask',function(x)x.lightMask=27 end,false},
 {'zone',function(x)x.zone='other-zone'end,false},
 {'instance color',function(x)x.useInstanceColor=true end,false},
 {'instance data',function(x)x.useInstanceCustomData=true end,false},
 }
for _,case in ipairs(rejects)do
 local x=drawable(s,model('changed-'..case[1]),shared,'changed');case[2](x)
 local original=group(x,'unchanged-'..case[1],4)
 local c,stats=Compact.Compact({groups[1],original})
 eq(#c,2,'separate or reject '..case[1])
 if case[3]then check(c[1]==original or c[2]==original,'unknown/unsupported preserves original atom '..case[1])end
 if case[1]=='unknown native API'then
  eq(stats.errors,1,'native binding exception counted');check(stats.firstError:find('unsupported')~=nil,'native binding error retained')
 end
end
-- Two state keys can still share native geometry/material: isolate both single passes.
local x=drawable(s,base,shared,'same-native-geometry');x.zone='other-zone'
local isolated=Compact.Compact({group(d,'a',4),group(x,'b',4)})
local used={};check(Compact.CanAppend(isolated[1],used,0),'first single accepted')
Compact.Mark(isolated[1],used)
check(not Compact.CanAppend(isolated[2],used,1),'same geometry material single cannot re-instance')
local unknown={key='unknown',kind='CustomGeometry',items={}}
check(not Compact.CanAppend(unknown,used,1),'known and unknown singles separate')
local unknownUsed={};Compact.Mark(unknown,unknownUsed)
check(not Compact.CanAppend(isolated[1],unknownUsed,1),'unknown and known singles separate')
check(Compact.CanAppend(unknown,unknownUsed,1),'old unknown groups keep original batching')
return {result='PASS',checks=checks,originalGroups=current.originalGroups,groups=#current.groups,
 originalFrames=oldFrames,frames=newFrames,rejectCases=#rejects,cancellationBoundaries=newFrames+1,
 boundary='Strict CPU native adapters and real production collection/presentation; fixture obligation equality is not an actual engine shader-compile-set or GPU acceptance.'}

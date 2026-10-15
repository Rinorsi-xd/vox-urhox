local BP=require 'construction.Blueprint'
local View=require 'render.VehicleView'
local Assembly=require 'intro.IntroAssembly'
local function Same(a,b)return (a-b).length<.00001 end
local fixture={}
V.atFrame(2,function()
 local data=require('intro.IntroSession').Data();local bp=BP.New():Load(data.actors.hero)
 V.assert(bp:Size()==431,'frozen original hero contains 431 authored parts')
 local scene=Scene();local view=View.New(scene,'OriginalAssemblyFixture')
 for _,part in ipairs(bp:List()) do view:AddPart(part) end;view.joined:Update()
 local assembly=Assembly.New(view,bp);local identities={};local count=0
 for id,vis in pairs(view.visuals) do identities[id]=vis.node;count=count+1 end
 local components=#scene:GetComponents('StaticModel',true);local nodes=#scene:GetChildren(true)
 V.assert(count==431 and components>431,'all original part nodes and actual model geometries prepared')
 local sorted=true;local previous=-math.huge
 for _,part in ipairs(assembly.parts) do local score=part.pos[2]*4+(math.abs(part.pos[1])+math.abs(part.pos[3]))*.3
  sorted=sorted and score>=previous;previous=score
 end
 V.assert(sorted,'assembly follows original height and radial weighted ordering')
 assembly:Begin();local hidden=true
 for _,part in ipairs(assembly.parts) do hidden=hidden and not view.visuals[part.id].node.enabled end
 V.assert(hidden and assembly.index==0,'new montage begins with existing original parts hidden')
 local duration=data.durations.vo_n08;local time=0;local checks=true
 for frame=0,180 do
  local age=frame*duration/180;local k=math.min(1,age/(duration*.85));k=k<.5 and 4*k^3 or 1-(-2*k+2)^3/2
  time=time+duration/180;assembly:Update(age,time,duration)
  checks=checks and assembly.index==math.floor(k*431)
  for i,part in ipairs(assembly.parts) do
   local node=view.visuals[part.id].node
   checks=checks and node==identities[part.id] and node.enabled==(i<=assembly.index)
  end
 end
 V.assert(checks,'every montage frame preserves exact source cubic reveal count and original node identity')
 assembly:Update(duration+.5,time+.5,duration);local homes=true
 for _,part in ipairs(assembly.parts) do homes=homes and Same(view.visuals[part.id].node.position,assembly.homes[part.id]) end
 V.assert(homes and assembly.index==431,'all 431 original parts finish at authored positions after original .24 second extrusion')
 V.assert(#scene:GetComponents('StaticModel',true)==components and #scene:GetChildren(true)==nodes,'montage adds no model components or scene nodes during active voice')
 assembly:Begin();assembly:Update(duration*.425,100,duration)
 V.assert(assembly.index==215,'restart restores source halfway reveal without rebuilding geometry')
 local first=view.visuals[assembly.parts[1].id].node
 V.assert(Same(first.position,assembly.homes[assembly.parts[1].id]+Vector3(0,-.44,0)),'original .12 normal scale extrudes from bottom face instead of falling from above')
 local transforms=true;local sample=Vector3(.32,.27,-.19)
 for _,offset in ipairs({0,.06,.12,.18,.24,.3,.31}) do
  assembly:Update(duration*.425,100+offset,duration)
  local t=math.min(1,offset/.24);local along=.12+.88*(1+2.4*(t-1)^3+1.4*(t-1)^2);local side=.8+.2*(1-(1-t)^3)
  for i=1,215 do local part=assembly.parts[i];local node=view.visuals[part.id].node;local home=assembly.homes[part.id]
   local pivot=home-Vector3(0,.5,0);local raw=node.rotation*sample+home-pivot
   local want=view.root:LocalToWorld(pivot+Vector3(raw.x*side,raw.y*along,raw.z*side))
   transforms=transforms and Same(node:LocalToWorld(sample),want)
  end
 end
 V.assert(transforms,'all revealed original orientations exactly match source pivot/world-axis backOut and easeOut matrices')
 local clear=true;local flashCount=0
 for _,list in pairs(assembly.flashes) do for _,model in ipairs(list) do flashCount=flashCount+1;clear=clear and not model.enabled end end
 print('[IntroAssemblyFixture] pooledFlashModels='..flashCount..' disabledAfterFade='..tostring(clear))
 V.assert(clear and flashCount>431,'original .3 second cyan rim shells are pooled and disabled after fading')
 assembly:WarmFlash(true);local warmOn=true;local flashes={}
 for _,list in pairs(assembly.flashes) do for _,model in ipairs(list) do flashes[model]=true;warmOn=warmOn and model.enabled end end
 V.assert(warmOn,'explicit original flash warmup enables every actual cached component')
 scene:CreateComponent('Octree');view.root:SetEnabledRecursive(true)
 local camera=scene:CreateChild('AssemblyFixtureCamera'):CreateComponent('Camera');camera.node.position=Vector3(15,10,24);camera.node:LookAt(Vector3(0,2,0));camera.fov=50
 local warm=require('render.SceneWarmup').New(scene,8,camera);local accepted=false
 for _,item in ipairs(warm.items) do accepted=accepted or flashes[item.drawable]==true end
 V.assert(accepted,'real frustum and prewarm collect actual active original flash drawables')
 fixture.scene=scene;fixture.view=view;fixture.assembly=assembly;fixture.warm=warm;fixture.camera=camera
end)
for frame=3,11 do V.atFrame(frame,function()
 if not fixture.scene then return end
 renderer:SetViewport(0,Viewport:new(fixture.scene,fixture.camera))
 if frame==10 then
  fixture.warm:Restore();fixture.assembly:WarmFlash(false);local off=true
  for _,list in pairs(fixture.assembly.flashes) do for _,model in ipairs(list) do off=off and not model.enabled end end
  V.assert(off,'flash warmup restores all original component enable state before narrative')
 elseif frame==11 then
  fixture.assembly:Dispose();fixture.view:Dispose();V.assert(not fixture.scene:GetChild('OriginalAssemblyFixture'),'actual model view disposal removes pooled part nodes')
  fixture.scene:Dispose();fixture.scene=nil;V.finish()
 end
end) end

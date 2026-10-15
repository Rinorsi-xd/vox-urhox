-- Production material ownership and xray paths; adapters only replace native objects.
local checks={}
local function Check(value,label) assert(value,label);checks[#checks+1]=label end
local created,disposed,clones,writes=0,0,0,0
local failParameter,failClone=false,false
local function Material(properties)
    created=created+1
    local m={properties=properties or {},disposed=false}
    function m:Clone()
        if failClone then error('clone failed') end
        clones=clones+1
        local p={};for k,v in pairs(self.properties) do p[k]=v end
        return Material(p)
    end
    function m:SetShaderParameter(key,value)
        if failParameter then error('parameter failed') end
        writes=writes+1;self.properties[key]=value
    end
    function m:Dispose()
        assert(not self.disposed,'material disposed twice')
        self.disposed=true;disposed=disposed+1
    end
    return m
end
local texture={nativeTexture=true}
local baseProperties={base_color=0xcbd1d7,roughness_value=.52,metallic_value=.28,
    clearcoat_value=.06,clearcoat_roughness_value=.52,shader='VoxPBRCoat.shader',
    texture=texture,vertexDefines='INSTANCED',cullMode='ccw',renderOrder=17,hemi_intensity=1.85}
local base=Material(baseProperties)
Variant=function(v)return v end
Color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end
local function Point(x,y,z)return {x=x,y=y,z=z}end
Vector3={ZERO=Point(0,0,0)}
cjson={null={}}
package.loaded.Config={CELL=.5,HexLinear=function(hex)return hex end}
package.loaded['parts.Materials']={Get=function(key)assert(key=='armorWhite');return base end,
    New=function()return Material()end}
local nodeCreated,nodeDisposed,resources,resourcesFreed=0,0,0,0
local function Node(parent,name)
    nodeCreated=nodeCreated+1
    local n={children={},parent=parent,name=name}
    if parent then parent.children[n]=true end
    function n:CreateChild(label)return Node(self,label)end
    function n:SetScale(v)self.scale=v end
    function n:SetParent(p)self.parent.children[self]=nil;self.parent=p;p.children[self]=true end
    function n:Dispose()
        assert(not self.disposed,'node disposed twice')
        local children={};for child in pairs(self.children)do children[#children+1]=child end
        for _,child in ipairs(children)do child:Dispose()end
        if self.parent then self.parent.children[self]=nil end
        self.disposed=true;nodeDisposed=nodeDisposed+1
    end
    return n
end
local function Model()
    local m={materials={[0]=base,[1]=base},castShadows=true}
    function m:GetMaterial(i)return self.materials[i]end
    function m:SetMaterial(i,material)
        if self.failIndex==i then self.failIndex=nil;error('bind failed')end
        assert(not material.disposed,'binding disposed material')
        self.materials[i]=material
    end
    return m
end
package.loaded['parts.Defs']={PARTS={shell={shape='cube',instanced=true}}}
package.loaded['core.Coord']={CellPos=Point,RotQuat=function(v)return v end}
package.loaded['parts.PartAssets']={Get=function()return {segments=cjson.null}end,
    Release=function(list)resourcesFreed=resourcesFreed+#list end}
package.loaded['render.PartRig']={Build=function(node,data,part,vis)
    local model=Model();vis.data=data;vis.rig={};vis.models={model};vis.resources={'model'};resources=resources+1
    vis.materialSlots={[model]={'armorWhite','armorWhite'}}
    vis.shellSlots={{model=model,index=0},{model=model,index=1}}
end}
package.loaded['render.JoinedSurface']={IsJoined=function()return false end}
package.loaded['render.JoinedMesh']={New=function()return {
    meshes={},Remove=function()end,Clear=function()end,Dispose=function()end,Update=function()end,SetXray=function()end}end}
package.loaded['render.LiveryLayer']={New=function()return {
    PartsChanged=function()end,Clear=function()end,Dispose=function()end,Set=function()end,Update=function()end}end}
local Pool=require 'render.ShellMaterials'
local View=require 'render.VehicleView'
local scene=Node(nil,'Scene')
local a,b=View.New(scene,'A'),View.New(scene,'B')
local function Part(id,color)return {id=id,type='shell',pos={0,0,0},rot=0,color=42,shellColor=color}end
local pa,pb=Part(1,0x123456),Part(1,0x123456)
local va,vb=a:AddPart(pa),b:AddPart(pb)
local shared=va.shellMaterial
Check(shared==vb.shellMaterial and clones==1,'same exact base/color across vehicles shares one clone')
local precise=true;for key,value in pairs(baseProperties)do
    if key~='base_color' and shared.properties[key]~=value then precise=false end
end
Check(precise and shared.properties.base_color==pa.shellColor,'all exact base parameters/textures/flags retained; only color changes')
Check(base.properties.base_color==0xcbd1d7,'shared base remains immutable')
Check(va.models[1]:GetMaterial(0)==shared and va.models[1]:GetMaterial(1)==shared,'all shell material slots bound')
local beforeWrites,beforeClones=writes,clones
a:Repaint(pa)
Check(writes==beforeWrites and clones==beforeClones,'same repaint has no parameter writes/allocation/ref increase')
pa.shellColor=0x654321;a:Repaint(pa)
Check(va.shellMaterial~=shared and vb.shellMaterial==shared and not shared.disposed,'repainting one owner keeps other owner unchanged')
Check(shared.properties.base_color==0x123456,'leased material never mutated during repaint')
local replaced=va.shellMaterial
pa.shellColor=nil;a:Repaint(pa)
Check(replaced.disposed and va.shellMaterial==nil and va.models[1]:GetMaterial(0)==base,'nil restores exact base and retires last color owner')
pa.shellColor=0x123456;a:Repaint(pa)
Check(va.shellMaterial==shared,'repaint can rejoin retained exact variant')
local oldBase=base;base=Material(baseProperties)
local pc=Part(2,0x123456);local vc=a:AddPart(pc)
Check(vc.shellMaterial~=shared,'different base identity never aliases same hex')
base=oldBase
pb.shellColor=cjson.null;b:Repaint(pb)
Check(vb.shellMaterial==nil and vb.models[1]:GetMaterial(1)==base and not shared.disposed,'cjson null restores base without releasing another owner')
a:SetXray(true)
local xrayMaterial=va.models[1]:GetMaterial(0)
pa.shellColor=0xabcdef;a:Repaint(pa)
Check(va.models[1]:GetMaterial(0)==xrayMaterial,'repaint while xray retains active xray binding')
Check(va.xrayOriginals[va.models[1]].materials[1]==va.shellMaterial,'xray hidden originals receive new shared base')
Check(shared.disposed,'last old variant retired during xray repaint')
local expected=va.shellMaterial;a:SetXray(false)
Check(va.models[1]:GetMaterial(0)==expected and va.models[1].castShadows,'xray restore uses correct new variant and shadow flags')
local lease=va.shellLease
b:RemovePart(1)
Check(a:TransferStaticPart(pa,b) and b.visuals[1]==va and va.shellLease==lease,'static debris transfer moves existing lease with visual identity')
a:Clear()
Check(not expected.disposed and b.visuals[1].models[1]:GetMaterial(0)==expected,'donor clear retains transferred material')
b:RemovePart(1)
Check(expected.disposed,'target removal releases final transferred lease')
Pool.Release(va)
Check(va.shellLease==nil and va.shellMaterial==nil,'repeated release on cleared visual is idempotent')
local legacy=Material();local legacyVis={shellMaterial=legacy,shellSlots={{model=Model(),index=0}}}
Pool.Apply(legacyVis,0x123456)
Check(legacy.disposed and legacyVis.shellMaterial.properties.base_color==0x123456,'script reload legacy private material replaced and disposed')
Pool.Release(legacyVis)
local failed={shellSlots={{model=Model(),index=0}}}
local beforeLive=created-disposed
failClone=true;local ok=pcall(Pool.Apply,failed,1);failClone=false
Check(not ok and created-disposed==beforeLive and not failed.shellMaterial,'clone failure leaves no lease or live allocation')
failParameter=true;ok=pcall(Pool.Apply,failed,1);failParameter=false
Check(not ok and created-disposed==beforeLive and not failed.shellMaterial,'shader parameter failure immediately disposes clone')
local model=Model();failed.shellSlots={{model=model,index=0},{model=model,index=1}}
Pool.Apply(failed,1);local original=failed.shellMaterial;beforeLive=created-disposed
model.failIndex=1;ok=pcall(Pool.Apply,failed,2)
Check(not ok and failed.shellMaterial==original and created-disposed==beforeLive,'bind failure retains previous lease and disposes acquired clone')
Check(model:GetMaterial(0)==original and model:GetMaterial(1)==original,'partial bind failure rolls back both slots')
Pool.Release(failed)
local parts={Part(3,15),Part(4,15),Part(5,15)}
local bp={List=function()return parts end}
ok=pcall(function()a:Rebuild(bp,function()error('cancel')end)end)
Check(not ok and a.visuals[3].shellMaterial,'cancelled rebuild retains visible owner until normal teardown')
a:Clear()
local afterCancel=clones
a:Rebuild(bp);local rebuilt=a.visuals[3].shellMaterial
Check(a.visuals[4].shellMaterial==rebuilt and a.visuals[5].shellMaterial==rebuilt and clones==afterCancel+1,'rebuild allocates one lease variant for equal colors')
math.randomseed(8251);local randomExpected=math.random();math.randomseed(8251)
a:Repaint(parts[1]);a:Dispose();b:Dispose();scene:Dispose()
Check(math.random()==randomExpected,'material lifecycle does not consume gameplay RNG')
Check(rebuilt.disposed and created-disposed==2,'all pool/private clones retired; only two cached bases remain')
Check(nodeCreated==nodeDisposed and resources==resourcesFreed,'normal/cancel/transfer teardown releases every node and model acquisition')
return checks

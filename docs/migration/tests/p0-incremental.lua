package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
package.loaded['core.ResourceData']={Read=readData}
local checks=0
local function Check(ok,label) checks=checks+1;assert(ok,label) end
local function Same(a,b,label)
    Check(type(a)==type(b),label..' type')
    if type(a)=='table' then
        for k,v in pairs(a) do Same(v,b[k],label..'.'..tostring(k)) end
        for k in pairs(b) do Check(a[k]~=nil,label..' extra '..tostring(k)) end
    else Check(a==b,label..' value') end
end
local function Copy(t) if type(t)~='table' then return t end;local r={};for k,v in pairs(t) do r[k]=Copy(v) end;return r end
local Surface=require 'render.JoinedSurface'
local previous=assert(load(oldSource('render/JoinedSurface')))()
local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local function Exact(parts,cache,label)
    local a,b=Surface.BuildCached(parts,cache);local x,y=previous.Build(parts)
    Same(a,x,label..' surfaces');Same(b,y,label..' groups');return a
end
local rebuilt,total=0,0
for _,name in ipairs({'raceCar','megaMech','scorpion','fox','trooper','vanguard','tianyuan','fuyuan'}) do
    local bp=Prefab.Create(BP.New(),name);local parts=bp:List();local cache={}
    local first=Exact(parts,cache,name..' initial')
    Exact(parts,cache,name..' unchanged');Check(cache.rebuiltParts==0,name..' unchanged does not regenerate')
    for _,p in ipairs(parts) do if Surface.IsJoined(p) then
        local saved=Copy(p)
        bp:Remove(p.id);Exact(bp:List(),cache,name..' damage')
        rebuilt=rebuilt+cache.rebuiltParts;total=total+#parts
        Check(cache.parts[p.id]==nil,name..' releases removed surface')
        bp:Add(saved);Exact(bp:List(),cache,name..' repair')
        break
    end end
    local joined={};for _,p in ipairs(bp:List()) do if Surface.IsJoined(p) then joined[#joined+1]=p end end
    for i=1,math.min(12,#joined) do
        local p=joined[i];p.rot=(p.rot+1)%24;p.color=p.color~0x113355;p.g=p.g+1
        if i%3==0 then p.pos[1]=p.pos[1]+4 end
        Exact(bp:List(),cache,name..' mutation '..i)
    end
    Exact({},cache,name..' clear');Check(next(cache.parts)==nil,name..' releases cache')
end
-- Complementary slopes, all rotations, overlapping cells and different slots.
for rotation=0,23 do
    local parts={};for i,kind in ipairs({'cube','slope','corner','heavy','glass','neonCube'}) do
        if require('parts.Defs').PARTS[kind] then parts[#parts+1]={id=i,type=kind,pos={i%2,0,i//2},rot=rotation,g=1,color=0xff8844} end
    end
    local cache={};Exact(parts,cache,'rotation '..rotation)
    table.remove(parts,1);Exact(parts,cache,'exposed rotation '..rotation)
end
print('[P0Surface] PASS exact vertices/normals/colors/groups; damage regenerated '..rebuilt..' / '..total..' candidate parts')
local dense={}
for x=0,7 do for y=0,3 do for z=0,7 do dense[#dense+1]={id=#dense+1,type='cube',pos={x,y,z},rot=0,g=1,color=0xff8844} end end end
local denseCache={};Exact(dense,denseCache,'dense initial');table.remove(dense,100);Exact(dense,denseCache,'dense damage')
Check(denseCache.rebuiltParts<=6,'only six adjacent parts can change after cube removal')
print('[P0Surface] dense damage regenerated '..denseCache.rebuiltParts..' / '..#dense..' remaining parts')

Vector3=function(x,y,z) return {x=x or 0,y=y or 0,z=z or 0} end
Color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end
TRIANGLE_LIST=1;LINE_LIST=2
local uploads=0
local function Node()
    local n={position=Vector3(),rotation={}}
    function n:CreateChild()return Node()end
    function n:Dispose()self.disposed=true end
    function n:CreateComponent()
        local geo={vertices={}}
        function geo:BeginGeometry()self.vertices={}end
        function geo:DefineVertex(v)self.vertices[#self.vertices+1]={p=v}end
        function geo:DefineNormal(v)self.vertices[#self.vertices].n=v end
        function geo:DefineColor(v)self.vertices[#self.vertices].c=v end
        function geo:Commit()uploads=uploads+1 end
        function geo:SetMaterial(v)self.material=v end
        return geo
    end
    return n
end
local modules={['render.JoinedSurface']=Surface,['core.Coord']=require('core.Coord'),Config=require('Config'),
    ['parts.Materials']={Joined=function(slot,xray)return slot..tostring(xray)end,JoinedOutline=function()return 'outline'end}}
local function Load(path,source)
    return assert(load(source or assert(io.open(path)):read('*a'),'@'..path,'t',setmetatable({require=function(k)return assert(modules[k],k)end},{__index=_G})))()
end
local Joined=Load('scripts/render/JoinedMesh.lua');modules['render.JoinedMesh']=Joined
modules['construction.Rotors']={Is=function()return false end};modules['core.Math3']=require('core.Math3');modules['render.RotorDisc']={}
local Rotor=Load('scripts/render/RotorView.lua')
local view={root=Node(),visuals={},joined=Joined.New(Node()),livery={PartsChanged=function()end,Update=function()end}}
for i=1,10 do local p={id=i,type=i==10 and 'heavy' or 'cube',pos={i,0,0},rot=0,g=1,color=0x123456}
    view.visuals[i]={part=p,node=Node(),joined=true}
end
local vehicle={spec={rotorOf={}},rotors={}}
Rotor.New(view,vehicle);local firstUploads=uploads;local paint=view.joined.meshes.paint;local heavy=view.joined.meshes.heavyPaint
Rotor.New(view,vehicle);Check(uploads==firstUploads and view.joined.meshes.paint==paint,'unchanged rebind preserves meshes without upload')
local heavySurface=heavy.surface;view.visuals[5]=nil;Rotor.New(view,vehicle)
Check(uploads==firstUploads+1 and heavy.surface==heavySurface,'damage uploads only changed material')
vehicle.spec.rotorOf[1]=1;Rotor.New(view,vehicle);Check(view.rotorJoined[1].parts[1] and not view.joined.parts[1],'part transfers to rotor')
local rotorMesh=view.rotorJoined[1];local before=uploads;Rotor.New(view,vehicle);Check(uploads==before and view.rotorJoined[1]==rotorMesh,'rotor retains unchanged geometry')
vehicle.spec.rotorOf[1]=2;Rotor.New(view,vehicle);Check(rotorMesh.root.disposed and view.rotorJoined[2].parts[1],'owner reindex retires old mesh')
vehicle.spec.rotorOf={};Rotor.New(view,vehicle);Check(next(view.rotorJoined)==nil and view.joined.parts[1],'rotor removal rejoins chassis')
view.joined:SetXray(true);view.joined:SetXray(false);view.joined:Dispose();Check(next(view.joined.surfaceCache)==nil,'mesh dispose releases surfaces')
print('[P0Rebind] PASS mesh identity/uploads, adjacent exposure, rotor owner migration, xray and disposal')
Ray=function() return {Define=function() end} end
package.loaded['physics.Body']={Wrap=function(native,changed)
    return {native=native,invalidate=function()end,setEnabled=function(on) native.enabled=on;if changed then changed()end end}
end}
package.loaded['diagnostics.PhysicsStats']={Step=function()return false end}
local Space=require 'physics.Space'
local native={mass=0,kinematic=false,trigger=false,enabled=true,node={GetID=function()return 1 end}}
local casts=0;local hit=true
local world={Raycast=function() casts=casts+1;return hit and {{body=native,position={x=0,y=0,z=0},normal={x=0,y=1,z=0},distance=2}} or {} end}
local space=Space.New({GetComponent=function()return world end})
local body=space:Register(native,{type='ground'})
local function Cast(p,d,l,mask,excluded,skip,fixed) return space:Raycast(p or {0,2,0},d or {0,-1,0},l or 4,excluded,skip,fixed~=false,mask) end
local a=Cast();local before=casts;local b=Cast();Same(a.point,b.point,'cached hit');Check(casts==before,'identical static ray reused')
a.point[2]=99;a.normal[2]=-1;a.dist=99;Same(Cast().point,{0,0,0},'hit protected from mutation')
for _,f in ipairs({function()Cast({.001,2,0})end,function()Cast(nil,{0,-.99,0})end,function()Cast(nil,nil,5)end,
    function()Cast(nil,nil,nil,1)end,function()Cast(nil,nil,nil,nil,nil,'ground')end,
    function()Cast(nil,nil,nil,nil,{native={node={GetID=function()return 99 end}}})end}) do
    before=casts;f();Check(casts==before+1,'changed scalar/filter/exclusion is fresh')
end
hit=false;space:InvalidateStaticQueries();Check(Cast()==nil,'fresh miss');before=casts;Check(Cast()==nil and casts==before,'miss reused')
hit=true;space:InvalidateStaticQueries();Check(Cast()~=nil,'static edit invalidates miss')
before=casts;Cast(nil,nil,nil,nil,nil,nil,false);Cast(nil,nil,nil,nil,nil,nil,false);Check(casts==before+2,'dynamic support never cached')
body.setEnabled(false);before=casts;Cast();Check(casts==before+1,'static enable change invalidates')
space:SetOwner(native,{type='changed'});before=casts;Check(Cast().owner.type=='changed' and casts==before+1,'owner invalidates')
space:SetOwner(native,{type=''})
Check(Cast()~=nil and Cast(nil,nil,nil,nil,nil,'')==nil,'empty owner filter differs from no filter')
space:Unregister(native);before=casts;Cast();Check(casts==before+1,'unregister invalidates')
for i=1,1100 do Cast({i,2,0}) end;Check(space.staticQueryCount<=512,'cache is bounded')
space:Dispose();Check(next(space.staticQueries)==nil,'dispose releases cached bodies')

-- Collision audio consumes a boolean, so later contacts and events can stop early.
local events={};SubscribeToEvent=function(node,_,callback)events[node]=callback end;UnsubscribeFromEvent=function(node)events[node]=nil end
package.loaded['diagnostics.PhysicsStats']={Scope=function()return nil end}
local Audio=require 'audio.CollisionAudio'
local audio=Audio.New();local speed=3;local unit={vehicle={node={},body={isValid=function()return true end,linvel=function()return {x=speed,y=0,z=0}end,center=function()return {x=0,y=0,z=0}end}}}
audio:BeforeStep({unit});local reads=0;local buffer={eof=false,ReadVector3=function()reads=reads+1;return {x=0,y=0,z=0}end,ReadFloat=function()end}
local data={GetBool=function()return false end,GetBuffer=function()return buffer end}
events[unit.vehicle.node](nil,data);Check(reads==2,'first side contact finishes buffer scan')
events[unit.vehicle.node](nil,data);Check(reads==2,'later contact event does not reparse')
speed=0;local out={};audio:AfterStep(1,out);Check(#out==1 and out[1].type=='vehicleCollision','same collision cue')
audio:Dispose();Check(next(events)==nil,'audio cleanup')
local callback
local slide=require 'drive.ObstacleSlide'
local v={native={},node={CreateScriptObject=function()return {SubscribeToEvent=function(_,_,_,fn)callback=fn end}end}}
slide.Install(v);local readOther=0
local collision=setmetatable({}, {__index=function(_,key)
    if key=='OtherBody' then return {GetPtr=function()readOther=readOther+1;return native end} end
    if key=='Contacts' then return {GetBuffer=function()return {eof=true}end} end
end})
callback(nil,nil,collision);Check(readOther==0,'idle/excluded slide does not decode unused contacts')
v.slideBefore={};callback(nil,nil,collision);Check(readOther==1,'active movement still observes contacts')
v.slideBefore=nil;v.slideStep={};callback(nil,nil,collision);Check(readOther==2,'belly support still observes contacts')
print('[P0Queries] PASS exact cache/filter/invalidation/capacity/mutation protection and collision audio; assertions '..checks)

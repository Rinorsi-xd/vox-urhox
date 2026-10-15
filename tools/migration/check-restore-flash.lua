-- Actual module event/lifecycle checks. No GPU claims are made by this test.
package.path='scripts/?.lua;'..package.path
local function eq(a,b,s)assert(a==b,(s or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function near(a,b,s)assert(math.abs(a-b)<1e-10,s or 'numeric mismatch')end
local V={};V.__index=V
function V.__mul(a,b)return setmetatable({x=a.x*b,y=a.y*b,z=a.z*b},V)end
function Vector3(x,y,z)return setmetatable({x=x,y=y,z=z},V)end
local matrix=setmetatable({},{__mul=function(_,b)return b end});function matrix:Inverse()return self end
local bounds={__eq=function(a,b)return a.value==b.value end}
function BoundingBox(b)return setmetatable({value=b.value},bounds)end
function Color(r,g,b,a)return {r=r,g=g,b=b,a=a}end
function Variant(a)return a end
function BiasParameters()return {}end
TRIANGLE_LIST=1
local created,freed=0,0
Model={};function Model:new()
 created=created+1;local m={geometry={}}
 function m:SetNumGeometries(n)self.numGeometries=n end
 function m:SetBoundingBox(b)self.boundingBox=b end
 function m:SetNumGeometryLodLevels()end
 function m:SetGeometry(i,_,g)self.geometry[i]=g end
 function m:Dispose()assert(not self.disposed,'double model disposal');self.disposed=true;freed=freed+1 end
 return m
end
Material={};function Material:new()
 local m={};function m:SetSurfaceShader()return true end
 function m:Clone()return Material:new()end
 function m:Dispose()self.disposed=true end
 function m:SetShaderParameter(k,v)self[k]=v end
 return m
end
local Node={};Node.__index=Node
function Node:CreateChild(name)
 local n=setmetatable({name=name,children={},components={},position=Vector3(0,0,0),rotation={},scale=Vector3(1,1,1),worldPosition=Vector3(2,3,4),worldRotation={},worldScale=Vector3(1,1,1),worldTransform=matrix,enabled=true,transforms=0},Node)
 self.children[#self.children+1]=n;return n
end
function Node:SetTransform(...)self.transforms=self.transforms+1 end
function Node:CreateComponent(kind)
 local c={kind=kind,vertices={}};function c:BeginGeometry()end
 function c:DefineVertex(v)self.vertices[#self.vertices+1]=v end
 function c:DefineNormal()end;function c:Commit()end;function c:SetMaterial(m)self.material=m end
 self.components[#self.components+1]=c;return c
end
function Node:Dispose()self.disposed=true end
package.loaded['core.Coord']={Vec=Vector3}
package.loaded['render.JoinedSurface']={Shape=function()return {position={0,0,0,1,0,0,0,1,0},normal={0,0,1,0,0,1,0,0,1}}end}
local visibility=0;package.loaded['render.NodeVisibility']={Set=function()visibility=visibility+1 end}
local Restore=require'render.RestoreFlash'
local function source(name)
 return {name=name,numGeometries=3,boundingBox=BoundingBox{value=1},GetGeometry=function(_,i)return name..i end}
end
local function fixture()
 local scene=setmetatable({children={}},Node);local root=scene:CreateChild('vehicle')
 local model=source('shared');local view={root=root,visuals={}};local player={alive=true,bp={parts={}}}
 for i=1,3 do
  local node=root:CreateChild('part'..i);node.position=Vector3(i,2*i,3*i);node.scale=Vector3(i,i,i)
  view.visuals[i]={node=node,data={model='shared',slots={'steel','beamCyan','holoPaint'}},models={{model=model,node=node}},joined=i==3}
  player.bp.parts[i]={id=i}
 end
 local flash=Restore.New(scene);flash:Consume(player,view,{})
 return flash,player,view,model
end
local scenarios=0
local function check(name,fn)fn();scenarios=scenarios+1;print('PASS '..name)end
check('empty update advances clock without native root writes',function()
 local f=fixture();local count=f.root.transforms;local vis=visibility;f:Update(.1);near(f.time,.1);eq(f.root.transforms,count);eq(visibility,vis);f:Dispose()
end)
check('duplicates retain last occurrence ordering and one shell each',function()
 local f,p,v=fixture();local before=created
 f:Consume(p,v,{{type='partRestored',unit=p,id=1},{type='partRestored',unit=p,id=2},{type='partRestored',unit=p,id=1}})
 eq(#f.items,2);eq(f.items[1].id,2);eq(f.items[2].id,1);eq(created-before,1)
 eq(f.items[1].copies[1],f.items[2].copies[1]);eq(f.items[1].copies[1].numGeometries,1);eq(f.items[1].copies[1].geometry[0],'shared0')
 eq(f.items[1].node.position.x,2);eq(f.items[2].node.position.x,1);f:Dispose()
end)
check('source alpha expansion and pop golden at 100 milliseconds',function()
 local f,p,v=fixture();f:Consume(p,v,{{type='partRestored',unit=p,id=1}});f:Update(.1)
 local item=f.items[1];local k=.1/.34;near(item.alpha,1.1*(1-k)^1.5)
 near(item.node.scale.x,1+.14*(1-(1-k)^3));near(v.visuals[1].node.scale.x,1.07)
 near(item.models[1].instanceColor.a,item.alpha);f:Dispose();near(v.visuals[1].node.scale.x,1)
end)
check('joined shell winding alpha and expiration',function()
 local f,p,v=fixture();f:Consume(p,v,{{type='partRestored',unit=p,id=3}})
 local item=f.items[1];eq(#item.geometry.vertices,3);eq(item.geometry.vertices[2].y,1);eq(item.geometry.vertices[3].x,1)
 f:Update(.2);near(item.material.joined_alpha,1.1*(1-.2/.34)^1.5);near(v.visuals[3].node.scale.x,3)
 f:Update(.14);eq(#f.items,0);eq(item.material,nil);f:Dispose()
end)
check('kill and remove barriers discard preceding restores',function()
 for _,kind in ipairs({'unitKilled','unitRemoved'})do
  local f,p,v=fixture();f:Consume(p,v,{{type='partRestored',unit=p,id=1},{type=kind,unit=p},{type='partRestored',unit=p,id=2}})
  eq(#f.items,1);eq(f.items[1].id,2);f:Dispose()
 end
end)
check('dead player missing parts foreign unit produce no shell',function()
 local f,p,v=fixture();p.alive=false;f:Consume(p,v,{{type='partRestored',unit=p,id=1}});eq(#f.items,0)
 p.alive=true;f:Consume(p,v,{{type='partRestored',unit={},id=1},{type='partRestored',unit=p,id=99}});eq(#f.items,0);f:Dispose()
end)
check('shared copies release only at last shell and no idle cache',function()
 local f,p,v=fixture();local before=freed;f:Consume(p,v,{{type='partRestored',unit=p,id=1},{type='partRestored',unit=p,id=2}})
 local a=f.items[1];local copy=a.copies[1];f:Drop(a);table.remove(f.items,1);eq(freed,before);eq(copy.disposed,nil)
 f:Clear();eq(freed,before+1);eq(next(f.copyCache),nil);eq(next(f.copyOwners),nil);f:Dispose();f:Dispose()
end)
check('bounds replacement generations retire independent copy owners',function()
 local f,p,v,m=fixture();f:Consume(p,v,{{type='partRestored',unit=p,id=1}})
 local old=f.items[1].copies[1];m.boundingBox=BoundingBox{value=2};f:Consume(p,v,{{type='partRestored',unit=p,id=2}})
 local new=f.items[2].copies[1];assert(new~=old);local item=f.items[2];f:Drop(item);table.remove(f.items,2)
 eq(new.disposed,true);eq(old.disposed,nil);f:Clear();eq(old.disposed,true);f:Dispose()
end)
check('omitted slots allocate no empty wrappers',function()
 local f,p,v=fixture();v.visuals[1].data.slots={'beamCyan','holoPaint','beamOrange'};local before=created
 f:Consume(p,v,{{type='partRestored',unit=p,id=1}});eq(created,before);eq(#f.items[1].models,0);f:Dispose()
end)
check('generation cancellation and random sequence unchanged',function()
 math.randomseed(159);local expected=math.random();math.randomseed(159)
 local f,p,v=fixture();f:Consume(p,v,{{type='partRestored',unit=p,id=1},{type='partRestored',unit=p,id=1}})
 local old=f.items[1];v.visuals={};f:Update(.01);eq(#f.items,0);eq(old.node.disposed,true);eq(next(f.copyOwners),nil)
 eq(math.random(),expected);f:Dispose();f:Consume(p,v,{});f:Update(1)
end)
eq(created,freed,'all wrappers released');print('RESTORE FLASH '..scenarios..' scenarios PASS')

package.path='scripts/?.lua;'..package.path
local V={};V.__index=V
function Vector3(x,y,z)return setmetatable({x=x,y=y,z=z},V)end
function V.__add(a,b)return Vector3(a.x+b.x,a.y+b.y,a.z+b.z)end
function V.__mul(a,b)return Vector3(a.x*b,a.y*b,a.z*b)end
function V:Lerp(b,k)return Vector3(self.x+(b.x-self.x)*k,self.y+(b.y-self.y)*k,self.z+(b.z-self.z)*k)end
local Q={};Q.__index=Q
function Quaternion(w,x,y,z)return setmetatable({w=w,x=x,y=y,z=z},Q)end
function Q:Slerp(b,k) -- Equal endpoint quaternions in these pose fixtures.
 assert(self.w==b.w and self.x==b.x and self.y==b.y and self.z==b.z);return self
end
function Q.__mul(q,v)
 local u=Vector3(q.x,q.y,q.z);local dot=u.x*v.x+u.y*v.y+u.z*v.z;local uu=u.x*u.x+u.y*u.y+u.z*u.z
 return Vector3(2*dot*u.x+(q.w*q.w-uu)*v.x+2*q.w*(u.y*v.z-u.z*v.y),2*dot*u.y+(q.w*q.w-uu)*v.y+2*q.w*(u.z*v.x-u.x*v.z),2*dot*u.z+(q.w*q.w-uu)*v.z+2*q.w*(u.x*v.y-u.y*v.x))
end
package.loaded['core.Coord']={Vec=function(x,y,z)return Vector3(-x,y,z)end}
package.loaded.Config={CELL=.5};package.loaded['render.DriveView']={};package.loaded['render.WeaponView']={}
local writes=0
package.loaded['render.VehicleView']={New=function()
 local root={position=Vector3(0,0,0),scale=.5};function root:SetScale(n)writes=writes+1;self.scale=n end
 local v={root=root,joined={Update=function()end}};function v:AddPart()end;function v:Dispose()self.disposed=true end;return v
end}
local Combat=require'render.CombatView';local view=Combat.New({})
local q={w=math.sqrt(.5),x=0,y=math.sqrt(.5),z=0}
local piece={parts={{_cells={{2,3,4}}}},previous={p={1,2,3},q=q},current={p={5,8,9},q=q},age=0}
local world={viewEvents={},debris={events={{type='spawn',piece=piece}}}}
math.randomseed(582);local expectedRandom=math.random();math.randomseed(582)
view:Consume(world);local d=view.pieces[piece]
for _,age in ipairs({0,1,4.39,4.4,4.7,4.99,5,5.1})do
 piece.age=age;local before=writes;local old=d.scaleK;view:Update(.3,.016,{})
 local k=math.min(1,math.max(.01,(5-age)/.6));local root=d.view.root
 local pos=Vector3(-1,2,3):Lerp(Vector3(-5,8,9),.3)
 local rot=Quaternion(q.w,q.x,-q.y,-q.z);local wanted=pos+rot*(d.center*(.5*(1-k)))
 for _,axis in ipairs({'x','y','z'})do assert(math.abs(root.position[axis]-wanted[axis])<1e-12,axis..' pose')end
 assert(root.scale==.5*k);assert(writes-before==(old~=k and 1 or 0),'scale writes')
end
assert(math.random()==expectedRandom,'RNG sequence changed')
world.debris.events={{type='remove',piece=piece}};view:Consume(world);assert(d.view.disposed);assert(next(view.pieces)==nil);view:Dispose();view:Dispose()
print('COMBAT DEBRIS 8 pose/fade golden samples, unchanged RNG, release PASS')

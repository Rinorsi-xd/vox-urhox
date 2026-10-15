-- Actual production geometry against frozen matchView.js dimensions/dash rules.
local checks=0
local function Check(v,label) assert(v,label);checks=checks+1 end
function Vector3(x,y,z) return {x=x,y=y,z=z} end
Vector3=setmetatable({UP={x=0,y=1,z=0}},{__call=function(_,...) return {x=select(1,...),y=select(2,...),z=select(3,...)} end})
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a} end
TRIANGLE_LIST=0
Material={new=function() return {SetSurfaceShader=function(self,name) self.shader=name;return true end,Dispose=function() end} end}
package.preload['core.Coord']=function() return {Vec=function(x,y,z) return Vector3(-x,y,z) end} end
local function Node(name)
    local node={name=name,children={}}
    function node:CreateChild(n) local child=Node(n);self.children[n]=child;return child end
    function node:CreateComponent()
        local mesh={vertices={}}
        function mesh:BeginGeometry() self.vertices={} end
        function mesh:DefineVertex(v) self.vertices[#self.vertices+1]=v end
        function mesh:DefineNormal() end
        function mesh:DefineColor(v) self.color=v end
        function mesh:Commit() end
        self.mesh=mesh;return mesh
    end
    function node:Dispose() self.disposed=true end
    return node
end
package.path='scripts/?.lua;'..package.path
local scene=Node('Scene')
local mode={id='escort',path={{0,0,0},{3,4,0},{6,8,0}},cum={0,3,6},length=6,tuning={checkpoints={.5}}}
function mode:At() return {pos={2,1,0}} end
local view=require('render.ObjectiveView').New({scene=scene},mode)
local route=view.root.children.Route2.mesh.vertices
-- A 3m dash on a 3-4-5 slope ends at x=1.8,y=2.4; next dash starts at arc=5.
Check(math.abs(route[3].x+1.8)<1e-9 and math.abs(route[3].y-2.4)<1e-9,'3D dash length')
local nextDash=view.root.children.Route3.mesh.vertices
Check(math.abs(nextDash[3].x+1.8)<1e-9 and math.abs(nextDash[3].y-2.4)<1e-9,'continuous dash phase')
local post=view.root.children.Checkpoint1
Check(post.position.x==-3 and post.position.y==4,'checkpoint uses original horizontal cumulative nodes')
Check(#post.mesh.vertices==120,'closed 10-segment source cylinder')
view:Update(.1,{s=0,idle=0,pushing=0,contested=false})
Check(view.batches.PayloadHalo.mesh.material.shader:find('ObjectiveOverlay',1,true)~=nil,'intentional halo overlay')
Check(#view.batches.PayloadHalo.mesh.vertices==128*6,'source halo resolution')
view:Dispose();Check(view.root.disposed,'scene ownership release')
local capture={id='conquest',points={{pos={0,0,0},radius=22}},bases={blue={aim={0,5,0}},red={aim={50,5,0}}}}
local zones=require('render.ObjectiveView').New({scene=Node('Zones')},capture)
zones:Update(.1,{points={{v=.5,owner='blue'}},score={blue=100,red=100},shield={blue=true,red=false}}, {position={x=0,y=150,z=0}})
local volume=zones.batches.PointVolume1.mesh
-- Source fades by horizontal distance: a camera directly above has no 90m beam.
Check(#volume.vertices==96*6+96*6,'horizontal distance, fill plus 3m wall')
local minY,maxY=math.huge,-math.huge
for i=96*6+1,#volume.vertices do local y=volume.vertices[i].y;minY=math.min(minY,y);maxY=math.max(maxY,y) end
Check(minY==0 and maxY==3,'source wall bounds')
Check(volume.material.shader:find('ObjectiveOverlay',1,true)==nil,'volume depth tests')
Check(zones.batches.PointRing1.mesh.material.shader:find('ObjectiveOverlay',1,true)~=nil,'ring intentional overlay')
zones:Dispose()
return {result='PASS',checks=checks,boundary='Actual Lua geometry with renderer adapters; shader/depth pixels and Web performance require runtime verification.'}

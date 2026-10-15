local input=...
package.path='scripts/?.lua;'..package.path
local function Same(a,b,path)
    path=path or 'output';assert(type(a)==type(b),path..' type')
    if type(a)=='number' then assert(math.abs(a-b)<1e-12,path)
    elseif type(a)=='table' then
        for k,v in pairs(a) do Same(v,b[k],path..'.'..tostring(k)) end
        for k in pairs(b) do assert(a[k]~=nil,path..' extra '..tostring(k)) end
    else assert(a==b,path) end
end
Vector3=function(x,y,z)return {x=x,y=y,z=z}end
Vector2=function(x,y)return {x=x,y=y}end
Vector4=function(x,y,z,w)return {x=x,y=y,z=z,w=w}end
Color=function(r,g,b,a)return {r=r,g=g,b=b,a=a or 1}end
Variant=function(v)return v end;TRIANGLE_LIST=1;LINE_LIST=2
package.loaded['core.ResourceData']={Read=function(path)return assert(input.resources[path],path)end}
local Config=require 'Config'
local Coord=require 'core.Coord'
local Surface=require 'render.JoinedSurface'
local function Node(stats)
    local node={enabled=true}
    function node:CreateChild()stats.nodes=stats.nodes+1;return Node(stats)end
    function node:Dispose()self.disposed=true end
    function node:CreateComponent()
        stats.meshes=stats.meshes+1
        local g={vertices={},enabled=true}
        function g:BeginGeometry()stats.begins=stats.begins+1;self.vertices={}end
        function g:DefineVertex(v)self.vertices[#self.vertices+1]={p=v}end
        function g:DefineNormal(v)self.vertices[#self.vertices].n=v end
        function g:DefineColor(v)self.vertices[#self.vertices].c=v end
        function g:DefineTexCoord(v)self.vertices[#self.vertices].uv=v end
        function g:DefineTangent(v)self.vertices[#self.vertices].tangent=v end
        function g:Commit()stats.commits=stats.commits+1 end
        function g:SetMaterial(v)self.material=v end
        return g
    end
    return node
end
local function Stats()return {nodes=0,meshes=0,begins=0,commits=0,colors=0,clocks=0,materials=0}end
local function Joined(path)
    local stats=Stats()
    local modules={['render.JoinedSurface']=Surface,['parts.Materials']={Joined=function(slot,xray)return slot..tostring(xray)end,JoinedOutline=function()return 'outline'end},
        ['core.Coord']=Coord,Config={HexLinear=function(...)stats.colors=stats.colors+1;return Config.HexLinear(...)end}}
    local env=setmetatable({require=function(k)return assert(modules[k],k)end},{__index=_G})
    local M=assert(loadfile(path,'t',env))();local m=M.New(Node(stats));local colors={0xff3424,0x33aaff,0xe8edf0}
    local kinds={'cube','heavySlope','glassCorner','neonCube','slope','heavy'}
    for i=1,240 do m:Add({id=i,type=kinds[i%6+1],pos={i%20,i%3,i//20},rot=i%24,g=i%4+1,color=colors[i%3+1]}) end
    m:Update();local firstColors=stats.colors;local firstVertices=m.vertices
    local function Snapshot()
        local out={vertices=m.vertices,meshes={},outlines={}}
        for slot,mesh in pairs(m.meshes) do out.meshes[slot]={vertices=mesh.geometry.vertices,material=mesh.geometry.material,shadow=mesh.geometry.castShadows} end
        for id,line in pairs(m.outlines) do out.outlines[id]={vertices=line.geometry.vertices,enabled=line.node.enabled} end
        return out
    end
    local rows={Snapshot()}
    for i=2,240,7 do m:Remove(i) end
    m:Update();rows[#rows+1]=Snapshot()
    m:SetXray(true);rows[#rows+1]=Snapshot()
    m:SetXray(false);m:Clear();m:Update();rows[#rows+1]=Snapshot();m:Dispose()
    return rows,stats,firstColors,firstVertices
end
local old,oldStats,oldColors,vertices=Joined(input.baseline..'/JoinedMesh.lua')
local current,stats,colors=Joined('scripts/render/JoinedMesh.lua')
Same(old,current,'joined vertex/normal/color/material/outline/lifecycle')
assert(oldColors==vertices and colors==3,'all initial vertex color work reduces to three exact colors')
assert(oldStats.meshes==stats.meshes and oldStats.commits==stats.commits,'no geometry or mesh allocation changes')
print('[JoinedMeshCost] PASS exact mixed-shape vertices/normals/colors/materials/xray/removal; initial HexLinear calls '..oldColors..' -> '..colors)
local function Batch(path)
    local stats=Stats()
    local material={}
    function material:new()
        stats.materials=stats.materials+1
        return {SetSurfaceShader=function()return true end,SetShaderParameter=function(self,key,value)
            assert(key=='clock');stats.clocks=stats.clocks+1;self.clock=value
        end,Dispose=function()end}
    end
    local env=setmetatable({Material=material,require=function(k)assert(k=='core.Coord');return Coord end},{__index=_G})
    local M=assert(loadfile(path,'t',env))();local rows={}
    for _,kind in ipairs({'Glow','Smoke','Ring','Streak','Ribbon'}) do
        local batch=M.New(Node(stats),kind,4)
        for frame=1,7 do
            batch:Begin({3,5,-20},frame*.125)
            if frame==2 or frame==4 or frame==5 then
                for i=1,6 do
                    batch:Segment({i,2,3},{i+2,3,7},.3,{3,4,5},1.2,.4,.2,.8,true,.97)
                    batch:Disc({i,3,4},1,{2,3,4},.8,{1,0,0},{0,1,0},nil,1)
                end
            end
            batch:Finish()
            local row={kind=kind,frame=frame,enabled=batch.mesh.enabled,count=batch.count}
            if batch.count>0 then row.vertices=batch.mesh.vertices;row.clock=batch.material.clock end
            rows[#rows+1]=row
        end
        -- Zero-capacity batches must never initialize or upload an empty stream.
        local empty=M.New(Node(stats),kind,0);empty:Begin({0,0,0},99);empty:Disc({0,0,0},1,{1,1,1},1,{1,0,0},{0,1,0});empty:Finish()
        assert(not empty.mesh.enabled and empty.count==0);empty:Dispose();batch:Dispose()
    end
    return rows,stats
end
local previous,oldBatch=Batch(input.baseline..'/EffectBatch.lua')
local actual,newBatch=Batch('scripts/render/EffectBatch.lua')
Same(previous,actual,'batch vertex/normal/uv/tangent/HDR/clock/visibility')
assert(newBatch.commits==oldBatch.commits and newBatch.meshes==oldBatch.meshes and newBatch.materials==oldBatch.materials,'draw content/resources unchanged')
assert(oldBatch.begins==40 and newBatch.begins==15 and newBatch.clocks==15,'only fifteen nonempty frames initialize and set clock')
print('[EffectBatchCost] PASS five kinds, capacity, empty/nonempty transitions, exact vertices/clock; native begins/clock '..oldBatch.begins..' -> '..newBatch.begins)

-- Native vertex-by-vertex gate. Separate from all timing measurements.
local Base=require 'render.EffectBatch'
local Candidate=require 'dev.IndexedEffectCandidate'
local output='';for _,arg in ipairs(GetArguments()) do output=arg:match('^%-probe%-output=(.+)$') or output end
local checks,vertices=0,0;local rows={}
---@type Scene|nil
local scene=nil
local owned={}
local function Check(ok,label) checks=checks+1;assert(ok,label) end
local function Attr(v,kind)
    local p,n,uv=v.position,v.normal,v.texCoord
    local r={p.x,p.y,p.z,n.x,n.y,n.z,v.color,uv.x,uv.y}
    if kind=='Streak' then local t=v.tangent;r[10]=t.x;r[11]=t.y;r[12]=t.z;r[13]=t.w end
    return r
end
local function Compare(a,b,label)
    Check(a.count==b.count,label..' count');Check(a.mesh.enabled==b.mesh.enabled,label..' enabled')
    Check(b.geometry:GetIndexCount()==b.count*6,label..' index count')
    Check(b.geometry:GetVertexCount()==b.count*4,label..' vertex count')
    Check(b.geometry:IsEmpty()==(b.count==0),label..' empty')
    if a.count==0 then return end
    local data,index=b.vb:GetData(),b.ib:GetData();index:Seek(0)
    for vertex=0,a.count*6-1 do
        local corner=b.largeIndices and index:ReadUInt() or index:ReadUShort()
        data:Seek(corner*b.vb:GetVertexSize())
        local p,n,c,uv=data:ReadVector3(),data:ReadVector3(),data:ReadUInt(),data:ReadVector2()
        local actual={p.x,p.y,p.z,n.x,n.y,n.z,c,uv.x,uv.y}
        if b.kind=='Streak' then local t=data:ReadVector4();actual[10]=t.x;actual[11]=t.y;actual[12]=t.z;actual[13]=t.w end
        local expected=Attr(a.mesh:GetVertex(0,vertex),a.kind)
        Check(#actual==#expected,label..' attribute arity')
        for i=1,#expected do Check(actual[i]==expected[i],label..' vertex '..vertex..' attr '..i) end
        vertices=vertices+1
    end
    data:Clear();index:Clear()
    local expected,actual=a.mesh:GetBoundingBox(),b.mesh:GetBoundingBox()
    for _,axis in ipairs({'x','y','z'}) do
        local flat=expected.min[axis]==expected.max[axis]
        if flat then
            -- Observed Model sanitation affects bounds only, never vertex data.
            Check(actual.min[axis]<=expected.min[axis] and actual.max[axis]>=expected.max[axis],label..' flat bound covers data')
            Check(expected.min[axis]-actual.min[axis]<=.0011 and actual.max[axis]-expected.max[axis]<=.0011,label..' flat sanitation <= .0011m')
        else
            Check(actual.min[axis]==expected.min[axis] and actual.max[axis]==expected.max[axis],label..' active tight '..axis)
        end
    end
end
local function Run()
    local prior=io.open(output,'rb');if prior then prior:close();error('Preserve prior evidence') end
    local ok,err=xpcall(function()
        scene=Scene();scene:CreateComponent('Octree')
        for _,kind in ipairs({'Glow','Streak','Ribbon','Ring','Smoke'}) do for _,limit in ipairs({0,1,2}) do
            local a=Base.New(scene,kind,limit);local b=Candidate.New(scene,kind,limit)
            owned[#owned+1]=a;owned[#owned+1]=b
            local function Both(key,... ) a[key](a,...);b[key](b,...) end
            for revision,alpha in ipairs({-1,0,.7,1,2}) do
                Both('Begin',{0,0,-12},revision);Both('Finish');Compare(a,b,kind..' empty')
                Both('Begin',{0,0,-12},revision)
                local points={{1,2,3},{4,5,6},{7,8,9},{10,11,12}}
                local uvs={{.1,.2},{.3,.4},{.5,.6},{.7,.8}}
                local color={2,3,4};local params=revision%2==0 and {.2,.4,.6,.8} or nil
                for _=1,3 do Both('Quad',points,uvs,color,alpha,params) end
                Both('Finish');Compare(a,b,kind..' direct '..revision)
                for _,p in ipairs(points) do p[1]=99;p[2]=99;p[3]=99 end
                for _,uv in ipairs(uvs) do uv[1]=99;uv[2]=99 end
                color[1]=99;if params then params[1]=99 end
                Compare(a,b,kind..' caller mutation '..revision)
                Both('Begin',{0,0,-12},revision)
                Both('Segment',{0,0,0},{0,0,0},.4,{1,2,3},alpha,.3,0,1,true,.65)
                Both('Segment',{0,0,1},{0,0,4},.8,{2,1,3},alpha,.5,0,1,false,.9)
                Both('Finish');Compare(a,b,kind..' segments '..revision)
                Both('Begin',{0,0,-12},revision)
                Both('Disc',{3,2,10},2,{1,2,3},alpha,{1,0,0},{0,1,0},.2,2)
                Both('Finish');Compare(a,b,kind..' flat disc '..revision)
                a.node.position=Vector3(1,2,3);b.node.position=a.node.position
                a.node.scale=Vector3(2,3,4);b.node.scale=a.node.scale
                a.node.rotation=Quaternion(25,Vector3.UP);b.node.rotation=a.node.rotation
                Compare(a,b,kind..' node transform '..revision)
                Both('Begin',{0,0,-12},revision+1);Both('Finish');Compare(a,b,kind..' cleared '..revision)
            end
            rows[#rows+1]={kind=kind,limit=limit}
        end end
    end,debug.traceback)
    local disposal=true
    for _,batch in ipairs(owned) do local disposed=pcall(batch.Dispose,batch);if not disposed then disposal=false end end
    if scene then scene:Dispose();scene=nil end
    local result={status=ok and disposal and 'STRICT_PASS' or 'FAIL',checks=checks,deindexedVertices=vertices,
        cases=rows,disposePassed=disposal,error=not ok and tostring(err) or nil,
        boundary='Exact native deindexed position/normal/packed-color/UV/tangent equality. Bounds-only flat-axis Model sanitation allowance <= .0011m, no attribute tolerance. No timing or full combat/device claim; culling gate is separate.'}
    local file=assert(io.open(output,'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
function Start() Run() end

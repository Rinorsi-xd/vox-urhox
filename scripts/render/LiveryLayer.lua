local Project=require 'render.LiveryProjection'
local Data=require 'construction.LiveryData'
local Coord=require 'core.Coord'
local Gate=require 'app.ResourceGate'
local Quality=require 'render.Quality'
local M={};M.__index=M
function M.New(view)
    return setmetatable({view=view,meshes={},list={},dirty=false,preview=false,gate=Gate.New(),texturePaths={},disposed=false,
        async=false,jobs={},damage=false},M)
end
-- 驾驶/战斗中的车：掉件时被打掉零件上的贴花三角形立刻剔除（只重建一次网格，不重投影）；
-- 只有修复补回零件时才排队分帧精确重投影，期间旧贴花照常显示。编辑器、机库预览不开。
function M:SetDamageMode(on) self.damage=on==true end
-- While the livery editor is open, an edited decal first follows rigidly and is
-- re-projected in per-frame slices. Thumbnails and other one-shot callers keep
-- the synchronous path; SetAsync(false) finishes all pending projections.
function M:Set(list) self.list=list or {};self.dirty=true end
function M:SetPreview(d)
    local key=d and cjson.encode(d) or '';if key==self.previewKey then return end
    self.previewKey=key;self.preview=d;self.dirty=true
end
function M:PartsChanged() self.dirty=true end
local function Color(hex) return Vector3(((hex>>16)&255)/255,((hex>>8)&255)/255,(hex&255)/255) end
local function Retire(mesh)
    if not mesh then return end;mesh.node:Dispose();mesh.material:Dispose();mesh.vertices={};mesh.retired=true
end
local function Build(node,vertices,pause)
    local geometry=node:GetComponent('CustomGeometry') or node:CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
    -- Reverse winding at the same X-mirror boundary used by export-parts.
    for i=1,#vertices,3 do for _,index in ipairs({i,i+2,i+1}) do
        local v=vertices[index];geometry:DefineVertex(Coord.Vec(v.p[1],v.p[2],v.p[3]));geometry:DefineNormal(Coord.Vec(v.n[1],v.n[2],v.n[3]));geometry:DefineTexCoord(Vector2(v.u,v.v))
    end;if pause and i%768==1 then pause() end end;geometry:Commit();geometry.castShadows=false
    return geometry
end
-- Right-handed engine basis of a decal frame (X mirror, then flip the normal).
local function Basis(f)
    return Quaternion(Coord.Vec(f.x[1],f.x[2],f.x[3]),Coord.Vec(f.y[1],f.y[2],f.y[3]),Coord.Vec(f.n[1],f.n[2],f.n[3])*-1)
end
-- Move geometry projected in frame `from` (width w0) so it sits at decal d.
local function Follow(mesh,d)
    local to=Project.Frame(d);local from=mesh.frame
    local rotation=Basis(to)*Basis(from):Inverse();local scale=d.w/mesh.w
    local p0=Coord.Vec(from.p[1],from.p[2],from.p[3]);local p1=Coord.Vec(to.p[1],to.p[2],to.p[3])
    mesh.node.rotation=rotation;mesh.node.scale=Vector3(scale,scale,scale)
    mesh.node.position=p1-rotation*(p0*scale)
end
-- Per-part key fragments, rebuilt only when that part's identity fields change.
local partKeys=setmetatable({},{__mode='k'})
local function PartKey(p)
    local c=partKeys[p];local pos=p.pos;local g=p.g or 0
    if c and c.id==p.id and c.type==p.type and c.rot==p.rot and c.g==g and c.x==pos[1] and c.y==pos[2] and c.z==pos[3] then return c.key end
    c={id=p.id,type=p.type,rot=p.rot,g=g,x=pos[1],y=pos[2],z=pos[3],key=p.id..':'..p.type..':'..table.concat(pos,',')..':'..p.rot..':'..g}
    partKeys[p]=c;return c.key
end
local function Rest(mesh) mesh.node.position=Vector3.ZERO;mesh.node.rotation=Quaternion.IDENTITY;mesh.node.scale=Vector3.ONE end
function M:Mesh(d,parts,old,keep,order,ghost,owner)
    local st=Data.Catalog().byId[d.s];if not st then return nil end
    local path=st.kind=='shape' and st.mask or st.texture
    if not cache:Exists(path) then return nil end
    local near=Project.Near(d,st,parts);local key={};local nearKeys={}
    for _,p in ipairs(near) do local k=PartKey(p);key[#key+1]=k;nearKeys[k]=p.id end
    local tail=table.concat(d.p,',')..'|'..table.concat(d.n,',')..'|'..d.r..'|'..d.w..'|'..(d.f or 0)..'|'..st.aspect..(ghost and '|g' or '')..'|'..(owner or 0)
    local gk=table.concat(key,';')..'|'..tail
    local mesh
    for _,candidate in pairs(old) do if not keep[candidate] and candidate.key==gk then mesh=candidate;break end end
    if mesh and mesh.target then
        mesh.target=nil;self.jobs[mesh]=nil;Rest(mesh)
        if self.job and self.job.mesh==mesh then self:CancelJob() end
    end
    if not mesh and self.damage then
        local candidate=nil
        for _,c in pairs(old) do
            if not keep[c] and c.tail==tail and c.order==order and c.ghost==ghost and c.owner==owner and c.nearKeys then candidate=c;break end
        end
        if candidate then
            if not self:Damaged(candidate,nearKeys) then return nil end
            mesh=candidate
            local added=false;for k in pairs(nearKeys) do if not candidate.nearKeys[k] then added=true;break end end
            if added then
                -- 修复补回了零件：旧贴花先留着，精确投影分帧做完再替换
                mesh.target={d=cjson.decode(cjson.encode(d)),st=st,near=near,key=gk,nearKeys=nearKeys};self.jobs[mesh]=true
            else mesh.key=gk;mesh.nearKeys=nearKeys end
        end
    end
    if not mesh and self.async then
        -- The same decal slot moved: follow now, project the exact surface later.
        for _,candidate in pairs(old) do
            if not keep[candidate] and candidate.order==order and candidate.ghost==ghost and candidate.owner==owner and candidate.frame then
                mesh=candidate;break
            end
        end
        if mesh then
            Follow(mesh,d)
            mesh.target={d=cjson.decode(cjson.encode(d)),st=st,near=near,key=gk};self.jobs[mesh]=true
        end
    end
    if not mesh then
        local vertices=Project.Project(d,st,near);if #vertices==0 then return nil end
        local node=self.view.root:CreateChild(ghost and 'LiveryPreview' or 'Livery'..order)
        local geometry=Build(node,vertices)
        local material=Material:new();assert(material:SetSurfaceShader('Shaders/BLGL/Livery.shader'))
        geometry.material=material;mesh={node=node,geometry=geometry,material=material,vertices=vertices,key=gk,ghost=ghost,
            order=order,frame=Project.Frame(d),w=d.w,tail=tail,nearKeys=nearKeys}
    end
    mesh.owner=owner;keep[mesh]=true;mesh.material.renderOrder=100+order
    mesh.material:SetShaderParameter('opacity',Variant(ghost and .62 or 1.0))
    mesh.material:SetShaderParameter('shape_mask',Variant(st.kind=='shape' and 1.0 or 0.0))
    local c=d.c or st.colors
    if c and c~=cjson.null then
        mesh.material:SetShaderParameter('primary_color',Variant(Color(c[1] or st.colors[1])))
        mesh.material:SetShaderParameter('secondary_color',Variant(Color(c[2] or c[1] or st.colors[1])))
    end
    if mesh.texturePath~=path then
        local texture=assert(cache:GetResource('Texture2D',path),path)
        texture:SetSRGB(false)
        mesh.material:SetSurfaceTexture('image_map',texture);mesh.texturePath=path;self.texturePaths[path]=true
    end;return mesh
end
-- 战斗掉件：投在已不在附近零件上的三角形就地压成零面积（只改这些顶点，原生 Commit 重传），
-- 不在 Lua 里逐顶点重建整张贴花。挂着的精确投影任务基于旧零件，一并作废（否则完成后会把
-- 打掉的零件上的贴花装回来）。返回 false 表示贴花已无可见部分。
function M:Damaged(mesh,nearKeys)
    if mesh.target then
        self.jobs[mesh]=nil;if self.job and self.job.mesh==mesh then self:CancelJob() end
        mesh.target=nil;Rest(mesh)
    end
    local alive={};for _,id in pairs(nearKeys) do alive[id]=true end
    local vertices=mesh.vertices;local geometry=mesh.geometry
    -- 几何顶点与 vertices 一一对应（Build 按三角形顺序写入，只换了绕序）
    local inPlace=geometry:GetNumVertices(0)==#vertices
    local removed,live=false,0
    for i=1,#vertices,3 do
        local a=vertices[i]
        if not a.dead then
            if a.part==nil or alive[a.part] then live=live+1
            else
                a.dead=true;removed=true
                if inPlace then
                    local base=i-1;local point=geometry:GetVertex(0,base).position
                    geometry:GetVertex(0,base+1).position=point;geometry:GetVertex(0,base+2).position=point
                end
            end
        end
    end
    if live==0 then return false end
    if removed then
        if inPlace then geometry:Commit()
        else
            local kept={}
            for i=1,#vertices,3 do if not vertices[i].dead then kept[#kept+1]=vertices[i];kept[#kept+1]=vertices[i+1];kept[#kept+1]=vertices[i+2] end end
            mesh.vertices=kept;mesh.geometry=Build(mesh.node,kept);mesh.geometry.material=mesh.material
        end
    end
    return true
end
-- Advance at most one exact projection per frame within a small CPU budget.
function M:CancelJob()
    local job=self.job;self.job=nil
    if job and job.node then job.node:Dispose() end
end
function M:StepJobs(budget)
    local job=self.job
    if job and job.mesh.retired then self:CancelJob();job=nil end
    if not job then
        local mesh=next(self.jobs);if not mesh then return end
        self.jobs[mesh]=nil
        if mesh.retired or not mesh.target then return end
        local target=mesh.target;local result=nil
        job={mesh=mesh,target=target,deadline=math.huge}
        local function Pause() if os.clock()>job.deadline then coroutine.yield() end end
        job.thread=coroutine.create(function()
            result=Project.Project(target.d,target.st,target.near,Pause)
            -- Fill a hidden node in slices too; it replaces the visible one at once.
            if #result>0 then
                job.node=self.view.root:CreateChild(mesh.ghost and 'LiveryPreview' or 'Livery'..mesh.order);job.node.enabled=false
                job.geometry=Build(job.node,result,Pause)
            end
        end)
        job.result=function() return result end;self.job=job
    end
    job.deadline=budget<math.huge and os.clock()+budget or math.huge
    local ok,err=coroutine.resume(job.thread);if not ok then self:CancelJob();error(err) end
    if coroutine.status(job.thread)~='dead' then return end
    self.job=nil
    local mesh,target,vertices=job.mesh,job.target,job.result()
    if mesh.retired then return end
    -- Install the finished surface even if the decal has moved on; then follow
    -- the newest target from this frame and keep refining toward it.
    if job.node then
        mesh.node:Dispose();mesh.node=job.node;mesh.geometry=job.geometry
        job.geometry.material=mesh.material;mesh.node.enabled=true
    else mesh.node.enabled=false end
    mesh.vertices=vertices;mesh.key=target.key;mesh.frame=Project.Frame(target.d);mesh.w=target.d.w
    if target.nearKeys then mesh.nearKeys=target.nearKeys end
    if mesh.target==target then mesh.target=nil;Rest(mesh)
    elseif mesh.target then Follow(mesh,mesh.target.d);self.jobs[mesh]=true end
    local drag=self.dragFollow;if drag then self:Follow(drag[1],drag[2],drag[3],drag[4]) end
end
-- Gizmo drag preview: move every mesh of decal `index` (and its mirror twin)
-- rigidly to the dragged placement. Nothing is re-projected until the edit lands.
function M:Follow(index,d,twin,twinD)
    self.dragFollow={index,d,twin,twinD}
    for _,mesh in ipairs(self.meshes) do
        if mesh.frame and not mesh.retired then
            if mesh.order==index then Follow(mesh,d) elseif twinD and mesh.order==twin then Follow(mesh,twinD) end
        end
    end
end
function M:EndFollow() self.dragFollow=nil end
function M:SetAsync(on)
    self.async=on==true
    if not self.async then
        if self.dirty then self:Update() end
        while self.job or next(self.jobs) do self:StepJobs(math.huge) end
    end
end
-- 每帧最多推进一次分帧投影（同一张车可能同时被 Update 和 Tick 调到）
function M:Tick()
    if self.disposed or not (self.async or self.damage) or not (self.job or next(self.jobs)) then return end
    if self.damage then local frame=time.frameNumber;if self.stepFrame==frame then return end;self.stepFrame=frame end
    self:StepJobs(Quality.current.name=='mobile' and .004 or .006)
end
function M:Update()
    if self.disposed then return end
    self:Tick()
    if not self.dirty then return end;self.dirty=false
    local requested={};local catalog=Data.Catalog()
    for _,d in ipairs(self.list) do local s=catalog.byId[d.s];if s then requested[#requested+1]=s.kind=='shape' and s.mask or s.texture end end
    if self.preview then local s=catalog.byId[self.preview.s];if s then requested[#requested+1]=s.kind=='shape' and s.mask or s.texture end end
    local requestKey=table.concat(requested,'|')
    if requestKey~=self.requestKey then
        self.requestKey=requestKey
        self.gate:Start(requested,function(ok,err) if self.disposed then return end;if ok then self.dirty=true else print('[Livery] '..err) end end)
    end
    local parts={};for _,v in pairs(self.view.visuals) do parts[#parts+1]=v.part end;table.sort(parts,function(a,b) return a.id<b.id end)
    local old={};for _,v in pairs(self.meshes) do old[#old+1]=v end;if self.previewMesh then old[#old+1]=self.previewMesh end
    local keep={};local meshes={}
    local buckets={[0]={}};local owners=self.view.rotorOwners or {}
    for _,p in ipairs(parts) do local owner=owners[p.id] or 0;buckets[owner]=buckets[owner] or {};buckets[owner][#buckets[owner]+1]=p end
    for i,d in ipairs(self.list) do for owner,bucket in pairs(buckets) do
        local mesh=self:Mesh(d,bucket,old,keep,i,false,owner>0 and owner or nil)
        if mesh then meshes[#meshes+1]=mesh end
    end end
    self.previewMesh=self.preview and self:Mesh(self.preview,parts,old,keep,#self.list+1,true) or nil
    for _,v in ipairs(old) do if not keep[v] then Retire(v) end end;self.meshes=meshes
    local used={};for _,m in pairs(meshes) do used[m.texturePath]=true end;if self.previewMesh then used[self.previewMesh.texturePath]=true end
    for path in pairs(self.texturePaths) do if not used[path] then cache:ReleaseResource('Texture2D',path,false);self.texturePaths[path]=nil end end
end
function M:Clear()
    self.gate:Cancel();self.requestKey=nil;self:CancelJob();self.jobs={};self.dragFollow=nil
    for _,m in pairs(self.meshes) do Retire(m) end;Retire(self.previewMesh);self.meshes={};self.previewMesh=nil;self.preview=false;self.previewKey=nil
    for path in pairs(self.texturePaths) do cache:ReleaseResource('Texture2D',path,false) end;self.texturePaths={}
end
function M:Dispose() self.disposed=true;self:Clear() end
return M

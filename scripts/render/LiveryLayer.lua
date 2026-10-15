local Project=require 'render.LiveryProjection'
local Data=require 'construction.LiveryData'
local Coord=require 'core.Coord'
local Gate=require 'app.ResourceGate'
local M={};M.__index=M
function M.New(view)
    return setmetatable({view=view,meshes={},list={},dirty=false,preview=false,gate=Gate.New(),texturePaths={},disposed=false},M)
end
function M:Set(list) self.list=list or {};self.dirty=true end
function M:SetPreview(d)
    local key=d and cjson.encode(d) or '';if key==self.previewKey then return end
    self.previewKey=key;self.preview=d;self.dirty=true
end
function M:PartsChanged() self.dirty=true end
local function Color(hex) return Vector3(((hex>>16)&255)/255,((hex>>8)&255)/255,(hex&255)/255) end
local function Retire(mesh)
    if not mesh then return end;mesh.node:Dispose();mesh.material:Dispose();mesh.vertices={}
end
function M:Mesh(d,parts,old,keep,order,ghost,owner)
    local st=Data.Catalog().byId[d.s];if not st then return nil end
    local path=st.kind=='shape' and st.mask or st.texture
    if not cache:Exists(path) then return nil end
    local near=Project.Near(d,st,parts);local key={}
    for _,p in ipairs(near) do key[#key+1]=p.id..':'..p.type..':'..table.concat(p.pos,',')..':'..p.rot..':'..(p.g or 0) end
    local gk=table.concat(key,';')..'|'..table.concat(d.p,',')..'|'..table.concat(d.n,',')..'|'..d.r..'|'..d.w..'|'..(d.f or 0)..'|'..st.aspect..(ghost and '|g' or '')..'|'..(owner or 0)
    local mesh
    for _,candidate in pairs(old) do if not keep[candidate] and candidate.key==gk then mesh=candidate;break end end
    if not mesh then
        local vertices=Project.Project(d,st,near);if #vertices==0 then return nil end
        local node=self.view.root:CreateChild(ghost and 'LiveryPreview' or 'Livery'..order)
        local geometry=node:CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
        -- Reverse winding at the same X-mirror boundary used by export-parts.
        for i=1,#vertices,3 do for _,index in ipairs({i,i+2,i+1}) do
            local v=vertices[index];geometry:DefineVertex(Coord.Vec(table.unpack(v.p)));geometry:DefineNormal(Coord.Vec(table.unpack(v.n)));geometry:DefineTexCoord(Vector2(v.u,v.v))
        end end;geometry:Commit();geometry.castShadows=false
        local material=Material:new();assert(material:SetSurfaceShader('Shaders/BLGL/Livery.shader'))
        geometry.material=material;mesh={node=node,geometry=geometry,material=material,vertices=vertices,key=gk,ghost=ghost}
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
function M:Update()
    if self.disposed or not self.dirty then return end;self.dirty=false
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
    self.gate:Cancel();self.requestKey=nil
    for _,m in pairs(self.meshes) do Retire(m) end;Retire(self.previewMesh);self.meshes={};self.previewMesh=nil;self.preview=false;self.previewKey=nil
    for path in pairs(self.texturePaths) do cache:ReleaseResource('Texture2D',path,false) end;self.texturePaths={}
end
function M:Dispose() self.disposed=true;self:Clear() end
return M

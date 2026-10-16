-- Read the exported native mesh, reversing the exporter's X/winding conversion.
-- Projection shares exactly the triangles displayed by PartRig, not cell boxes.
local Defs=require("parts.Defs")
local JoinedSurface=require("render.JoinedSurface")
local PartAssets=require("parts.PartAssets")

local M={};local meshes={};local tick=0;local cachedVertices=0
function M.Read(layer)
    tick=tick+1;local old=meshes[layer.model];if old then old.tick=tick;return old.data end
    local file=assert(cache:GetFile(layer.model),layer.model)
    local ok,result=pcall(function()
        assert(file:ReadFileID()=='UMDL','Livery expects exported UMDL geometry')
        local vertices={};local count=file:ReadUInt()
        for i=1,count do
            local n,mask=file:ReadUInt(),file:ReadUInt();file:ReadUInt();file:ReadUInt()
            assert(mask==11 and n<1000000,'Unexpected livery vertex format')
            local list={};for j=1,n do
                local x,y,z,nx,ny,nz=file:ReadFloat(),file:ReadFloat(),file:ReadFloat(),file:ReadFloat(),file:ReadFloat(),file:ReadFloat()
                file:ReadFloat();file:ReadFloat();list[j]={-x,y,z,-nx,ny,nz}
            end;vertices[i]=list
        end
        local indices={};assert(file:ReadUInt()==count,'Unexpected livery index buffers')
        for i=1,count do
            local n,stride=file:ReadUInt(),file:ReadUInt();assert((stride==2 or stride==4) and n<3000000,'Unexpected livery indices')
            local list={};for j=1,n do list[j]=(stride==2 and file:ReadUShort() or file:ReadUInt())+1 end;indices[i]=list
        end
        local out={};assert(file:ReadUInt()==count,'Unexpected livery geometries')
        for i=1,count do
            assert(file:ReadUInt()==0 and file:ReadUInt()==1,'Unexpected livery LOD')
            file:ReadFloat();assert(file:ReadUInt()==TRIANGLE_LIST,'Unexpected livery primitive')
            local vb,ib,start,n=file:ReadUInt()+1,file:ReadUInt()+1,file:ReadUInt(),file:ReadUInt();local p,ix=vertices[vb],indices[ib]
            local tris={};for j=start+1,start+n,3 do tris[#tris+1]={p[ix[j]],p[ix[j+2]],p[ix[j+1]]} end
            out[i]={slot=layer.slots[i],triangles=tris}
        end;return out
    end)
    file:Dispose();if not ok then error(result) end
    local count=0;for _,mesh in ipairs(result) do count=count+#mesh.triangles*3 end
    -- A drag repeatedly projects the same chassis; retain a bounded CPU mesh set.
    if count<=200000 then
        meshes[layer.model]={data=result,tick=tick,vertices=count};cachedVertices=cachedVertices+count
        while true do
            local entries=0;local oldestTick=tick+1;local oldestKey=false
            for key,entry in pairs(meshes) do entries=entries+1;if entry.tick<oldestTick then oldestTick=entry.tick;oldestKey=key end end
            if entries<=16 and cachedVertices<=200000 then break end
            cachedVertices=cachedVertices-meshes[oldestKey].vertices;meshes[oldestKey]=nil
        end
    end
    return result
end
function M.Skip(slot)
    return slot:find('glow') or slot:find('Glow') or slot:find('beam') or slot:find('holo') or slot:find('neon')
        or slot:find('flag') or slot:find('flame') or slot:find('lamp') or slot:find('Fx') or slot:find('fx')
end
function M.Fixed(part)
    local def=Defs.PARTS[part.type]
    if not def or def.weapon or def.wheel or def.leg or def.mech then return false end
    if JoinedSurface.IsJoined(part) then return true end
    local data=PartAssets.Get(part.type,part.rot)
    return not data.segments or data.segments==cjson.null
end
return M

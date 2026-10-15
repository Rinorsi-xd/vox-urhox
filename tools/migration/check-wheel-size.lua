-- Compare original Three.js assembly with actual native scene transforms.
local View=require 'render.VehicleView'
local f=assert(io.open('tools/migration/source-wheel-size.json'));local fixture=cjson.decode(f:read('*a'));f:close()
local raw={}
local results={cases={},maxError=0}
---@type VehicleView|nil
local view=nil
local function Vec(v) return {v.x,v.y,v.z} end
local function Bounds(node,tire)
    local box=BoundingBox()
    for _,sm in ipairs(node:GetComponents('StaticModel',true)) do
        local name=sm.model.name
        if not raw[name] then
            local file=assert(io.open('assets/'..name,'rb'));local data=file:read('*a');file:close()
            assert(data:sub(1,4)=='UMDL');local count,p=string.unpack('<I4',data,5);local buffers={}
            for i=1,count do
                local n,mask,a,b;n,mask,a,b,p=string.unpack('<I4I4I4I4',data,p);assert(mask==11)
                local points={}
                for k=1,n do local x,y,z=string.unpack('<fff',data,p);p=p+32;points[k]=Vector3(x,y,z) end
                buffers[i]=points
            end
            raw[name]=buffers
        end
        for i,points in ipairs(raw[name]) do
            local isTire=false
            for _,layer in ipairs(view.visuals[1].data.segments.spin.layers) do
                if layer.model==name and layer.slots[i]=='rubber' then isTire=true end
            end
            if not tire or isTire then for _,p in ipairs(points) do
                local v=sm.node:LocalToWorld(p);box:Merge(Vector3(-v.x,v.y,v.z))
            end end
        end
    end
    return {min=Vec(box.min),max=Vec(box.max)}
end
V.atFrame(50,function() view=View.New(VOX_HANGAR.scene,'WheelSizeQA');view:SetVisible(false) end)
for i,c in ipairs(fixture.cases) do V.atFrame(50+i,function()
    view:Clear();local part=c.part;part.id=1
    local vis=view:AddPart(part)
    local hub=vis.rig.spin.worldPosition
    local actual={whole=Bounds(vis.node),spin=Bounds(vis.rig.spin),tire=Bounds(vis.rig.spin,true),hub={-hub.x,hub.y,hub.z}}
    local error=0
    for _,key in ipairs({'whole','spin','tire'}) do
        for _,side in ipairs({'min','max'}) do for k=1,3 do error=math.max(error,math.abs(actual[key][side][k]-c[key][side][k])) end end
    end
    for k=1,3 do error=math.max(error,math.abs(actual.hub[k]-c.hub[k])) end
    results.maxError=math.max(results.maxError,error)
    results.cases[i]={type=part.type,rot=part.rot,pos=part.pos,maxError=error,actual=actual,expected=c}
    V.assert(error<.00002,part.type..' mounted wheel width/diameter/hub, rotation '..part.rot..', error '..error)
end) end
V.atFrame(52+#fixture.cases,function()
    view:Dispose();view=nil
    local file=assert(io.open('docs/migration/evidence/wheel-size-measurements.json','w'));file:write(cjson.encode(results));file:close()
    V.finish()
end)

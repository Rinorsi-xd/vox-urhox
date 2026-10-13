local M={};M.__index=M
local corners={{0,0},{1,0},{0,1},{0,1},{1,0},{1,1}}
function M.New(root,data,materials)
    local self=setmetatable({},M);self:init(root,data,materials);return self
end
function M:init(root,data,materials)
    self.materials=materials;self.data=data;self.time=0;self.uploads=0;self.disposed=false
    self.node=root:CreateChild('WarehouseDust')
    self.geometry=self.node:CreateComponent('CustomGeometry');self.geometry.dynamic=false
    self.material=Material:new();assert(self.material:SetSurfaceShader('Shaders/BLGL/Warehouse/Dust.shader'))
    self.material.renderOrder=133;self.geometry.material=self.material;self.geometry.castShadows=false
    local g=self.geometry;g:BeginGeometry(0,TRIANGLE_LIST)
    for i,p in ipairs(data.dust.positions) do for _,q in ipairs(corners) do
        g:DefineVertex(Vector3(-p[1],p[2],p[3]));g:DefineNormal(Vector3(data.dust.seeds[i],0,0));g:DefineTexCoord(Vector2(q[1],q[2]))
    end end
    -- GPU drift extends beyond seed bounds; degenerate triangles preserve culling.
    for _,p in ipairs({Vector3(-27,-.2,-30),Vector3(27,16.2,30)}) do for _=1,3 do
        g:DefineVertex(p);g:DefineNormal(Vector3.ZERO);g:DefineTexCoord(Vector2.ZERO)
    end end
    g:Commit();self.uploads=1
end
function M:Update(time)
    self.time=time;self.material:SetShaderParameter('hangar_time',Variant(time))
    for i,d in ipairs(self.data.materials) do local m=self.materials[i]
        if m and d.role=='orangePulse' then
            local scale=(3.0+math.sin(time*1.6)*.25)/3.0
            m:SetShaderParameter('emission_color',Variant(Vector3(d.emission[1]*scale,d.emission[2]*scale,d.emission[3]*scale)))
        elseif m and d.role=='traderHolo' then
            m:SetShaderParameter('tint',Variant(Vector4(d.color[1],d.color[2],d.color[3],.85+math.sin(time*7)*.05+(math.sin(time*23)>.97 and -.4 or 0))))
        end
    end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.node:Dispose();self.material:Dispose();self.materials={};self.data={}
end
return M

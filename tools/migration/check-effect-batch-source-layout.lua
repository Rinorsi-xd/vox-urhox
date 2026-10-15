package.path='scripts/?.lua;'..package.path
local function vector(x,y,z,w)return {x=x,y=y,z=z,w=w}end
Vector2=vector;Vector3=vector;Vector4=vector;Color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end;Variant=function(v)return v end;TRIANGLE_LIST=1
package.loaded['core.Coord']={Vec=vector}
Material={};function Material:new()local m={};function m:SetSurfaceShader()return true end;function m:SetShaderParameter()end;function m:Dispose()end;return m end
local function root()
 local node={};function node:CreateChild()return root()end;function node:Dispose()end
 function node:CreateComponent()
  local c={vertices={}};function c:BeginGeometry()self.vertices={}end
  function c:DefineVertex(v)self.vertices[#self.vertices+1]={position=v}end
  function c:DefineNormal(n)self.vertices[#self.vertices].normal=n end
  function c:DefineColor(n)self.vertices[#self.vertices].color=n end
  function c:DefineTexCoord(n)self.vertices[#self.vertices].uv=n end
  function c:DefineTangent(n)self.vertices[#self.vertices].tangent=n end
  function c:Commit()self.committed=true end;return c
 end;return node
end
local Batch=require'render.EffectBatch';local st=Batch.New(root(),'Streak',10);st:Begin({0,0,-10},0)
st:Segment({0,0,0},{0,0,10},.4,{3,2,1},.7,.3,0,1,true,.97);st:Finish()
assert(#st.mesh.vertices==6);for _,v in ipairs(st.mesh.vertices)do assert(v.tangent.x==.97 and v.normal.x==.3 and v.normal.y==10 and v.normal.z==.4)end
assert(math.abs(st.mesh.vertices[3].position.z-10.2)<1e-12,'rounded head extension')
local glow=Batch.New(root(),'Glow',10);glow:Begin({0,0,-10},0);glow:Disc({0,0,0},2,{2,3,4},1.2,{1,0,0},{0,1,0},nil,1)
local p=glow.mesh.vertices[1];assert(p.normal.y==1,'legacy gradient profile');assert(p.color.a==1);assert(math.abs(p.color.r*16-2.4)<1e-12,'HDR alpha above one retained')
local smoke=Batch.New(root(),'Smoke',10);assert(smoke.material.renderOrder<st.material.renderOrder and st.material.renderOrder<glow.material.renderOrder,'source smoke/light ordering')
st:Begin({0,0,-10},1);st:Finish();assert(not st.mesh.enabled,'empty batch hidden')
print('EFFECT BATCH taper/geometry/profile/HDR-alpha/order/empty layout PASS')

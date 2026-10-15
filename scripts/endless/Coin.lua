-- Source endlessLoot.js: six-sided radius .55, height .14, three stacked coins.
local M={}
function M.Add(parent,material,index)
    local node=parent:CreateChild('Coin');node.position=Vector3((index-1)*.18,index*.17,(index%2)*.12);node.rotation=Quaternion(math.deg(index*.4),Vector3.UP)
    local mesh=node:CreateComponent('CustomGeometry');mesh:BeginGeometry(0,TRIANGLE_LIST)
    local function Vertex(p,n) mesh:DefineVertex(p);mesh:DefineNormal(n);mesh:DefineTexCoord(Vector2.ZERO) end
    local radius,half=.55,.07
    for i=0,5 do
        local a,b=i*math.pi/3,(i+1)*math.pi/3
        local x,z=math.sin(a)*radius,math.cos(a)*radius;local u,w=math.sin(b)*radius,math.cos(b)*radius
        local p,q,r,s=Vector3(x,-half,z),Vector3(u,-half,w),Vector3(u,half,w),Vector3(x,half,z)
        local normal=Vector3(math.sin((a+b)/2),0,math.cos((a+b)/2))
        for _,v in ipairs({p,q,r,p,r,s}) do Vertex(v,normal) end
        for _,v in ipairs({Vector3(0,half,0),s,r}) do Vertex(v,Vector3.UP) end
        for _,v in ipairs({Vector3(0,-half,0),q,p}) do Vertex(v,Vector3.DOWN) end
    end
    mesh:Commit();mesh:SetMaterial(material);return node
end
return M

-- Original warehouse.js articulation. Static batches stay merged; only seven
-- authored transforms move. Geometry is baked relative to its nearest joint.
local M={};M.__index=M
function M.New(root,definitions)
    local self=setmetatable({},M);self:init(root,definitions);return self
end
function M:init(root,definitions)
    self.nodes={};self.time=0;self.updates=0;self.disposed=false
    for _,d in ipairs(definitions) do
        local node=(d.parent and assert(self.nodes[d.parent]) or root):CreateChild('Warehouse_'..d.id)
        local p,q,s=d.position,d.quaternion,d.scale
        node.position=Vector3(-p[1],p[2],p[3]);node.rotation=Quaternion(q[4],q[1],-q[2],-q[3]);node.scale=Vector3(table.unpack(s))
        self.nodes[d.id]=node
    end
end
function M:Update(time)
    if self.disposed then return end
    self.time=time;self.updates=self.updates+1
    local n=self.nodes
    n.bridge.position=Vector3(0,0,-22+(0.5+0.5*math.sin(time*.07))*6)
    n.trolley.position=Vector3(14-math.sin(time*.05+1)*3,0,0)
    local top=14.2;local hang=9.5+math.sin(time*.11)*.4
    n.load.position=Vector3(0,top-hang,0)
    n.cable.scale=Vector3(1,hang-1.3,1)
    n.cable.position=Vector3(0,top-(hang-1.3)/2,0)
    n.bot.position=Vector3(-.6,math.sin(time*1.3)*.04,-1.3)
    n.head.rotation=Quaternion(-math.deg(math.sin(time*.45)*.35),Vector3.UP)
end
function M:Snapshot()
    local nodes={}
    for id,node in pairs(self.nodes) do
        local p,q,s=node.position,node.rotation,node.scale
        nodes[id]={position={-p.x,p.y,p.z},quaternion={q.x,-q.y,-q.z,q.w},scale={s.x,s.y,s.z}}
    end
    return {time=self.time,updates=self.updates,nodes=nodes}
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    for _,id in ipairs({'bridge','trader'}) do self.nodes[id]:Dispose() end
    self.nodes={}
end
return M

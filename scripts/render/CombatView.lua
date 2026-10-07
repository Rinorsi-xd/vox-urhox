local DriveView=require "render.DriveView"
local View=require "render.VehicleView"
local Coord=require "core.Coord"
local CELL=require("Config").CELL
local M={};M.__index=M
local function Vec(p) return Coord.Vec(table.unpack(p)) end
local function Quat(q) return Quaternion(q.w,q.x,-q.y,-q.z) end
function M.New(scene) return setmetatable({scene=scene,units={},pieces={}},M) end
function M:Consume(world)
    for _,e in ipairs(world.viewEvents) do
        local v=self.units[e.unit]
        if e.type=="unitSpawn" then
            if v then v:Dispose() end
            self.units[e.unit]=DriveView.New(self.scene,e.unit.bp,e.unit.vehicle)
        elseif e.type=="partRemoved" then if v then v.view:RemovePart(e.id) end
        elseif e.type=="unitRebuilt" then if v then v:Bind(e.unit.bp,e.unit.vehicle) end
        elseif e.type=="unitKilled" or e.type=="unitRemoved" then
            if v then v:Dispose();self.units[e.unit]=nil end
        end
    end
    world.viewEvents={}
    for _,e in ipairs(world.debris.events) do
        if e.type=="spawn" then
            local vis=View.New(self.scene,"DetachedParts");local count=0;local c={0,0,0}
            for _,p in ipairs(e.piece.parts) do
                vis:AddPart(p)
                for _,cell in ipairs(p._cells) do c[1]=c[1]+cell[1];c[2]=c[2]+cell[2]+.5;c[3]=c[3]+cell[3];count=count+1 end
            end
            self.pieces[e.piece]={view=vis,center=Coord.Vec(c[1]/count,c[2]/count,c[3]/count)}
        else
            local d=self.pieces[e.piece];if d then d.view:Dispose();self.pieces[e.piece]=nil end
        end
    end
    world.debris.events={}
end
function M:SavePose() for _,view in pairs(self.units) do view:SavePose() end end
function M:Update(alpha,dt,context)
    for _,view in pairs(self.units) do
        view:Update(alpha,dt,context)
        view.view:UpdateIdle(dt,context and context.time or 0)
        view.view:UpdateWeaponEffects(dt,context)
    end
    for piece,d in pairs(self.pieces) do
        local root=d.view.root;root.position=Vec(piece.previous.p):Lerp(Vec(piece.current.p),alpha)
        root.rotation=Quat(piece.previous.q):Slerp(Quat(piece.current.q),alpha)
        local k=math.min(1,math.max(.01,(5-piece.age)/.6));root:SetScale(CELL*k)
        root.position=root.position+root.rotation*(d.center*(CELL*(1-k)))
    end
end
function M:Dispose()
    for _,v in pairs(self.units) do v:Dispose() end
    for _,d in pairs(self.pieces) do d.view:Dispose() end
    self.units={};self.pieces={}
end
return M

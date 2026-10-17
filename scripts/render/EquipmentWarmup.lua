-- Loading-only equipment draws use the production renderer without simulation.
local Equipment=require 'render.EquipmentEffects'
local Quality=require('render.Quality').current
local M={};M.__index=M
local function Source(p) return {-p.x,p.y,p.z} end
local function Collect(drive,visuals,seen)
    local equipment=drive and drive.equipment
    if not equipment or equipment.disposed then return end
    for _,item in pairs(equipment.items) do
        local s=item.vis.data.segments
        local family=(s.thruster or s.mech) and 'Thruster' or s.hover and 'Hover' or 'Contact'
        if not seen[family] then
            seen[family]=true;visuals[#visuals+1]=item.vis
        end
    end
end
function M.New(session)
    local visuals,seen={},{}
    Collect(session.view,visuals,seen)
    for _,drive in pairs(session.combatView and session.combatView.units or {}) do Collect(drive,visuals,seen) end
    if #visuals==0 then return nil end
    local self=setmetatable({},M)
    local ok,err=pcall(self.init,self,session,visuals)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:init(session,visuals)
    self.disposed=false;self.kinds={};self.camera=session.camera:GetCamera()
    self.time=session.effects.time
    self.owner=Equipment.New(session.scene)
    -- Bind copies presentation bookkeeping; no live item or vehicle is updated.
    self.owner:Bind({visuals=visuals},{})
    for _,item in pairs(self.owner.items) do
        local s=item.vis.data.segments
        local kind=(s.thruster or s.mech) and 'Thruster' or s.hover and 'Hover'
        if kind then self.kinds[kind]=item end
    end
    self:Show(0)
end
function M:Show(copies)
    if self.disposed then return end
    local owner=self.owner
    if not owner or not owner.root then return end
    owner.root.enabled=copies>0
    if copies==0 then return end
    local camera=self.camera.node;local rotation=camera.worldRotation
    local native=camera.worldPosition+rotation*Vector3.FORWARD*8
    for kind,item in pairs(self.kinds) do
        for i=1,4 do
            local p=owner:Proxy(item,i,kind)
            p.node.enabled=i<=copies;p.model.enabled=i<=copies
            p.node.position=native+rotation*Vector3.RIGHT*((i-2.5)*.7)
                +rotation*Vector3.UP*(kind=='Thruster' and -.6 or .6)
            p.node.rotation=rotation;p.node:SetScale(Vector3(.4,.4,.8))
            p.model.instanceCustomData=Vector4(1,.37,2,kind=='Thruster' and Quality.thrusterSteps or Quality.hoverSteps)
        end
    end
    local right,up=Source(rotation*Vector3.RIGHT),Source(rotation*Vector3.UP)
    for kind,batch in pairs(owner.batches) do
        batch:Begin(Source(camera.worldPosition),self.time)
        for i=1,copies do
            local at=Source(native+rotation*Vector3.RIGHT*((i-2.5)*.7))
            if kind=='Flare' then
                local r,u=rotation*Vector3.RIGHT*.2,rotation*Vector3.UP*.2
                local p=native+rotation*Vector3.RIGHT*((i-2.5)*.7)
                batch:Quad({Source(p-r-u),Source(p+r-u),Source(p-r+u),Source(p+r+u)},
                    {{-1,-1},{1,-1},{-1,1},{1,1}},{1,1,1},1,{1,.37,1})
            else batch:Disc(at,.4,{.08,.65,1.5},1,right,up) end
        end
        batch:Finish()
    end
end
function M:Snapshot()
    local batches,volumes=0,0
    if self.owner then
        for _ in pairs(self.owner.batches) do batches=batches+1 end
        for _ in pairs(self.kinds) do volumes=volumes+1 end
    end
    return {batches=batches,volumes=volumes,disposed=self.disposed}
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.owner then self.owner:Dispose();self.owner=nil end
    self.camera=nil;self.kinds={}
end
return M

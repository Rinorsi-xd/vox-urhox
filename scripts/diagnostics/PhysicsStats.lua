-- 物理诊断，只在性能监控开启时工作（PerformanceBindings 每帧把 monitor 交过来），不改玩法。
-- 每个物理空间每秒抽一步：
--   统计刚体（静态/动态/运动学/触发器、动态里醒着的）、碰撞形状（总数、动态刚体上的、醒着的刚体上的、按形状类型）；
--   本步碰撞对与接触点数（这一步临时订阅 PhysicsCollision，只读 Contacts 缓冲长度，不解析）；
--   先单独跑一次 UpdateCollisions（只做宽相 + 窄相碰撞检测）计时，再跑整步 Update 计时。
--   整步里自带一次碰撞检测，所以「求解 + 积分 + 碰撞事件」≈ 整步 - 单独检测，是估算值；
--   额外那次检测只在抽样步发生，会让这一步多花一份检测时间、接触缓存提前刷新一次。
-- 计时用毫秒整数时钟，单次有量化误差，按抽样次数取平均。
local M={monitor=nil}
local INTERVAL=1000
local CONTACT_BYTES=32 -- Vector3 位置 + Vector3 法线 + 距离 + 冲量
local SHAPE_NAMES={}
local function Now() return Time:GetSystemTime() end
local function Delta(a,b) return (a-b)%4294967296 end
local states=setmetatable({},{__mode='k'})
local receiver=nil ---@type LuaScriptObject|nil
local counting=nil ---@type table|nil
local function ShapeName(kind)
    if not next(SHAPE_NAMES) then
        for name,value in pairs({box=SHAPE_BOX,sphere=SHAPE_SPHERE,staticPlane=SHAPE_STATICPLANE,cylinder=SHAPE_CYLINDER,
            capsule=SHAPE_CAPSULE,cone=SHAPE_CONE,triangleMesh=SHAPE_TRIANGLEMESH,convexHull=SHAPE_CONVEXHULL,
            terrain=SHAPE_TERRAIN,gimpact=SHAPE_GIMPACTMESH}) do if value~=nil then SHAPE_NAMES[value]=name end end
    end
    return SHAPE_NAMES[kind] or tostring(kind)
end
local function Receiver()
    if receiver then return receiver end
    local node=Node();M.node=node
    receiver=node:CreateScriptObject('LuaScriptObject')
    return receiver
end
local function Census(scene)
    local c={bodies=0,static=0,dynamic=0,kinematic=0,trigger=0,awake=0,shapes=0,dynamicShapes=0,awakeShapes=0,dynamicNodes=0,dynamicShapeTypes={},staticShapeTypes={}}
    for _,body in ipairs(scene:GetComponents('RigidBody',true)) do
        if body.enabled then
            c.bodies=c.bodies+1
            local shapes=body.node:GetComponents('CollisionShape');local n=#shapes
            c.shapes=c.shapes+n
            if body.trigger then c.trigger=c.trigger+1
            elseif body.kinematic then c.kinematic=c.kinematic+1
            elseif body.mass==0 then
                c.static=c.static+1
                for _,shape in ipairs(shapes) do
                    local name=ShapeName(shape.shapeType);c.staticShapeTypes[name]=(c.staticShapeTypes[name] or 0)+1
                end
            else
                c.dynamic=c.dynamic+1;c.dynamicShapes=c.dynamicShapes+n
                -- 物理每步回写刚体节点变换，子节点越多，引擎标脏/更新变换的量越大
                c.dynamicNodes=c.dynamicNodes+body.node:GetNumChildren(true)
                if body.active then c.awake=c.awake+1;c.awakeShapes=c.awakeShapes+n end
                for _,shape in ipairs(shapes) do
                    local name=ShapeName(shape.shapeType);c.dynamicShapeTypes[name]=(c.dynamicShapeTypes[name] or 0)+1
                end
            end
        end
    end
    return c
end
--- Space:Step 的诊断版本；返回 true 表示这一步已由这里完成。
---@param space PhysicsSpace
---@param dt number
function M.Step(space,dt)
    local monitor=M.monitor
    if not monitor or not monitor.enabled or not monitor.recording then return false end
    local now=Now();local s=states[space]
    if not s then s={last=now-INTERVAL,samples=0,collideMs=0,stepMs=0,pairs=0,contacts=0};states[space]=s end
    if Delta(now,s.last)<INTERVAL then return false end
    s.last=now
    local census=Census(space.scene)
    local world=space.world
    local r=Receiver();counting={pairs=0,contacts=0}
    r:SubscribeToEvent(world,'PhysicsCollision',function(_,_,data)
        local c=counting;if not c then return end
        c.pairs=c.pairs+1
        local buffer=data['Contacts']:GetBuffer();if buffer then c.contacts=c.contacts+math.floor(buffer.size/CONTACT_BYTES) end
    end)
    local t0=Now();world:UpdateCollisions();local t1=Now()
    world:Update(dt);local t2=Now()
    r:UnsubscribeFromEvent(world,'PhysicsCollision')
    local seen=counting;counting=nil
    s.samples=s.samples+1;s.collideMs=s.collideMs+Delta(t1,t0);s.stepMs=s.stepMs+Delta(t2,t1)
    s.pairs=s.pairs+seen.pairs;s.contacts=s.contacts+seen.contacts
    local n=s.samples
    M.last={samples=n,iterations=world.numIterations,
        bodies=census.bodies,static=census.static,dynamic=census.dynamic,kinematic=census.kinematic,trigger=census.trigger,awake=census.awake,
        shapes=census.shapes,dynamicShapes=census.dynamicShapes,awakeShapes=census.awakeShapes,dynamicNodes=census.dynamicNodes,
        dynamicShapeTypes=census.dynamicShapeTypes,staticShapeTypes=census.staticShapeTypes,
        pairs=seen.pairs,contacts=seen.contacts,avgPairs=s.pairs/n,avgContacts=s.contacts/n,
        -- 平均值：单独碰撞检测、整步、两者之差（求解+积分+碰撞事件的估算）
        collideMs=s.collideMs/n,stepMs=s.stepMs/n,solveEstimateMs=math.max(0,s.stepMs-s.collideMs)/n}
    return true
end
--- 碰撞事件 Lua 回调计时（在 world:Update 里同步执行，会算进 physics.Step）
---@param name string
function M.Scope(name)
    local monitor=M.monitor
    if not monitor or not monitor.enabled then return nil end
    return monitor:Begin(name)
end
return M

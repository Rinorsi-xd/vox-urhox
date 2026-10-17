-- Explicit user markers only. Queries observe collision without changing it.
local Math3=require 'core.Math3'
local M={}
local function Number(value)
    return type(value)=='number' and value==value and math.abs(value)<math.huge and value or nil
end
local function Primitive(value)
    if type(value)=='number' then return Number(value) end
    if type(value)=='string' then return value:sub(1,240) end
    if type(value)=='boolean' then return value end
    return nil
end
local function Point(value)
    if type(value)~='table' then return nil end
    local x,y,z=Number(value[1] or value.x),Number(value[2] or value.y),Number(value[3] or value.z)
    if x and y and z then return {x,y,z} end
    return nil
end
local function Rotation(value)
    if type(value)~='table' then return nil end
    local x,y,z,w=Number(value.x),Number(value.y),Number(value.z),Number(value.w)
    if x and y and z and w then return {x=x,y=y,z=z,w=w} end
    return nil
end
local function Read(result,label,callback)
    local ok,value=pcall(callback)
    if ok then return value end
    result.errors=result.errors or {}
    if #result.errors<8 then result.errors[#result.errors+1]={stage=label,error=tostring(value):sub(1,240)} end
    return nil
end
local function Hit(result,hit)
    if type(hit)~='table' then return nil end
    local out={dist=Number(hit.dist),point=Point(hit.point),normal=Point(hit.normal),collider=Primitive(hit.collider)}
    local owner=hit.owner
    if type(owner)=='table' then
        local ref=type(owner.ref)=='table' and owner.ref or {}
        out.owner={type=Primitive(owner.type),id=Primitive(owner.id) or Primitive(ref.id),name=Primitive(owner.name) or Primitive(ref.name)}
    end
    Read(result,'hit.native',function()
        local native=hit.body and hit.body.native
        if native then
            out.nodeName=native.node and Primitive(native.node.name)
            out.collisionLayer=Primitive(native.collisionLayer)
            out.collisionMask=Primitive(native.collisionMask)
        end
    end)
    return out
end
local function Capture(app,result)
    if not app then result.reason='no-app';return end
    result.mode=Primitive(app.mode)
    local trial=app.trial
    if not trial or trial.disposed then result.reason='no-active-trial';return end
    result.map=Primitive(type(trial.map)=='table' and trial.map.id or trial.map)
    result.aimPoint=Point(trial.aimPoint)
    local vehicle=trial.vehicle
    local body=vehicle and vehicle.body
    local space=trial.world and trial.world.space
    if not body or not space or space.disposed then result.reason='no-active-vehicle-world';return end
    if body.isValid and not body.isValid() then result.reason='invalid-body';return end
    local position=Point(body.translation())
    local rotation=Rotation(body.rotation())
    if not position or not rotation then result.reason='invalid-pose';return end
    result.position=position;result.rotation=rotation;result.available=true
    result.center=Read(result,'body.center',function() return Point(body.center()) end) or {table.unpack(position)}
    local forward=Math3.Normalize(Math3.Rotate(rotation,{0,0,1}))
    if Math3.Length(forward)<.001 then result.available=false;result.reason='invalid-forward';return end
    result.forward=forward
    local bounds=vehicle.spec and vehicle.spec.bounds
    local lo=bounds and Point(bounds.min) or {-1,-.5,-1}
    local hi=bounds and Point(bounds.max) or {1,.5,1}
    lo=lo or {-1,-.5,-1};hi=hi or {1,.5,1}
    result.bounds={min=lo,max=hi}
    local function Local(x,y,z) return Math3.Add(position,Math3.Rotate(rotation,{x,y,z})) end
    local lower=lo[2]+math.min(.35,math.max(.05,(hi[2]-lo[2])*.2))
    local front=hi[3]-.05
    local rayLength=math.min(80,math.max(12,hi[3]+12))
    -- Side view: center ----> [wall]; front-low ----> [lip]
    -- The fifth ray slopes down to distinguish a low step from a tall wall.
    local probes={
        {'center',result.center,forward,rayLength},
        {'front-low',Local(0,lower,front),forward,12},
        {'left-low',Local(lo[1]+.05,lower,front),forward,12},
        {'right-low',Local(hi[1]-.05,lower,front),forward,12},
        {'front-down',Local(0,lower,front),Math3.Normalize(Math3.Add(forward,{0,-.35,0})),12},
    }
    result.rays={}
    for _,probe in ipairs(probes) do
        local row={label=probe[1],origin=probe[2],direction=probe[3],length=probe[4]}
        result.rays[#result.rays+1]=row
        local hit=Read(result,'ray.'..probe[1],function() return space:Raycast(probe[2],probe[3],probe[4],body) end)
        row.hit=Read(result,'serialize.'..probe[1],function() return Hit(result,hit) end)
    end
end
function M.Capture(app)
    local result={schema=1,space='source-rh-metres',available=false}
    Read(result,'capture',function() Capture(app,result) end)
    return result
end
return M

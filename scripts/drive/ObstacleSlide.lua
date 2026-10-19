-- Contact-only experiment. Never move a body unless every solid chassis shape
-- clears both legs of the correction; no ray-only teleport through scenery.
local Config=require 'Config'
local V=require 'core.Math3'
local Coord=require 'core.Coord'
local M={}
local function Vec(a) return Coord.Vec(a[1],a[2],a[3]) end
function M.Install(v)
    v.staticContacts={};v.native.collisionEventMode=COLLISION_ALWAYS
    local receiver=v.node:CreateScriptObject('LuaScriptObject')
    receiver:SubscribeToEvent(v.node,'NodeCollision',function(_,_,data)
        local other=data['OtherBody']:GetPtr('RigidBody')
        if not other or other.mass~=0 or other.kinematic or other.trigger then return end
        local buffer=data['Contacts']:GetBuffer()
        while not buffer.eof do
            local point=buffer:ReadVector3();local normal=buffer:ReadVector3();local distance=buffer:ReadFloat();buffer:ReadFloat()
            if distance<=.06 then v.staticContacts[#v.staticContacts+1]={point={-point.x,point.y,point.z},normal={-normal.x,normal.y,normal.z},body=other} end
        end
    end)
    v.slideReceiver=receiver
end
function M.Prepare(v,cmd,dt,frame)
    v.slideBefore=nil;v.telemetry.obstacleSlide=nil
    local t=v.telemetry;local belly=false
    for _,c in ipairs(v.staticContacts) do if v.slideStep and c.body==v.slideStep.body and c.normal[2]>.65 then belly=true end end
    local excluded=Config.OBSTACLE_SLIDE==false or cmd.handbrake or t.legJumped or t.mechJet or (t.wingLift or 0)>0
        or v.flightTarget~=nil or v.drill and v.drill:ControlsBody()
    if excluded then v.slideStep=nil end
    if not excluded and ((t.contact or 0)>0 or (t.hovers or 0)>0 or (t.legContacts or 0)>0 or belly) and frame.up[2]>.8 then
        local f=frame.fwd;local throttle,strafe=cmd.throttle or 0,cmd.strafe or 0
        local wish={f[1]*throttle+f[3]*strafe,0,f[3]*throttle-f[1]*strafe};local length=V.Length(wish)
        if length>.1 then
            v.slideBefore={dt=dt,wish=V.Scale(wish,1/length),velocity=V.Array(v.body.linvel()),expected=v.body.predictedAngvel(dt)}
        else v.slideStep=nil end
    end
    v.staticContacts={}
end
function M.Clear(v,from,move)
    local length=V.Length(move);if length<1e-6 then return true end
    local delta=Vec(move);local origin=v.native.position+Vec(from);local rotation=v.native.rotation
    local layer=v.native.collisionLayer;v.native.collisionLayer=0
    local ok,result=pcall(function()
        for _,shape in ipairs(v.node:GetComponents('CollisionShape',false)) do
            -- Native ConvexCast already applies CollisionShape position/rotation.
            local start=origin;local q=rotation
            local finish=start+delta
            local hit=v.space.world:ConvexCast(shape,start,q,finish,q,0x6fff)
            if hit.body and hit.distance<length-.002 and hit.normal:DotProduct(delta)<-1e-5 then return false end
            -- Reverse sweep rejects endpoint overlap as well as narrow intervening hulls.
            local back=v.space.world:ConvexCast(shape,finish,q,start,q,0x6fff)
            if back.body and back.distance<.002 and back.normal:DotProduct(-delta)<-1e-5 then return false end
        end
        return true
    end)
    v.native.collisionLayer=layer
    if not ok then error(result) end
    return result
end
function M.Finish(v)
    local before=v.slideBefore;v.slideBefore=nil
    if not before or v.disposed or v.drill and v.drill:ControlsBody() then return end
    local list={};local belly=false
    for _,c in ipairs(v.staticContacts) do
        if math.abs(c.normal[2])<=.65 and V.Dot(c.normal,before.wish)<-.025 then list[#list+1]=c end
        if v.slideStep and c.body==v.slideStep.body and c.normal[2]>.65 then belly=true end
    end
    local body=v.body;local velocity=body.linvel();local wish=before.wish
    if #list==0 then
        if belly then
            local crawl=V.Scale(wish,math.max(2,V.Dot(before.velocity,wish)))
            if M.Clear(v,{0,0,0},V.Scale(crawl,before.dt)) then
                body.setLinvel({x=crawl[1],y=math.min(velocity.y,math.max(1,before.velocity[2])),z=crawl[3]},true)
                body.setAngvel(before.expected,true);v.telemetry.obstacleSlide='belly';return
            end
        end
        v.slideClearTime=(v.slideClearTime or 0)+before.dt
        if v.slideClearTime>1 then v.slideStep=nil end
        return
    end
    v.slideClearTime=0
    local p=V.Array(body.translation());local speed=math.max(.8,V.Dot(before.velocity,wish))
    local forward=V.Scale(wish,V.Clamp(speed*before.dt,.12,.55));local radius=.5
    for _,wheel in ipairs(v.wheels) do radius=math.max(radius,wheel.radius) end
    local maxStep=v.hoverMode and .85 or V.Clamp(radius*.45,.25,.45)
    local ceiling=p[2]+maxStep
    for _,c in ipairs(list) do if v.slideStep and v.slideStep.body==c.body then ceiling=v.slideStep.ceiling;break end end
    local needed=math.huge
    if not v.hoverMode then for _,c in ipairs(list) do
        local at={c.point[1]-c.normal[1]*.12,c.point[2]+maxStep+.1,c.point[3]-c.normal[3]*.12}
        local hit=v.space:Raycast(at,{0,-1,0},maxStep+.1,body,nil,true)
        if hit and hit.body.native==c.body and hit.dist>=.05 and hit.normal[2]>=.65 then
            needed=math.min(needed,math.max(.1,hit.point[2]-math.min(c.point[2],p[2]+v.spec.bounds.min[2])+.08))
        end
    end end
    local correction,mode
    local heights=v.hoverMode and {.15,.3,.5,.7,.85} or {needed,needed+.1,maxStep}
    for _,height in ipairs(heights) do
        if (v.hoverMode or needed<math.huge and height>=needed) and height<=maxStep+.001 and p[2]+height<=ceiling+.001 then
            local up={0,height,0}
            if M.Clear(v,{0,0,0},up) and M.Clear(v,up,forward) then
                correction=V.Add(up,forward);mode='step';v.slideStep={body=list[1].body,ceiling=ceiling};break
            end
        end
    end
    if not correction then
        local side={wish[3],0,-wish[1]};local offset=V.Dot(V.Sub(list[1].point,p),side)
        local width=v.spec.bounds.max[1]-v.spec.bounds.min[1]
        if math.abs(offset)>width*.25 then
            for _,amount in ipairs({.15,.35,.7,1.1}) do
                local move=V.Scale(side,(offset>0 and -1 or 1)*amount)
                if M.Clear(v,{0,0,0},move) and M.Clear(v,move,forward) then correction=V.Add(move,forward);mode='corner';break end
            end
        end
    end
    if correction then
        local at=V.Add(p,correction);body.setTranslation({x=at[1],y=at[2],z=at[3]},true)
        body.setLinvel({x=wish[1]*speed,y=math.min(velocity.y,0),z=wish[3]*speed},true)
    else
        local slide={before.velocity[1],0,before.velocity[3]}
        for _=1,3 do for _,c in ipairs(list) do
            local n={c.normal[1],0,c.normal[3]};local into=V.Dot(slide,n)
            if into<0 then slide=V.Add(slide,V.Scale(n,-into/V.Dot(n,n))) end
        end end
        if V.Length(slide)<.25 or V.Dot(slide,wish)<.1 or not M.Clear(v,{0,0,0},V.Scale(slide,before.dt)) then return end
        body.setLinvel({x=slide[1],y=velocity.y,z=slide[3]},true);mode='slide'
    end
    local w=body.angvel();local e=before.expected
    body.setAngvel({x=e.x+(w.x-e.x)*.1,y=e.y+(w.y-e.y)*.1,z=e.z+(w.z-e.z)*.1},true)
    v.telemetry.obstacleSlide=mode
end
return M

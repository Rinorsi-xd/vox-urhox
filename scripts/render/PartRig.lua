-- Joint hierarchy uses source pivots. Display state never supplies physics/damage.
local Coord=require "core.Coord"
local Materials=require "parts.Materials"
local Config=require "Config"
local WeaponPresentation=require 'render.WeaponPresentation'
local M={}
local function Vec(v) return Coord.Vec(v[1],v[2],v[3]) end
local function Group(parent,name,p)
    local node=parent:CreateChild(name)
    if p then node.position=Vec(p) end
    return node
end
local function Attach(parent,data,part,vis)
    if not data or not data.layers then return end
    for _,layer in ipairs(data.layers) do
        local sm=parent:CreateComponent("StaticModel")
        sm.model=require('parts.PartAssets').Model(layer)
        local dynamic=false
        for i,slot in ipairs(layer.slots) do
            local emission=vis.emissionSlot==slot;dynamic=dynamic or emission
            local weapon=vis.weaponMaterials and WeaponPresentation.slots[slot]
            sm:SetMaterial(i-1,weapon and WeaponPresentation.Material(vis,slot) or emission and Materials.DynamicEmission(slot) or Materials.Get(slot,vis.instanced))
            if slot=='armorWhite' then vis.shellSlots[#vis.shellSlots+1]={model=sm,index=i-1} end
        end
        if dynamic then sm.instanceCustomData=Vector4(vis.emissionDefault,0,0,0);vis.emissionModels[#vis.emissionModels+1]=sm end
        if vis.weaponMaterials then
            -- Base geometry already uses authored weapon coordinates; the part's
            -- placement within its vehicle must never offset angular energy flow.
            local base=parent==vis.node;local p=base and Vector3.ZERO or parent.position
            sm.instanceCustomData=Vector4(-p.x,p.y,p.z,base and 1 or 0)
        end
        sm.castShadows=layer.shadow
        if vis.instanced then vis.materialSlots[sm]=layer.slots end
        sm.instanceColor=Config.HexLinear(part.color,vis.variation)
        vis.models[#vis.models+1]=sm
        vis.resources[#vis.resources+1]=layer.model
    end
end
function M.Build(node,data,part,vis)
    local s=data.segments
    vis.data=data;vis.rig={};vis.shellSlots={};vis.materialSlots={}
    if data.weapon and data.weapon~=cjson.null and (part.type:match('^mg%d+$') or part.type:match('^laser%d+$') or part.type:match('^sniper%d+$') or part.type:match('^missile%d+$')) then
        WeaponPresentation.Create(vis,part.type)
    end
    vis.emissionModels={}
    if s and s~=cjson.null then
        vis.emissionSlot=(s.thruster or s.hover) and 'glowBlue' or s.leg and 'legJumpGlow' or nil
        vis.emissionDefault=s.thruster and 1.5 or s.hover and 0 or 2.8
    end
    local r=vis.rig
    local function Add(n,d) Attach(n,d,part,vis) end
    if not s or s==cjson.null or s.mech or s.wing then Add(node,data.whole);return end
    if s.wheel then
        Add(node,s.mount);r.steer=Group(node,"Steer")
        if s.knuckle then Add(Group(r.steer,"Knuckle",data.wheel.kingpin),s.knuckle) end
        r.spin=Group(r.steer,"Wheel",data.wheel.hub);Add(r.spin,s.spin)
    elseif s.track then
        Add(node,s.frame);r.pads={};r.wheels={}
        for _,kind in ipairs(s.pads) do for _,index in ipairs(kind.idx) do
            local n=Group(node,"Pad"..index);Add(n,kind.model);r.pads[#r.pads+1]={node=n,index=index}
        end end
        for _,list in ipairs({s.wheels,s.rings}) do for _,w in ipairs(list) do
            local n=Group(node,"Wheel",w.c);Add(n,w.model);r.wheels[#r.wheels+1]={node=n,r=w.r}
        end end
        M.SetTrack(vis,0)
    elseif s.thruster then
        Add(node,s.mount);r.gimbal=Group(node,"Gimbal",s.pivot)
        local housing=Group(r.gimbal,"Housing",{-s.pivot[1],-s.pivot[2],-s.pivot[3]});Add(housing,s.base)
        r.housing=housing
        r.rotors={};for _,v in ipairs(s.rotors) do local n=Group(housing,v.name,v.origin);Add(n,v.model);r.rotors[#r.rotors+1]=n end
    elseif s.hover then
        Add(node,s.base);r.rings={}
        for _,v in ipairs(s.rings) do local n=Group(node,v.name,v.origin);Add(n,v.model);r.rings[#r.rings+1]=n end
    elseif s.leg then
        r.joints={};local parents={hip="base",link1="hip",link2="link1",blade="link2"}
        for _,name in ipairs({"base","hip","link1","link2","blade"}) do
            local parent=parents[name];local p=s.info.origins[name];local q=parent and s.info.origins[parent] or {0,0,0}
            local n=Group(parent and r.joints[parent] or node,name,{p[1]-q[1],p[2]-q[2],p[3]-q[3]})
            r.joints[name]=n;Add(n,s.segments[name])
        end
    else
        Add(node,s.base);r.head=Group(node,"Head");vis.head=r.head;Add(r.head,s.head)
        if s.spin and data.weapon and data.weapon~=cjson.null then r.spin=Group(r.head,"BarrelSpin",data.weapon.spin);Add(r.spin,s.spin) end
        r.parts={}
        local function Parts(parent,list)
            for _,p in ipairs(list or {}) do
                local n=Group(parent,p.name,p.origin);Add(n,p.model)
                r.parts[#r.parts+1]={node=n,definition=p}
            end
        end
        Parts(r.head,s.parts)
        if s.pod then r.pod=Group(r.head,'Pod');Add(r.pod,s.pod);Parts(r.pod,s.podParts) end
    end
end
function M.SetTrack(vis,distance)
    local s,r=vis.data.segments,vis.rig
    local path=s.path
    for _,pad in ipairs(r.pads) do
        local t=((pad.index+0.5)*s.spacing+distance)%path.total
        local segment=path.segs[#path.segs]
        for _,g in ipairs(path.segs) do if t<g.s0+g.len then segment=g;break end end
        local u=t-segment.s0
        local x,z,nx,nz
        if segment.arc then
            local a=segment.a0+u/segment.R;nx,nz=math.cos(a),math.sin(a)
            x,z=segment.cx+segment.R*nx,segment.cz+segment.R*nz
        else nx,nz=segment.n[1],segment.n[2];x,z=segment.p0[1]-nz*u,segment.p0[2]+nx*u end
        pad.node.position=Vector3(-x,0,z)
        pad.node.rotation=Quaternion(Vector3(-nz,0,-nx),Vector3(-nx,0,nz),Vector3(0,1,0))
    end
    for _,w in ipairs(r.wheels) do w.node.rotation=Quaternion(-distance/w.r*180/math.pi,Vector3.UP) end
end
-- Arguments are simulation state, never keyboard inputs or elapsed demo time.
function M.SetWheel(vis,up,suspension,steer,roll)
    local r=vis.rig
    local kp=Vec(vis.data.wheel.kingpin or vis.data.wheel.hub)
    local axis=Vec(up)
    local rotation=Quaternion(-steer*180/math.pi,axis)
    r.steer.rotation=rotation
    r.steer.position=kp-rotation*kp+axis*suspension
    r.spin.rotation=Quaternion(-roll*180/math.pi,Vector3.UP)
end
function M.SetWeapon(vis,yaw,pitch,spin,recoil,kick)
    local p=Vec(vis.data.weapon.pivot)
    local turn=Quaternion(-yaw*180/math.pi,Vector3.UP)
    local tilt=Quaternion(-(pitch+(kick or 0))*180/math.pi,Vector3.RIGHT)
    if vis.rig.pod then
        vis.rig.head.rotation=turn;vis.rig.head.position=p-turn*p
        local pivot=Vec(vis.data.weapon.tilt)
        vis.rig.pod.rotation=tilt;vis.rig.pod.position=pivot-tilt*(pivot+Vector3(0,0,recoil or 0))
    else
        local rotation=turn*tilt
        vis.rig.head.rotation=rotation;vis.rig.head.position=p-rotation*(p+Vector3(0,0,recoil or 0))
    end
    if vis.rig.spin then vis.rig.spin.rotation=Quaternion(-spin*180/math.pi,Vector3.FORWARD) end
end
function M.SetLegTarget(vis,target,bladeAngle)
    local pose=require("parts.LegIK").Solve(vis.data.segments.info,target,bladeAngle)
    local j=vis.rig.joints
    j.hip.rotation=Quaternion(-pose.yaw*180/math.pi,Vector3.UP)
    j.link1.rotation=Quaternion(-pose.first*180/math.pi,Vector3.FORWARD)
    j.link2.rotation=Quaternion(-pose.second*180/math.pi,Vector3.FORWARD)
    j.blade.rotation=Quaternion(-pose.blade*180/math.pi,Vector3.FORWARD)
    return pose
end
return M

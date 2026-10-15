-- Source vehicle.stepRotors. State is keyed by persistent part ID across damage
-- rebuilds; nested poses are evaluated outer first, then shared by all consumers.
local R=require 'construction.Rotors'
local V=require 'core.Math3'
local M={}
local TAU=math.pi*2
local function Wrap(a) return a-math.floor(a/TAU+.5)*TAU end
function M.New(specs)
    local out={};for _,s in ipairs(specs or {}) do local r={};for k,v in pairs(s) do r[k]=v end
        r.angle=0;r.prev=0;r.target=0;r.pose=R.IDENT;r.loadSet={};r.ownSet={}
        for _,id in ipairs(r.load) do r.loadSet[id]=true end;for _,id in ipairs(r.own) do r.ownSet[id]=true end
        out[#out+1]=r
    end;return out
end
function M.Poses(rotors)
    for _,r in ipairs(rotors) do local up=r.parent and rotors[r.parent]
        r.pose=R.Pose(up and up.pose or R.IDENT,r.pivot,r.axis,r.angle);r.moved=r.angle~=0 or up and up.moved or false
    end
end
function M.Step(rotors,localAim,step,dt)
    for _,r in ipairs(rotors) do
        r.prev=r.angle;local a=r.angle;local range=r.range;local lim=not range.free;local stuck=lim and range.hi-range.lo<2*R.RANGE_STEP
        local function Bounce(dir,room) r.bounce={t=0,rest=r.target,amp=dir*V.Clamp(room,math.pi/18,math.pi/10)} end
        if r.bounce then
            r.bounce.t=r.bounce.t+dt;local k=r.bounce.t/.4
            a=k>=1 and r.bounce.rest or r.bounce.rest+r.bounce.amp*math.sin(math.pi*k)
            if k>=1 then r.bounce=nil end
        elseif r.mode=='spin' then
            if not lim then a=a+R.SPEED.spin*dt
            elseif stuck then Bounce(1,range.hi-a)
            else
                r.swing=r.swing or 1;a=a+r.swing*R.SPEED.spin*dt
                if a>=range.hi then a=range.hi;r.swing=-1 end
                if a<=range.lo then a=range.lo;r.swing=1 end
            end;r.target=a
        else
            if r.mode=='aim' and localAim then
                local lp=r.parent and R.Inverse(rotors[r.parent].pose,localAim) or localAim
                local p=V.Reject(V.Sub(lp,r.pivot),r.axis)
                if V.Length(p)>.5 then local want=math.atan(V.Dot(r.axis,V.Cross(r.ref,p)),V.Dot(r.ref,p))
                    if not lim then r.target=a+Wrap(want-a)
                    else
                        local inside=nil ---@type number|nil
                        for _,candidate in ipairs({want,want-TAU,want+TAU}) do if candidate>=range.lo and candidate<=range.hi then inside=candidate;break end end
                        r.target=inside or (math.abs(Wrap(want-range.lo))<math.abs(Wrap(want-range.hi)) and range.lo or range.hi)
                        local delta=Wrap(want-a)
                        if stuck and math.abs(delta)>.35 and not r.nudged then
                            r.nudged=true;Bounce(delta>0 and 1 or -1,delta>0 and range.hi-a or a-range.lo)
                        elseif math.abs(delta)<.2 then r.nudged=false end
                    end
                end
            elseif r.mode=='step' and step then
                if not lim then r.target=r.target+math.pi/2
                else
                    local spots={};local k=math.ceil((range.lo-1e-6)/(math.pi/2))
                    while k*math.pi/2<=range.hi+1e-6 do spots[#spots+1]=k*math.pi/2;k=k+1 end
                    local nextSpot=nil ---@type number|nil
                    for _,s in ipairs(spots) do if s>r.target+1e-6 then nextSpot=s;break end end
                    if nextSpot then r.target=nextSpot elseif #spots>1 then r.target=spots[1] else Bounce(1,range.hi-r.target) end
                end
            end
            if not r.bounce then a=V.Approach(a,r.target,R.SPEED[r.mode]*dt) end
        end
        if math.abs(a)>4*math.pi then local k=math.floor(a/TAU+.5)*TAU;a=a-k;r.target=r.target-k;r.prev=r.prev-k end
        r.angle=a;r.pose=R.Pose(r.parent and rotors[r.parent].pose or R.IDENT,r.pivot,r.axis,a)
    end
    M.Poses(rotors)
end
function M.Snapshot(rotors)
    local out={};for _,r in ipairs(rotors) do out[r.partId]={angle=r.angle,target=r.target,swing=r.swing} end;return out
end
function M.Restore(rotors,state)
    for _,r in ipairs(rotors) do local s=state and (state[r.partId] or state[tostring(r.partId)])
        r.angle=s and s.angle or 0;r.target=s and s.target or 0;r.prev=r.angle;r.swing=s and s.swing or nil;r.bounce=nil;r.nudged=false
    end;M.Poses(rotors)
end
function M.Follow(rotors,list,points,directions,quats)
    for _,o in ipairs(list or {}) do if o.rotor then local pose=rotors[o.rotor].pose
        if not o.rotorBase then local b={};for _,keys in ipairs({points or {},directions or {},quats or {}}) do for _,k in ipairs(keys) do b[k]=o[k] end end
            if o.emits then b.emits={};for i,e in ipairs(o.emits) do b.emits[i]=e.pos end end;o.rotorBase=b
        end
        local b=o.rotorBase
        for _,k in ipairs(points or {}) do if b[k] then o[k]=R.Apply(pose,b[k]) end end
        for _,k in ipairs(directions or {}) do if b[k] then o[k]=V.Rotate(pose.q,b[k]) end end
        for _,k in ipairs(quats or {}) do o[k]=V.QMul(pose.q,b[k] or R.IDENT.q) end
        if b.emits then for i,e in ipairs(o.emits) do e.pos=R.Apply(pose,b.emits[i]) end end
    end end
end
function M.Weapons(rotors,weapons)
    if #rotors==0 or not weapons then return end
    for _,g in ipairs(weapons.groups) do M.Follow(rotors,g.weapons,{'pivot','muzzle'},{'dir'},{'quat'}) end
end
return M

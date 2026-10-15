-- Frozen testDrive._focusPick/_aimTarget; selection is independent of aim assist.
local Coord=require 'core.Coord'
local M={}
local function Hostile(ref,me)
    return ref and ref~=me and ref.alive and ref.spec and (not me or ref.team~=me.team)
end
function M.Project(camera,pos,w,h,strictFar)
    if not pos then return end
    local point=Coord.Vec(pos[1],pos[2],pos[3])
    local depth=camera.node:WorldToLocal(point).z
    -- Source projected z rejects behind/far targets, but does not clip screen XY.
    if depth<=0 or depth>camera.farClip or strictFar and depth>=camera.farClip then return end
    local uv=camera:WorldToScreenPoint(point)
    return uv.x*w,uv.y*h,(point-camera.node.worldPosition):Length()
end
function M.Pick(s,camera,w,h)
    local me=s.combat and s.combat.player or s.assistPlayer
    local function Valid(ref)
        return Hostile(ref,me) or ref and ref.team=='neutral' and ref.alive and ref.spec
    end
    local function Screen(ref)
        local x,y,d=M.Project(camera,ref:Position(),w,h,true)
        if not x then return math.huge,d end
        return math.sqrt((x-w/2)^2+(y-h/2)^2),d
    end
    local keep=s.focusRef
    if Valid(keep) and Screen(keep)<h*.25 then return keep end
    local best=false;local closest=h*.13
    for _,ref in ipairs(s.world.combatUnits or s.world.units or {}) do
        if Valid(ref) then
            local distance,range=Screen(ref)
            if range and range<=1000 and distance<closest then best=ref;closest=distance end
        end
    end
    return best or nil
end
function M.Resolve(o,dt,camera,w,h)
    local s=o.session;local me=s.combat and s.combat.player or s.assistPlayer
    if me and me.alive==false then
        s.focusRef=nil;o.focusHold=nil;o.focusHoldTime=0;return
    end
    local owner=s.aimHit and s.aimHit.owner
    local ref=s.aimRef or owner and owner.ref
    if s.scope and not Hostile(ref,me) then ref=M.Pick(s,camera,w,h) end
    s.focusRef=s.scope and ref or nil
    if Hostile(ref,me) then o.focusHold=ref;o.focusHoldTime=.5
    else
        o.focusHoldTime=(o.focusHoldTime or 0)-dt
        if o.focusHoldTime<=0 then o.focusHold=nil end
    end
    local held=o.focusHold
    return held and held.alive and held or nil
end
return M

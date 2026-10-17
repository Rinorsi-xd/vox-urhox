-- Functional story diagnostics only: at most four rays per explicitly requested dump.
-- These instantaneous straight rays are not actual shot results or performance samples.
local storyCombatSessions=setmetatable({},{__mode='k'})
local function StoryCopy(p) return p and {p[1],p[2],p[3]} or nil end
function G0_StoryCombatState(session,data)
    local mission=session and session.story
    if not mission or not mission.player then return nil end
    local ids=storyCombatSessions[mission]
    if not ids then ids={next=1,units=setmetatable({},{__mode='k'})};storyCombatSessions[mission]=ids end
    local function Id(unit)
        if not unit then return nil end
        if unit==mission.player then return 0 end
        if not ids.units[unit] then ids.units[unit]=ids.next;ids.next=ids.next+1 end
        return ids.units[unit]
    end
    local function State(unit,parts)
        return {id=Id(unit),name=unit.name,team=unit.team,alive=unit.alive,
            pos=StoryCopy(unit.pos),parts=parts,hullEnabled=unit.hull~=nil,
            bodyHp=unit.bodyHp,bodyHpMax=unit.bodyHpMax,struct=unit.struct,structMax=unit.structMax,
            hitAt=unit.hitAt,kill=unit.kill}
    end
    local function Hit(hit)
        if not hit then return false end
        local owner=hit.owner
        local native=hit.body and hit.body.native
        return {distance=hit.dist,point=StoryCopy(hit.point),normal=StoryCopy(hit.normal),
            collider=hit.collider,node=native and native.node and native.node.name,
            ownerType=owner and owner.type,unitId=owner and owner.type=='car' and Id(owner.ref) or nil,
            name=owner and owner.ref and owner.ref.name,partId=hit.partId or owner and owner.partId}
    end
    local out={phase='post-update-query',worldTime=session.world.time,units={},rays=0,
        aimPoint=StoryCopy(session.aimPoint),aimUnitId=Id(session.aimRef),cameraHit=Hit(session.aimHit),
        firing=session.firing==true,player=State(mission.player),muzzles={}}
    local targetIndex=0
    for _,unit in ipairs(session.world.units) do
        if unit~=mission.player and unit.alive then
            targetIndex=targetIndex+1
            local target=data.aimTargets and data.aimTargets[targetIndex]
            local state=State(unit,target and target.parts)
            if target then target.unitId=state.id end
            if #out.units<32 then out.units[#out.units+1]=state else out.unitsTruncated=true end
        end
    end
    local system,vehicle=session.weapons,mission.player.vehicle
    if not system or not vehicle or not mission.player.alive then return out end
    local group=system:Group();out.group=group and group.kind;out.selected=system.current
    out.offline=system.offline;out.energy=system.energy;out.totalWeapons=group and #group.weapons or 0
    local body=vehicle.body;local p=body.translation()
    local state={pos={p.x,p.y,p.z},quat=body.rotation(),aim=session.aimPoint,body=body}
    for index,weapon in ipairs(group and group.weapons or {}) do
        if index>4 then break end
        local muzzle=system:Muzzle(weapon,state)
        local sample={id=weapon.id,type=weapon.type,pos=StoryCopy(muzzle.pos),turretDir=StoryCopy(muzzle.dir),
            yaw=weapon.yaw,pitch=weapon.pitch,error=weapon.err,limited=weapon.limited,
            aligned=system:Aligned(weapon),cool=weapon.cool,shotAt=weapon.shotAt,
            query='not-probed-special-or-missing-aim'}
        out.muzzles[#out.muzzles+1]=sample
        if state.aim and not weapon.stats.homing and not weapon.stats.drill then
            local dx,dy,dz=state.aim[1]-muzzle.pos[1],state.aim[2]-muzzle.pos[2],state.aim[3]-muzzle.pos[3]
            local length=math.sqrt(dx*dx+dy*dy+dz*dz)
            local reach=weapon.stats.reach or weapon.stats.range
            if length>0 and reach and reach>0 then
                local dir={dx/length,dy/length,dz/length}
                sample.query='instantaneous-center-shot-ray-no-spread';sample.aimDistance=length
                sample.direction=dir;sample.length=reach
                sample.hit=Hit(session.world:CastRay(muzzle.pos,dir,reach,body));out.rays=out.rays+1
            end
        end
    end
    return out
end

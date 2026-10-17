-- Lifecycle/filter comparison only; native timing and hit equivalence run separately.
local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
Vector3=function(x,y,z)return{x=x,y=y,z=z}end
Ray=function(origin,direction)return{origin=origin,direction=direction}end
package.loaded['core.Coord']={Vec=Vector3}
package.loaded['physics.Body']={Wrap=function(native)
    local wrapper={native=native,valid=true}
    wrapper.invalidate=function()wrapper.valid=false;wrapper.native=nil end
    return wrapper
end}
local function Exercise(source)
    local Space=assert(load(source,'@ray-body-cache-check'))()
    local world={results={}}
    function world:Raycast() return self.results end
    local scene={GetComponent=function()return world end}
    local space=Space.New(scene);local idCalls=0
    local function Native(id,mass,kinematic,trigger)
        return{node={GetID=function()idCalls=idCalls+1;return id end},mass=mass or 0,
            kinematic=kinematic or false,trigger=trigger or false}
    end
    local ground,car,trigger,moving=Native(1),Native(2,10),Native(3,0,false,true),Native(4,0,true)
    local function Hit(native,dist)
        return{body=native,distance=dist,position=Vector3(-1,2,3),normal=Vector3(0,1,0)}
    end
    local registered=space:Register(ground,{type='ground'})
    local own=space:Register(car,{type='car'})
    space:Register(trigger,{type='trigger'});space:Register(moving,{type='platform'})
    local result={}
    local function Cast(name,excluded,skip,fixed)
        local hit=space:Raycast({0,0,0},{0,-1,0},10,excluded,skip,fixed)
        result[#result+1]={name=name,collider=hit and hit.collider or false,
            dist=hit and hit.dist or false,owner=hit and hit.owner and hit.owner.type or false,
            point=hit and hit.point or false,normal=hit and hit.normal or false}
        return hit
    end
    world.results={Hit(ground,1)}
    local before=idCalls
    for _=1,20 do Check(Cast('registered').body==registered,'registered wrapper identity') end
    result.lookupIdCalls=idCalls-before
    space:SetOwner(ground,{type='changed'});Cast('owner replacement')
    world.results={Hit(trigger,.1),Hit(car,.2),Hit(moving,.3),Hit(ground,.4)}
    Cast('excluded and fixed',own,nil,true)
    Cast('owner skipped',nil,'car',false)
    Cast('skip last owner',own,'changed',true)
    world.results={};Cast('no hit')
    -- An externally invalidated old wrapper must not break replacement registration.
    registered.invalidate();registered=space:Register(ground,{type='replacement'})
    world.results={Hit(ground,1)}
    Check(Cast('reregister').body==registered,'reregister replaces wrapper')
    -- A replaced canonical entry must win over any cached native association.
    local replacement={body=package.loaded['physics.Body'].Wrap(ground),owner={type='canonical'}}
    space.bodies[1]=replacement
    Check(Cast('canonical replacement').body==replacement.body,'canonical map remains authoritative')
    space:Unregister(ground)
    Check(not replacement.body.native or not replacement.body.valid,'unregister invalidates wrapper')
    Cast('unregistered fallback')
    space:Dispose()
    Check(next(space.bodies)==nil and (not space.nativeBodies or next(space.nativeBodies)==nil),'dispose releases maps')
    return result
end
local baseline=Exercise(baselineSource)
local candidate=Exercise(candidateSource)
local function Same(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if k~='lookupIdCalls' and not Same(v,b[k])then return false end end
    for k in pairs(b)do if k~='lookupIdCalls' and a[k]==nil then return false end end
    return true
end
Check(Same(baseline,candidate),'all lifecycle and filter outcomes equal')
Check(candidate.lookupIdCalls==0 and baseline.lookupIdCalls==20,'registered queries avoid ID binding')
return checks
